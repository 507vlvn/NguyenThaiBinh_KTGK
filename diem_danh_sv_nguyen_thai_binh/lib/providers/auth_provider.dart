import 'package:flutter/foundation.dart';

import '../core/token_storage.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._storage);

  final TokenStorage _storage;
  bool ready = false;
  String? role;
  String? fullName;

  bool get isLoggedIn => role != null;

  Future<void> restore() async {
    if (await _storage.token != null) {
      role = await _storage.role;
      fullName = await _storage.fullName;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> saveSession(Map<String, dynamic> data) async {
    final newRole = data['role'].toString();
    final name = data['fullName'].toString();
    await _storage.save(token: data['token'] as String, role: newRole, fullName: name);
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
}
