import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../project_controller.dart';
import '../widgets/create_task_sheet.dart';
import '../widgets/add_member_sheet.dart';

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
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black87),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => AddMemberSheet(project: project),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_task_rounded, color: Colors.black87),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => CreateTaskSheet(project: project),
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

        final isOverdue = task.deadline != null &&
            task.deadline!.isBefore(DateTime.now()) &&
            task.status != TaskStatus.done;

        final deadlineColor = isOverdue ? Colors.red.shade600 : Colors.grey.shade500;
        final deadlineIcon = isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today_rounded;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isOverdue ? BorderSide(color: Colors.red.shade200, width: 1.5) : BorderSide.none,
          ),
          elevation: isOverdue ? 4 : 1,
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
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isOverdue ? Colors.red.shade900 : Colors.black87,
                        ),
                      ),
                    ),
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
                    Icon(deadlineIcon, size: 14, color: deadlineColor),
                    const Gap(4),
                    Text(
                      task.deadline != null
                          ? '${task.deadline!.day}/${task.deadline!.month}/${task.deadline!.year}'
                          : 'Không có hạn',
                      style: GoogleFonts.nunito(
                        color: deadlineColor,
                        fontSize: 12,
                        fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isOverdue) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Text('Trễ hạn', style: GoogleFonts.nunito(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    ],
                    const Spacer(),
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