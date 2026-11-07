
const nodemailer = require('nodemailer');
const EmailLog = require('../models/EmailLog');

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function sendTaskAssignedEmail({ task, recipient, creatorName }) {
  const subject = `Bạn được giao công việc mới: ${task.title}`;

  const emailLog = await EmailLog.create({
    taskId: task._id,
    recipientEmail: recipient.email,
    eventType: 'task_assigned',
    subject,
    status: 'pending',
    attempts: 0,
  });

  try {
    await transporter.sendMail({
      from: `"Task Manager" <${process.env.EMAIL_FROM}>`,
      to: recipient.email,
      subject,
      text: `
Xin chào ${recipient.fullName},

Bạn vừa được giao một công việc mới trên Task Manager.

Tên công việc: ${task.title}
Người giao: ${creatorName || 'Người dùng Task Manager'}
Mô tả: ${task.description || 'Không có mô tả'}
Độ ưu tiên: ${task.priority}
Hạn hoàn thành: ${
        task.dueDate
          ? new Date(task.dueDate).toLocaleString('vi-VN')
          : 'Chưa thiết lập'
      }

Vui lòng đăng nhập Task Manager để xem chi tiết công việc.
      `,
    });

    await EmailLog.findByIdAndUpdate(emailLog._id, {
      status: 'sent',
      attempts: 1,
      sentAt: new Date(),
      errorMessage: '',
    });
  } catch (error) {
    await EmailLog.findByIdAndUpdate(emailLog._id, {
      status: 'failed',
      attempts: 1,
      errorMessage: error.message,
    });

    console.error('Loi gui email:', error.message);
  }
}

module.exports = {
  sendTaskAssignedEmail,
};
