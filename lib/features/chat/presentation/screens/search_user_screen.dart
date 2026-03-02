import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../../../../features/auth/data/user_repository.dart';
import 'chat_screen.dart';

class SearchUserScreen extends ConsumerWidget {
  const SearchUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Lấy từ khóa đang gõ và kết quả tìm kiếm
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchUserProvider(searchQuery));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () {
            // Xóa trắng từ khóa khi thoát ra để lần sau vào không bị dính chữ cũ
            ref.read(searchQueryProvider.notifier).state = '';
            Navigator.of(context).pop();
          },
        ),
        title: TextField(
          autofocus: true, // Tự động bật bàn phím
          onChanged: (value) {
            // Cập nhật từ khóa mỗi khi người dùng gõ
            ref.read(searchQueryProvider.notifier).state = value;
          },
          decoration: InputDecoration(
            hintText: 'Nhập Tên hoặc mã UID...',
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
            Text(
              'Có thể tìm bằng Tên hoặc mã UID',
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      )
          : searchResultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Lỗi: $err')),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'Không tìm thấy ai phù hợp 😥',
                style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
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
                        ? Text(name[0].toUpperCase(), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                      Text('UID: $uid', style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Chat', style: GoogleFonts.nunito(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () {
                    // Bấm vào kết quả là nhảy thẳng vào Chat luôn
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