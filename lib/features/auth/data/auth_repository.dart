import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';


// 1. Provider cung cấp instance của AuthRepository để dùng ở mọi nơi trong app
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn(),
  );
});

// 2. Class Repository chứa toàn bộ logic gọi API Firebase
class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn;

  // Stream theo dõi trạng thái người dùng (Đã đăng nhập hay chưa)
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Đăng nhập bằng Email & Mật khẩu
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow; // Ném lỗi ra ngoài để UI hiển thị thông báo
    }
  }

  // Đăng ký bằng Email, Mật khẩu & Tên hiển thị
  Future<UserCredential> signUpWithEmail(String name, String email, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Cập nhật tên hiển thị ngay sau khi tạo tài khoản
      await credential.user?.updateDisplayName(name);
      // Cập nhật lại user để đảm bảo lấy được tên mới nhất
      await credential.user?.reload();
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập bằng Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Bật cửa sổ chọn tài khoản Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Người dùng bấm Hủy

      // Lấy token xác thực từ Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Đóng gói credential để gửi cho Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase
      return await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  // Đăng nhập bằng GitHub
  Future<UserCredential> signInWithGitHub() async {
    try {
      // Firebase hỗ trợ mở WebView đăng nhập GitHub rất tiện lợi
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      return await _firebaseAuth.signInWithProvider(githubProvider);
    } catch (e) {
      rethrow;
    }
  }

  // Đăng xuất
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  // Hàm gửi email khôi phục mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}