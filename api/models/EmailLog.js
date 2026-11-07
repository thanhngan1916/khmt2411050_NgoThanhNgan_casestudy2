
const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      default: null,
    },

    recipientEmail: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },

    eventType: {
      type: String,
      required: true,
      default: 'task_assigned',
    },

    subject: {
      type: String,
      required: true,
      trim: true,
    },

    status: {
      type: String,
      enum: ['pending', 'sent', 'failed'],
      default: 'pending',
      required: true,
    },

    attempts: {
      type: Number,
      default: 0,
      min: 0,
    },

    errorMessage: {
      type: String,
      default: '',
    },

    sentAt: {
      type: Date,
      default: null,
    },

    // Khóa nhận diện một lần nhắc hạn để tránh gửi trùng.
    reminderKey: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Chỉ áp dụng tính duy nhất cho các email có reminderKey.
// Các loại email hiện tại không bị ảnh hưởng.
emailLogSchema.index(
  {
    taskId: 1,
    recipientEmail: 1,
    eventType: 1,
    reminderKey: 1,
  },
  {
    unique: true,
    partialFilterExpression: {
      reminderKey: { $type: 'string' },
    },
  }
);

module.exports = mongoose.model('EmailLog', emailLogSchema);
