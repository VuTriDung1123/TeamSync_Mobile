import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/data/auth_repository.dart';

// Đổi thành ConsumerStatefulWidget để cập nhật giao diện khi đổi tên xong
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  // Hàm hiển thị hộp thoại đổi tên
  Future<void> _showEditNameDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Đổi tên hiển thị', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Nhập tên mới...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('HỦY', style: GoogleFonts.nunito(color: Colors.grey))
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('LƯU', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    // Xử lý lưu lên Firebase nếu tên có thay đổi
    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          // 1. Cập nhật trong Firebase Auth
          await user.updateDisplayName(newName);

          // 2. Cập nhật trong bảng users của Firestore (để người khác thấy)
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'name': newName,
          });

          // 3. Báo cho Flutter biết để vẽ lại UI
          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật tên thành công!')));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser; // Gọi lại user để lấy thông tin mới nhất

    if (user == null) return const Scaffold(body: Center(child: Text('Lỗi: Không tìm thấy user')));

    String providerName = 'Email/Mật khẩu';
    IconData providerIcon = Icons.email_rounded;
    Color providerColor = Colors.orange;

    if (user.providerData.isNotEmpty) {
      final pid = user.providerData.first.providerId;
      if (pid == 'google.com') {
        providerName = 'Google';
        providerIcon = Icons.g_mobiledata;
        providerColor = Colors.redAccent;
      } else if (pid == 'github.com') {
        providerName = 'GitHub';
        providerIcon = Icons.code;
        providerColor = Colors.black87;
      }
    }

    final currentDisplayName = user.displayName ?? 'Chưa cập nhật tên';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Hồ sơ của tôi',
          style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar (Hiện tại chưa làm logic upload ảnh nên đổi icon edit thành icon camera mờ)
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primary.withOpacity(0.2),
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    child: user.photoURL == null
                        ? Text(
                      currentDisplayName[0].toUpperCase(),
                      style: GoogleFonts.nunito(fontSize: 40, color: colorScheme.primary, fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                ],
              ),
            ),
            const Gap(16),

            // Khu vực Tên và Nút sửa
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentDisplayName,
                  style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const Gap(8),
                InkWell(
                  onTap: () => _showEditNameDialog(currentDisplayName), // Bấm vào để đổi tên
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.edit_rounded, color: colorScheme.primary, size: 16),
                  ),
                ),
              ],
            ),
            Text(
              user.email ?? 'Không có email',
              style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600),
            ),
            const Gap(32),

            _buildInfoCard(
              context,
              icon: Icons.fingerprint,
              title: 'UID (Mã định danh)',
              subtitle: user.uid,
              trailing: IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.grey),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: user.uid));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy UID!')));
                },
              ),
            ),
            const Gap(16),
            _buildInfoCard(
              context,
              icon: providerIcon,
              iconColor: providerColor,
              title: 'Phương thức đăng nhập',
              subtitle: providerName,
            ),
            const Gap(32),

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

  Widget _buildInfoCard(BuildContext context, {required IconData icon, required String title, required String subtitle, Widget? trailing, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (iconColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600)),
                Text(subtitle, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}