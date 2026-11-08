
const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    // Người nhận thông báo
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    // Công việc liên quan đến thông báo
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: true,
      index: true,
    },

    // Loại sự kiện tạo thông báo
    type: {
      type: String,
      required: true,
      trim: true,
    },

    // Tiêu đề thông báo
    title: {
      type: String,
      required: true,
      trim: true,
    },

    // Nội dung thông báo
    message: {
      type: String,
      required: true,
      trim: true,
    },

    // Trạng thái đã đọc hay chưa
    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Tối ưu truy vấn thông báo theo người nhận và thời gian tạo
notificationSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
