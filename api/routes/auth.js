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

module.exports = router;