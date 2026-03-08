import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository.dart';

class CreateProjectSheet extends ConsumerStatefulWidget {
  const CreateProjectSheet({super.key});

  @override
  ConsumerState<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends ConsumerState<CreateProjectSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Danh sách các màu để chọn (Sakura Pink, Blue, Orange, Purple, Green)
  final List<String> _colors = ['#FFB7B2', '#A2C2E6', '#FFDAC1', '#C5A3FF', '#B5EAD7'];
  String _selectedColor = '#FFB7B2'; // Mặc định chọn màu hồng Sakura
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final newProject = ProjectModel(
        id: '', // Sẽ do Firestore tự tạo
        name: name,
        description: _descController.text.trim(),
        colorHex: _selectedColor,
        ownerId: uid,
        memberIds: [uid], // Khởi tạo thì mình là thành viên đầu tiên
        createdAt: DateTime.now(), createdBy: '',
      );

      await ref.read(projectRepositoryProvider).createProject(newProject);
      if (mounted) Navigator.pop(context); // Tạo xong thì đóng sheet lại
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hàm chuyển mã Hex thành Color của Flutter
  Color hexToColor(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding này giúp form không bị bàn phím che khuất
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tạo Dự án mới', style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold)),
          const Gap(20),

          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tên dự án',
              hintText: 'VD: Báo cáo mô phỏng SD-WAN...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Gap(16),

          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Mô tả ngắn',
              hintText: 'VD: Nhóm 5 người (Ký, Đức, Linh, Nam, Quyết)...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Gap(16),

          Text('Chọn màu đặc trưng:', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          const Gap(8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _colors.map((colorStr) {
              final color = hexToColor(colorStr);
              final isSelected = _selectedColor == colorStr;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorStr),
                child: CircleAvatar(
                  backgroundColor: color,
                  radius: 20,
                  child: isSelected ? const Icon(Icons.check, color: Colors.black54) : null,
                ),
              );
            }).toList(),
          ),
          const Gap(24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('TẠO DỰ ÁN', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}