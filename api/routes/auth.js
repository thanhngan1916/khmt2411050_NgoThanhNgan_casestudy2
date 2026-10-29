const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const authMiddleware = require('../middleware/authMiddleware');

const {
  getProfile,
  updateProfile
} = require('../controllers/userController');

const router = express.Router();
// Xem thông tin cá nhân
router.get('/me', authMiddleware, getProfile);

// Cập nhật thông tin cá nhân
router.put('/me', authMiddleware, updateProfile);
// Đăng ký
router.post('/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    const userExists = await User.findOne({ email });

    if (userExists) {
      return res.status(400).json({
        message: 'Email đã tồn tại'
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await User.create({
      fullName,
      email,
      passwordHash
    });

    res.status(201).json({
      message: 'Đăng ký thành công',
      user
    });

  } catch (err) {
    res.status(500).json({
      message: err.message
    });
  }
});

// Đăng nhập
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(401).json({
        message: 'Sai email hoặc mật khẩu'
      });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);

    if (!isMatch) {
      return res.status(401).json({
        message: 'Sai email hoặc mật khẩu'
      });
    }

    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET,
      { expiresIn: '1d' }
    );

    res.json({
      message: 'Đăng nhập thành công',
      token
    });

  } catch (err) {
    res.status(500).json({
      message: err.message
    });
  }
});

/* Đăng xuất */
router.post('/logout', (req, res) => {
  res.json({
    message: 'Đăng xuất thành công'
  });
});

/* Đổi mật khẩu */
router.put('/change-password', authMiddleware, async (req, res) => {
  try {
    const {
      currentPassword,
      newPassword,
      confirmNewPassword
    } = req.body;

    // Kiểm tra dữ liệu đầu vào
    if (!currentPassword || !newPassword || !confirmNewPassword) {
      return res.status(400).json({
        message: 'Vui lòng nhập đầy đủ thông tin'
      });
    }

    // Kiểm tra mật khẩu mới
    if (newPassword.length < 8) {
      return res.status(400).json({
        message: 'Mật khẩu mới phải có ít nhất 8 ký tự'
      });
    }

    // Kiểm tra xác nhận mật khẩu mới
    if (newPassword !== confirmNewPassword) {
      return res.status(400).json({
        message: 'Mật khẩu xác nhận không khớp'
      });
    }

    // Tìm tài khoản đang đăng nhập
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    // Kiểm tra mật khẩu hiện tại
    const isMatch = await bcrypt.compare(
      currentPassword,
      user.passwordHash
    );

    if (!isMatch) {
      return res.status(400).json({
        message: 'Mật khẩu hiện tại không chính xác'
      });
    }

    // Mã hóa mật khẩu mới trước khi lưu
    user.passwordHash = await bcrypt.hash(newPassword, 10);
    await user.save();

    return res.status(200).json({
      message: 'Đổi mật khẩu thành công'
    });

  } catch (err) {
    return res.status(500).json({
      message: 'Lỗi máy chủ khi đổi mật khẩu'
    });
  }
});

module.exports = router;