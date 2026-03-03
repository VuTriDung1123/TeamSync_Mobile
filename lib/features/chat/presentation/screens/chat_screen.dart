import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar; // Thêm biến nhận Avatar

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar, // Bắt buộc truyền vào
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    ref.read(chatRepositoryProvider).sendMessage(
      currentUserId: currentUserId,
      receiverId: widget.receiverId,
      text: text,
    );

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    final messagesAsync = ref.watch(chatStreamProvider(widget.receiverId));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: colorScheme.primary.withOpacity(0.2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Hiển thị Avatar thật trên AppBar
            CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              backgroundImage: widget.receiverAvatar.isNotEmpty ? NetworkImage(widget.receiverAvatar) : null,
              child: widget.receiverAvatar.isEmpty
                  ? Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : '?',
                style: GoogleFonts.nunito(color: colorScheme.primary, fontWeight: FontWeight.bold),
              )
                  : null,
            ),
            const Gap(12),
            Text(
              widget.receiverName,
              style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải tin nhắn: $err')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Hãy gửi lời chào đầu tiên! 🌸',
                      style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      // Lấy avatar của mình hoặc của bạn chat
                      avatarUrl: isMe ? (currentUser?.photoURL ?? '') : widget.receiverAvatar,
                      // Lấy tên của mình hoặc của bạn chat
                      senderName: isMe ? (currentUser?.displayName ?? 'Tôi') : widget.receiverName,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            const Gap(12),
            GestureDetector(
              onTap: _sendMessage,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// KHỐI UI MỚI: BONG BÓNG TIN NHẮN CÓ AVATAR, TÊN VÀ THỜI GIAN
class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String avatarUrl;
  final String senderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.avatarUrl,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Format thời gian thành dạng Giờ:Phút (VD: 14:30)
    final timeString = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end, // Căn avatar nằm ở đáy bong bóng
        children: [
          // 1. Avatar người nhận (bên trái)
          if (!isMe) _buildAvatar(colorScheme),

          if (!isMe) const Gap(8),

          // 2. Khối Tên + Bong bóng + Thời gian
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Tên người gửi (nhỏ ở trên)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    senderName,
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),

                // Bong bóng tin nhắn
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? colorScheme.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.nunito(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Thời gian (nhỏ ở dưới)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Text(
                    timeString,
                    style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const Gap(8),

          // 3. Avatar của mình (bên phải)
          if (isMe) _buildAvatar(colorScheme),
        ],
      ),
    );
  }

  // Widget vẽ Avatar tròn tròn
  Widget _buildAvatar(ColorScheme colorScheme) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primary.withOpacity(0.2),
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
        style: GoogleFonts.nunito(fontSize: 14, color: colorScheme.primary, fontWeight: FontWeight.bold),
      )
          : null,
    );
  }
}