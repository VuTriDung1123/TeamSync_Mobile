import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../../../features/auth/data/user_repository.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/message_model.dart'; // 🚀 IMPORT THÊM MODEL TIN NHẮN

class ChatSettingsScreen extends ConsumerStatefulWidget {
  final String targetId;
  final bool isGroup;

  const ChatSettingsScreen({
    super.key,
    required this.targetId,
    required this.isGroup,
  });

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _isUploadingAvatar = false;
  bool _isMuted = false;

  Future<void> _showEditNameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên nhóm', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('LƯU')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      await ref.read(chatRepositoryProvider).updateGroupName(widget.targetId, newName);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đổi tên nhóm!')));
    }
  }

  Future<void> _updateGroupAvatar() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;
    setState(() => _isUploadingAvatar = true);

    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(File(pickedFile.path).path),
        'upload_preset': dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '',
        'folder': 'teamsync_group_avatars',
      });
      final response = await dio.post('https://api.cloudinary.com/v1_1/${dotenv.env['CLOUDINARY_CLOUD_NAME']}/image/upload', data: formData);
      await ref.read(chatRepositoryProvider).updateGroupAvatar(widget.targetId, response.data['secure_url']);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh nhóm!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời khỏi nhóm?'),
        content: const Text('Bạn sẽ không thể xem hoặc gửi tin nhắn vào nhóm này nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
              await ref.read(chatRepositoryProvider).leaveGroup(widget.targetId, currentUserId);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('RỜI NHÓM', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final combinedId = widget.isGroup ? "group_${widget.targetId}" : "single_${widget.targetId}";

    final roomAsync = ref.watch(chatRoomStreamProvider(combinedId));
    final usersAsync = ref.watch(usersStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => Navigator.pop(context)),
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Lỗi tải thông tin')),
        data: (room) {
          if (room == null) return const Center(child: Text('Phòng chat không tồn tại'));

          String name = '';
          String avatar = '';
          List<String> memberIds = List<String>.from(room['users'] ?? []);

          if (widget.isGroup) {
            name = room['groupName'] ?? 'Nhóm';
            avatar = room['groupAvatar'] ?? '';
          } else {
            final usersList = usersAsync.value ?? [];
            String otherUid = memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
            final otherUser = usersList.firstWhere((u) => u['uid'] == otherUid, orElse: () => <String, dynamic>{});
            name = otherUser['name'] ?? 'Ẩn danh';
            avatar = otherUser['avatar'] ?? '';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50, backgroundColor: colorScheme.primary.withOpacity(0.2),
                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: _isUploadingAvatar ? const CircularProgressIndicator(color: Colors.white) : (avatar.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.nunito(fontSize: 40, color: colorScheme.primary)) : null),
                      ),
                      if (widget.isGroup)
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _updateGroupAvatar,
                          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16)),
                        ),
                    ],
                  ),
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    if (widget.isGroup) ...[
                      const Gap(8),
                      GestureDetector(
                        onTap: () => _showEditNameDialog(name),
                        child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.edit_rounded, color: colorScheme.primary, size: 16)),
                      ),
                    ]
                  ],
                ),
                const Gap(32),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.1), child: const Icon(Icons.notifications_off_rounded, color: Colors.purple)),
                        title: Text('Tắt thông báo (Mute)', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        value: _isMuted, activeColor: Colors.purple, onChanged: (val) => setState(() => _isMuted = val),
                      ),
                      const Divider(height: 1, indent: 60),

                      // 🚀 NÚT 1: XEM ẢNH & MEDIA
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.image_rounded, color: Colors.blue)),
                        title: Text('File phương tiện & Ảnh', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatMediaScreen(combinedId: combinedId)));
                        },
                      ),
                      const Divider(height: 1, indent: 60),

                      // 🚀 NÚT 2: TÌM KIẾM TIN NHẮN
                      ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.search_rounded, color: Colors.orange)),
                        title: Text('Tìm kiếm tin nhắn', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatSearchScreen(combinedId: combinedId, usersAsync: usersAsync)));
                        },
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                if (widget.isGroup) ...[
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text('${memberIds.length} Thành viên', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.grey.shade700)))),
                  const Gap(8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: usersAsync.when(
                      loading: () => const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                      error: (e, st) => const Text('Lỗi tải danh sách'),
                      data: (users) {
                        final groupMembers = users.where((u) => memberIds.contains(u['uid'])).toList();
                        return Column(
                          children: groupMembers.map((user) {
                            final isAdmin = user['uid'] == room['adminId'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['avatar'] != null && user['avatar'].toString().isNotEmpty ? NetworkImage(user['avatar']) : null,
                                child: user['avatar'] == null || user['avatar'].toString().isEmpty ? Text((user['name'] ?? '?')[0]) : null,
                              ),
                              title: Text(user['uid'] == currentUserId ? 'Bạn' : (user['name'] ?? 'Ẩn danh'), style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                              subtitle: isAdmin ? Text('Quản trị viên', style: GoogleFonts.nunito(color: colorScheme.primary, fontSize: 12)) : null,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  const Gap(32),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20), width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _leaveGroup, icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                      label: Text('RỜI KHỎI NHÓM NÀY', style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const Gap(40),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// 🚀 TÍNH NĂNG MỚI 1: MÀN HÌNH XEM TOÀN BỘ ẢNH TRONG CHAT (MEDIA GALLERY)
// =========================================================================
class ChatMediaScreen extends ConsumerWidget {
  final String combinedId;
  const ChatMediaScreen({super.key, required this.combinedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(chatStreamProvider(combinedId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text('Ảnh & File phương tiện', style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Lỗi tải dữ liệu')),
        data: (messages) {
          // Lọc ra các tin nhắn là hình ảnh và không bị thu hồi
          final imageMessages = messages.where((m) => m.type == MessageType.image && m.mediaUrl != null && !m.isDeleted).toList();

          if (imageMessages.isEmpty) {
            return Center(child: Text('Chưa có hình ảnh nào được gửi.', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 ảnh 1 hàng
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: imageMessages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // Mở ảnh full màn hình khi bấm vào
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: EdgeInsets.zero,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          InteractiveViewer(child: Image.network(imageMessages[index].mediaUrl!, fit: BoxFit.contain)),
                          Positioned(
                            top: 40, right: 20,
                            child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                          )
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(imageMessages[index].mediaUrl!, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =========================================================================
// 🚀 TÍNH NĂNG MỚI 2: MÀN HÌNH TÌM KIẾM TIN NHẮN BẰNG TEXT
// =========================================================================
class ChatSearchScreen extends ConsumerStatefulWidget {
  final String combinedId;
  final AsyncValue<List<Map<String, dynamic>>> usersAsync;

  const ChatSearchScreen({super.key, required this.combinedId, required this.usersAsync});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final messagesAsync = ref.watch(chatStreamProvider(widget.combinedId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nhập từ khóa...',
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
      ),
      body: messagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Lỗi tải dữ liệu')),
        data: (messages) {
          if (_searchQuery.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 80, color: Colors.grey.shade300),
                  const Gap(16),
                  Text('Tìm kiếm nội dung tin nhắn', style: GoogleFonts.nunito(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }

          // Lọc ra các tin nhắn text có chứa từ khóa
          final filteredMessages = messages.where((m) {
            return m.type == MessageType.text && !m.isDeleted && m.text.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

          if (filteredMessages.isEmpty) {
            return Center(child: Text('Không tìm thấy kết quả nào.', style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16)));
          }

          return ListView.builder(
            itemCount: filteredMessages.length,
            itemBuilder: (context, index) {
              final msg = filteredMessages[index];
              final timeString = "${msg.createdAt.day}/${msg.createdAt.month} lúc ${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}";

              // Tìm tên người gửi
              String senderName = 'Tôi';
              if (msg.senderId != FirebaseAuth.instance.currentUser?.uid) {
                final usersList = widget.usersAsync.value ?? [];
                final senderInfo = usersList.firstWhere((u) => u['uid'] == msg.senderId, orElse: () => <String, dynamic>{});
                senderName = senderInfo['name'] ?? 'Thành viên';
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(senderName, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14, color: colorScheme.primary)),
                      Text(timeString, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(msg.text, style: GoogleFonts.nunito(fontSize: 16, color: Colors.black87)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}