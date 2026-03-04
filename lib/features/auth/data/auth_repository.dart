import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/utils/secure_storage_service.dart';

// 1. Cập nhật Provider: Tiêm thêm secureStorageProvider vào
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn(),
    secureStorage: ref.read(secureStorageProvider), // <--- Thêm dòng này
  );
});

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final SecureStorageService _secureStorage;

  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required SecureStorageService secureStorage,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _secureStorage = secureStorage;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // --- HÀM LƯU JWT (DÙNG CHUNG) ---
  Future<void> _saveTokenLocally(User? user) async {
    if (user != null) {
      // Ép Firebase nhả JWT ra (getIdToken)
      final token = await user.getIdToken();
      if (token != null) {
        // Cất vào két sắt
        await _secureStorage.saveToken(token);
        // (Tuỳ chọn) Bạn có thể in ra console để ngắm thành quả
        // print('Đã lưu JWT thành công: $token');
      }
    }
  }

  // Đăng nhập bằng Email
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      await _saveTokenLocally(credential.user); // <--- Lưu token
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng ký bằng Email
  Future<UserCredential> signUpWithEmail(String name, String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
      await _saveTokenLocally(_firebaseAuth.currentUser); // <--- Lưu token
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      await _saveTokenLocally(userCredential.user); // <--- Lưu token
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập bằng GitHub
  Future<UserCredential> signInWithGitHub() async {
    try {
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      final userCredential = await _firebaseAuth.signInWithProvider(githubProvider);
      await _saveTokenLocally(userCredential.user); // <--- Lưu token
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Khôi phục mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    // Xóa sạch token khỏi két sắt khi đăng xuất
    await _secureStorage.deleteToken();
  }
}