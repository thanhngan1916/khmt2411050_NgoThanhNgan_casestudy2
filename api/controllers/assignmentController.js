const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');
const { sendTaskAssignedEmail } = require('../services/emailService');

// Kiểm tra ObjectId hợp lệ
const isValidId = (id) => mongoose.Types.ObjectId.isValid(id);

// 1. Xem danh sách người được giao công việc
const getAssignees = async (req, res) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user.id;

    if (!isValidId(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Người tạo, người được giao hoặc người được chia sẻ
    // có thể xem danh sách người được giao.
    const task = await Task.findOne({
      _id: id,
      $or: [
        { userId: currentUserId },
        { assignedTo: currentUserId },
        { receivedBy: currentUserId },
        { sharedWith: currentUserId },
      ],
    })
      .populate('assignedTo', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email');

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xem',
      });
    }

    return res.status(200).json({
      message: 'Lấy danh sách người được giao thành công',
      assignees: task.assignedTo,
      primaryAssignee: task.primaryAssigneeId,
    });
  } catch (error) {
    console.error('Lỗi lấy danh sách người được giao:', error);

    return res.status(500).json({
      message: 'Không thể lấy danh sách người được giao',
    });
  }
};

// 2. Giao công việc cho một hoặc nhiều người
const assignTask = async (req, res) => {
  try {
    const { id } = req.params;
    const currentUserId = req.user.id;
    const { assigneeIds, primaryAssigneeId } = req.body;

    if (!isValidId(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Chỉ người tạo công việc mới được giao hoặc thay đổi người được giao.
    const task = await Task.findOne({
      _id: id,
      userId: currentUserId,
    });
    // Lưu danh sách người đã được giao trước đó để tránh gửi email trùng.
    const previousAssigneeIds = task
      ? task.assignedTo.map((userId) => userId.toString())
      : [];

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền giao việc',
      });
    }

    if (!Array.isArray(assigneeIds) || assigneeIds.length === 0) {
      return res.status(400).json({
        message: 'Vui lòng chọn ít nhất một người được giao',
      });
    }

    // Kiểm tra định dạng ID của từng người được chọn.
    if (!assigneeIds.every(isValidId)) {
      return res.status(400).json({
        message: 'Có ID người dùng không hợp lệ',
      });
    }

    // Loại bỏ ID trùng lặp.
    const uniqueIds = [
      ...new Set(assigneeIds.map((userId) => userId.toString())),
    ];

    // Kiểm tra những tài khoản được chọn có tồn tại hay không.
    const users = await User.find({
      _id: { $in: uniqueIds },
    }).select('_id fullName email');

    if (users.length !== uniqueIds.length) {
      return res.status(400).json({
        message: 'Có tài khoản người dùng không tồn tại',
      });
    }

    // Người phụ trách chính bắt buộc phải thuộc danh sách được giao.
    if (
      !primaryAssigneeId ||
      !isValidId(primaryAssigneeId) ||
      !uniqueIds.includes(primaryAssigneeId.toString())
    ) {
      return res.status(400).json({
        message: 'Vui lòng chọn người phụ trách chính trong danh sách người được giao',
      });
    }

    // Lưu danh sách người được giao.
    task.assignedTo = uniqueIds;

    // Đồng bộ danh sách nhận việc để tương thích với code danh sách công việc hiện tại.
    task.receivedBy = uniqueIds;

    // Lưu người phụ trách chính.
    task.primaryAssigneeId = primaryAssigneeId;

    await task.save();
    // Chỉ lấy những người mới được giao công việc.
    const newlyAssignedUsers = users.filter(
      (user) => !previousAssigneeIds.includes(user._id.toString())
    );

    // Lấy tên người tạo công việc.
    const creator = await User.findById(currentUserId).select('fullName');

    console.log('SO NGUOI MOI DUOC GIAO:', newlyAssignedUsers.length);
    console.log('DANH SACH EMAIL:', newlyAssignedUsers.map(user => user.email));

    // Gửi email cho những người mới được giao.
    try {
      await Promise.all(
        newlyAssignedUsers.map((recipient) =>
          sendTaskAssignedEmail({
            task,
            recipient,
            creatorName: creator ? creator.fullName : 'Người dùng',
          })
        )
      );
    } catch (emailError) {
      // Lỗi gửi email không làm mất kết quả giao công việc.
      console.error('Lỗi xử lý gửi email thông báo:', emailError);
    }

    await task.populate('assignedTo', 'fullName email');
    await task.populate('primaryAssigneeId', 'fullName email');

    return res.status(200).json({
      message: 'Giao công việc thành công',
      task: {
        _id: task._id,
        title: task.title,
        assignedTo: task.assignedTo,
        primaryAssignee: task.primaryAssigneeId,
      },
    });
  } catch (error) {
    console.error('Lỗi giao công việc:', error);

    return res.status(500).json({
      message: 'Không thể giao công việc',
    });
  }
};

