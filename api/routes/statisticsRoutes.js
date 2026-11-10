
const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getTaskStatistics,
} = require('../controllers/statisticsController');

// Yêu cầu đăng nhập khi sử dụng API thống kê
router.use(authMiddleware);

// Thống kê tổng số công việc theo trạng thái
router.get('/tasks', getTaskStatistics);

module.exports = router;
