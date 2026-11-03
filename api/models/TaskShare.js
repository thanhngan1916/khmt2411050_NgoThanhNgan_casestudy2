
const mongoose = require('mongoose');

const taskShareSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: true,
    },

    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer',
      required: true,
    },

    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Không cho phép một người có nhiều bản ghi
// chia sẻ trùng nhau trên cùng một công việc.
taskShareSchema.index(
  { taskId: 1, userId: 1 },
  { unique: true }
);

module.exports = mongoose.model('TaskShare', taskShareSchema);
