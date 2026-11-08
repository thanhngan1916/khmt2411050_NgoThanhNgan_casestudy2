
const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const EmailLog = require('../models/EmailLog');
const { retryEmailLog } = require('../services/emailService');

// Xem lịch sử gửi email của công việc
const getTaskEmailLogs = async (req, res) => {
  try {
    const userId = req.user.id.toString();
    const { id } = req.params;

    // Kiểm tra ID công việc
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Tìm công việc
    const task = await Task.findById(id).select(
      'userId assignedTo receivedBy sharedWith'
    );

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    // Kiểm tra người dùng có liên quan đến công việc
    const isCreator =
      task.userId?.toString() === userId;

    const isAssigned = (task.assignedTo || []).some(
      (item) => item.toString() === userId
    );

    const isReceived = (task.receivedBy || []).some(
      (item) => item.toString() === userId
    );

    const isSharedWith = (task.sharedWith || []).some(
      (item) => item.toString() === userId
    );

    // Kiểm tra quyền chia sẻ trong TaskShare
    const taskShare = await TaskShare.findOne({
      taskId: id,
      userId,
    });

    const hasAccess =
      isCreator ||
      isAssigned ||
      isReceived ||
      isSharedWith ||
      !!taskShare;

    if (!hasAccess) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xem',
      });
    }

    // Lấy lịch sử gửi email, mới nhất trước
    const emailLogs = await EmailLog.find({
      taskId: id,
    })
      .select(
        'taskId recipientEmail eventType subject status attempts errorMessage sentAt createdAt'
      )
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lấy lịch sử gửi email thành công',
      emailLogs,
    });
  } catch (error) {
    console.error('Lỗi lấy lịch sử gửi email:', error);

    return res.status(500).json({
      message: 'Không thể lấy lịch sử gửi email',
    });
  }
};
// Gửi lại email đã thất bại
const retryTaskEmail = async (req, res) => {
  try {
    const userId = req.user.id.toString();
    const { id } = req.params;

    // Kiểm tra ID lịch sử email
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        message: 'ID lịch sử email không hợp lệ',
      });
    }

    // Tìm lịch sử email
    const emailLog = await EmailLog.findById(id);

    if (!emailLog) {
      return res.status(404).json({
        message: 'Không tìm thấy lịch sử email',
      });
    }

    // Chỉ cho phép gửi lại email thất bại
    if (emailLog.status !== 'failed') {
      return res.status(400).json({
        message: 'Chỉ có thể gửi lại email đã thất bại',
      });
    }

    // Kiểm tra nội dung email đã được lưu
    if (!emailLog.emailText || !emailLog.emailText.trim()) {
      return res.status(400).json({
        message: 'Email cũ không có nội dung để gửi lại',
      });
    }

    // Kiểm tra quyền truy cập công việc
    if (!emailLog.taskId) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc liên quan',
      });
    }

    const task = await Task.findById(emailLog.taskId).select(
      'userId assignedTo receivedBy sharedWith'
    );

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    const isCreator = task.userId?.toString() === userId;

    const isAssigned = (task.assignedTo || []).some(
      (item) => item.toString() === userId
    );

    const isReceived = (task.receivedBy || []).some(
      (item) => item.toString() === userId
    );

    const isSharedWith = (task.sharedWith || []).some(
      (item) => item.toString() === userId
    );

    const taskShare = await TaskShare.findOne({
      taskId: emailLog.taskId,
      userId,
    });

    const hasAccess =
      isCreator ||
      isAssigned ||
      isReceived ||
      isSharedWith ||
      !!taskShare;

    if (!hasAccess) {
      return res.status(403).json({
        message: 'Bạn không có quyền gửi lại email này',
      });
    }

    // Khóa bản ghi để tránh nhiều yêu cầu gửi lại cùng lúc
    const pendingLog = await EmailLog.findOneAndUpdate(
      {
        _id: id,
        status: 'failed',
      },
      {
        $set: {
          status: 'pending',
          errorMessage: '',
        },
        $inc: {
          attempts: 1,
        },
      },
      {
        new: true,
      }
    );

    if (!pendingLog) {
      return res.status(409).json({
        message: 'Email đang được xử lý hoặc đã được gửi lại',
      });
    }

    try {
      await retryEmailLog(pendingLog);

      await EmailLog.findByIdAndUpdate(id, {
        status: 'sent',
        sentAt: new Date(),
        errorMessage: '',
      });

      return res.status(200).json({
        message: 'Gửi lại email thành công',
      });
    } catch (error) {
      await EmailLog.findByIdAndUpdate(id, {
        status: 'failed',
        errorMessage: error.message,
      });

      return res.status(500).json({
        message: 'Gửi lại email thất bại',
        error: error.message,
      });
    }
  } catch (error) {
    console.error('Lỗi gửi lại email:', error);

    return res.status(500).json({
      message: 'Không thể gửi lại email',
    });
  }
};

module.exports = {
  getTaskEmailLogs,
  retryTaskEmail,
};
