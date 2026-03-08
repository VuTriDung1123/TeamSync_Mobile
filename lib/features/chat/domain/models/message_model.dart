import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, file }

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final MessageType type;
  final String? mediaUrl;
  final String? replyToId;
  final bool isDeleted; // Thu hồi
  final bool isEdited; // 🚀 MỚI: Đánh dấu đã chỉnh sửa
  final bool isPinned; // 🚀 MỚI: Đánh dấu tin nhắn ghim
  final Map<String, String> reactions; // 🚀 MỚI: Map lưu trữ <UID, Emoji> (VD: {'uid123': '❤️'})
  final List<String> readBy;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = MessageType.text,
    this.mediaUrl,
    this.replyToId,
    this.isDeleted = false,
    this.isEdited = false,
    this.isPinned = false,
    this.reactions = const {},
    this.readBy = const [],
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
            (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'],
      replyToId: map['replyToId'],
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
      isPinned: map['isPinned'] ?? false,
      // Ép kiểu an toàn cho Map reactions
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      readBy: List<String>.from(map['readBy'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'replyToId': replyToId,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'isPinned': isPinned,
      'reactions': reactions,
      'readBy': readBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}