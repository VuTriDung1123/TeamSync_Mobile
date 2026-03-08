import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../../../features/auth/data/user_repository.dart';

class CreateTaskSheet extends ConsumerStatefulWidget {
  final ProjectModel project;
  final String? taskId; // 🚀 THÊM: Nếu có taskId thì là Sửa, không thì là Tạo

  const CreateTaskSheet({super.key, required this.project, this.taskId});

  @override
  ConsumerState<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<CreateTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _checklistController = TextEditingController();

  String? _selectedAssigneeId;
  DateTime? _selectedDeadline;
  TaskPriority _selectedPriority = TaskPriority.medium;
  List<String> _selectedTags = [];
  List<ChecklistItem> _checklist = [];

  bool _isLoading = false;
  bool _isDataLoaded = false; // Cờ để tránh việc ghi đè controller liên tục

  final List<String> _availableTags = ['Thiết kế', 'Lập trình', 'Lỗi (Bug)', 'Gấp', 'Họp'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  // 🚀 Hàm đổ dữ liệu cũ vào form nếu là chế độ Sửa
  void _populateData(TaskModel task) {
    if (!_isDataLoaded) {
      _titleController.text = task.title;
      _descController.text = task.description;
      _selectedAssigneeId = task.assigneeIds.isNotEmpty ? task.assigneeIds.first : null;
      _selectedDeadline = task.deadline;
      _selectedPriority = task.priority;
      _selectedTags = List.from(task.tags);
      _checklist = List.from(task.checklist);
      _isDataLoaded = true;
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDeadline = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (widget.taskId == null) {
        // 🚀 CHẾ ĐỘ TẠO MỚI
        final newTask = TaskModel(
          id: '',
          projectId: widget.project.id,
          title: title,
          description: _descController.text.trim(),
          status: TaskStatus.todo,
          priority: _selectedPriority,
          assigneeIds: _selectedAssigneeId != null ? [_selectedAssigneeId!] : [],
          tags: _selectedTags,
          checklist: _checklist,
          deadline: _selectedDeadline,
          createdAt: DateTime.now(),
          createdBy: currentUserId,
        );
        await ref.read(taskRepositoryProvider).createTask(newTask);
      } else {
        // 🚀 CHẾ ĐỘ CẬP NHẬT
        await ref.read(taskRepositoryProvider).updateTaskDetails(widget.taskId!, {
          'title': title,
          'description': _descController.text.trim(),
          'priority': _selectedPriority.name,
          'assigneeIds': _selectedAssigneeId != null ? [_selectedAssigneeId!] : [],
          'tags': _selectedTags,
          'checklist': _checklist.map((e) => e.toMap()).toList(),
          'deadline': _selectedDeadline,
        });
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usersAsync = ref.watch(usersStreamProvider);

    // 🚀 Lắng nghe dữ liệu nếu đang ở chế độ Sửa
    if (widget.taskId != null) {
      final taskStream = ref.watch(singleTaskProvider(widget.taskId!));
      taskStream.whenData((task) => _populateData(task));
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.taskId == null ? 'Thêm công việc' : 'Chi tiết công việc',
                    style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold)),
                if (widget.taskId != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      ref.read(taskRepositoryProvider).deleteTask(widget.taskId!);
                      Navigator.pop(context);
                    },
                  )
              ],
            ),
            const Gap(16),

            // 1. Tiêu đề & Mô tả
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên công việc', border: OutlineInputBorder()),
            ),
            const Gap(16),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Mô tả', border: OutlineInputBorder()),
            ),
            const Gap(16),

            // 2. Độ ưu tiên (Priority)
            Text('Mức độ ưu tiên', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            Row(
              children: TaskPriority.values.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p.name.toUpperCase()),
                    selected: _selectedPriority == p,
                    onSelected: (val) => setState(() => _selectedPriority = p),
                  ),
                );
              }).toList(),
            ),
            const Gap(16),

            // 3. Giao cho ai & Deadline
            Row(
              children: [
                Expanded(
                  child: usersAsync.when(
                    data: (users) {
                      final members = users.where((u) => widget.project.memberIds.contains(u['uid'])).toList();
                      return DropdownButtonFormField<String>(
                        value: _selectedAssigneeId,
                        decoration: const InputDecoration(labelText: 'Giao cho', border: OutlineInputBorder()),
                        items: members.map((u) => DropdownMenuItem(value: u['uid'].toString(), child: Text(u['name'] ?? ''))).toList(),
                        onChanged: (v) => setState(() => _selectedAssigneeId = v),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20)),
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_selectedDeadline == null ? 'Hạn chót' : DateFormat('dd/MM').format(_selectedDeadline!)),
                    onPressed: _pickDeadline,
                  ),
                ),
              ],
            ),
            const Gap(16),

            // 4. Nhãn dán (Tags)
            Text('Nhãn dán', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: _availableTags.map((tag) => FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (val) => setState(() => val ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
              )).toList(),
            ),
            const Gap(16),

            // 5. Checklist (Công việc con)
            Text('Checklist', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ..._checklist.asMap().entries.map((entry) => CheckboxListTile(
              title: Text(entry.value.title, style: TextStyle(decoration: entry.value.isDone ? TextDecoration.lineThrough : null)),
              value: entry.value.isDone,
              onChanged: (v) => setState(() => _checklist[entry.key].isDone = v!),
              controlAffinity: ListTileControlAffinity.leading,
            )),
            Row(
              children: [
                Expanded(child: TextField(controller: _checklistController, decoration: const InputDecoration(hintText: 'Thêm việc con...'))),
                IconButton(icon: const Icon(Icons.add_box), onPressed: () {
                  if (_checklistController.text.isNotEmpty) {
                    setState(() => _checklist.add(ChecklistItem(id: DateTime.now().toString(), title: _checklistController.text)));
                    _checklistController.clear();
                  }
                }),
              ],
            ),
            const Gap(30),

            // 6. Nút Gửi / Lưu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(widget.taskId == null ? 'TẠO CÔNG VIỆC' : 'LƯU THAY ĐỔI',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }
}