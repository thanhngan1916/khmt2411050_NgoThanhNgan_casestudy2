const TaskActivity = require('../models/TaskActivity');

// Ghi nhận lịch sử hoạt động của công việc
const createTaskActivity = async ({
  taskId,
  userId,
  action,
  details = {},
}) => {
  try {
    if (!taskId || !userId || !action) {
      throw new Error('Thiếu thông tin ghi nhận hoạt động.');
    }

    const activity = await TaskActivity.create({
      taskId,
      userId,
      action,
      details,
    });

    return activity;
  } catch (error) {
    console.error('Lỗi ghi nhận lịch sử hoạt động:', error);
    throw error;
  }
};

module.exports = {
  createTaskActivity,
};