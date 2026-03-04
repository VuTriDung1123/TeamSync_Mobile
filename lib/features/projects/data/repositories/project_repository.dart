import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project_model.dart';

// Provider để gọi ở các tầng giao diện (UI)
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

class ProjectRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProjectRepository(this._firestore, this._auth);

  // 1. THÊM: Tạo dự án mới
  Future<void> createProject(ProjectModel project) async {
    await _firestore.collection('projects').add(project.toMap());
  }

  // 2. ĐỌC: Lấy danh sách dự án của user hiện tại (Dùng Stream để UI tự cập nhật realtime)
  Stream<List<ProjectModel>> getUserProjects() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    // Tuyệt chiêu arrayContains: Chỉ lấy những dự án mà UID của mình nằm trong mảng memberIds
    return _firestore
        .collection('projects')
        .where('memberIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ProjectModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // 3. SỬA: Cập nhật tên, mô tả, màu sắc...
  Future<void> updateProject(String projectId, Map<String, dynamic> data) async {
    await _firestore.collection('projects').doc(projectId).update(data);
  }

  // 4. XÓA: Xóa dự án
  Future<void> deleteProject(String projectId) async {
    await _firestore.collection('projects').doc(projectId).delete();
    // (Mở rộng sau: Khi xóa Project thì nên xóa luôn các Task bên trong nó)
  }
}