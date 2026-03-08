import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { todo, inProgress, review, done }
enum TaskPriority { low, medium, high } // 🚀 MỚI: Mức độ ưu tiên

// 🚀 MỚI: Model cho Checklist con (Ví dụ: Các bước nhỏ trong 1 Task)
class ChecklistItem {
  String id;
  String title;
  bool isDone;

  ChecklistItem({required this.id, required this.title, this.isDone = false});

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isDone: map['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'isDone': isDone};
  }
}

class TaskModel {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority; // 🚀 MỚI
  final List<String> assigneeIds;
  final List<String> tags; // 🚀 MỚI: Nhãn dán (Labels)
  final List<ChecklistItem> checklist; // 🚀 MỚI: Checklist con
  final DateTime? deadline;
  final DateTime createdAt;
  final String createdBy;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium, // Mặc định là Medium
    this.assigneeIds = const [],
    this.tags = const [],
    this.checklist = const [],
    this.deadline,
    required this.createdAt,
    required this.createdBy, String? assigneeId,
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    return TaskModel(
      id: id,
      projectId: map['projectId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      status: TaskStatus.values.firstWhere(
            (e) => e.name == (map['status'] ?? 'todo'),
        orElse: () => TaskStatus.todo,
      ),
      priority: TaskPriority.values.firstWhere(
            (e) => e.name == (map['priority'] ?? 'medium'),
        orElse: () => TaskPriority.medium,
      ),
      assigneeIds: List<String>.from(map['assigneeIds'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      checklist: (map['checklist'] as List<dynamic>?)
          ?.map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item)))
          .toList() ?? [],
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'assigneeIds': assigneeIds,
      'tags': tags,
      'checklist': checklist.map((item) => item.toMap()).toList(),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}