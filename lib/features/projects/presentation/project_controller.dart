import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/project_repository.dart';
import '../data/models/project_model.dart';

// Provider này sẽ tự động lắng nghe Firebase và cập nhật UI mỗi khi có Project mới
final userProjectsProvider = StreamProvider.autoDispose<List<ProjectModel>>((ref) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.getUserProjects();
});