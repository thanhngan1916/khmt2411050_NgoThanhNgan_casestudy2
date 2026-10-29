const express = require('express');
const router = express.Router();

console.log('TASK ROUTER DA DUOC NAP');

const authMiddleware = require('../middleware/authMiddleware');

const {
  getTaskList,
  getTaskDetail,
  createTask,
  updateTask,
  deleteTask,
} = require('../controllers/taskController');

router.use(authMiddleware);

router.get('/', getTaskList);
router.post('/', createTask);
router.get('/:id', getTaskDetail);
router.put('/:id', updateTask);
router.delete('/:id', deleteTask);

module.exports = router;