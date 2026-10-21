import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../core/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._storage);

  final TokenStorage _storage;
  bool ready = false;
  String? role;
  String? fullName;

  bool get isLoggedIn => role != null;

  // Khôi phục phiên khi mở app. Token hết hạn (sau 8 giờ) thì xoá và yêu cầu đăng nhập lại.
  Future<void> restore() async {
    final token = await _storage.token;
    if (token != null && !JwtDecoder.isExpired(token)) {
      role = JwtDecoder.decode(token)['role']?.toString() ?? await _storage.role;
      fullName = await _storage.fullName;
    } else if (token != null) {
      await _storage.clear();
    }
    ready = true;
    notifyListeners();
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final newRole = JwtDecoder.decode(token)['role']?.toString() ?? data['role'].toString();
    final name = data['fullName'].toString();
    await _storage.save(token: token, role: newRole, fullName: name);
    role = newRole;
    fullName = name;
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clear();
    role = null;
    fullName = null;
    notifyListeners();
  }

  // Gọi khi server trả 401 lúc đang dùng app. Trả về true nếu thật sự vừa đăng xuất
  // (để chỉ thông báo một lần dù nhiều request cùng lỗi).
  Future<bool> expireSession() async {
    if (!isLoggedIn) return false;
    await logout();
    return true;
  }
}
