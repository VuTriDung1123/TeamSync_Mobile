import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Lắng nghe trạng thái để báo thành công và lùi về trang Login
    ref.listen<AsyncValue<void>>(
      authControllerProvider,
          (previous, next) {
        next.whenOrNull(
          data: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã gửi link khôi phục! Vui lòng kiểm tra hộp thư email của bạn.'),
                duration: Duration(seconds: 4),
              ),
            );
            context.pop(); // Gửi xong thì tự động quay về trang Login
          },
          error: (error, stackTrace) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: Không thể gửi email. Hãy kiểm tra lại địa chỉ!')),
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
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_reset_rounded, size: 100, color: colorScheme.primary.withOpacity(0.8)),
              const Gap(24),
              Text(
                'Quên mật khẩu?',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(12),
              Text(
                'Đừng lo lắng! Hãy nhập email bạn đã đăng ký, chúng tôi sẽ gửi cho bạn một liên kết để đặt lại mật khẩu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              ),
              const Gap(40),

              // TextField Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email của bạn',
                  prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.primaryContainer.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const Gap(30),

              // Nút Gửi yêu cầu
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                  final email = _emailController.text.trim();
                  if (email.isNotEmpty) {
                    ref.read(authControllerProvider.notifier).resetPassword(email);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vui lòng nhập email!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text('GỬI LIÊN KẾT', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}