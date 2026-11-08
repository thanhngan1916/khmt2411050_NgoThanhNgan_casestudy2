const express = require('express');
                        const router = express.Router();
                        const {
                          getTaskEmailLogs,
                          retryTaskEmail,
                        } = require('../controllers/emailLogController');

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
                        router.get('/:id/email-logs', getTaskEmailLogs);
                        router.post('/email-logs/:id/retry', retryTaskEmail);
                        router.put('/:id', updateTask);
                        router.delete('/:id', deleteTask);

                        console.log(
                          'DANH SACH ROUTE TASK:',
                          router.stack
                            .filter((layer) => layer.route)
                            .map((layer) => ({
                              method: Object.keys(layer.route.methods).join(', ').toUpperCase(),
                              path: layer.route.path,
                            }))
                        );
                        module.exports = router;