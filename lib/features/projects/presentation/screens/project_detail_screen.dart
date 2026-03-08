import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../widgets/create_task_sheet.dart';
import 'project_settings_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  // Cấu hình các cột Kanban
  final List<TaskStatus> _columns = [
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.review,
    TaskStatus.done,
  ];

  String _getColumnName(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo: return 'CẦN LÀM';
      case TaskStatus.inProgress: return 'ĐANG LÀM';
      case TaskStatus.review: return 'ĐANG DUYỆT';
      case TaskStatus.done: return 'HOÀN THÀNH';
    }
  }

  Color _getColumnColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo: return Colors.grey.shade300;
      case TaskStatus.inProgress: return Colors.blue.shade200;
      case TaskStatus.review: return Colors.orange.shade300;
      case TaskStatus.done: return Colors.green.shade300;
    }
  }

  Color hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final projectColor = hexToColor(widget.project.colorHex);

    // Lấy danh sách toàn bộ Task của dự án này
    final tasksAsync = ref.watch(projectTasksProvider(widget.project.id));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: projectColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(widget.project.name, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectSettingsScreen(project: widget.project),
                ),
              );
            },
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Lỗi tải công việc')),
        data: (allTasks) {
          return Column(
            children: [
              // Thanh chứa nút "Thêm công việc"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: projectColor.withOpacity(0.1),
                  border: Border(bottom: BorderSide(color: projectColor.withOpacity(0.3))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${allTasks.length} Công việc', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: projectColor, foregroundColor: Colors.white, elevation: 0),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context, isScrollControlled: true,
                          builder: (context) => CreateTaskSheet(project: widget.project),
                        );
                      },
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: Text('Thêm Task', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 🚀 BẢNG KANBAN KÉO THẢ (Vuốt ngang được)
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(16),
                  itemCount: _columns.length,
                  itemBuilder: (context, colIndex) {
                    final status = _columns[colIndex];
                    // Lọc ra các Task thuộc cột này
                    final columnTasks = allTasks.where((t) => t.status == status).toList();

                    return Container(
                      width: 280, // Chiều rộng mỗi cột
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. HEADER CỦA CỘT
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _getColumnColor(status).withOpacity(0.3),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_getColumnName(status), style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Text('${columnTasks.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),

                          // 2. KHU VỰC THẢ TASK VÀO (DRAG TARGET)
                          Expanded(
                            child: DragTarget<TaskModel>(
                              // Cho phép thả vào cột này nếu Task đang kéo khác trạng thái với cột hiện tại
                              onWillAcceptWithDetails: (details) => details.data.status != status,
                              // Khi thả thành công -> Cập nhật Database
                              onAcceptWithDetails: (details) {
                                ref.read(taskRepositoryProvider).updateTaskStatus(details.data.id, status);
                              },
                              builder: (context, candidateData, rejectedData) {
                                return Container(
                                  // Hiệu ứng đổi màu cột khi đang kéo Task lơ lửng bên trên
                                  color: candidateData.isNotEmpty ? _getColumnColor(status).withOpacity(0.1) : Colors.transparent,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: columnTasks.length,
                                    itemBuilder: (context, taskIndex) {
                                      final task = columnTasks[taskIndex];

                                      // 3. WIDGET CÓ THỂ KÉO ĐƯỢC (DRAGGABLE)
                                      return LongPressDraggable<TaskModel>(
                                        data: task,
                                        // Giao diện khi đang bay lơ lửng trên tay
                                        feedback: Material(
                                          elevation: 8, borderRadius: BorderRadius.circular(12),
                                          child: SizedBox(
                                            width: 260,
                                            child: _buildTaskCard(task, isDragging: true),
                                          ),
                                        ),
                                        // Giao diện để lại dưới nền khi đang kéo đi
                                        childWhenDragging: Opacity(
                                          opacity: 0.3,
                                          child: _buildTaskCard(task),
                                        ),
                                        // Giao diện bình thường
                                        child: _buildTaskCard(task),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Giao diện của 1 thẻ Task
  Widget _buildTaskCard(TaskModel task, {bool isDragging = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: isDragging ? [BoxShadow(color: Colors.black26, blurRadius: 10)] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mức độ ưu tiên
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: task.priority == TaskPriority.high ? Colors.red.shade100
                  : task.priority == TaskPriority.medium ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              task.priority.name.toUpperCase(),
              style: GoogleFonts.nunito(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: task.priority == TaskPriority.high ? Colors.red.shade700
                    : task.priority == TaskPriority.medium ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          const Gap(8),
          Text(task.title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
          if (task.description.isNotEmpty) ...[
            const Gap(4),
            Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 13)),
          ],
          const Gap(12),
          // Hàng dưới cùng: Checklist và Avatar người làm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Checklist
              if (task.checklist.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.check_box_outlined, size: 14, color: Colors.grey.shade600),
                    const Gap(4),
                    Text('${task.checklist.where((i) => i.isDone).length}/${task.checklist.length}', style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                )
              else
                const SizedBox(),

              // Avatar người phụ trách (Tạm thời vẽ hình tròn)
              if (task.assigneeIds.isNotEmpty)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.person, size: 14, color: Colors.blue),
                ),
            ],
          )
        ],
      ),
    );
  }
}