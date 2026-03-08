import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider cung cấp instance của Secure Storage để gọi ở bất kỳ đâu
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

class SecureStorageService {
  // Khởi tạo két sắt
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Chìa khóa để lưu JWT
  static const String _jwtKey = 'TEAMSYNC_JWT_TOKEN';

  // 1. Cất JWT vào két
  Future<void> saveToken(String token) async {
    await _storage.write(key: _jwtKey, value: token);
  }

  // 2. Lấy JWT ra (Dùng để kẹp vào Header khi gọi API server khác sau này)
  Future<String?> getToken() async {
    return await _storage.read(key: _jwtKey);
  }

  // 3. Xóa JWT (Khi đăng xuất)
  Future<void> deleteToken() async {
    await _storage.delete(key: _jwtKey);
  }
}