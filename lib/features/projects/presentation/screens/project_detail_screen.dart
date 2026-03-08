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
import '../widgets/task_detail_sheet.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  // 🚀 TÍNH NĂNG MỚI: Biến trạng thái để Quản lý Lọc và View
  bool _isCalendarView = false; // Đang xem dạng Lịch hay Kanban?
  TaskPriority? _filterPriority; // Bộ lọc độ ưu tiên (null = TẤT CẢ)
  DateTime _selectedDate = DateTime.now(); // Ngày đang chọn trên Lịch

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

  // Hàm so sánh 2 ngày (bỏ qua giờ/phút/giây)
  bool isSameDay(DateTime? d1, DateTime? d2) {
    if (d1 == null || d2 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    final projectColor = hexToColor(widget.project.colorHex);
    final tasksAsync = ref.watch(projectTasksProvider(widget.project.id));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: projectColor,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(widget.project.name, style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // 🚀 1. NÚT LỌC (FILTER) PRIORITY
          PopupMenuButton<TaskPriority?>(
            icon: Icon(Icons.filter_list_rounded, color: _filterPriority == null ? Colors.white : Colors.amberAccent),
            tooltip: 'Lọc độ ưu tiên',
            onSelected: (val) => setState(() => _filterPriority = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Hiển thị tất cả')),
              const PopupMenuItem(value: TaskPriority.high, child: Text('🔴 Quan trọng cao')),
              const PopupMenuItem(value: TaskPriority.medium, child: Text('🟠 Bình thường')),
              const PopupMenuItem(value: TaskPriority.low, child: Text('🟢 Ưu tiên thấp')),
            ],
          ),

          // 🚀 2. NÚT CHUYỂN ĐỔI KANBAN / CALENDAR
          IconButton(
            icon: Icon(_isCalendarView ? Icons.view_kanban_rounded : Icons.calendar_month_rounded, color: Colors.white),
            tooltip: _isCalendarView ? 'Xem dạng Bảng Kanban' : 'Xem dạng Lịch',
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
          ),

          // NÚT SETTING (Vẫn giữ nguyên)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProjectSettingsScreen(project: widget.project))),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Lỗi tải công việc')),
        data: (allTasks) {

          // 🚀 ÁP DỤNG BỘ LỌC NẾU CÓ
          var displayTasks = allTasks;
          if (_filterPriority != null) {
            displayTasks = displayTasks.where((t) => t.priority == _filterPriority).toList();
          }

          return Column(
            children: [
              // Thanh chứa Header thông tin chung
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: projectColor.withOpacity(0.1), border: Border(bottom: BorderSide(color: projectColor.withOpacity(0.3)))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${displayTasks.length} Công việc ${_filterPriority != null ? "(Đã lọc)" : ""}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87)),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: projectColor, foregroundColor: Colors.white, elevation: 0),
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => CreateTaskSheet(project: widget.project)),
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: Text('Thêm Task', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 🚀 RẼ NHÁNH GIAO DIỆN DỰA VÀO BIẾN _isCalendarView
              Expanded(
                child: _isCalendarView
                    ? _buildCalendarView(displayTasks, projectColor) // 📅 GIAO DIỆN LỊCH
                    : _buildKanbanView(displayTasks),                // 📋 GIAO DIỆN BẢNG
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // 📋 GIAO DIỆN BẢNG KÉO THẢ (KANBAN VIEW)
  // ==========================================
  Widget _buildKanbanView(List<TaskModel> displayTasks) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      itemCount: _columns.length,
      itemBuilder: (context, colIndex) {
        final status = _columns[colIndex];
        final columnTasks = displayTasks.where((t) => t.status == status).toList();

        return Container(
          width: 280,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _getColumnColor(status).withOpacity(0.3), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
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
              Expanded(
                child: DragTarget<TaskModel>(
                  onWillAcceptWithDetails: (details) => details.data.status != status,
                  onAcceptWithDetails: (details) {
                    ref.read(taskRepositoryProvider).updateTaskStatus(details.data.id, status);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Container(
                      color: candidateData.isNotEmpty ? _getColumnColor(status).withOpacity(0.1) : Colors.transparent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: columnTasks.length,
                        itemBuilder: (context, taskIndex) {
                          final task = columnTasks[taskIndex];
                          return LongPressDraggable<TaskModel>(
                            data: task,
                            feedback: Material(elevation: 8, borderRadius: BorderRadius.circular(12), child: SizedBox(width: 260, child: _buildTaskCard(task, isDragging: true))),
                            childWhenDragging: Opacity(opacity: 0.3, child: _buildTaskCard(task)),
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
    );
  }

  // ==========================================
  // 📅 GIAO DIỆN LỊCH (CALENDAR VIEW)
  // ==========================================
  Widget _buildCalendarView(List<TaskModel> displayTasks, Color projectColor) {
    // Tìm các task có deadline trùng với ngày đang chọn
    final tasksOnSelectedDate = displayTasks.where((t) => isSameDay(t.deadline, _selectedDate)).toList();

    return Column(
      children: [
        // 1. Widget Lịch mặc định của Flutter
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(primary: projectColor),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              onDateChanged: (newDate) {
                setState(() => _selectedDate = newDate);
              },
            ),
          ),
        ),

        // 2. Danh sách Task của ngày hôm đó
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Công việc tới hạn ngày ${_selectedDate.day}/${_selectedDate.month}', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold)),
                const Gap(12),
                if (tasksOnSelectedDate.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text('Không có công việc nào tới hạn vào ngày này 🏖️', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: tasksOnSelectedDate.length,
                      itemBuilder: (context, index) {
                        return _buildTaskCard(tasksOnSelectedDate[index]); // Tái sử dụng giao diện thẻ Kanban
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 🏷️ GIAO DIỆN THẺ TASK (DÙNG CHUNG CHO CẢ 2 VIEW)
  // ==========================================
  Widget _buildTaskCard(TaskModel task, {bool isDragging = false}) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => CreateTaskSheet(project: widget.project, taskId: task.id),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: isDragging ? [const BoxShadow(color: Colors.black26, blurRadius: 10)] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: task.priority == TaskPriority.high ? Colors.red.shade100 : task.priority == TaskPriority.medium ? Colors.orange.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(task.priority.name.toUpperCase(), style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: task.priority == TaskPriority.high ? Colors.red.shade700 : task.priority == TaskPriority.medium ? Colors.orange.shade700 : Colors.green.shade700)),
                ),
                // Hiển thị trạng thái (Dành riêng cho View Lịch để biết Task đang ở cột nào)
                if (_isCalendarView)
                  Text(_getColumnName(task.status), style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              ],
            ),

            if (task.tags.isNotEmpty) ...[
              const Gap(8),
              Wrap(
                spacing: 4, runSpacing: 4,
                children: task.tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(tag, style: GoogleFonts.nunito(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)))).toList(),
              ),
            ],
            const Gap(8),
            Text(task.title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
            if (task.description.isNotEmpty) ...[
              const Gap(4),
              Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 13)),
            ],
            const Gap(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (task.checklist.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.check_box_outlined, size: 14, color: Colors.grey.shade600),
                      const Gap(4),
                      Text('${task.checklist.where((i) => i.isDone).length}/${task.checklist.length}', style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  )
                else const SizedBox(),
                if (task.assigneeIds.isNotEmpty)
                  CircleAvatar(radius: 12, backgroundColor: Colors.blue.shade100, child: const Icon(Icons.person, size: 14, color: Colors.blue)),
              ],
            )
          ],
        ),
      ),
    );
  }
}