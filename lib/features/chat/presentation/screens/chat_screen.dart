import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../data/chat_repository.dart';
import '../../domain/models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isUploadingImage = false; // Trạng thái đang up ảnh

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // 🚀 TÍNH NĂNG 1: GỬI TIN NHẮN TEXT
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    ref.read(chatRepositoryProvider).sendMessage(
      currentUserId: currentUserId,
      receiverId: widget.receiverId,
      text: text,
      type: MessageType.text, // Loại tin nhắn là Text
    );

    _messageController.clear();
  }

  // 🚀 TÍNH NĂNG 2: CHỌN VÀ GỬI ẢNH (DÙNG CLOUDINARY)
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final file = File(pickedFile.path);
      final dio = Dio();
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': uploadPreset,
        'folder': 'teamsync_chat_media',
      });

      // Up lên Cloudinary
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
      );

      final downloadUrl = response.data['secure_url'];
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Up xong thì gọi hàm gửi tin nhắn với loại Image
      await ref.read(chatRepositoryProvider).sendMessage(
        currentUserId: currentUserId,
        receiverId: widget.receiverId,
        text: 'Đã gửi một ảnh', // Text mồi để hiển thị ngoài màn hình Home
        type: MessageType.image,
        mediaUrl: downloadUrl,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi gửi ảnh: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
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

                    // 🚀 TÍNH NĂNG 3: TỰ ĐỘNG ĐÁNH DẤU "ĐÃ XEM"
                    // Nếu đây là tin của người kia gửi, và mình CHƯA xem -> Báo lên Firebase là đã xem
                    if (!isMe && !message.readBy.contains(currentUserId)) {
                      Future.microtask(() {
                        ref.read(chatRepositoryProvider).markAsRead(currentUserId, widget.receiverId, message.id);
                      });
                    }

                    // Biến check xem đối phương đã đọc tin nhắn của MÌNH chưa
                    final isSeenByReceiver = isMe && message.readBy.contains(widget.receiverId);

                    // Chỉ hiển thị chữ "Đã xem" ở tin nhắn MỚI NHẤT của mình
                    final isLastMessage = index == messages.length - 1;

                    return ChatBubble(
                      message: message,
                      isMe: isMe,
                      avatarUrl: isMe ? (currentUser?.photoURL ?? '') : widget.receiverAvatar,
                      senderName: isMe ? (currentUser?.displayName ?? 'Tôi') : widget.receiverName,
                      isSeen: isSeenByReceiver,
                      showSeenStatus: isLastMessage && isMe, // Chỉ hiện status ở tin nhắn cuối
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
            // Nút Gửi Ảnh
            IconButton(
              icon: _isUploadingImage
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                  : Icon(Icons.image_rounded, color: colorScheme.primary, size: 28),
              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
            ),
            const Gap(4),
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

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String avatarUrl;
  final String senderName;
  final bool isSeen; // Đã xem hay chưa
  final bool showSeenStatus; // Có hiển thị dòng text "Đã xem" không

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.avatarUrl,
    required this.senderName,
    required this.isSeen,
    required this.showSeenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeString = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(colorScheme),
          if (!isMe) const Gap(8),

          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    senderName,
                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),

                // 🚀 TÍNH NĂNG 4: RENDER ẢNH HOẶC TEXT TÙY LOẠI TIN NHẮN
                Container(
                  padding: message.type == MessageType.image ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.type == MessageType.image ? Colors.transparent : (isMe ? colorScheme.primary : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: message.type == MessageType.image ? [] : [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                    ],
                  ),
                  child: message.type == MessageType.image
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    // Hiển thị ảnh tải từ Cloudinary
                    child: Image.network(
                      message.mediaUrl ?? '',
                      width: 220, // Kích thước khung ảnh
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 220, height: 200, color: Colors.grey.shade200,
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  )
                      : Text(
                    message.text,
                    style: GoogleFonts.nunito(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // 🚀 TÍNH NĂNG 5: HIỂN THỊ THỜI GIAN VÀ TRẠNG THÁI "ĐÃ XEM"
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeString, style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500)),
                      if (showSeenStatus) ...[
                        const Gap(6),
                        Icon(
                          isSeen ? Icons.done_all_rounded : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: isSeen ? colorScheme.primary : Colors.grey.shade500,
                        ),
                        const Gap(2),
                        Text(
                          isSeen ? 'Đã xem' : 'Đã gửi',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            color: isSeen ? colorScheme.primary : Colors.grey.shade500,
                            fontWeight: isSeen ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isMe) const Gap(8),
          if (isMe) _buildAvatar(colorScheme),
        ],
      ),
    );
  }

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