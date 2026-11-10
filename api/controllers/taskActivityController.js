const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const TaskActivity = require('../models/TaskActivity');

// Lấy lịch sử hoạt động của công việc
const getTaskActivities = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    // Kiểm tra ID công việc
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Kiểm tra quyền xem công việc
    const task = await Task.findById(id);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    const isOwner =
      task.userId.toString() === userId.toString();

    const isAssigned = task.assignedTo.some(
      (assignee) => assignee.toString() === userId.toString()
    );

    const isReceived = (task.receivedBy || []).some(
      (receiver) => receiver.toString() === userId.toString()
    );

    const isSharedWith = (task.sharedWith || []).some(
      (sharedUser) => sharedUser.toString() === userId.toString()
    );

    const share = await TaskShare.findOne({
      taskId: id,
      userId,
    });

    if (
      !isOwner &&
      !isAssigned &&
      !isReceived &&
      !isSharedWith &&
      !share
    ) {
      return res.status(403).json({
        message: 'Bạn không có quyền xem lịch sử công việc này',
      });
    }

    // Lấy lịch sử hoạt động mới nhất trước
    const activities = await TaskActivity.find({
      taskId: id,
    })
      .populate('userId', 'fullName email')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lấy lịch sử hoạt động thành công',
      activities,
    });
  } catch (error) {
    console.error('Lỗi lấy lịch sử hoạt động:', error);

    return res.status(500).json({
      message: 'Không thể lấy lịch sử hoạt động',
      error: error.message,
    });
  }
};

module.exports = {
  getTaskActivities,
};