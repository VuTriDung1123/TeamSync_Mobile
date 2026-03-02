import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth_controller.dart';

// Nâng cấp lên ConsumerStatefulWidget để quản lý text input
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Tạo bộ điều khiển cho Email và Password
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Đừng quên dọn dẹp bộ nhớ khi hủy màn hình
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Lắng nghe trạng thái loading
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Lắng nghe trạng thái để tự động nhảy trang
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
          (previous, next) {
        next.whenOrNull(
          data: (_) {
            context.go('/home'); // Đăng nhập thành công -> Vào Home
          },
          error: (error, stackTrace) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi đăng nhập: ${error.toString()}')),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Gap(20),
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
                controller: _emailController, // Gắn controller
                keyboardType: TextInputType.emailAddress,
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
                controller: _passwordController, // Gắn controller
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

              // 1. Nút Đăng nhập Email/Password
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                  // Lấy text và gửi lên Firebase
                  final email = _emailController.text.trim();
                  final password = _passwordController.text.trim();
                  if (email.isNotEmpty && password.isNotEmpty) {
                    ref.read(authControllerProvider.notifier).signInWithEmail(email, password);
                  } else {
                    // Báo lỗi nhẹ nếu bỏ trống (bạn có thể thay bằng SnackBar sau)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  'ĐĂNG NHẬP',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Gap(30),

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

              // 2. Nút đăng nhập Google
              OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () {
                  ref.read(authControllerProvider.notifier).signInWithGoogle();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
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

              // 3. Nút đăng nhập GitHub
              OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () {
                  ref.read(authControllerProvider.notifier).signInWithGitHub();
                },
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

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chưa có tài khoản? ',
                    style: GoogleFonts.nunito(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () {
                      context.push('/signup');
                    },
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