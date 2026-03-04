import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String colorHex; // Lưu màu sắc dưới dạng chuỗi hex (vd: #FFB6C1)
  final String ownerId; // Ai là người tạo dự án này
  final List<String> memberIds; // Danh sách UID các thành viên trong dự án
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.colorHex,
    required this.ownerId,
    required this.memberIds,
    required this.createdAt,
  });

  // Chuyển từ JSON (Firestore) sang Object trong App
  factory ProjectModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProjectModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      colorHex: map['colorHex'] ?? '#FF5722', // Mặc định màu cam nếu thiếu
      ownerId: map['ownerId'] ?? '',
      memberIds: List<String>.from(map['memberIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Đóng gói Object thành JSON để đẩy lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'colorHex': colorHex,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}