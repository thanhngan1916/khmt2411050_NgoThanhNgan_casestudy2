
const User = require('../models/User');

// Xem thông tin cá nhân
const getProfile = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).select(
      '-passwordHash'
    );

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    res.status(200).json({
      message: 'Lấy thông tin cá nhân thành công',
      user
    });
  } catch (error) {
    res.status(500).json({
      message: 'Lỗi khi lấy thông tin cá nhân',
      error: error.message
    });
  }
};

// Cập nhật thông tin cá nhân
const updateProfile = async (req, res) => {
  try {
    const { fullName, email } = req.body;

    if (!fullName || !email) {
      return res.status(400).json({
        message: 'Vui lòng nhập đầy đủ họ tên và email'
      });
    }

    const normalizedEmail = email.trim().toLowerCase();

    const existingUser = await User.findOne({
      email: normalizedEmail,
      _id: { $ne: req.user.id }
    });

    if (existingUser) {
      return res.status(400).json({
        message: 'Email đã được sử dụng'
      });
    }

    const user = await User.findByIdAndUpdate(
      req.user.id,
      {
        fullName: fullName.trim(),
        email: normalizedEmail
      },
      {
        new: true,
        runValidators: true
      }
    ).select('-passwordHash');

    if (!user) {
      return res.status(404).json({
        message: 'Không tìm thấy tài khoản'
      });
    }

    res.status(200).json({
      message: 'Cập nhật thông tin cá nhân thành công',
      user
    });
  } catch (error) {
    res.status(500).json({
      message: 'Lỗi khi cập nhật thông tin cá nhân',
      error: error.message
    });
  }
};

// Tìm kiếm người dùng theo họ tên hoặc email
const searchUsers = async (req, res) => {
  try {
    const keyword = String(req.query.q || '').trim();

    if (keyword.length < 2) {
      return res.status(400).json({
        message: 'Vui lòng nhập ít nhất 2 ký tự để tìm kiếm'
      });
    }

    const escapedKeyword = keyword.replace(
      /[.*+?^${}()|[\]\\]/g,
      '\\$&'
    );

    const users = await User.find({
      $or: [
        {
          fullName: {
            $regex: escapedKeyword,
            $options: 'i'
          }
        },
        {
          email: {
            $regex: escapedKeyword,
            $options: 'i'
          }
        }
      ]
    })
      .select('_id fullName email')
      .limit(10)
      .lean();

    res.status(200).json({
      message: 'Tìm kiếm người dùng thành công',
      users
    });
  } catch (error) {
    console.error('Lỗi tìm kiếm người dùng:', error);

    res.status(500).json({
      message: 'Không thể tìm kiếm người dùng',
      error: error.message
    });
  }
};

module.exports = {
  getProfile,
  updateProfile,
  searchUsers
};
