import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/chat/presentation/screens/search_user_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';


// Đưa GoRouter vào một Provider để nó có thể đọc được trạng thái từ Riverpod
final goRouterProvider = Provider<GoRouter>((ref) {
  // Lắng nghe stream trạng thái đăng nhập
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    // Redirect logic: Chạy mỗi khi có sự thay đổi trang hoặc thay đổi state đăng nhập
    redirect: (context, state) {
      if (authState.isLoading || authState.hasError) return null;

      final isAuthenticated = authState.value != null;
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSignUp = state.matchedLocation == '/signup';
      final isGoingToForgotPass = state.matchedLocation == '/forgot-password'; // Thêm dòng này

      // 1. Nếu CHƯA đăng nhập mà cố tình vào các trang bên trong (không phải 3 trang Auth) -> Đuổi về Login
      if (!isAuthenticated && !isGoingToLogin && !isGoingToSignUp && !isGoingToForgotPass) {
        return '/login';
      }

      // 2. Nếu ĐÃ đăng nhập mà lại đứng ở màn hình Login/Signup/Quên MK -> Đẩy thẳng vào Home
      if (isAuthenticated && (isGoingToLogin || isGoingToSignUp || isGoingToForgotPass)) {
        return '/home';
      }

      // 3. Hợp lệ -> Cho đi tiếp
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
          path: '/search',
          builder: (context, state) => const SearchUserScreen()
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
    ],
  );
});