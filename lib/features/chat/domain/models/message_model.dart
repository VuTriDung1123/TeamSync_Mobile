import 'package:cloud_firestore/cloud_firestore.dart';

// Định nghĩa các loại tin nhắn
enum MessageType { text, image, video, audio }

class Message {
  final String id;
  final String senderId;
  final String receiverId; // Đối với chat nhóm thì đây là groupId
  final String text;
  final MessageType type; // Phân loại text hay media
  final String? mediaUrl; // Link ảnh, video, hoặc voice từ Cloudinary
  final String? replyToId; // ID của tin nhắn đang được reply (nếu có)
  final bool isDeleted; // Trạng thái thu hồi tin nhắn
  final List<String> readBy; // Danh sách UID những người đã xem tin nhắn này
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
      'readBy': readBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}