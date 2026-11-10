const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getTaskStatistics,
  getAssignmentStatistics,
  getDeadlineTasks,
} = require('../controllers/statisticsController');

// Yêu cầu đăng nhập khi sử dụng API thống kê
router.use(authMiddleware);

// Thống kê tổng số công việc theo trạng thái
router.get('/tasks', getTaskStatistics);

// Thống kê công việc được giao và đang phụ trách
router.get('/assignments', getAssignmentStatistics);

// Lấy danh sách công việc sắp đến hạn và đã quá hạn
router.get('/deadlines', getDeadlineTasks);

module.exports = router;