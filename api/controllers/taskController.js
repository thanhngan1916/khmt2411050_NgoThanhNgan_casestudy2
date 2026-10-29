
const mongoose = require('mongoose');
const Task = require('../models/Task');

// 1. Xem danh sách công việc
const getTaskList = async (req, res) => {
  try {
    const userId = req.user.id;

    const tasks = await Task.find({
      $or: [
        { userId },
        { assignedTo: userId },
        { receivedBy: userId },
        { sharedWith: userId },
      ],
    }).sort({ createdAt: -1 });

    res.status(200).json({
      message: 'Lấy danh sách công việc thành công',
      tasks,
    });
  } catch (error) {
    console.error('Lỗi lấy danh sách công việc:', error);
    res.status(500).json({
      message: 'Không thể lấy danh sách công việc',
    });
  }
};

// Kiểm tra ID công việc
const validateTaskId = (id) => {
  return mongoose.Types.ObjectId.isValid(id);
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
    const userId = req.user.id;
    const {
      title,
      description,
      dueDate,
      priority,
      status,
    } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        message: 'Vui lòng nhập tên công việc',
      });
    }

    const taskData = {
      userId,
      title: title.trim(),
      description: description || '',
      priority: priority || 'Trung bình',
      status: status || 'Chưa thực hiện',
    };

    if (dueDate) {
      const parsedDate = new Date(dueDate);

      if (Number.isNaN(parsedDate.getTime())) {
        return res.status(400).json({
          message: 'Ngày hết hạn không hợp lệ',
        });
      }

      taskData.dueDate = parsedDate;
    }

    const task = await Task.create(taskData);

    res.status(201).json({
      message: 'Tạo công việc thành công',
      task,
    });
  } catch (error) {
      console.error('Lỗi tạo công việc:', error.message);
      console.error('Chi tiết lỗi:', error);

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

    const { title, description, dueDate, priority, status } = req.body;

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

    if (dueDate !== undefined) {
      if (dueDate === null || dueDate === '') {
        task.dueDate = null;
      } else {
        const parsedDate = new Date(dueDate);

        if (Number.isNaN(parsedDate.getTime())) {
          return res.status(400).json({
            message: 'Ngày hết hạn không hợp lệ',
          });
        }

        task.dueDate = parsedDate;
      }
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

    await task.save();

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
