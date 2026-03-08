import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Khởi tạo công cụ bắn thông báo cục bộ
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Cài đặt icon cho thông báo (Dùng icon mặc định của app Android)
    const AndroidInitializationSettings initSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: initSettingsAndroid);

    // FIX 1: Thêm chữ 'initializationSettings:' vào đây
    await _localNotif.initialize(settings: initSettings);

    // Xin quyền hiển thị thông báo trên Android 13+
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('✅ Đã khởi tạo hệ thống Thông báo Sinh viên!');

    // 2. BẮT ĐẦU THEO DÕI FIREBASE (Tuyệt chiêu ở đây)
    _listenToNewTasks(user.uid);
  }

  void _listenToNewTasks(String myUid) {
    // Lắng nghe bảng 'tasks' xem có biến động gì không
    _firestore
        .collection('tasks')
        .where('assigneeId', isEqualTo: myUid) // Chỉ quan tâm Task của mình
        .snapshots()
        .listen((snapshot) {

      // Lặp qua những thay đổi MỚI NHẤT
      for (var change in snapshot.docChanges) {
        // Nếu có 1 Task MỚI VỪA ĐƯỢC TẠO THÊM (added)
        if (change.type == DocumentChangeType.added) {
          final taskData = change.doc.data();
          if (taskData == null) continue;

          // Kiểm tra xem task này có phải vừa tạo trong vòng 1 phút đổ lại không
          final createdAt = (taskData['createdAt'] as Timestamp).toDate();
          if (DateTime.now().difference(createdAt).inMinutes < 1) {

            // Bắn thông báo nảy lên màn hình!
            _showNotification(
              title: 'Có công việc mới! 📋',
              body: 'Bạn vừa được giao task: "${taskData['title']}"',
            );
          }
        }
      }
    });
  }

  // Hàm cấu hình giao diện của cái bảng thông báo rớt từ trên xuống
  Future<void> _showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'teamsync_channel', // ID của kênh thông báo
      'TeamSync Notifications', // Tên kênh
      channelDescription: 'Thông báo công việc và tin nhắn',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // FIX 2: Thêm tên tham số (id, title, body, notificationDetails) vào đây
    await _localNotif.show(
      id: DateTime.now().millisecond, // ID ngẫu nhiên cho thông báo
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}