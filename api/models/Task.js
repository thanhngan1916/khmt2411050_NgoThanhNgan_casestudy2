
const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },

    title: {
      type: String,
      required: [true, 'Vui lòng nhập tên công việc'],
      trim: true,
    },

    description: {
      type: String,
      default: '',
      trim: true,
    },

    startDate: {
      type: Date,
      default: null,
    },
    dueDate: {
      type: Date,
      default: null,
    },

    priority: {
      type: String,
      enum: ['Thấp', 'Trung bình', 'Cao'],
      default: 'Trung bình',
    },

   status: {
     type: String,
     enum: ['Chưa thực hiện', 'Đang thực hiện', 'Đã hoàn thành'],
     default: 'Chưa thực hiện',
   },

    assignedTo: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    }],

    receivedBy: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    }],

    sharedWith: [{
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    }],
  },
  { timestamps: true }
);

module.exports = mongoose.model('Task', taskSchema);
