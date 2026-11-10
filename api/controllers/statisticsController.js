const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

// Thống kê tổng số công việc theo trạng thái
const getTaskStatistics = async (req, res) => {
  try {
    const userId = req.user.id;
    const userObjectId = new mongoose.Types.ObjectId(userId);

    // Lấy danh sách công việc được chia sẻ với người dùng
    const shares = await TaskShare.find({
      userId: userObjectId,
    }).select('taskId');

    const sharedTaskIds = shares.map(
      (share) => share.taskId
    );

    // Lấy tất cả công việc có liên quan đến người dùng
    const taskQuery = {
      $or: [
        { userId: userObjectId },
        { assignedTo: userObjectId },
        { receivedBy: userObjectId },
        { sharedWith: userObjectId },
        { _id: { $in: sharedTaskIds } },
      ],
    };

    // Đếm số lượng công việc theo từng trạng thái
    const statistics = await Task.aggregate([
      {
        $match: taskQuery,
      },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
        },
      },
    ]);

    const result = {
      total: 0,
      notStarted: 0,
      inProgress: 0,
      completed: 0,
    };

    statistics.forEach((item) => {
      result.total += item.count;

      if (item._id === 'Chưa thực hiện') {
        result.notStarted = item.count;
      } else if (item._id === 'Đang thực hiện') {
        result.inProgress = item.count;
      } else if (item._id === 'Đã hoàn thành') {
        result.completed = item.count;
      }
    });

    return res.status(200).json({
      message: 'Thống kê công việc thành công',
      statistics: result,
    });
  } catch (error) {
    console.error('Lỗi thống kê công việc:', error);

    return res.status(500).json({
      message: 'Không thể thống kê công việc',
      error: error.message,
    });
  }
};

module.exports = {
  getTaskStatistics,
};
