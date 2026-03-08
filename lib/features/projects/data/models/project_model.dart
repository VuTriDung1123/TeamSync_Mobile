import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String colorHex;
  final List<String> memberIds;
  final Map<String, dynamic> roles; // 🚀 MỚI: Phân quyền {uid: 'owner', uid2: 'admin', uid3: 'member'}
  final DateTime createdAt;
  final String createdBy;

  ProjectModel({
    required this.id,
    required this.name,
    this.description = '',
    this.colorHex = '#FF2196F3',
    this.memberIds = const [],
    this.roles = const {}, // Khởi tạo roles rỗng
    required this.createdAt,
    required this.createdBy, required String ownerId,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    return ProjectModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      colorHex: map['colorHex'] ?? '#FF2196F3',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      roles: Map<String, dynamic>.from(map['roles'] ?? {}), // 🚀 Đọc Role từ Firebase
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '', ownerId: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'colorHex': colorHex,
      'memberIds': memberIds,
      'roles': roles, // 🚀 Lưu Role lên Firebase
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}