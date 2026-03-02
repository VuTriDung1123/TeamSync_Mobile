import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/auth_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lấy thông tin user hiện tại từ Firebase
    final user = FirebaseAuth.instance.currentUser;
    // Lấy tên phương thức đăng nhập (password, google.com, github.com)
    final provider = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId
        : 'Không rõ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard - TeamSync'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Đăng xuất và đá về màn hình Login
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'ĐĂNG NHẬP THÀNH CÔNG!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text('Email: ${user?.email ?? "Không có email"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('Đăng nhập bằng: $provider', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('UID: ${user?.uid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}