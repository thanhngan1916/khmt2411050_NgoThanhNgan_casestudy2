
const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
} = require('../controllers/notificationController');

// Lấy danh sách thông báo
router.get('/', authMiddleware, getNotifications);

// Đếm số thông báo chưa đọc
router.get('/unread-count', authMiddleware, getUnreadCount);

// Đánh dấu tất cả thông báo đã đọc
router.patch('/read-all', authMiddleware, markAllAsRead);

// Đánh dấu một thông báo đã đọc
router.patch('/:id/read', authMiddleware, markAsRead);

module.exports = router;
