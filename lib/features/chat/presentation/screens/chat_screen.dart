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
  final ScrollController _scrollController = ScrollController();
  bool _isUploadingImage = false;
  bool _isTyping = false;
  Message? _replyingTo; // Biến lưu tin nhắn đang được trả lời


  // 🚀 1. THÊM BỘ ĐỊNH VỊ VÀ BIẾN HIGHLIGHT
  final Map<String, GlobalKey> _messageKeys = {}; // Lưu tọa độ từng tin nhắn
  String? _highlightedMessageId; // Tin nhắn nào đang được nhá sáng

  // 🚀 2. HÀM CUỘN TỚI TIN NHẮN GỐC
  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      // Tự động cuộn màn hình tới vị trí tin nhắn đó (canh giữa màn hình)
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      // Bật hiệu ứng nháy màu nền
      setState(() => _highlightedMessageId = messageId);

      // Tắt hiệu ứng sau 1.5 giây
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tin nhắn ở quá xa, không thể cuộn tới!')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Lắng nghe bàn phím để báo trạng thái "Đang gõ..."
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
    _updateTypingStatus(false);
    _messageController.dispose();
    super.dispose();
    _scrollController.dispose();
  }

  void _updateTypingStatus(bool isTyping) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    ref.read(chatRepositoryProvider).setTypingStatus(currentUserId, widget.receiverId, isTyping);
  }

  // HÀM GỬI TIN NHẮN
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    ref.read(chatRepositoryProvider).sendMessage(
      currentUserId: currentUserId,
      receiverId: widget.receiverId,
      text: text,
      type: MessageType.text,
      replyToId: _replyingTo?.id, // Đính kèm ID tin nhắn đang trả lời
    );
    _messageController.clear();
    setState(() => _replyingTo = null);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // HÀM GỬI ẢNH
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

  // HIỂN THỊ MENU CHỈ ĐỂ THU HỒI TIN NHẮN
  void _showMessageMenu(Message message, bool isMe) {
    if (!isMe || message.isDeleted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
    final roomDataAsync = ref.watch(chatRoomStreamProvider(widget.receiverId));

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
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    // Báo cáo đã đọc
                    if (!isMe && !message.readBy.contains(currentUserId)) {
                      Future.microtask(() => ref.read(chatRepositoryProvider).markAsRead(currentUserId, widget.receiverId, message.id));
                    }

                    // Tìm tin nhắn bị trích dẫn
                    Message? repliedMsg;
                    if (message.replyToId != null) {
                      repliedMsg = messages.where((m) => m.id == message.replyToId).firstOrNull;
                    }

                    final isLastMessage = index == 0;

                    _messageKeys.putIfAbsent(message.id, () => GlobalKey());

                    return AnimatedContainer(
                      key: _messageKeys[message.id], // 🚀 GẮN ĐỊNH VỊ VÀO ĐÂY
                      duration: const Duration(milliseconds: 500),
                      // Nếu trùng ID đang nhảy tới thì tô màu nền nhạt, không thì trong suốt
                      color: _highlightedMessageId == message.id
                          ? colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      child: GestureDetector(
                        onLongPress: () => _showMessageMenu(message, isMe),
                        child: Dismissible(
                          key: ValueKey(message.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            setState(() => _replyingTo = message);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.2), shape: BoxShape.circle),
                              child: Icon(Icons.reply_rounded, color: colorScheme.primary),
                            ),
                          ),
                          child: ChatBubble(
                            message: message,
                            isMe: isMe,
                            avatarUrl: isMe ? (currentUser?.photoURL ?? '') : widget.receiverAvatar,
                            senderName: isMe ? 'Tôi' : widget.receiverName,
                            receiverName: widget.receiverName,
                            isSeen: isMe && message.readBy.contains(widget.receiverId),
                            showSeenStatus: isLastMessage && isMe,
                            repliedMessage: repliedMsg,
                            // 🚀 TRUYỀN HÀM CLICK VÀO ĐÂY
                            onReplyTap: () {
                              if (message.replyToId != null) {
                                _scrollToMessage(message.replyToId!);
                              }
                            },
                          ),
                        ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // KHUNG PREVIEW TRẢ LỜI
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingTo!.senderId == FirebaseAuth.instance.currentUser?.uid ? 'Đang trả lời chính mình' : 'Đang trả lời ${widget.receiverName}',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12),
                          ),
                          const Gap(4),
                          Text(
                            _replyingTo!.type == MessageType.image ? '📸 Hình ảnh' : _replyingTo!.text,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                      onPressed: () => setState(() => _replyingTo = null), // Bấm X để hủy trả lời
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  final String receiverName; // Để biết mình đang trả lời ai
  final bool isSeen;
  final bool showSeenStatus;
  final Message? repliedMessage;
  final VoidCallback? onReplyTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.avatarUrl,
    required this.senderName,
    required this.receiverName,
    required this.isSeen,
    required this.showSeenStatus,
    this.repliedMessage,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeString = "${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}";

    // UI Tin nhắn bị thu hồi
    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
            child: Text('🚫 Tin nhắn đã bị thu hồi', style: GoogleFonts.nunito(color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  child: Text(senderName, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                ),

                // 🚀 3. BỌC KHỐI TRÍCH DẪN BẰNG GESTURE DETECTOR ĐỂ BẤM ĐƯỢC
                if (repliedMessage != null)
                  GestureDetector(
                    onTap: onReplyTap, // Kích hoạt hiệu ứng cuộn khi bấm
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, right: 4, left: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.reply_rounded, size: 14, color: Colors.grey.shade600),
                              const Gap(4),
                              Text(
                                isMe
                                    ? 'Bạn đã trả lời ${repliedMessage!.senderId == message.senderId ? "chính mình" : receiverName}'
                                    : '$senderName đã trả lời',
                                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? colorScheme.primary.withOpacity(0.15) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            repliedMessage!.type == MessageType.image ? '📸 Hình ảnh' : repliedMessage!.text,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(fontSize: 14, color: isMe ? Colors.black87 : Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ... (BONG BÓNG TIN NHẮN CHÍNH, GIỜ GIẤC, ĐÃ XEM CỦA BẠN BÊN DƯỚI GIỮ NGUYÊN)
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
                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(message.mediaUrl ?? '', width: 220, fit: BoxFit.cover))
                      : Text(message.text, style: GoogleFonts.nunito(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeString, style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500)),
                      if (showSeenStatus) ...[
                        const Gap(6),
                        Icon(isSeen ? Icons.done_all_rounded : Icons.check_circle_outline_rounded, size: 14, color: isSeen ? colorScheme.primary : Colors.grey.shade500),
                        const Gap(2),
                        Text(isSeen ? 'Đã xem' : 'Đã gửi', style: GoogleFonts.nunito(fontSize: 10, color: isSeen ? colorScheme.primary : Colors.grey.shade500)),
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
          ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?', style: GoogleFonts.nunito(fontSize: 14, color: colorScheme.primary, fontWeight: FontWeight.bold))
          : null,
    );
  }
}