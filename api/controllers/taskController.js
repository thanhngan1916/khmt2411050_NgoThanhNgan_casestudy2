
const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');
const TaskShare = require('../models/TaskShare');
const {
  sendTaskAssignedEmail,
  sendTaskUpdatedEmail,
} = require('../services/emailService');

// Kiểm tra ID công việc
const validateTaskId = (id) => {
  return mongoose.Types.ObjectId.isValid(id);
};

// Kiểm tra ngày bắt đầu và hạn hoàn thành
const validateTaskDates = (startDate, dueDate) => {
  if (startDate && dueDate) {
    const start = new Date(startDate);
    const due = new Date(dueDate);

    // So sánh theo ngày, không xét giờ
    start.setHours(0, 0, 0, 0);
    due.setHours(0, 0, 0, 0);

    if (due < start) {
      return false;
    }
  }

  return true;
};

// Kiểm tra danh sách người phụ trách
const validateAssignedTo = async (assignedTo) => {

  if (!Array.isArray(assignedTo)) {
    return false;
  }

  // Kiểm tra định dạng ObjectId
  if (!assignedTo.every(id => mongoose.Types.ObjectId.isValid(id))) {
    return false;
  }

  // Kiểm tra người dùng có tồn tại hay không
  const uniqueIds = [...new Set(assignedTo.map(id => id.toString()))];

  const users = await User.find({
    _id: { $in: uniqueIds }
  }).select('_id');

  return users.length === uniqueIds.length;

};
console.log('validateAssignedTo:', typeof validateAssignedTo);


// 1. Xem danh sách công việc và sắp xếp

const getTaskList = async (req, res) => {
  try {
    const currentUserId = req.user.id.toString();

    const {
      sortBy = 'createdAt',
      order = 'desc',
      scope = 'all',
    } = req.query;

    const validSortFields = [
      'dueDate',
      'priority',
      'createdAt',
    ];

    const validScopes = [
      'all',
      'created',
      'assigned',
      'received',
      'shared',
    ];

    if (!validSortFields.includes(sortBy)) {
      return res.status(400).json({
        message: 'Tiêu chí sắp xếp không hợp lệ',
      });
    }

    if (!['asc', 'desc'].includes(order)) {
      return res.status(400).json({
        message: 'Thứ tự sắp xếp không hợp lệ',
      });
    }

    if (!validScopes.includes(scope)) {
      return res.status(400).json({
        message: 'Nhóm công việc không hợp lệ',
      });
    }

    // Lấy danh sách công việc được chia sẻ từ TaskShare
    const shares = await TaskShare.find({
      userId: currentUserId,
    }).select('taskId');

    const sharedTaskIds = shares.map(
      (share) => share.taskId
    );

    // Điều kiện truy vấn theo vai trò
    const roleConditions = {
      created: {
        userId: currentUserId,
      },
      assigned: {
        assignedTo: currentUserId,
      },
      received: {
        receivedBy: currentUserId,
      },
      shared: {
        _id: { $in: sharedTaskIds },
      },
    };

    let taskQuery = {};

    if (scope === 'all') {
      taskQuery = {
        $or: [
          { userId: currentUserId },
          { assignedTo: currentUserId },
          { receivedBy: currentUserId },
          { sharedWith: currentUserId },
          { _id: { $in: sharedTaskIds } },
        ],
      };
    } else {
      taskQuery = roleConditions[scope];
    }

    const tasks = await Task.find(taskQuery)
      .populate('assignedTo', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email');

    // Phân loại công việc theo các vai trò
    const classifiedTasks = tasks.map((task) => {
      const taskData = task.toObject();

      const isCreator =
        task.userId.toString() === currentUserId;

      const isAssigned = task.assignedTo.some(
        (assignee) =>
          assignee._id.toString() === currentUserId
      );

      const isReceived = task.receivedBy.some(
        (id) => id.toString() === currentUserId
      );

      const isShared =
        sharedTaskIds.some(
          (id) => id.toString() === task._id.toString()
        );

      const taskRoles = [];

      if (isCreator) taskRoles.push('Được tạo');
      if (isAssigned) taskRoles.push('Được giao');
      if (isReceived) taskRoles.push('Được nhận');
      if (isShared) taskRoles.push('Được chia sẻ');

      taskData.taskRoles = taskRoles;

      // Giữ taskType để tương thích giao diện Flutter hiện tại
      taskData.taskType =
        taskRoles[0] ?? 'Không xác định';

      return taskData;
    });

    const direction = order === 'asc' ? 1 : -1;

    const priorityRank = {
      'Cao': 3,
      'Trung bình': 2,
      'Thấp': 1,
    };

    // Sắp xếp danh sách công việc
    classifiedTasks.sort((a, b) => {
      let result = 0;

      if (sortBy === 'dueDate') {
        if (!a.dueDate && !b.dueDate) return 0;
        if (!a.dueDate) return 1;
        if (!b.dueDate) return -1;

        result =
          new Date(a.dueDate) - new Date(b.dueDate);
      } else if (sortBy === 'priority') {
        result =
          (priorityRank[a.priority] || 0) -
          (priorityRank[b.priority] || 0);
      } else {
        result =
          new Date(a.createdAt) -
          new Date(b.createdAt);
      }

      if (result !== 0) {
        return result * direction;
      }

      return (
        new Date(b.createdAt) -
        new Date(a.createdAt)
      );
    });

    return res.status(200).json({
      message: 'Lấy danh sách công việc thành công',
      tasks: classifiedTasks,
      sortBy,
      order,
      scope,
    });

  } catch (error) {
    console.error('Lỗi lấy danh sách công việc:', error);

    return res.status(500).json({
      message: 'Không thể lấy danh sách công việc',
      error: error.message,
    });
  }
};



// 2. Xem chi tiết công việc
const getTaskDetail = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    if (!validateTaskId(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    const task = await Task.findOne({
      _id: id,
      $or: [
        { userId },
        { assignedTo: userId },
        { receivedBy: userId },
        { sharedWith: userId },
      ],
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xem',
      });
    }

    res.status(200).json({
      message: 'Lấy chi tiết công việc thành công',
      task,
    });
  } catch (error) {
    console.error('Lỗi xem chi tiết công việc:', error);

    res.status(500).json({
      message: 'Không thể lấy chi tiết công việc',
    });
  }
};

