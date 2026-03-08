import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/project_repository.dart';
import '../data/models/project_model.dart';
import '../data/models/task_model.dart';
import '../data/repositories/task_repository.dart';

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