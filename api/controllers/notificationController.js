
const mongoose = require('mongoose');
const Notification = require('../models/Notification');

// Lấy danh sách thông báo của người dùng đang đăng nhập
const getNotifications = async (req, res) => {
  try {
    const userId = req.user.id;

    const notifications = await Notification.find({ userId })
      .populate('taskId', 'title status dueDate')
      .sort({ createdAt: -1 });

    return res.status(200).json({
      message: 'Lấy danh sách thông báo thành công',
      notifications,
    });
  } catch (error) {
    console.error('Lỗi lấy danh sách thông báo:', error);

    return res.status(500).json({
      message: 'Không thể lấy danh sách thông báo',
    });
  }
};

// Đếm số thông báo chưa đọc
const getUnreadCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const unreadCount = await Notification.countDocuments({
      userId,
      isRead: false,
    });

    return res.status(200).json({
      message: 'Lấy số thông báo chưa đọc thành công',
      unreadCount,
    });
  } catch (error) {
    console.error('Lỗi đếm thông báo chưa đọc:', error);

    return res.status(500).json({
      message: 'Không thể đếm thông báo chưa đọc',
    });
  }
};

// Đánh dấu một thông báo đã đọc
const markAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({
        message: 'ID thông báo không hợp lệ',
      });
    }

    const notification = await Notification.findOneAndUpdate(
      {
        _id: id,
        userId,
      },
      {
        $set: { isRead: true },
      },
      {
        new: true,
      }
    );

    if (!notification) {
      return res.status(404).json({
        message: 'Không tìm thấy thông báo',
      });
    }

    return res.status(200).json({
      message: 'Đánh dấu thông báo đã đọc thành công',
      notification,
    });
  } catch (error) {
    console.error('Lỗi đánh dấu thông báo đã đọc:', error);

    return res.status(500).json({
      message: 'Không thể đánh dấu thông báo đã đọc',
    });
  }
};

// Đánh dấu tất cả thông báo đã đọc
const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user.id;

    const result = await Notification.updateMany(
      {
        userId,
        isRead: false,
      },
      {
        $set: { isRead: true },
      }
    );

    return res.status(200).json({
      message: 'Đánh dấu tất cả thông báo đã đọc thành công',
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('Lỗi đánh dấu tất cả thông báo:', error);

    return res.status(500).json({
      message: 'Không thể đánh dấu tất cả thông báo đã đọc',
    });
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
};
