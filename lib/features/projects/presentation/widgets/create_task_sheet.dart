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

  const CreateTaskSheet({super.key, required this.project});

  @override
  ConsumerState<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<CreateTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedAssigneeId; // UI tạm thời vẫn chọn 1 người cho nhanh
  DateTime? _selectedDeadline;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final newTask = TaskModel(
        id: '',
        projectId: widget.project.id,
        title: title,
        description: _descController.text.trim(),
        status: TaskStatus.todo,
        priority: TaskPriority.medium, // 🚀 Thêm Mức độ ưu tiên mặc định

        // 🚀 QUAN TRỌNG: Chuyển 1 người được chọn thành Mảng (List) để khớp Model mới
        assigneeIds: _selectedAssigneeId != null ? [_selectedAssigneeId!] : [],

        deadline: _selectedDeadline,
        createdAt: DateTime.now(),
        createdBy: currentUserId,
      );

      await ref.read(taskRepositoryProvider).createTask(newTask);
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thêm thẻ công việc', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold)),
            const Gap(20),

            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tên công việc',
                hintText: 'VD: Vẽ UI màn hình Kanban...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Gap(16),

            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Mô tả',
                hintText: 'VD: Nhờ Ký hoặc Đức chuẩn bị cấu trúc mảng...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const Gap(16),

            // 🚀 NÚT GIAO CHO AI ĐÃ QUAY TRỞ LẠI
            usersAsync.when(
              data: (users) {
                final projectMembers = users.where((u) => widget.project.memberIds.contains(u['uid'])).toList();

                return DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Giao cho ai?',
                    prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  value: _selectedAssigneeId,
                  items: projectMembers.map((user) {
                    return DropdownMenuItem<String>(
                      value: user['uid'],
                      child: Text(user['name'] ?? 'Ẩn danh', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedAssigneeId = val),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Lỗi tải danh sách'),
            ),
            const Gap(16),

            InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, color: _selectedDeadline == null ? Colors.grey : colorScheme.primary),
                    const Gap(12),
                    Text(
                      _selectedDeadline == null
                          ? 'Chọn hạn chót (Deadline)'
                          : 'Hạn chót: ${DateFormat('dd/MM/yyyy').format(_selectedDeadline!)}',
                      style: GoogleFonts.nunito(
                        color: _selectedDeadline == null ? Colors.grey.shade700 : Colors.black87,
                        fontSize: 16,
                        fontWeight: _selectedDeadline == null ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('TẠO CÔNG VIỆC', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}