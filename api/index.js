
require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const taskRoutes = require('./routes/task');
const authRoutes = require('./routes/auth');
const assignmentRoutes = require('./routes/assignmentRoutes');
const userRoutes = require('./routes/userRoutes');
const taskShareRoutes = require('./routes/taskShareRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const statisticsRoutes = require('./routes/statisticsRoutes');
const cron = require('node-cron');

const {
  checkDueTaskReminders,
} = require('./services/taskReminderService');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Middleware ghi log yêu cầu
app.use((req, res, next) => {
  console.log('REQUEST:', req.method, req.originalUrl);
  next();
});

// API kiểm tra Backend
app.get('/', (req, res) => {
  res.json({
    message: 'TaskManager API is running!'
  });
});

// API kiểm tra kết nối MongoDB
app.get('/api/health', (req, res) => {
  res.json({
    api: 'OK',
    database:
      mongoose.connection.readyState === 1
        ? 'Connected'
        : 'Disconnected'
  });
});

// Đăng ký các route API
app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);


// Route giao công việc
app.use('/api/tasks', assignmentRoutes);

// Route chia sẻ công việc
app.use('/api/tasks', taskShareRoutes);

// Route người dùng
app.use('/api/users', userRoutes);

// Route thông báo
app.use('/api/notifications', notificationRoutes);

// Route thống kê công việc
app.use('/api/statistics', statisticsRoutes);

// Kết nối MongoDB trước khi khởi động server
async function startServer() {
  try {
    if (!process.env.MONGODB_URI) {
      throw new Error('Chua cau hinh MONGODB_URI trong file .env');
    }

    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Ket noi MongoDB thanh cong!');

    // Khởi chạy lịch kiểm tra nhắc việc.
    const reminderCron =
      process.env.TASK_REMINDER_CHECK_CRON || '*/5 * * * *';

    if (!cron.validate(reminderCron)) {
      throw new Error('TASK_REMINDER_CHECK_CRON không hợp lệ.');
    }

    cron.schedule(reminderCron, () => {
      console.log('Dang kiem tra cong viec can nhac han...');
      checkDueTaskReminders();
    });

    console.log(
      `Lich nhac viec da kich hoat: ${reminderCron}`
    );

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server dang chay tai http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('Loi ket noi:', error.message);
    process.exit(1);
  }
}

startServer();
