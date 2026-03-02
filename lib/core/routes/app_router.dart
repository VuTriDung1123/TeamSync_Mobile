import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';

// Tạo một instance của GoRouter
final goRouter = GoRouter(
  initialLocation: '/login', // Màn hình đầu tiên khi mở app
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Sau này các màn hình như Chat, Workspace sẽ được khai báo thêm ở đây
  ],
);