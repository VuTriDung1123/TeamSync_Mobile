import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

// Provider cung cấp Controller này cho UI
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(authRepository: ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthController({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AsyncData(null)); // Trạng thái ban đầu là không làm gì cả

  // Hàm xử lý khi user bấm nút Google
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading(); // Bật trạng thái Loading (quay vòng vòng)
    try {
      await _authRepository.signInWithGoogle();
      state = const AsyncData(null); // Thành công -> Tắt Loading
    } catch (e, st) {
      state = AsyncError(e, st); // Thất bại -> Báo lỗi
    }
  }
}