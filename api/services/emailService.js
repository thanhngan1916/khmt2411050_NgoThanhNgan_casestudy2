
const nodemailer = require('nodemailer');
const EmailLog = require('../models/EmailLog');

// Cấu hình SMTP
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT),
  secure: process.env.SMTP_SECURE === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// Kiểm tra SMTP đang được sử dụng
console.log(
  'SMTP HOST trong emailService:',
  process.env.SMTP_HOST
);

// Định dạng ngày giờ
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

// Hàm cập nhật lịch sử gửi email
async function updateEmailLogAfterSending(emailLog, errorPrefix) {
  try {
    await transporter.sendMail({
      from: `"Task Manager" <${process.env.EMAIL_FROM}>`,
      to: emailLog.recipientEmail,
      subject: emailLog.subject,
      text: emailLog.emailText,
    });

    await EmailLog.findByIdAndUpdate(emailLog._id, {
      $set: {
        status: 'sent',
        sentAt: new Date(),
        errorMessage: '',
      },
      $inc: {
        attempts: 1,
      },
    });

    return true;
  } catch (error) {
    await EmailLog.findByIdAndUpdate(emailLog._id, {
      $set: {
        status: 'failed',
        errorMessage: error.message,
      },
      $inc: {
        attempts: 1,
      },
    });

    console.error(errorPrefix, error.message);
    return false;
  }
}

// Tạo lịch sử email mới
async function createEmailLog({
  task,
  recipientEmail,
  eventType,
  subject,
  emailText,
}) {
  const emailLog = await EmailLog.create({
    taskId: task._id,
    recipientEmail,
    eventType,
    subject,
    emailText,
    status: 'pending',
    attempts: 0,
  });

  return emailLog;
}

// 1. Gửi email khi được giao công việc
async function sendTaskAssignedEmail({
  task,
  recipient,
  creatorName,
}) {
  const subject = `Bạn được giao công việc mới: ${task.title}`;

  const emailText = `
Xin chào ${recipient.fullName},

Bạn vừa được giao một công việc mới trên Task Manager.

Tên công việc: ${task.title}
Người giao: ${creatorName || 'Người dùng Task Manager'}
Mô tả: ${task.description || 'Không có mô tả'}
Độ ưu tiên: ${task.priority}
Hạn hoàn thành: ${
    task.dueDate
      ? formatDateTime(task.dueDate)
      : 'Chưa thiết lập'
  }

Vui lòng đăng nhập Task Manager để xem chi tiết công việc.
`;

  const emailLog = await createEmailLog({
    task,
    recipientEmail: recipient.email,
    eventType: 'task_assigned',
    subject,
    emailText,
  });

  return updateEmailLogAfterSending(
    emailLog,
    'Lỗi gửi email giao công việc:'
  );
}

// 2. Gửi email khi công việc được chia sẻ
async function sendTaskSharedEmail({
  task,
  recipient,
  creatorName,
  permission,
}) {
  const permissionText =
    permission === 'editor'
      ? 'Chỉnh sửa công việc'
      : 'Chỉ xem công việc';

  const subject =
    `Bạn được mời ${permissionText.toLowerCase()}: ${task.title}`;

  const emailText = `
Xin chào ${recipient.fullName},

Bạn vừa được mời truy cập một công việc trên Task Manager.

Tên công việc: ${task.title}
Người chia sẻ: ${creatorName || 'Người dùng Task Manager'}
Mô tả: ${task.description || 'Không có mô tả'}
Quyền được cấp: ${permissionText}

Vui lòng đăng nhập Task Manager để xem công việc.
`;

  const emailLog = await createEmailLog({
    task,
    recipientEmail: recipient.email,
    eventType: 'task_shared',
    subject,
    emailText,
  });

  return updateEmailLogAfterSending(
    emailLog,
    'Lỗi gửi email mời chia sẻ:'
  );
}

// 3. Gửi email khi công việc được cập nhật
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

  const emailText = `
Xin chào ${recipient.fullName},

Một công việc mà bạn có liên quan vừa được cập nhật trên Task Manager.

Tên công việc: ${task.title}
Người cập nhật: ${updaterName || 'Người dùng Task Manager'}

Thông tin thay đổi:

${changeDetails}

Vui lòng đăng nhập Task Manager để xem chi tiết công việc.
`;

  const emailLog = await createEmailLog({
    task,
    recipientEmail: recipient.email,
    eventType: 'task_updated',
    subject,
    emailText,
  });

  return updateEmailLogAfterSending(
    emailLog,
    `Lỗi gửi email cập nhật đến ${recipient.email}:`
  );
}

