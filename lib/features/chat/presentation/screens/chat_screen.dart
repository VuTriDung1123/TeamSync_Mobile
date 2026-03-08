import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Đảm bảo import đúng đường dẫn đến user_repository của bạn
import '../../../../features/auth/data/user_repository.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/message_model.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final bool isGroup; // 🚀 CỜ PHÂN BIỆT NHÓM VÀ 1-1

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
    this.isGroup = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploadingImage = false;
  bool _isTyping = false;
  Message? _replyingTo;

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
      setState(() => _highlightedMessageId = messageId);
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
    _scrollController.dispose();
    super.dispose();
  }

  void _updateTypingStatus(bool isTyping) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Truyền thêm cờ isGroup
    ref.read(chatRepositoryProvider).setTypingStatus(currentUserId, widget.receiverId, isTyping, widget.isGroup);
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
      replyToId: _replyingTo?.id,
      isGroup: widget.isGroup, // 🚀 TRUYỀN CỜ isGroup
    );
    _messageController.clear();
    setState(() => _replyingTo = null);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
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
        isGroup: widget.isGroup, // 🚀 TRUYỀN CỜ isGroup
      );
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi ảnh: $e')));
    } finally {
      if(mounted) setState(() => _isUploadingImage = false);
    }
  }

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
                // Truyền thêm cờ isGroup
                ref.read(chatRepositoryProvider).recallMessage(currentUserId, widget.receiverId, message.id, widget.isGroup);
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

    // 🚀 GHÉP CHUỖI ĐỂ TRUYỀN VÀO PROVIDER PHÂN BIỆT NHÓM VÀ 1-1
    final combinedId = widget.isGroup ? "group_${widget.receiverId}" : "single_${widget.receiverId}";

    final messagesAsync = ref.watch(chatStreamProvider(combinedId));
    final roomDataAsync = ref.watch(chatRoomStreamProvider(combinedId));
    final usersAsync = ref.watch(usersStreamProvider); // Để dò tìm Avatar trong Group

    bool isReceiverTyping = false;
    roomDataAsync.whenData((room) {
      if (room != null && room['typing'] != null) {
        final typingList = List<String>.from(room['typing']);
        // Trong nhóm, nếu có ai đó đang gõ (khác mình) thì bật chữ Đang gõ...
        if (typingList.any((uid) => uid != currentUserId)) isReceiverTyping = true;
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
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              backgroundImage: widget.receiverAvatar.isNotEmpty ? NetworkImage(widget.receiverAvatar) : null,
              child: widget.receiverAvatar.isEmpty
                  ? (widget.isGroup ? Icon(Icons.group, color: colorScheme.primary) : Text(widget.receiverName[0].toUpperCase()))
                  : null,
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

                    // Đánh dấu đã đọc
                    if (!isMe && !message.readBy.contains(currentUserId)) {
                      Future.microtask(() => ref.read(chatRepositoryProvider).markAsRead(currentUserId, widget.receiverId, message.id, widget.isGroup));
                    }

                    Message? repliedMsg;
                    if (message.replyToId != null) {
                      repliedMsg = messages.where((m) => m.id == message.replyToId).firstOrNull;
                    }

                    final isLastMessage = index == 0;
                    _messageKeys.putIfAbsent(message.id, () => GlobalKey());

                    // 🚀 LOGIC TÌM TÊN VÀ AVATAR TRONG NHÓM
                    String senderName = isMe ? 'Tôi' : widget.receiverName;
                    String senderAvatar = isMe ? (currentUser?.photoURL ?? '') : widget.receiverAvatar;

                    if (!isMe && widget.isGroup) {
                      final usersList = usersAsync.value ?? [];
                      final senderInfo = usersList.firstWhere(
                            (u) => u['uid'] == message.senderId,
                        orElse: () => <String, dynamic>{}, // Fix lỗi null nếu không tìm thấy
                      );
                      senderName = senderInfo['name'] ?? 'Thành viên';
                      senderAvatar = senderInfo['avatar'] ?? '';
                    }

                    return AnimatedContainer(
                      key: _messageKeys[message.id],
                      duration: const Duration(milliseconds: 500),
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
                            avatarUrl: senderAvatar, // Đã cập nhật
                            senderName: senderName,  // Đã cập nhật
                            receiverName: widget.receiverName,
                            // Đã xem: Trong 1-1 thì chỉ cần đối phương đọc. Trong Group thì chỉ cần có >1 người đọc (kể cả mình) là hiện
                            isSeen: widget.isGroup ? (message.readBy.length > 1) : (isMe && message.readBy.contains(widget.receiverId)),
                            showSeenStatus: isLastMessage && isMe,
                            repliedMessage: repliedMsg,
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
                            _replyingTo!.senderId == FirebaseAuth.instance.currentUser?.uid ? 'Đang trả lời chính mình' : 'Đang trả lời ${widget.isGroup ? "thành viên" : widget.receiverName}',
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
                      onPressed: () => setState(() => _replyingTo = null),
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
  final String receiverName;
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

                if (repliedMessage != null)
                  GestureDetector(
                    onTap: onReplyTap,
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