import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(firestore: FirebaseFirestore.instance);
});

// Provider lắng nghe Stream tin nhắn
final chatStreamProvider = StreamProvider.family<List<Message>, String>((ref, receiverId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.watch(chatRepositoryProvider).getMessages(currentUserId, receiverId);
});

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  // Thuật toán tạo ID phòng chat 1-1
  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // 🚀 NÂNG CẤP: Gửi tin nhắn đa phương tiện (Hỗ trợ Text, Ảnh, Video)
  Future<void> sendMessage({
    required String currentUserId,
    required String receiverId,
    required String text,
    MessageType type = MessageType.text, // Mặc định là text
    String? mediaUrl,
    String? replyToId,
  }) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final message = Message(
      id: '',
      senderId: currentUserId,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      replyToId: replyToId,
      // Vừa gửi xong thì mặc định mình đã "xem" tin nhắn của chính mình
      readBy: [currentUserId],
      createdAt: DateTime.now(),
    );

    // 1. Lưu tin nhắn vào collection
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());

    // 2. Cập nhật lastMessage cho phòng chat để hiển thị ở ngoài màn hình chính
    String displayLastMessage = text;
    if (type == MessageType.image) displayLastMessage = 'Đã gửi một ảnh 📸';
    if (type == MessageType.video) displayLastMessage = 'Đã gửi một video 🎥';
    if (type == MessageType.audio) displayLastMessage = 'Đã gửi tin nhắn thoại 🎤';

    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'users': [currentUserId, receiverId],
      'lastMessage': displayLastMessage,
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 🚀 TÍNH NĂNG MỚI: Đánh dấu Đã Xem (Seen)
  Future<void> markAsRead(String currentUserId, String receiverId, String messageId) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    // Thêm UID của mình vào mảng readBy của tin nhắn đó
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'readBy': FieldValue.arrayUnion([currentUserId])
    });
  }

  // LẮNG NGHE tin nhắn (Thêm limit 50 để phân trang cho mượt)
  Stream<List<Message>> getMessages(String currentUserId, String receiverId) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('createdAt', descending: true) // Lấy từ mới nhất (để hiển thị dưới cùng)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      // Vì ListView.builder mặc định xếp từ trên xuống, ta lấy descending: true rồi reverse lại
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data(), doc.id);
      }).toList().reversed.toList();
    });
  }
}