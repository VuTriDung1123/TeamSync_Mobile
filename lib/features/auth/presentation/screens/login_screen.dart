import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_controller.dart';

// 1. Đổi StatelessWidget thành ConsumerWidget
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  // 2. Thêm tham số WidgetRef ref vào hàm build
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy theme màu hiện tại (Tone hồng nhạt đã setup ở main.dart)
    final colorScheme = Theme.of(context).colorScheme;

    // 3. Lắng nghe trạng thái loading từ AuthController
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(20),
              // Icon Logo và Tên App
              Icon(
                Icons.hub_rounded,
                size: 80,
                color: colorScheme.primary,
              ),
              const Gap(16),
              Text(
                'TeamSync',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Smart Collab & Communication',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const Gap(50),

              // TextField: Email
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Nhập email của bạn',
                  prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
              ),
              const Gap(16),

              // TextField: Mật khẩu
              TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  hintText: 'Nhập mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                  suffixIcon: Icon(Icons.visibility_off_outlined, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
              ),

              // Nút Quên mật khẩu
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Quên mật khẩu?',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const Gap(10),

              // Nút Đăng nhập chính
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'ĐĂNG NHẬP',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Gap(30),

              // Đường kẻ "Hoặc"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'HOẶC',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                ],
              ),
              const Gap(30),

              // 4. Nút đăng nhập Google đã được gắn logic
              OutlinedButton(
                // Nếu đang loading thì khóa nút lại (nhận giá trị null)
                onPressed: isLoading
                    ? null
                    : () {
                  // Gọi hàm đăng nhập từ Controller
                  ref.read(authControllerProvider.notifier).signInWithGoogle();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                // Hiển thị vòng quay nếu đang loading, ngược lại hiện Icon + Text
                child: isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.g_mobiledata, size: 30, color: Colors.redAccent),
                    const Gap(8),
                    Text(
                      'Tiếp tục với Google',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(16),

              // Nút đăng nhập GitHub
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.code, size: 24, color: Colors.white),
                    const Gap(12),
                    Text(
                      'Tiếp tục với GitHub',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // Đăng ký tài khoản mới
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chưa có tài khoản? ',
                    style: GoogleFonts.nunito(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Đăng ký ngay',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}