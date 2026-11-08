
const Notification = require('../models/Notification');

// Tạo thông báo cho một hoặc nhiều người nhận
const createNotifications = async ({
  recipientIds,
  actorId,
  task,
  type,
  title,
  message,
}) => {
    try {
      console.log('===== KIEM TRA TAO THONG BAO =====');
      console.log('Task ID:', task?._id);
      console.log('Recipient IDs:', recipientIds);
      console.log('Actor ID:', actorId);

      if (!task || !task._id || !Array.isArray(recipientIds)) {
        console.log('Khong du dieu kien tao thong bao');
        return;
      }

    // Loại bỏ ID trùng và không gửi thông báo cho người thực hiện.
    const uniqueRecipientIds = [
      ...new Set(
        recipientIds
          .filter(Boolean)
          .map((id) => id.toString())
          .filter((id) => id !== actorId?.toString())
      ),
    ];

    if (uniqueRecipientIds.length === 0) {
      return;
    }

    const notifications = uniqueRecipientIds.map((userId) => ({
      userId,
      taskId: task._id,
      type,
      title,
      message,
      isRead: false,
    }));

    await Notification.insertMany(notifications);

    console.log(
      `Da tao ${notifications.length} thong bao: ${type}`
    );
  } catch (error) {
    // Lỗi tạo thông báo không làm gián đoạn nghiệp vụ chính.
    console.error('Loi tao thong bao:', error);
  }
};

module.exports = {
  createNotifications,
};
