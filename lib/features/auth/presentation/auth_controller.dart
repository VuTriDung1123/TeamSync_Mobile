import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../projects/data/models/task_model.dart';
import '../../projects/data/repositories/task_repository.dart';
import '../data/auth_repository.dart';


final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(authRepository: ref.watch(authRepositoryProvider));
});
// Provider lắng nghe trạng thái đăng nhập realtime từ Firebase
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
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

  // Thêm tham số name vào đây
  Future<void> signUpWithEmail(String name, String email, String password) async {
    state = const AsyncLoading();
    try {
      await _authRepository.signUpWithEmail(name, email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  // Hàm xử lý UI cho Quên mật khẩu
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    try {
      await _authRepository.sendPasswordResetEmail(email);
      state = const AsyncData(null); // Thành công
    } catch (e, st) {
      state = AsyncError(e, st); // Thất bại
    }
  }

}


final projectTasksProvider = StreamProvider.family<List<TaskModel>, String>((ref, projectId) {
  final repository = ref.watch(taskRepositoryProvider);
  return repository.getProjectTasks(projectId);
});