// 4. Gửi email khi công việc hoàn thành
async function sendTaskCompletedEmail({
  task,
  recipient,
  completerName,
}) {
  const subject = `Công việc đã hoàn thành: ${task.title}`;

  const completedAt = formatDateTime(new Date());

  const emailText = `
Xin chào ${recipient.fullName},

Một công việc mà bạn có liên quan vừa được hoàn thành trên Task Manager.

Tên công việc: ${task.title}
Người hoàn thành: ${completerName || 'Người dùng Task Manager'}
Thời gian hoàn thành: ${completedAt}

Vui lòng đăng nhập Task Manager để xem chi tiết công việc.
`;

  const emailLog = await createEmailLog({
    task,
    recipientEmail: recipient.email,
    eventType: 'task_completed',
    subject,
    emailText,
  });

  return updateEmailLogAfterSending(
    emailLog,
    `Lỗi gửi email hoàn thành đến ${recipient.email}:`
  );
}

// 5. Gửi email nhắc nhở công việc sắp đến hạn
async function sendTaskReminderEmail({
  task,
  recipient,
  reminderHours,
  reminderKey,
}) {
  const recipientEmail = recipient.email.trim().toLowerCase();

  const subject =
    `Nhắc nhở: Công việc "${task.title}" sắp đến hạn`;

  const emailText = `
Xin chào ${recipient.fullName},

Task Manager gửi thông báo nhắc nhở về công việc sắp đến hạn.

Tên công việc: ${task.title}
Mô tả: ${task.description || 'Không có mô tả'}
Độ ưu tiên: ${task.priority}
Hạn hoàn thành: ${
    task.dueDate
      ? formatDateTime(task.dueDate)
      : 'Chưa thiết lập'
  }

Công việc sẽ đến hạn trong khoảng ${reminderHours} giờ nữa.

Vui lòng đăng nhập Task Manager để kiểm tra và hoàn thành công việc đúng hạn.
`;

  let emailLog;

  try {
    emailLog = await EmailLog.findOne({
      taskId: task._id,
      recipientEmail,
      eventType: 'task_due_reminder',
      reminderKey,
    });

    // Không gửi lại nếu email đã gửi thành công
    if (emailLog?.status === 'sent') {
      return true;
    }

    // Tạo lịch sử nếu chưa tồn tại
    if (!emailLog) {
      emailLog = await createEmailLog({
        task,
        recipientEmail,
        eventType: 'task_due_reminder',
        subject,
        emailText,
      });

      emailLog.reminderKey = reminderKey;
      await emailLog.save();
    } else {
      emailLog.status = 'pending';
      emailLog.subject = subject;
      emailLog.emailText = emailText;
      emailLog.errorMessage = '';
      await emailLog.save();
    }

    return updateEmailLogAfterSending(
      emailLog,
      `Lỗi gửi email nhắc hạn đến ${recipientEmail}:`
    );
  } catch (error) {
    if (emailLog?._id) {
      await EmailLog.findByIdAndUpdate(emailLog._id, {
        $set: {
          status: 'failed',
          errorMessage: error.message,
        },
      });
    }

    console.error(
      `Lỗi gửi email nhắc hạn đến ${recipientEmail}:`,
      error.message
    );

    return false;
  }
}

// 6. Gửi lại email đã thất bại
async function retryEmailLog(emailLog) {
  if (!emailLog.emailText || !emailLog.emailText.trim()) {
    throw new Error('Email không có nội dung để gửi lại.');
  }

  await transporter.sendMail({
    from: `"Task Manager" <${process.env.EMAIL_FROM}>`,
    to: emailLog.recipientEmail,
    subject: emailLog.subject,
    text: emailLog.emailText,
  });
}

// Xuất các hàm để Controller sử dụng
module.exports = {
  sendTaskAssignedEmail,
  sendTaskSharedEmail,
  sendTaskUpdatedEmail,
  sendTaskCompletedEmail,
  sendTaskReminderEmail,
  retryEmailLog,
};
