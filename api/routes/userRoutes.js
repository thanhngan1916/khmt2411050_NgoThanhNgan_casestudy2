
const express = require('express');
const router = express.Router();
console.log('USER ROUTES DA DUOC NAP');

const authMiddleware = require('../middleware/authMiddleware');

const {
  getProfile,
  updateProfile,
  searchUsers
} = require('../controllers/userController');

// Yêu cầu đăng nhập cho các API người dùng
router.use(authMiddleware);

// Tìm kiếm người dùng
router.get('/search', searchUsers);

// Xem thông tin cá nhân
router.get('/profile', getProfile);

// Cập nhật thông tin cá nhân
router.put('/profile', updateProfile);

module.exports = router;
