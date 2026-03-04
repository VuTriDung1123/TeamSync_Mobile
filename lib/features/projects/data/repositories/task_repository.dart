import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';

// Provider cho Task
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(FirebaseFirestore.instance);
});

class TaskRepository {
  final FirebaseFirestore _firestore;

  TaskRepository(this._firestore);

  // 1. THÊM: Tạo Task mới
  Future<void> createTask(TaskModel task) async {
    await _firestore.collection('tasks').add(task.toMap());
  }

  // 2. ĐỌC: Lấy toàn bộ Task của một Dự án cụ thể (Dùng cho bảng Kanban)
  Stream<List<TaskModel>> getProjectTasks(String projectId) {
    return _firestore
        .collection('tasks')
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true) // Xếp task mới lên trên
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 3. SỬA NHANH: Cập nhật trạng thái khi người dùng kéo thả cột Kanban
  Future<void> updateTaskStatus(String taskId, TaskStatus newStatus) async {
    await _firestore.collection('tasks').doc(taskId).update({
      'status': newStatus.name,
    });
  }

  // 4. SỬA CHI TIẾT: Gán người làm (Assignee), đổi Deadline, đổi tên...
  Future<void> updateTaskDetails(String taskId, Map<String, dynamic> data) async {
    await _firestore.collection('tasks').doc(taskId).update(data);
  }

  // 5. XÓA: Xóa Task
  Future<void> deleteTask(String taskId) async {
    await _firestore.collection('tasks').doc(taskId).delete();
  }
}