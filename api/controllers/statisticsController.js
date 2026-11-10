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
// Thống kê công việc được giao và công việc đang phụ trách
const getAssignmentStatistics = async (req, res) => {
  try {
    const userObjectId = new mongoose.Types.ObjectId(req.user.id);

    // Đếm công việc được giao cho người dùng
    const assignedCount = await Task.countDocuments({
      assignedTo: userObjectId,
    });

    // Đếm công việc người dùng đang phụ trách chính
    const responsibleCount = await Task.countDocuments({
      primaryAssigneeId: userObjectId,
    });

    return res.status(200).json({
      message: 'Thống kê công việc được giao và đang phụ trách thành công',
      statistics: {
        assigned: assignedCount,
        responsible: responsibleCount,
      },
    });
  } catch (error) {
    console.error('Lỗi thống kê công việc được giao:', error);

    return res.status(500).json({
      message: 'Không thể thống kê công việc được giao',
      error: error.message,
    });
  }
};
// Lấy danh sách công việc sắp đến hạn và đã quá hạn
const getDeadlineTasks = async (req, res) => {
  try {
    const userObjectId = new mongoose.Types.ObjectId(req.user.id);

    // Lấy danh sách công việc được chia sẻ với người dùng
    const shares = await TaskShare.find({
      userId: userObjectId,
    }).select('taskId');

    const sharedTaskIds = shares.map((share) => share.taskId);

    // Xác định các công việc có liên quan đến người dùng
    const taskQuery = {
      $or: [
        { userId: userObjectId },
        { assignedTo: userObjectId },
        { receivedBy: userObjectId },
        { sharedWith: userObjectId },
        { _id: { $in: sharedTaskIds } },
      ],
      dueDate: { $ne: null },
      status: { $ne: 'Đã hoàn thành' },
    };

    const now = new Date();

    // Thời điểm kết thúc 7 ngày tiếp theo
    const sevenDaysLater = new Date(now);
    sevenDaysLater.setDate(sevenDaysLater.getDate() + 7);

    // Công việc sắp đến hạn trong 7 ngày tới
    const upcomingTasks = await Task.find({
      ...taskQuery,
      dueDate: {
        $gte: now,
        $lte: sevenDaysLater,
      },
    })
      .populate('userId', 'fullName email')
      .sort({ dueDate: 1 });

    // Công việc đã quá hạn
    const overdueTasks = await Task.find({
      ...taskQuery,
      dueDate: { $lt: now },
    })
      .populate('userId', 'fullName email')
      .sort({ dueDate: 1 });

    return res.status(200).json({
      message: 'Lấy danh sách công việc theo hạn hoàn thành thành công',
      upcoming: {
        count: upcomingTasks.length,
        tasks: upcomingTasks,
      },
      overdue: {
        count: overdueTasks.length,
        tasks: overdueTasks,
      },
    });
  } catch (error) {
    console.error('Lỗi lấy công việc theo hạn hoàn thành:', error);

    return res.status(500).json({
      message: 'Không thể lấy danh sách công việc theo hạn hoàn thành',
      error: error.message,
    });
  }
};
module.exports = {
  getTaskStatistics,
  getAssignmentStatistics,
  getDeadlineTasks,
};