// 3. Tạo công việc
const createTask = async (req, res) => {
  try {
    console.log(
      'KIEM TRA TRONG createTask:',
      typeof validateAssignedTo
    );

    const userId = req.user.id;

    const {
      title,
      description,
      startDate,
      dueDate,
      priority,
      status,
      assignedTo,
    } = req.body;

    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        message: 'Vui lòng nhập tên công việc',
      });
    }

    // Kiểm tra danh sách người phụ trách
    const assignees = assignedTo || [];

    if (!Array.isArray(assignees)) {
      return res.status(400).json({
        message: 'Danh sách người phụ trách không hợp lệ',
      });
    }

    if (!(await validateAssignedTo(assignees))) {
      return res.status(400).json({
        message: 'Người phụ trách không tồn tại hoặc ID không hợp lệ',
      });
    }

    // Tạo dữ liệu công việc
    const taskData = {
      userId,
      title: title.trim(),
      description,
      priority,
      status,
      assignedTo: assignees,
    };

    // Xử lý ngày bắt đầu
    if (startDate !== undefined && startDate !== null && startDate !== '') {
      const parsedStartDate = new Date(startDate);

      if (Number.isNaN(parsedStartDate.getTime())) {
        return res.status(400).json({
          message: 'Ngày bắt đầu không hợp lệ',
        });
      }

      taskData.startDate = parsedStartDate;
    }

    // Xử lý hạn hoàn thành
    if (dueDate !== undefined && dueDate !== null && dueDate !== '') {
      const parsedDueDate = new Date(dueDate);

      if (Number.isNaN(parsedDueDate.getTime())) {
        return res.status(400).json({
          message: 'Hạn hoàn thành không hợp lệ',
        });
      }

      taskData.dueDate = parsedDueDate;
    }

    // Kiểm tra hạn hoàn thành không trước ngày bắt đầu
    if (!validateTaskDates(taskData.startDate, taskData.dueDate)) {
      return res.status(400).json({
        message: 'Hạn hoàn thành không được trước ngày bắt đầu',
      });
    }

    const task = await Task.create(taskData);

    // Lấy thông tin người tạo công việc
    const creator = await User.findById(userId).select('fullName');

    // Lấy danh sách người phụ trách
    const assigneesInfo = await User.find({
      _id: { $in: assignees },
    }).select('fullName email');

    // Gửi email cho từng người phụ trách
    for (const recipient of assigneesInfo) {
      try {
        await sendTaskAssignedEmail({
          task,
          recipient,
          creatorName: creator?.fullName || 'Người dùng Task Manager',
        });
      } catch (emailError) {
        console.error(
          `Lỗi gửi email đến ${recipient.email}:`,
          emailError.message
        );
      }
    }

    await task.populate('assignedTo', 'fullName email');
    res.status(201).json({
      message: 'Tạo công việc thành công',
      task,
    });
     } catch (error) {
       console.error('Lỗi tạo công việc:', error.stack);

       res.status(500).json({
         message: 'Không thể tạo công việc',
         error: error.message,
       });
     }
   };

