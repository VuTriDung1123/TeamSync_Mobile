import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(firestore: FirebaseFirestore.instance);
});

// Provider lắng nghe tin nhắn trong 1 phòng
final chatStreamProvider = StreamProvider.family<List<Message>, String>((ref, receiverId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.watch(chatRepositoryProvider).getMessages(currentUserId, receiverId);
});

// Provider lắng nghe trạng thái CỦA PHÒNG CHAT (để biết ai đang gõ chữ)
final chatRoomStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, receiverId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.watch(chatRepositoryProvider).getChatRoomStream(currentUserId, receiverId);
});

// Provider lấy TẤT CẢ phòng chat của user (Dùng cho màn hình Home)
final userChatRoomsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(chatRepositoryProvider).getUserChatRooms();
});

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // 1. GỬI TIN NHẮN (Đã nâng cấp lưu lastMessageReadBy)
  Future<void> sendMessage({
    required String currentUserId,
    required String receiverId,
    required String text,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final message = Message(
      id: '',
      senderId: currentUserId,
      receiverId: receiverId,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      readBy: [currentUserId],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').add(message.toMap());

    String displayLastMessage = text;
    if (type == MessageType.image) displayLastMessage = 'Đã gửi một ảnh 📸';

    // Cập nhật thông tin phòng chat ra ngoài Home
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'roomId': chatRoomId,
      'users': [currentUserId, receiverId],
      'lastMessage': displayLastMessage,
      'lastMessageSenderId': currentUserId,
      'lastMessageReadBy': [currentUserId], // Mình vừa gửi thì coi như mình đã đọc
      'lastTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // 2. ĐÁNH DẤU ĐÃ XEM (Cho cả tin nhắn & ngoài Home)
  Future<void> markAsRead(String currentUserId, String receiverId, String messageId) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    // Đánh dấu đã xem ở chi tiết tin nhắn
    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId).update({
      'readBy': FieldValue.arrayUnion([currentUserId])
    });

    // Đánh dấu đã xem ở ngoài Home
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'lastMessageReadBy': FieldValue.arrayUnion([currentUserId])
    });
  }

  // 3. THU HỒI TIN NHẮN
  Future<void> recallMessage(String currentUserId, String receiverId, String messageId) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId).update({
      'isDeleted': true,
      'text': 'Tin nhắn đã bị thu hồi',
      'mediaUrl': null, // Xóa luôn link ảnh nếu có
    });
  }

  // 4. BẬT/TẮT TRẠNG THÁI "ĐANG GÕ..."
  Future<void> setTypingStatus(String currentUserId, String receiverId, bool isTyping) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing': isTyping ? FieldValue.arrayUnion([currentUserId]) : FieldValue.arrayRemove([currentUserId])
    }, SetOptions(merge: true));
  }

  Stream<List<Message>> getMessages(String currentUserId, String receiverId) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);
    return _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages')
        .orderBy('createdAt', descending: true).limit(50).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList().reversed.toList());
  }

  Stream<Map<String, dynamic>?> getChatRoomStream(String currentUserId, String receiverId) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots().map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> getUserChatRooms() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _firestore.collection('chat_rooms')
        .where('users', arrayContains: currentUserId)
        .orderBy('lastTimestamp', descending: true)
        .snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}