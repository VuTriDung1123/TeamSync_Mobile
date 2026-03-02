import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider cung cấp danh sách người dùng realtime
final usersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = FirebaseAuth.instance.currentUser;

  // 1. Tự động đồng bộ thông tin của CHÍNH MÌNH lên Firestore để người khác thấy
  if (currentUser != null) {
    FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
      'uid': currentUser.uid,
      'email': currentUser.email,
      // Nếu đăng nhập Google sẽ có tên, nếu Email thì lấy khúc đầu của email làm tên
      'name': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Thành viên mới',
      'avatar': currentUser.photoURL ?? '',
    }, SetOptions(merge: true)); // merge: true để không xóa nhầm dữ liệu cũ
  }

  // 2. Lấy danh sách tất cả những người khác (trừ bản thân mình ra)
  return FirebaseFirestore.instance
      .collection('users')
      .where('uid', isNotEqualTo: currentUser?.uid)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => doc.data()).toList();
  });
});

// Thêm đoạn này vào cuối file user_repository.dart
// Provider xử lý logic tìm kiếm user theo Tên hoặc UID
final searchUserProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];

  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  final searchQuery = query.trim();

  // 1. Thử tìm chính xác bằng UID trước
  final uidSnapshot = await firestore.collection('users').where('uid', isEqualTo: searchQuery).get();

  if (uidSnapshot.docs.isNotEmpty) {
    // Nếu tìm thấy bằng UID, trả về luôn (loại trừ chính mình)
    return uidSnapshot.docs
        .map((doc) => doc.data())
        .where((data) => data['uid'] != currentUser?.uid)
        .toList();
  }

  // 2. Nếu không tìm thấy bằng UID, chuyển sang tìm bằng Tên (gần đúng)
  // Lưu ý: Firestore không hỗ trợ tìm kiếm chứa (LIKE %text%) như SQL,
  // nên ta dùng thủ thuật tìm các chuỗi bắt đầu bằng từ khóa (Prefix search)
  final nameSnapshot = await firestore
      .collection('users')
      .where('name', isGreaterThanOrEqualTo: searchQuery)
      .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff')
      .get();

  return nameSnapshot.docs
      .map((doc) => doc.data())
      .where((data) => data['uid'] != currentUser?.uid) // Không tự tìm ra chính mình
      .toList();
});

// Provider quản lý state của thanh tìm kiếm (chữ người dùng đang gõ)
final searchQueryProvider = StateProvider<String>((ref) => '');