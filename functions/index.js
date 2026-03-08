const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Lắng nghe sự kiện: Cứ hễ có một Task mới được tạo trong bảng 'tasks'
exports.sendTaskNotification = functions.firestore
  .document('tasks/{taskId}')
  .onCreate(async (snap, context) => {
    const task = snap.data();
    
    // Nếu task này không được giao cho ai (assigneeId trống) thì thôi, không gửi
    if (!task.assigneeId) return null;

    // Lấy thông tin của người được giao việc từ bảng 'users'
    const userDoc = await admin.firestore().collection('users').doc(task.assigneeId).get();
    const user = userDoc.data();

    // Nếu người này không có FCM Token (chưa từng đăng nhập trên app) thì chịu
    if (!user || !user.fcmToken) {
      console.log('Nguời dùng chưa có FCM Token');
      return null;
    }

    // Gói hàng (Nội dung thông báo)
    const payload = {
      notification: {
        title: 'Có công việc mới! 📋',
        body: `Bạn vừa được giao phụ trách task: "${task.title}"`,
      },
      token: user.fcmToken
    };

    // Bấm nút gửi qua trạm bưu điện FCM
    try {
      await admin.messaging().send(payload);
      console.log('✅ Đã bắn thông báo thành công tới:', user.name);
    } catch (error) {
      console.error('❌ Lỗi khi bắn thông báo:', error);
    }
    return null;
  });