const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getTaskStatistics,
  getAssignmentStatistics,
} = require('../controllers/statisticsController');

// Yêu cầu đăng nhập khi sử dụng API thống kê
router.use(authMiddleware);

// Thống kê tổng số công việc theo trạng thái
router.get('/tasks', getTaskStatistics);

// Thống kê công việc được giao và đang phụ trách
router.get('/assignments', getAssignmentStatistics);

module.exports = router;