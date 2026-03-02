import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/message_model.dart';

// 1. Provider cung cấp Repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(firestore: FirebaseFirestore.instance);
});

// 2. Provider lắng nghe Stream tin nhắn (NẰM NGOÀI CLASS)
final chatStreamProvider = StreamProvider.family<List<Message>, String>((ref, receiverId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return ref.watch(chatRepositoryProvider).getMessages(currentUserId, receiverId);
});

// 3. Class chứa Logic chính
class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  // Hàm tạo ID phòng chat duy nhất
  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Hàm GỬI tin nhắn
  Future<void> sendMessage({
    required String currentUserId,
    required String receiverId,
    required String text,
  }) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    final message = Message(
      id: '',
      senderId: currentUserId,
      receiverId: receiverId,
      text: text,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(message.toMap());
  }

  // Hàm LẮNG NGHE tin nhắn
  Stream<List<Message>> getMessages(String currentUserId, String receiverId) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }
}