import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/data/user_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isUploading = false; // Trạng thái đang up ảnh

  // 1. Logic: Tải ảnh đại diện lên CLOUDINARY
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    // imageQuality: 50 giúp nén bớt ảnh ngay trên điện thoại cho nhẹ
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);

      // Khởi tạo Dio để gọi API
      final dio = Dio();

      // Lấy thông tin từ file .env cực kỳ bảo mật
      final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
      final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': uploadPreset,
        'folder': 'teamsync_avatars',
      });

      // Bắn thẳng lên API của Cloudinary
      final response = await dio.post(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: formData,
      );

      // Lấy đường link ảnh xịn xò từ Cloudinary trả về
      final downloadUrl = response.data['secure_url'];

      // Cập nhật link ảnh mới vào Firebase Auth
      await user.updatePhotoURL(downloadUrl);

      // Cập nhật link ảnh vào bảng Users trong Firestore để bạn bè thấy
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'avatar': downloadUrl,
      });

      // Cập nhật lại UI
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện thành công!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // 2. Logic: Đổi tên hiển thị (Đã có từ trước)
  Future<void> _showEditNameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên hiển thị', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('LƯU')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updateDisplayName(newName);
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'name': newName});
      setState(() {});
    }
  }

  // 3. Logic: Cập nhật Trạng thái cá nhân (Status message)
  Future<void> _showEditStatusDialog(String currentStatus) async {
    final controller = TextEditingController(text: currentStatus);
    final newStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trạng thái cá nhân', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'VD: Đang code sấp mặt...'),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('LƯU')),
        ],
      ),
    );

    if (newStatus != null) {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'statusMessage': newStatus});
    }
  }

  // 4. Logic: Đổi mật khẩu
  Future<void> _showChangePasswordDialog() async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi mật khẩu', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(controller: controller, obscureText: true, autofocus: true, decoration: const InputDecoration(hintText: 'Nhập mật khẩu mới')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('ĐỔI')),
        ],
      ),
    );

    if (newPassword != null && newPassword.length >= 6) {
      try {
        await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: Bạn cần đăng nhập lại trước khi đổi mật khẩu.')));
      }
    } else if (newPassword != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu phải từ 6 ký tự!')));
    }
  }

  // 5. Logic: Chuyển đổi Online/Offline
  Future<void> _toggleOnlineStatus(bool isOnline) async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'isOnline': isOnline});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text('Lỗi: Không tìm thấy user')));

    // Lắng nghe dữ liệu realtime từ Firestore
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profileData = profileAsync.value ?? {};

    final currentDisplayName = user.displayName ?? 'Chưa cập nhật tên';
    final statusMessage = profileData['statusMessage'] ?? 'Đang rảnh...';
    final isOnline = profileData['isOnline'] ?? true; // Mặc định là bật

    // Kiểm tra xem có phải tài khoản tạo bằng Email/Password không (để cho phép đổi pass)
    final isEmailProvider = user.providerData.any((info) => info.providerId == 'password');

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87), onPressed: () => Navigator.of(context).pop()),
        title: Text('Hồ sơ của tôi', style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // --- AVATAR UPLOAD ---
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: colorScheme.primary.withOpacity(0.2),
                      backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                      child: _isUploading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : (user.photoURL == null ? Text(currentDisplayName.isNotEmpty ? currentDisplayName[0].toUpperCase() : '?', style: GoogleFonts.nunito(fontSize: 40, color: colorScheme.primary, fontWeight: FontWeight.bold)) : null),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),

            // --- ĐỔI TÊN ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(currentDisplayName, style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const Gap(8),
                InkWell(
                  onTap: () => _showEditNameDialog(currentDisplayName),
                  child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.edit_rounded, color: colorScheme.primary, size: 16)),
                ),
              ],
            ),
            Text(user.email ?? '', style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600)),
            const Gap(32),

            // --- DANH SÁCH TÍNH NĂNG ---
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  // 1. Trạng thái cá nhân
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.speaker_notes_rounded, color: Colors.blue)),
                    title: Text('Trạng thái', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    subtitle: Text(statusMessage, style: GoogleFonts.nunito(color: Colors.grey.shade600)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () => _showEditStatusDialog(statusMessage),
                  ),
                  const Divider(height: 1, indent: 60),

                  // 2. Trạng thái Online/Offline
                  SwitchListTile(
                    secondary: CircleAvatar(backgroundColor: (isOnline ? Colors.green : Colors.grey).withOpacity(0.1), child: Icon(Icons.wifi_rounded, color: isOnline ? Colors.green : Colors.grey)),
                    title: Text('Hiển thị Online', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    subtitle: Text(isOnline ? 'Mọi người có thể thấy bạn' : 'Đang ẩn danh', style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 12)),
                    value: isOnline,
                    activeColor: Colors.green,
                    onChanged: (value) => _toggleOnlineStatus(value),
                  ),
                  const Divider(height: 1, indent: 60),

                  // 3. Đổi mật khẩu (Chỉ hiện nếu đăng nhập bằng Email)
                  if (isEmailProvider) ...[
                    ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.password_rounded, color: Colors.orange)),
                      title: Text('Đổi mật khẩu', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 1, indent: 60),
                  ],

                  // 4. Copy UID
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.1), child: const Icon(Icons.fingerprint_rounded, color: Colors.purple)),
                    title: Text('UID của bạn', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    subtitle: Text(user.uid, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.grey),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.uid));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy UID!')));
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Gap(32),

            // --- NÚT ĐĂNG XUẤT ---
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: Text('ĐĂNG XUẤT', style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}