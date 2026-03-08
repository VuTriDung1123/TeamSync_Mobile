import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/message_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(firestore: FirebaseFirestore.instance));

// 🚀 THỦ THUẬT: Dùng chuỗi "group_id" hoặc "single_id" để Riverpod phân biệt được loại chat
final chatStreamProvider = StreamProvider.family<List<Message>, String>((ref, combinedId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final isGroup = combinedId.startsWith('group_');
  final targetId = combinedId.replaceFirst(RegExp(r'^(group_|single_)'), '');
  return ref.watch(chatRepositoryProvider).getMessages(currentUserId, targetId, isGroup);
});

final chatRoomStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, combinedId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final isGroup = combinedId.startsWith('group_');
  final targetId = combinedId.replaceFirst(RegExp(r'^(group_|single_)'), '');
  return ref.watch(chatRepositoryProvider).getChatRoomStream(currentUserId, targetId, isGroup);
});

final userChatRoomsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(chatRepositoryProvider).getUserChatRooms();
});

class ChatRepository {
  final FirebaseFirestore _firestore;
  ChatRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  // 🚀 NẾU LÀ GROUP THÌ ID CHÍNH LÀ TARGET ID, CÒN 1-1 THÌ GHÉP CHUỖI
  String _getChatRoomId(String currentUserId, String targetId, bool isGroup) {
    if (isGroup) return targetId;
    List<String> ids = [currentUserId, targetId];
    ids.sort();
    return ids.join('_');
  }

  // CÁC HÀM TƯƠNG TÁC (Đã thêm biến isGroup)
  Future<void> sendMessage({
    required String currentUserId, required String receiverId, required String text,
    MessageType type = MessageType.text, String? mediaUrl, String? replyToId,
    bool isGroup = false, // 🚀 THÊM VÀO ĐÂY
  }) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);

    final message = Message(
      id: '', senderId: currentUserId, receiverId: receiverId, text: text,
      type: type, mediaUrl: mediaUrl, replyToId: replyToId, readBy: [currentUserId], createdAt: DateTime.now(),
    );

    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').add(message.toMap());

    String displayLastMessage = text;
    if (type == MessageType.image) displayLastMessage = 'Đã gửi một ảnh 📸';

    // Cập nhật thông tin phòng
    Map<String, dynamic> roomUpdate = {
      'lastMessage': displayLastMessage,
      'lastMessageSenderId': currentUserId,
      'lastMessageReadBy': [currentUserId],
      'lastTimestamp': FieldValue.serverTimestamp(),
    };

    // Nếu là chat 1-1 thì tạo list users, group thì không ghi đè list users
    if (!isGroup) {
      roomUpdate['users'] = [currentUserId, receiverId];
      roomUpdate['roomId'] = chatRoomId;
    }

    await _firestore.collection('chat_rooms').doc(chatRoomId).set(roomUpdate, SetOptions(merge: true));
  }

  Future<void> markAsRead(String currentUserId, String receiverId, String messageId, bool isGroup) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);
    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId).update({'readBy': FieldValue.arrayUnion([currentUserId])});
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({'lastMessageReadBy': FieldValue.arrayUnion([currentUserId])});
  }

  Future<void> recallMessage(String currentUserId, String receiverId, String messageId, bool isGroup) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);
    await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').doc(messageId).update({'isDeleted': true, 'text': 'Tin nhắn đã bị thu hồi', 'mediaUrl': null});
  }

  Future<void> setTypingStatus(String currentUserId, String receiverId, bool isTyping, bool isGroup) async {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);
    await _firestore.collection('chat_rooms').doc(chatRoomId).set({
      'typing': isTyping ? FieldValue.arrayUnion([currentUserId]) : FieldValue.arrayRemove([currentUserId])
    }, SetOptions(merge: true));
  }

  Stream<List<Message>> getMessages(String currentUserId, String receiverId, bool isGroup) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);
    return _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages')
        .orderBy('createdAt', descending: true).limit(50).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Message.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<Map<String, dynamic>?> getChatRoomStream(String currentUserId, String receiverId, bool isGroup) {
    final chatRoomId = _getChatRoomId(currentUserId, receiverId, isGroup);
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots().map((doc) => doc.data());
  }

  Stream<List<Map<String, dynamic>>> getUserChatRooms() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _firestore.collection('chat_rooms').where('users', arrayContains: currentUserId)
        .orderBy('lastTimestamp', descending: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Hàm tạo nhóm của bạn
  Future<void> createGroupChat(String groupName, List<String> memberIds, {String? groupAvatar}) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!memberIds.contains(currentUserId)) memberIds.add(currentUserId);
    final groupRoomRef = _firestore.collection('chat_rooms').doc();
    await groupRoomRef.set({
      'roomId': groupRoomRef.id, 'isGroup': true, 'groupName': groupName, 'groupAvatar': groupAvatar ?? '',
      'adminId': currentUserId, 'users': memberIds, 'lastMessage': 'Nhóm đã được tạo 🎉',
      'lastMessageSenderId': currentUserId, 'lastMessageReadBy': [currentUserId], 'lastTimestamp': FieldValue.serverTimestamp(),
    });
  }
}