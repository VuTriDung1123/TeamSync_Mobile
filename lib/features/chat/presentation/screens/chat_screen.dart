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

  const ChatScreen({super.key, required this.receiverId, required this.receiverName, required this.receiverAvatar});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isUploadingImage = false;
  bool _isTyping = false; // Biến local check xem mình có đang gõ ko

  @override
  void initState() {
    super.initState();
    // Lắng nghe sự thay đổi của Text để bắn trạng thái "Đang gõ"
    _messageController.addListener(() {
      final text = _messageController.text;
      if (text.isNotEmpty && !_isTyping) {
        _isTyping = true;
        _updateTypingStatus(true);
      } else if (text.isEmpty && _isTyping) {
        _isTyping = false;
        _updateTypingStatus(false);
      }
    });
  }

  @override
  void dispose() {
    _updateTypingStatus(false); // Thoát phòng là tắt trạng thái gõ
    _messageController.dispose();
    super.dispose();
  }

  void _updateTypingStatus(bool isTyping) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    ref.read(chatRepositoryProvider).setTypingStatus(currentUserId, widget.receiverId, isTyping);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    ref.read(chatRepositoryProvider).sendMessage(
      currentUserId: currentUserId,
      receiverId: widget.receiverId,
      text: text,
      type: MessageType.text,
    );
    _messageController.clear();
  }

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile == null) return;
    setState(() => _isUploadingImage = true);

    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(File(pickedFile.path).path),
        'upload_preset': dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '',
        'folder': 'teamsync_chat_media',
      });

      final response = await dio.post('https://api.cloudinary.com/v1_1/${dotenv.env['CLOUDINARY_CLOUD_NAME']}/image/upload', data: formData);
      await ref.read(chatRepositoryProvider).sendMessage(
        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        receiverId: widget.receiverId,
        text: 'Đã gửi một ảnh',
        type: MessageType.image,
        mediaUrl: response.data['secure_url'],
      );
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi ảnh: $e')));
    } finally {
      if(mounted) setState(() => _isUploadingImage = false);
    }
  }

  // HIỂN THỊ MENU THU HỒI TIN NHẮN
  void _showMessageMenu(Message message, bool isMe) {
    if (!isMe || message.isDeleted) return; // Chỉ được thu hồi tin của mình và chưa bị thu hồi

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              title: const Text('Thu hồi tin nhắn', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                ref.read(chatRepositoryProvider).recallMessage(currentUserId, widget.receiverId, message.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    final messagesAsync = ref.watch(chatStreamProvider(widget.receiverId));
    final roomDataAsync = ref.watch(chatRoomStreamProvider(widget.receiverId)); // Lắng nghe phòng chat

    // Kiểm tra xem ĐỐI PHƯƠNG có đang gõ không
    bool isReceiverTyping = false;
    roomDataAsync.whenData((room) {
      if (room != null && room['typing'] != null) {
        final typingList = List<String>.from(room['typing']);
        if (typingList.contains(widget.receiverId)) isReceiverTyping = true;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.receiverAvatar.isNotEmpty ? NetworkImage(widget.receiverAvatar) : null,
              child: widget.receiverAvatar.isEmpty ? Text(widget.receiverName[0].toUpperCase()) : null,
            ),
            const Gap(12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName, style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
                // NẾU ĐANG GÕ THÌ HIỆN CHỮ NHỎ DƯỚI TÊN
                if (isReceiverTyping)
                  Text('Đang gõ...', style: GoogleFonts.nunito(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(child: Text('Lỗi tải tin nhắn')),
              data: (messages) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    if (!isMe && !message.readBy.contains(currentUserId)) {
                      Future.microtask(() => ref.read(chatRepositoryProvider).markAsRead(currentUserId, widget.receiverId, message.id));
                    }

                    final isLastMessage = index == messages.length - 1;
                    return GestureDetector(
                      onLongPress: () => _showMessageMenu(message, isMe), // NHẤN GIỮ ĐỂ THU HỒI
                      child: ChatBubble(
                        message: message,
                        isMe: isMe,
                        avatarUrl: isMe ? (currentUser?.photoURL ?? '') : widget.receiverAvatar,
                        senderName: isMe ? 'Tôi' : widget.receiverName,
                        isSeen: isMe && message.readBy.contains(widget.receiverId),
                        showSeenStatus: isLastMessage && isMe,
                      ),
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
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: _isUploadingImage ? const SizedBox(width:20,height:20,child:CircularProgressIndicator()) : Icon(Icons.image_rounded, color: colorScheme.primary),
              onPressed: _isUploadingImage ? null : _pickAndUploadImage,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  filled: true, fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            IconButton(icon: Icon(Icons.send_rounded, color: colorScheme.primary), onPressed: _sendMessage),
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
  final bool isSeen;
  final bool showSeenStatus;

  const ChatBubble({super.key, required this.message, required this.isMe, required this.avatarUrl, required this.senderName, required this.isSeen, required this.showSeenStatus});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Nếu tin nhắn bị thu hồi, đổi style thành dạng mờ nhạt
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300)
            ),
            child: Text('🚫 Tin nhắn đã bị thu hồi', style: GoogleFonts.nunito(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) CircleAvatar(radius: 16, backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null, child: avatarUrl.isEmpty ? Text(senderName[0].toUpperCase()) : null),
          if (!isMe) const Gap(8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: message.type == MessageType.image ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: message.type == MessageType.image ? Colors.transparent : (isMe ? colorScheme.primary : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: message.type == MessageType.image
                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(message.mediaUrl ?? '', width: 220, fit: BoxFit.cover))
                      : Text(message.text, style: GoogleFonts.nunito(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                ),
                if (showSeenStatus)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isSeen ? Icons.done_all_rounded : Icons.check_circle_outline_rounded, size: 14, color: isSeen ? colorScheme.primary : Colors.grey.shade500),
                        const Gap(4),
                        Text(isSeen ? 'Đã xem' : 'Đã gửi', style: GoogleFonts.nunito(fontSize: 10, color: isSeen ? colorScheme.primary : Colors.grey.shade500)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}