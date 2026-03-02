import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Thêm .autoDispose để tự động dọn dẹp cache khi rời trang
final usersStreamProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;

  // CHẶN BẢO VỆ: Nếu vừa đăng xuất (currentUser bị null), trả về list rỗng ngay lập tức
  // để không gửi request không hợp lệ lên Firestore
  if (currentUser == null) {
    return Stream.value([]);
  }

  // 1. Tự động đồng bộ thông tin của CHÍNH MÌNH lên Firestore
  FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
    'uid': currentUser.uid,
    'email': currentUser.email,
    'name': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Thành viên mới',
    'avatar': currentUser.photoURL ?? '',
  }, SetOptions(merge: true));

  // 2. Lấy danh sách tất cả những người khác
  return FirebaseFirestore.instance
      .collection('users')
      .where('uid', isNotEqualTo: currentUser.uid)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});

// Thêm .autoDispose cho thanh tìm kiếm luôn để thoát ra vào lại là sạch bong
final searchUserProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  final searchQuery = query.trim();

  // 1. Tìm bằng UID
  final uidSnapshot = await firestore.collection('users').where('uid', isEqualTo: searchQuery).get();

  if (uidSnapshot.docs.isNotEmpty) {
    return uidSnapshot.docs
        .map((doc) => doc.data())
        .where((data) => data['uid'] != currentUser?.uid)
        .toList();
  }

  // 2. Tìm bằng Tên (gần đúng)
  final nameSnapshot = await firestore
      .collection('users')
      .where('name', isGreaterThanOrEqualTo: searchQuery)
      .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
      .get();

  return nameSnapshot.docs
      .map((doc) => doc.data())
      .where((data) => data['uid'] != currentUser?.uid)
      .toList();
});

// Thêm .autoDispose để ô tìm kiếm không bị lưu chữ cũ
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');