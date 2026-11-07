const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const EmailLog = require('../models/EmailLog');

const {
  sendTaskReminderEmail,
} = require('./emailService');

async function checkDueTaskReminders() {
  const reminderHours = Number(
    process.env.TASK_REMINDER_HOURS || 24
  );

  if (!Number.isFinite(reminderHours) || reminderHours <= 0) {
    console.error('TASK_REMINDER_HOURS không hợp lệ.');
    return;
  }

  const now = new Date();

  // Khoảng thời gian cần nhắc trước hạn.
  const reminderEnd = new Date(
    now.getTime() + reminderHours * 60 * 60 * 1000
  );

  const reminderStart = new Date(
    reminderEnd.getTime() - 5 * 60 * 1000
  );

  try {
    const tasks = await Task.find({
      dueDate: {
        $gt: reminderStart,
        $lte: reminderEnd,
      },
      status: {
        $ne: 'Đã hoàn thành',
      },
    });

    for (const task of tasks) {
      // Thu thập ID tất cả người liên quan.
      const userIds = [
        task.userId,
        ...(task.assignedTo || []),
        task.primaryAssigneeId,
        ...(task.receivedBy || []),
        ...(task.sharedWith || []),
      ].filter(Boolean);

      // Lấy thêm người được chia sẻ qua TaskShare.
      const shares = await TaskShare.find({
        taskId: task._id,
      }).select('userId');

      userIds.push(...shares.map((share) => share.userId));

      // Loại bỏ ID trùng.
      const uniqueUserIds = [
        ...new Set(userIds.map((id) => id.toString())),
      ];

      const recipients = await User.find({
        _id: { $in: uniqueUserIds },
      }).select('fullName email');

      // Tạo khóa nhắc việc theo công việc, hạn và người nhận.
      for (const recipient of recipients) {
        const recipientEmail = recipient.email.trim().toLowerCase();

        const reminderKey = [
          task._id.toString(),
          new Date(task.dueDate).getTime(),
          reminderHours,
          recipientEmail,
        ].join('_');

        // Đã gửi thành công thì bỏ qua.
        const sentLog = await EmailLog.findOne({
          taskId: task._id,
          recipientEmail,
          eventType: 'task_due_reminder',
          reminderKey,
          status: 'sent',
        });

        if (sentLog) {
          continue;
        }

        await sendTaskReminderEmail({
          task,
          recipient,
          reminderHours,
          reminderKey,
        });
      }
    }
  } catch (error) {
    console.error(
      'Lỗi kiểm tra công việc cần nhắc hạn:',
      error.message
    );
  }
}

module.exports = {
  checkDueTaskReminders,
};