const taskRoutes = require('./routes/task');
const authRoutes = require('./routes/auth');
const User = require('./models/User');
require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

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

// Kết nối MongoDB trước khi khởi động server
async function startServer() {
  try {
    if (!process.env.MONGODB_URI) {
      throw new Error('Chua cau hinh MONGODB_URI trong file .env');
    }

    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Ket noi MongoDB thanh cong!');

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server dang chay tai http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('Loi ket noi:', error.message);
    process.exit(1);
  }
}
// Middleware ghi log yêu cầu
app.use((req, res, next) => {
  console.log('REQUEST:', req.method, req.originalUrl);
  next();
});

// Đăng ký các route API
app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);

startServer();