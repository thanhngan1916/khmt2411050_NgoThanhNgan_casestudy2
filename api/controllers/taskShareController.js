
const mongoose = require('mongoose');

const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');
const { sendTaskSharedEmail } = require('../services/emailService');

// Kiểm tra ID hợp lệ
const isValidId = (id) => {
  return mongoose.Types.ObjectId.isValid(id);
};

// Chỉ người tạo công việc mới được quản lý chia sẻ
const getOwnedTask = async (taskId, userId) => {
  if (!isValidId(taskId)) {
    return null;
  }

  return Task.findOne({
    _id: taskId,
    userId: userId,
  });
};

// 1. Xem danh sách người được chia sẻ
const getTaskShares = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;

    const task = await getOwnedTask(id, userId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền quản lý chia sẻ',
      });
    }

    const shares = await TaskShare.find({
      taskId: id,
    })
      .populate('userId', 'fullName email')
      .populate('sharedBy', 'fullName email')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lấy danh sách chia sẻ thành công',
      shares,
    });
  } catch (error) {
    console.error('Lỗi lấy danh sách chia sẻ:', error);

    return res.status(500).json({
      message: 'Không thể lấy danh sách chia sẻ',
      error: error.message,
    });
  }
};

// 2. Chia sẻ công việc cho một hoặc nhiều người
const shareTask = async (req, res) => {
  try {
    console.log('========== DA GOI HAM shareTask ==========');
    const { id } = req.params;
    const currentUserId = req.user.id;

    const { userIds, permission = 'viewer' } = req.body;

    const task = await getOwnedTask(id, currentUserId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền chia sẻ',
      });
    }

    if (
      !Array.isArray(userIds) ||
      userIds.length === 0
    ) {
      return res.status(400).json({
        message: 'Vui lòng chọn ít nhất một người để chia sẻ',
      });
    }

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        message: 'Quyền chia sẻ không hợp lệ',
      });
    }

    // Kiểm tra định dạng ID
    if (!userIds.every((id) => isValidId(id))) {
      return res.status(400).json({
        message: 'Có ID người dùng không hợp lệ',
      });
    }

    // Loại bỏ ID trùng nhau trong yêu cầu
    const uniqueUserIds = [
      ...new Set(userIds.map((id) => id.toString())),
    ];

    // Không cho phép chia sẻ cho chính người tạo
    if (uniqueUserIds.includes(currentUserId.toString())) {
      return res.status(400).json({
        message: 'Không thể chia sẻ công việc cho chính mình',
      });
    }

    // Kiểm tra người dùng có tồn tại
   const users = await User.find({
     _id: { $in: uniqueUserIds },
   }).select('_id fullName email');

    if (users.length !== uniqueUserIds.length) {
      return res.status(400).json({
        message: 'Có người dùng không tồn tại',
      });
    }

    // Kiểm tra những người đã được chia sẻ trước đó
    const existingShares = await TaskShare.find({
      taskId: id,
      userId: { $in: uniqueUserIds },
    }).select('userId');

    const existingIds = existingShares.map(
      (share) => share.userId.toString()
    );

    const newUserIds = uniqueUserIds.filter(
      (userId) => !existingIds.includes(userId)
    );

    if (newUserIds.length === 0) {
      return res.status(409).json({
        message: 'Tất cả người được chọn đã có quyền truy cập công việc',
      });
    }

    // Tạo bản ghi chia sẻ
    const shareData = newUserIds.map((userId) => ({
      taskId: id,
      userId,
      permission,
      sharedBy: currentUserId,
    }));

    await TaskShare.insertMany(shareData);

    // Đồng bộ danh sách sharedWith trong Task
    await Task.updateOne(
      { _id: id },
      {
        $addToSet: {
          sharedWith: { $each: newUserIds },
        },
      }
    );
    // Gửi email mời những người vừa được chia sẻ công việc
    const creator = await User.findById(currentUserId).select('fullName');

    const newRecipients = users.filter((user) =>
      newUserIds.includes(user._id.toString())
    );

    console.log('Số người vừa được chia sẻ:', newUserIds.length);
    console.log('Số người nhận email:', newRecipients.length);

    const emailResults = await Promise.allSettled(
      newRecipients.map((recipient) =>
        sendTaskSharedEmail({
          task,
          recipient,
          creatorName: creator?.fullName || 'Người dùng Task Manager',
          permission,
        })
      )
    );

    emailResults.forEach((result, index) => {
      if (result.status === 'rejected') {
        console.error(
          `Lỗi gửi email cho người nhận thứ ${index + 1}:`,
          result.reason
        );
      } else {
        console.log(`Đã xử lý gửi email cho người nhận thứ ${index + 1}`);
      }
    });

    const shares = await TaskShare.find({
      taskId: id,
      userId: { $in: newUserIds },
    })
      .populate('userId', 'fullName email')
      .populate('sharedBy', 'fullName email');

    return res.status(201).json({
      message: 'Chia sẻ công việc thành công',
      createdCount: shares.length,
      skippedCount: existingIds.length,
      shares,
    });
  } catch (error) {
    console.error('Lỗi chia sẻ công việc:', error);

    return res.status(500).json({
      message: 'Không thể chia sẻ công việc',
      error: error.message,
    });
  }
};

