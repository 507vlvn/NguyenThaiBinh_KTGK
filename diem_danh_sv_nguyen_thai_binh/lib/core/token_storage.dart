import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final _storage = const FlutterSecureStorage();

  Future<String?> get token => _storage.read(key: 'token');
  Future<String?> get role => _storage.read(key: 'role');
  Future<String?> get fullName => _storage.read(key: 'fullName');

  Future<void> save({required String token, required String role, required String fullName}) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'role', value: role);
    await _storage.write(key: 'fullName', value: fullName);
  }

  Future<void> clear() => _storage.deleteAll();
}