// 3. Thay đổi người phụ trách chính
const updatePrimaryAssignee = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const currentUserId = req.user.id;

    if (!isValidId(id) || !isValidId(userId)) {
      return res.status(400).json({
        message: 'ID không hợp lệ',
      });
    }

    const task = await Task.findOne({
      _id: id,
      userId: currentUserId,
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền chỉnh sửa',
      });
    }

    const isAssignee = task.assignedTo.some(
      (assigneeId) => assigneeId.toString() === userId
    );

    if (!isAssignee) {
      return res.status(400).json({
        message: 'Người phụ trách chính phải nằm trong danh sách người được giao',
      });
    }

    task.primaryAssigneeId = userId;

    await task.save();

    await task.populate('assignedTo', 'fullName email');
    await task.populate('primaryAssigneeId', 'fullName email');

    return res.status(200).json({
      message: 'Cập nhật người phụ trách chính thành công',
      primaryAssignee: task.primaryAssigneeId,
    });
  } catch (error) {
    console.error('Lỗi cập nhật người phụ trách chính:', error);

    return res.status(500).json({
      message: 'Không thể cập nhật người phụ trách chính',
    });
  }
};

// 4. Hủy giao công việc cho một người
const removeAssignee = async (req, res) => {
  try {
    const { id, userId } = req.params;
    const currentUserId = req.user.id;

    if (!isValidId(id) || !isValidId(userId)) {
      return res.status(400).json({
        message: 'ID không hợp lệ',
      });
    }

    const task = await Task.findOne({
      _id: id,
      userId: currentUserId,
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền chỉnh sửa',
      });
    }

    const isAssignee = task.assignedTo.some(
      (assigneeId) => assigneeId.toString() === userId
    );

    if (!isAssignee) {
      return res.status(404).json({
        message: 'Người dùng này không nằm trong danh sách được giao',
      });
    }

    // Xóa người được chọn khỏi danh sách giao việc.
    task.assignedTo = task.assignedTo.filter(
      (assigneeId) => assigneeId.toString() !== userId
    );

    // Đồng bộ danh sách nhận việc.
    task.receivedBy = (task.receivedBy || []).filter(
      (receiverId) => receiverId.toString() !== userId
    );

    // Nếu hủy người phụ trách chính thì chọn người đầu tiên còn lại.
    if (
      task.primaryAssigneeId &&
      task.primaryAssigneeId.toString() === userId
    ) {
      task.primaryAssigneeId =
        task.assignedTo.length > 0 ? task.assignedTo[0] : null;
    }

    await task.save();

    await task.populate('assignedTo', 'fullName email');
    await task.populate('primaryAssigneeId', 'fullName email');

    return res.status(200).json({
      message: 'Hủy giao công việc thành công',
      task: {
        _id: task._id,
        assignedTo: task.assignedTo,
        primaryAssignee: task.primaryAssigneeId,
      },
    });
  } catch (error) {
    console.error('Lỗi hủy giao công việc:', error);

    return res.status(500).json({
      message: 'Không thể hủy giao công việc',
    });
  }
};

module.exports = {
  getAssignees,
  assignTask,
  updatePrimaryAssignee,
  removeAssignee,
};