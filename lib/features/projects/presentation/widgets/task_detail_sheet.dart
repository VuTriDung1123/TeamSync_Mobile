import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/task_model.dart';
import '../../data/repositories/task_repository.dart';

class TaskDetailSheet extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailSheet({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  final _checklistController = TextEditingController();

  // Danh sách các thẻ Tag có sẵn để chọn
  final List<String> _availableTags = ['Thiết kế', 'Lập trình', 'Lỗi (Bug)', 'Gấp', 'Họp'];

  @override
  void dispose() {
    _checklistController.dispose();
    super.dispose();
  }

  // 🚀 HÀM ĐÁNH DẤU CHECKLIST
  void _toggleChecklist(TaskModel task, int index) {
    final newList = List<ChecklistItem>.from(task.checklist);
    newList[index].isDone = !newList[index].isDone;
    ref.read(taskRepositoryProvider).updateTaskDetails(task.id, {
      'checklist': newList.map((e) => e.toMap()).toList()
    });
  }

  // 🚀 HÀM THÊM CHECKLIST MỚI
  void _addChecklist(TaskModel task) {
    final title = _checklistController.text.trim();
    if (title.isEmpty) return;

    final newList = List<ChecklistItem>.from(task.checklist);
    newList.add(ChecklistItem(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title));

    ref.read(taskRepositoryProvider).updateTaskDetails(task.id, {
      'checklist': newList.map((e) => e.toMap()).toList()
    });
    _checklistController.clear();
  }

  // 🚀 HÀM BẬT/TẮT THẺ TAG
  void _toggleTag(TaskModel task, String tag) {
    final newTags = List<String>.from(task.tags);
    if (newTags.contains(tag)) {
      newTags.remove(tag);
    } else {
      newTags.add(tag);
    }
    ref.read(taskRepositoryProvider).updateTaskDetails(task.id, {'tags': newTags});
  }

  // 🚀 HÀM ĐỔI ĐỘ ƯU TIÊN
  void _changePriority(TaskModel task, TaskPriority newPriority) {
    ref.read(taskRepositoryProvider).updateTaskDetails(task.id, {'priority': newPriority.name});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final taskAsync = ref.watch(singleTaskProvider(widget.taskId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // Chiếm 85% màn hình
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
        data: (task) {

          // Tính % hoàn thành checklist
          int doneCount = task.checklist.where((c) => c.isDone).length;
          double progress = task.checklist.isEmpty ? 0 : doneCount / task.checklist.length;

          return Column(
            children: [
              // HEADER (Nút đóng và Icon Thùng rác)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      onPressed: () {
                        ref.read(taskRepositoryProvider).deleteTask(task.id);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: GoogleFonts.nunito(fontSize: 26, fontWeight: FontWeight.bold)),
                      if (task.description.isNotEmpty) ...[
                        const Gap(8),
                        Text(task.description, style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade700)),
                      ],
                      const Gap(24),

                      // 1. MỨC ĐỘ ƯU TIÊN (PRIORITY)
                      Text('Mức độ ưu tiên', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const Gap(8),
                      Row(
                        children: TaskPriority.values.map((p) {
                          bool isSelected = task.priority == p;
                          Color pColor = p == TaskPriority.high ? Colors.red
                              : p == TaskPriority.medium ? Colors.orange : Colors.green;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(p.name.toUpperCase(), style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12)),
                              selected: isSelected,
                              selectedColor: pColor.withOpacity(0.2),
                              labelStyle: TextStyle(color: isSelected ? pColor : Colors.grey.shade600),
                              onSelected: (_) => _changePriority(task, p),
                            ),
                          );
                        }).toList(),
                      ),
                      const Gap(24),

                      // 2. THẺ TAGS (LABELS)
                      Text('Nhãn dán (Tags)', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                      const Gap(8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: _availableTags.map((tag) {
                          bool hasTag = task.tags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: hasTag,
                            selectedColor: colorScheme.primary.withOpacity(0.2),
                            checkmarkColor: colorScheme.primary,
                            onSelected: (_) => _toggleTag(task, tag),
                          );
                        }).toList(),
                      ),
                      const Gap(32),

                      // 3. CHECKLIST (CÔNG VIỆC CON)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Checklist công việc', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          Text('$doneCount/${task.checklist.length}', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                        ],
                      ),
                      const Gap(8),

                      // Thanh tiến trình (Tiến độ)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress, minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          color: progress == 1.0 ? Colors.green : colorScheme.primary,
                        ),
                      ),
                      const Gap(16),

                      // Danh sách các mục Checklist
                      ...List.generate(task.checklist.length, (index) {
                        final item = task.checklist[index];
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.green,
                          value: item.isDone,
                          title: Text(
                            item.title,
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              decoration: item.isDone ? TextDecoration.lineThrough : null,
                              color: item.isDone ? Colors.grey : Colors.black87,
                            ),
                          ),
                          onChanged: (_) => _toggleChecklist(task, index),
                        );
                      }),

                      // Khung nhập Checklist mới
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _checklistController,
                              decoration: InputDecoration(
                                hintText: 'Thêm mục mới...',
                                filled: true, fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              onSubmitted: (_) => _addChecklist(task),
                            ),
                          ),
                          const Gap(8),
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
                            icon: const Icon(Icons.add),
                            onPressed: () => _addChecklist(task),
                          )
                        ],
                      ),
                      const Gap(40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}