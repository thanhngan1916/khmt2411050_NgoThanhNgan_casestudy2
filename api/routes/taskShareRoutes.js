const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getTaskShares,
  shareTask,
  updateTaskShare,
  deleteTaskShare,
} = require('../controllers/taskShareController');

// Tất cả API đều yêu cầu đăng nhập
router.use(authMiddleware);

// Xem danh sách người được chia sẻ
router.get('/:id/shares', getTaskShares);

// Chia sẻ công việc cho nhiều người
router.post('/:id/shares', shareTask);

// Thay đổi quyền chia sẻ
router.patch('/:id/shares/:shareId', updateTaskShare);

// Thu hồi quyền chia sẻ
router.delete('/:id/shares/:shareId', deleteTaskShare);

module.exports = router;