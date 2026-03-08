import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Khởi tạo và xin quyền
  Future<void> initNotifications() async {
    // 1. Xin quyền hiển thị thông báo (Đặc biệt quan trọng trên iOS và Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Nguời dùng từ chối cấp quyền thông báo!');
      return;
    }

    // 2. Lấy Token (Địa chỉ thiết bị)
    String? token = await _fcm.getToken();
    debugPrint('🔥 FCM Token của máy này: $token');

    // 3. Cập nhật Token lên Firestore để app biết đường mà gửi
    _saveTokenToDatabase(token);

    // 4. Lắng nghe nếu Token bị thay đổi (do app cài lại, máy reset...)
    _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

    // 5. Cài đặt lắng nghe thông báo khi đang mở app (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('💌 Có tin nhắn đến khi đang mở app: ${message.notification?.title}');
      // Tạm thời in ra log, bước sau mình sẽ cho nó nảy cái popup lên màn hình
    });
  }

  // Hàm phụ trợ để lưu Token vào đúng user đang đăng nhập
  Future<void> _saveTokenToDatabase(String? token) async {
    if (token == null) return;

    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
      });
      debugPrint('✅ Đã cập nhật FCM Token lên Firestore thành công!');
    }
  }
}