// 3. Thay đổi quyền chia sẻ
const updateTaskShare = async (req, res) => {
  try {
    const { id, shareId } = req.params;
    const userId = req.user.id;
    const { permission } = req.body;

    const task = await getOwnedTask(id, userId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền quản lý chia sẻ',
      });
    }

    if (!isValidId(shareId)) {
      return res.status(400).json({
        message: 'ID chia sẻ không hợp lệ',
      });
    }

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        message: 'Quyền chia sẻ chỉ được là viewer hoặc editor',
      });
    }

    const share = await TaskShare.findOneAndUpdate(
      {
        _id: shareId,
        taskId: id,
      },
      {
        permission,
      },
      {
        new: true,
        runValidators: true,
      }
    )
      .populate('userId', 'fullName email')
      .populate('sharedBy', 'fullName email');

    if (!share) {
      return res.status(404).json({
        message: 'Không tìm thấy thông tin chia sẻ',
      });
    }

    return res.status(200).json({
      message: 'Cập nhật quyền chia sẻ thành công',
      share,
    });
  } catch (error) {
    console.error('Lỗi cập nhật quyền chia sẻ:', error);

    return res.status(500).json({
      message: 'Không thể cập nhật quyền chia sẻ',
      error: error.message,
    });
  }
};

// 4. Thu hồi quyền chia sẻ
const deleteTaskShare = async (req, res) => {
  try {
    const { id, shareId } = req.params;
    const userId = req.user.id;

    const task = await getOwnedTask(id, userId);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền quản lý chia sẻ',
      });
    }

    if (!isValidId(shareId)) {
      return res.status(400).json({
        message: 'ID chia sẻ không hợp lệ',
      });
    }

    const share = await TaskShare.findOneAndDelete({
      _id: shareId,
      taskId: id,
    });

    if (!share) {
      return res.status(404).json({
        message: 'Không tìm thấy thông tin chia sẻ',
      });
    }

    // Xóa khỏi sharedWith.
    // Nếu người này vẫn được giao công việc thì assignedTo
    // vẫn giữ quyền truy cập của họ.
    await Task.updateOne(
      { _id: id },
      {
        $pull: {
          sharedWith: share.userId,
        },
      }
    );

    return res.status(200).json({
      message: 'Thu hồi quyền chia sẻ thành công',
    });
  } catch (error) {
    console.error('Lỗi thu hồi quyền chia sẻ:', error);

    return res.status(500).json({
      message: 'Không thể thu hồi quyền chia sẻ',
      error: error.message,
    });
  }
};

module.exports = {
  getTaskShares,
  shareTask,
  updateTaskShare,
  deleteTaskShare,
};
