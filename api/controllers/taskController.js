
const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');

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
    const userId = req.user.id;
    const currentUserId = userId.toString();

    const { sortBy = 'createdAt', order = 'desc' } = req.query;

    const validSortFields = [
      'dueDate',
      'priority',
      'createdAt',
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

    // Lấy công việc mà người dùng có quyền truy cập
    const tasks = await Task.find({
      $or: [
        { userId: currentUserId },
        { assignedTo: currentUserId },
        { receivedBy: currentUserId },
        { sharedWith: currentUserId },
      ],
    }).populate('assignedTo', 'fullName email');

    // Xác định loại công việc theo tài khoản đang đăng nhập
    const classifiedTasks = tasks.map((task) => {
      const taskData = task.toObject();

      const isCreator =
        task.userId.toString() === currentUserId;

      const isAssigned = task.assignedTo.some((assignee) => {
        const assigneeId = assignee._id
          ? assignee._id.toString()
          : assignee.toString();

        return assigneeId === currentUserId;
      });

      const isReceived = task.receivedBy.some(
        (id) => id.toString() === currentUserId
      );

      const isShared = task.sharedWith.some(
        (id) => id.toString() === currentUserId
      );

      // Ưu tiên phân loại theo vai trò chính
      if (isCreator) {
        taskData.taskType = 'Được tạo';
      } else if (isAssigned) {
        taskData.taskType = 'Được giao';
      } else if (isReceived) {
        taskData.taskType = 'Được nhận';
      } else if (isShared) {
        taskData.taskType = 'Được chia sẻ';
      }

      return taskData;
    });

    const direction = order === 'asc' ? 1 : -1;

    // Sắp xếp công việc
    classifiedTasks.sort((a, b) => {
      let result = 0;

      if (sortBy === 'dueDate') {
        if (!a.dueDate && !b.dueDate) return 0;
        if (!a.dueDate) return 1;
        if (!b.dueDate) return -1;

        result = new Date(a.dueDate) - new Date(b.dueDate);
      } else if (sortBy === 'priority') {
        const priorityRank = {
          'Cao': 3,
          'Trung bình': 2,
          'Thấp': 1,
        };

        result =
          (priorityRank[a.priority] || 0) -
          (priorityRank[b.priority] || 0);
      } else if (sortBy === 'createdAt') {
        result = new Date(a.createdAt) - new Date(b.createdAt);
      }

      if (result !== 0) {
        return result * direction;
      }

      return new Date(b.createdAt) - new Date(a.createdAt);
    });

    res.status(200).json({
      message: 'Lấy danh sách công việc thành công',
      tasks: classifiedTasks,
      sortBy,
      order,
    });

  } catch (error) {
    console.error('Lỗi lấy danh sách công việc:', error);

    res.status(500).json({
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

    const task = await Task.findOne({
      _id: id,
      userId,
    });

    if (!task) {
      return res.status(404).json({
        message: 'Không tìm thấy công việc hoặc bạn không có quyền chỉnh sửa',
      });
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

    await task.save();
    await task.populate('assignedTo', 'fullName email');

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
