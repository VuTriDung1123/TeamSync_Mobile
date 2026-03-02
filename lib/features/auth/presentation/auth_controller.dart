import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(authRepository: ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  AuthController({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AsyncData(null));

  // Hàm xử lý Google
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithGoogle();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // Thêm mới: Hàm xử lý Email & Mật khẩu
  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithEmail(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st); // Nếu sai pass hoặc email sẽ ném lỗi ra đây
    }
  }

  // Thêm mới: Hàm xử lý GitHub
  Future<void> signInWithGitHub() async {
    state = const AsyncLoading();
    try {
      await _authRepository.signInWithGitHub();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signUpWithEmail(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}