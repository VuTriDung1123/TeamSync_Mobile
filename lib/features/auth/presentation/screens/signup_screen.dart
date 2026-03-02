import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_controller.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Lắng nghe trạng thái để chuyển trang nếu Đăng ký thành công
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
          (previous, next) {
        next.whenOrNull(
          data: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Đăng ký thành công!')),
            );
            context.go('/home'); // Thành công thì vào Home
          },
          error: (error, stackTrace) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${error.toString()}')),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => context.pop(), // Nút Back về Login
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tạo tài khoản',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(8),
              Text(
                'Tham gia TeamSync ngay hôm nay!',
                style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade500),
              ),
              const Gap(40),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const Gap(16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const Gap(16),

              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nhập lại mật khẩu',
                  prefixIcon: Icon(Icons.lock_reset, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const Gap(40),

              // Nút Đăng ký
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                  final email = _emailController.text.trim();
                  final pass = _passwordController.text.trim();
                  final confirmPass = _confirmPasswordController.text.trim();

                  if (pass != confirmPass) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mật khẩu không khớp!')),
                    );
                    return;
                  }
                  if (email.isNotEmpty && pass.isNotEmpty) {
                    ref.read(authControllerProvider.notifier).signUpWithEmail(email, pass);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('ĐĂNG KÝ', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}