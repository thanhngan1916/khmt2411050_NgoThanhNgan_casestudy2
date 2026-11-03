const express = require('express');
const router = express.Router();

const authMiddleware = require('../middleware/authMiddleware');

const {
  getAssignees,
  assignTask,
  updatePrimaryAssignee,
  removeAssignee,
} = require('../controllers/assignmentController');

router.use(authMiddleware);

router.get('/:id/assignees', getAssignees);
router.post('/:id/assignees', assignTask);
router.patch('/:id/assignees/:userId', updatePrimaryAssignee);
router.delete('/:id/assignees/:userId', removeAssignee);

module.exports = router;