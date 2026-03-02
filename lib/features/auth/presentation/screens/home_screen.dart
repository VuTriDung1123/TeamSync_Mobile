import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Lắng nghe danh sách users từ Firestore (đã làm ở Bước 1)
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7), // Tone hồng nhạt
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Đồng đội',
          style: GoogleFonts.nunito(
            color: colorScheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          // Nút Tìm kiếm (Chuẩn bị cho tính năng kết bạn)
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black87),
            onPressed: () {
              context.push('/search');
            },
          ),
          // Nút Cài đặt
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              child: const Icon(Icons.settings_rounded, size: 18, color: Colors.black87),
            ),
            onPressed: () => context.push('/settings'),
          ),
          const Gap(8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lời chào hiển thị mềm mại
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Text(
              'Sẵn sàng kết nối\nvà làm việc cùng nhau! ✨',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),

          const Gap(10),

          // Container bo viền danh sách người dùng
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              child: usersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi tải danh sách: $err')),
                data: (users) {
                  // Nếu chưa có ai đăng nhập ngoài bạn
                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'Chưa có ai ở đây cả.\nHãy mời thêm bạn bè nhé! 🌸',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  // Vẽ danh sách người dùng
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final name = user['name'] ?? 'Ẩn danh';
                      final email = user['email'] ?? '';
                      final uid = user['uid'] ?? '';
                      final avatar = user['avatar'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F7).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: colorScheme.primary.withOpacity(0.2),
                            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Text(
                              name[0].toUpperCase(),
                              style: GoogleFonts.nunito(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                                : null,
                          ),
                          title: Text(
                            name,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            email,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                          ),
                          onTap: () {
                            // Chuyển thẳng sang màn hình Chat với ID và Tên của người này!
                            Navigator.push(
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
            ),
          ),
        ],
      ),
    );
  }
}