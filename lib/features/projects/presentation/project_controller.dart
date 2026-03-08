  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../data/repositories/project_repository.dart';
  import '../data/models/project_model.dart';
  import '../data/models/task_model.dart';
  import '../data/repositories/task_repository.dart';
  import 'package:firebase_auth/firebase_auth.dart';

  // Lấy danh sách dự án của user
  final userProjectsProvider = StreamProvider.autoDispose<List<ProjectModel>>((ref) {
    final repository = ref.watch(projectRepositoryProvider);
    return repository.getUserProjects();
  });

  // Lấy danh sách Task theo Project ID
  final projectTasksProvider = StreamProvider.autoDispose.family<List<TaskModel>, String>((ref, projectId) {
    final repository = ref.watch(taskRepositoryProvider);
    return repository.getProjectTasks(projectId);
  });

  final myActiveTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    final firestore = FirebaseFirestore.instance;
    return firestore
        .collection('tasks')
        .where('assigneeId', isEqualTo: uid)
    // Lọc bỏ những task đã xong
        .where('status', isNotEqualTo: TaskStatus.done.name)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  });