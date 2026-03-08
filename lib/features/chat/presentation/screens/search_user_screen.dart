import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../../../../features/auth/data/user_repository.dart';
import 'chat_screen.dart';

// Biến lưu trữ từ khóa do người dùng gõ
final searchQueryProvider = StateProvider<String>((ref) => '');

class SearchUserScreen extends ConsumerWidget {
  const SearchUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final searchQuery = ref.watch(searchQueryProvider);

    // 💡 SỬA Ở ĐÂY: Dùng usersStreamProvider thay vì gọi tìm kiếm trên Firebase
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            Navigator.of(context).pop();
          },
        ),
        title: TextField(
          autofocus: true,
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
          decoration: InputDecoration(
            hintText: 'Nhập Tên hoặc Email...',
            hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
            border: InputBorder.none,
          ),
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: searchQuery.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 80, color: colorScheme.primary.withOpacity(0.3)),
            const Gap(16),
            Text(
              'Tìm kiếm đồng đội',
              style: GoogleFonts.nunito(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      )
          : usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (users) {

          // 💡 SỬA Ở ĐÂY: Logic Lọc (Filter) thủ công bằng Dart
          final filteredUsers = users.where((user) {
            final name = (user['name'] ?? '').toString().toLowerCase();
            final email = (user['email'] ?? '').toString().toLowerCase();
            final query = searchQuery.toLowerCase();

            // Chỉ lấy những user có Tên hoặc Email chứa từ khóa
            return name.contains(query) || email.contains(query);
          }).toList();

          if (filteredUsers.isEmpty) {
            return Center(
              child: Text(
                'Không tìm thấy ai phù hợp 😥',
                style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final name = user['name'] ?? 'Ẩn danh';
              final email = user['email'] ?? '';
              final uid = user['uid'] ?? '';
              final avatar = user['avatar'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primary.withOpacity(0.2),
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                  subtitle: Text(email, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Chat', style: GoogleFonts.nunito(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: uid,
                          receiverName: name,
                          receiverAvatar: avatar,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}