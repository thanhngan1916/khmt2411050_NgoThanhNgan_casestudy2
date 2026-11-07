
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
function formatDateTime(value) {
  if (
    value === null ||
    value === undefined ||
    value === 'Chưa thiết lập' ||
    value === ''
  ) {
    return 'Chưa thiết lập';
  }

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
}

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
async function sendTaskSharedEmail({
  task,
  recipient,
  creatorName,
  permission,
}) {
  console.log('========== BAT DAU GUI EMAIL CHIA SE ==========');
  console.log('Email nguoi nhan:', recipient?.email);
  console.log('Ten cong viec:', task?.title);
  console.log('Quyen:', permission);

  const permissionText =
    permission === 'editor'
      ? 'Chỉnh sửa công việc'
      : 'Chỉ xem công việc';

  const subject = `Bạn được mời ${permissionText.toLowerCase()}: ${task.title}`;

  const emailLog = await EmailLog.create({
    taskId: task._id,
    recipientEmail: recipient.email,
    eventType: 'task_shared',
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

Bạn vừa được mời truy cập một công việc trên Task Manager.

Tên công việc: ${task.title}
Người chia sẻ: ${creatorName || 'Người dùng Task Manager'}
Mô tả: ${task.description || 'Không có mô tả'}
Quyền được cấp: ${permissionText}

Vui lòng đăng nhập Task Manager để xem công việc.
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

    console.error('Lỗi gửi email mời chia sẻ:', error.message);
  }
}

async function sendTaskUpdatedEmail({
  task,
  recipient,
  changes,
  updaterName,
}) {
  const subject = `Công việc đã được cập nhật: ${task.title}`;

  const dateFields = ['Ngày bắt đầu', 'Hạn hoàn thành'];

  const changeDetails = changes
    .map((change) => {
      const isDateField = dateFields.includes(change.label);

      const oldValue = isDateField
        ? formatDateTime(change.oldValue)
        : change.oldValue;

      const newValue = isDateField
        ? formatDateTime(change.newValue)
        : change.newValue;

      return `- ${change.label}:\n  Trước: ${oldValue}\n  Sau: ${newValue}`;
    })
    .join('\n\n');

  const emailLog = await EmailLog.create({
    taskId: task._id,
    recipientEmail: recipient.email,
    eventType: 'task_updated',
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

Một công việc mà bạn có liên quan vừa được cập nhật trên Task Manager.

Tên công việc: ${task.title}
Người cập nhật: ${updaterName || 'Người dùng Task Manager'}

Thông tin thay đổi:

${changeDetails}

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

    console.error(
      `Lỗi gửi email cập nhật đến ${recipient.email}:`,
      error.message
    );
  }
}
module.exports = {
  sendTaskAssignedEmail,
  sendTaskSharedEmail,
  sendTaskUpdatedEmail,
};