// 4. Chỉnh sửa công việc và cập nhật trạng thái
const updateTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    if (!validateTaskId(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Tìm công việc theo ID
    const task = await Task.findById(id);

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc',
      });
    }

    // Kiểm tra người dùng có phải chủ sở hữu không
    const isOwner = task.userId.toString() === userId.toString();

    // Nếu không phải chủ sở hữu, kiểm tra quyền chia sẻ
    if (!isOwner) {
      const taskShare = await TaskShare.findOne({
        taskId: id,
        userId: userId,
      });

      // Không có quyền chia sẻ hoặc chỉ có quyền xem
      if (!taskShare || taskShare.permission !== 'editor') {
        return res.status(403).json({
          message: 'Bạn không có quyền chỉnh sửa công việc này',
        });
      }
    }

    const {
      title,
      description,
      startDate,
      dueDate,
      priority,
      status,
      assignedTo,
    } = req.body;

    const originalTask = {
      title: task.title,
      description: task.description || '',
      startDate: task.startDate ? new Date(task.startDate).getTime() : null,
      dueDate: task.dueDate ? new Date(task.dueDate).getTime() : null,
      priority: task.priority,
      status: task.status,
    };

    if (title !== undefined) {
      if (typeof title !== 'string' || !title.trim()) {
        return res.status(400).json({
          message: 'Tên công việc không được để trống',
        });
      }

      task.title = title.trim();
    }

    if (description !== undefined) {
      task.description = description;
    }

    // Cập nhật ngày bắt đầu
    if (startDate !== undefined) {
      if (startDate === null || startDate === '') {
        task.startDate = null;
      } else {
        const parsedStartDate = new Date(startDate);

        if (Number.isNaN(parsedStartDate.getTime())) {
          return res.status(400).json({
            message: 'Ngày bắt đầu không hợp lệ',
          });
        }

        task.startDate = parsedStartDate;
      }
    }

    // Cập nhật hạn hoàn thành
    if (dueDate !== undefined) {
      if (dueDate === null || dueDate === '') {
        task.dueDate = null;
      } else {
        const parsedDueDate = new Date(dueDate);

        if (Number.isNaN(parsedDueDate.getTime())) {
          return res.status(400).json({
            message: 'Hạn hoàn thành không hợp lệ',
          });
        }

        task.dueDate = parsedDueDate;
      }
    }

    // Kiểm tra hai ngày sau khi cập nhật
    if (!validateTaskDates(task.startDate, task.dueDate)) {
      return res.status(400).json({
        message: 'Hạn hoàn thành không được trước ngày bắt đầu',
      });
    }

    if (priority !== undefined) {
      if (!['Thấp', 'Trung bình', 'Cao'].includes(priority)) {
        return res.status(400).json({
          message: 'Mức độ ưu tiên không hợp lệ',
        });
      }

      task.priority = priority;
    }

    if (status !== undefined) {
      const validStatuses = [
        'Chưa thực hiện',
        'Đang thực hiện',
        'Đã hoàn thành',
      ];

      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          message: 'Trạng thái công việc không hợp lệ',
        });
      }

      task.status = status;
    }

    // Cập nhật danh sách người phụ trách
    if (assignedTo !== undefined) {
      if (!Array.isArray(assignedTo)) {
        return res.status(400).json({
          message: 'Danh sách người phụ trách không hợp lệ',
        });
      }

      if (!(await validateAssignedTo(assignedTo))) {
        return res.status(400).json({
          message: 'Người phụ trách không tồn tại hoặc ID không hợp lệ',
        });
      }

      task.assignedTo = assignedTo;
    }

    const changes = [];

    const addChange = (key, label, oldValue, newValue) => {
      if (oldValue !== newValue) {
        changes.push({
          label,
          oldValue: oldValue ?? 'Chưa thiết lập',
          newValue: newValue ?? 'Chưa thiết lập',
        });
      }
    };

    addChange('title', 'Tên công việc', originalTask.title, task.title);
    addChange('description', 'Mô tả', originalTask.description, task.description || '');

    addChange(
      'startDate',
      'Ngày bắt đầu',
      originalTask.startDate,
      task.startDate ? new Date(task.startDate).getTime() : null
    );

    addChange(
      'dueDate',
      'Hạn hoàn thành',
      originalTask.dueDate,
      task.dueDate ? new Date(task.dueDate).getTime() : null
    );

    addChange('priority', 'Mức độ ưu tiên', originalTask.priority, task.priority);
    addChange('status', 'Trạng thái', originalTask.status, task.status);

    await task.save();

    // Lấy thông tin người thực hiện cập nhật
    const updater = await User.findById(userId).select('fullName');

    // Lấy danh sách người được chia sẻ công việc
    const shares = await TaskShare.find({
      taskId: id,
    }).select('userId');

    // Tổng hợp ID những người có liên quan đến công việc
    const recipientIds = [
      task.userId,
      ...task.assignedTo,
      ...(task.receivedBy || []),
      ...(task.sharedWith || []),
      ...(task.primaryAssigneeId ? [task.primaryAssigneeId] : []),
      ...shares.map((share) => share.userId),
    ]
      .filter(Boolean)
      .map((id) => id.toString())
      .filter((id, index, array) => array.indexOf(id) === index)
      .filter((id) => id !== userId.toString());

    // Lấy thông tin email người nhận
    const recipients = await User.find({
      _id: { $in: recipientIds },
    }).select('fullName email');

    // Chỉ gửi email khi có thông tin thực sự thay đổi
    if (changes.length > 0) {
      for (const recipient of recipients) {
        if (!recipient.email) continue;

        try {
          await sendTaskUpdatedEmail({
            task,
            recipient,
            changes,
            updaterName: updater?.fullName || 'Người dùng Task Manager',
          });
        } catch (emailError) {
          console.error(
            `Lỗi gửi email cập nhật đến ${recipient.email}:`,
            emailError.message
          );
        }
      }
    }

    return res.status(200).json({
      message: 'Cập nhật công việc thành công',
      task,
    });
  } catch (error) {
    console.error('Lỗi cập nhật công việc:', error);

    if (error.name === 'ValidationError') {
      return res.status(400).json({
        message: error.message,
      });
    }

    return res.status(500).json({
      message: 'Không thể cập nhật công việc',
      error: error.message,
    });
  }
};

// 5. Xóa công việc
const deleteTask = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    if (!validateTaskId(id)) {
      return res.status(400).json({
        message: 'ID công việc không hợp lệ',
      });
    }

    // Chỉ chủ sở hữu mới được xóa
    const task = await Task.findOneAndDelete({
      _id: id,
      userId,
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền xóa',
      });
    }

    res.status(200).json({
      message: 'Xóa công việc thành công',
    });
  } catch (error) {
    console.error('Lỗi xóa công việc:', error);

    res.status(500).json({
      message: 'Không thể xóa công việc',
    });
  }
};

module.exports = {
  getTaskList,
  getTaskDetail,
  createTask,
  updateTask,
  deleteTask,
};
