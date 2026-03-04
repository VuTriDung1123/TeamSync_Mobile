import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../project_controller.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectColor = Color(int.parse(project.colorHex.replaceFirst('#', '0xFF')));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF5F7),
        appBar: AppBar(
          backgroundColor: projectColor.withOpacity(0.2),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => context.pop(),
          ),
          title: Text(
            project.name,
            style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_task_rounded, color: Colors.black87),
              onPressed: () {
                // TODO: Gọi BottomSheet tạo Task mới (Làm ở phần sau)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng thêm Task đang được xây dựng!')),
                );
              },
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey,
            indicatorColor: projectColor,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'CẦN LÀM'),
              Tab(text: 'ĐANG LÀM'),
              Tab(text: 'ĐÃ XONG'),
            ],
          ),
        ),
        body: ref.watch(projectTasksProvider(project.id)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Lỗi: $err')),
          data: (tasks) {
            // Lọc Task vào 3 danh sách riêng biệt
            final todoTasks = tasks.where((t) => t.status == TaskStatus.todo).toList();
            final inProgressTasks = tasks.where((t) => t.status == TaskStatus.inProgress).toList();
            final doneTasks = tasks.where((t) => t.status == TaskStatus.done).toList();

            return TabBarView(
              children: [
                _buildTaskList(todoTasks, colorScheme, ref),
                _buildTaskList(inProgressTasks, colorScheme, ref),
                _buildTaskList(doneTasks, colorScheme, ref),
              ],
            );
          },
        ),
      ),
    );
  }

  // Giao diện danh sách Task
  Widget _buildTaskList(List<TaskModel> tasks, ColorScheme colorScheme, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'Chưa có công việc nào ở đây.',
          style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Nút bấm chọn chuyển cột (Thay vì kéo thả dễ lỗi trên mobile)
                    PopupMenuButton<TaskStatus>(
                      icon: Icon(Icons.swap_horiz_rounded, color: colorScheme.primary),
                      tooltip: 'Chuyển trạng thái',
                      onSelected: (newStatus) {
                        ref.read(taskRepositoryProvider).updateTaskStatus(task.id, newStatus);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: TaskStatus.todo, child: Text('Cần làm')),
                        const PopupMenuItem(value: TaskStatus.inProgress, child: Text('Đang làm')),
                        const PopupMenuItem(value: TaskStatus.done, child: Text('Hoàn thành')),
                      ],
                    ),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const Gap(4),
                  Text(task.description, style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 14)),
                ],
                const Gap(12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                    const Gap(4),
                    Text(
                      task.deadline != null
                          ? '${task.deadline!.day}/${task.deadline!.month}/${task.deadline!.year}'
                          : 'Không có hạn',
                      style: GoogleFonts.nunito(color: Colors.grey.shade500, fontSize: 12),
                    ),
                    const Spacer(),
                    // Tạm thời hiển thị icon user, sau này sẽ map với Avatar thật
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: colorScheme.primary.withOpacity(0.2),
                      child: const Icon(Icons.person, size: 14, color: Colors.black54),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}