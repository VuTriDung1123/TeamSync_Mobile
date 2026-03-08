import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../data/chat_repository.dart';

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleUser(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên nhóm')));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất 1 thành viên')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(chatRepositoryProvider).createGroupChat(groupName, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo nhóm thành công!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tạo nhóm: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final usersAsync = ref.watch(usersStreamProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 24,
      ),
      // Set chiều cao tối đa bằng 80% màn hình
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tạo nhóm Chat', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.bold)),
          const Gap(16),

          // 1. Nhập tên nhóm
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Tên nhóm',
              hintText: 'VD: Hội chém gió SD-WAN',
              prefixIcon: Icon(Icons.group_rounded, color: colorScheme.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const Gap(16),

          Text('Chọn thành viên:', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const Gap(8),

          // 2. Danh sách User để tích chọn
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Lỗi: $e')),
              data: (users) {
                if (users.isEmpty) return const Center(child: Text('Chưa có ai để thêm vào nhóm.'));

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUserIds.contains(user['uid']);
                    final avatar = user['avatar'] ?? '';
                    final name = user['name'] ?? 'Ẩn danh';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary.withOpacity(0.2),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty ? Text(name[0].toUpperCase()) : null,
                      ),
                      title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (_) => _toggleUser(user['uid']),
                      ),
                      onTap: () => _toggleUser(user['uid']),
                    );
                  },
                );
              },
            ),
          ),
          const Gap(16),

          // 3. Nút Tạo Nhóm
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('TẠO NHÓM (${_selectedUserIds.length})', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}