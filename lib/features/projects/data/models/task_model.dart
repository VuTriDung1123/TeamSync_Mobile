import 'package:cloud_firestore/cloud_firestore.dart';

// Định nghĩa 3 trạng thái của bảng Kanban
enum TaskStatus { todo, inProgress, done }

class TaskModel {
  final String id;
  final String projectId; // Task này thuộc về dự án nào
  final String title;
  final String description;
  final TaskStatus status; // Trạng thái hiện tại
  final String? assigneeId; // UID của người được giao việc (Có thể null nếu chưa giao)
  final DateTime? deadline; // Hạn chót (Có thể null)
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.status,
    this.assigneeId,
    this.deadline,
    required this.createdAt,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TaskModel(
      id: documentId,
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      // Chuyển string từ Firebase thành Enum
      status: TaskStatus.values.firstWhere(
            (e) => e.name == (map['status'] ?? 'todo'),
        orElse: () => TaskStatus.todo,
      ),
      assigneeId: map['assigneeId'],
      deadline: map['deadline'] != null ? (map['deadline'] as Timestamp).toDate() : null,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status.name, // Lưu Enum dưới dạng chữ (todo, inProgress, done)
      'assigneeId': assigneeId,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}