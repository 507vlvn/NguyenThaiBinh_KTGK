import 'package:dio/dio.dart';

import '../core/api_exception.dart';
import '../config/config_url.dart';
import '../core/token_storage.dart';

typedef Json = Map<String, dynamic>;

class ApiService {
  ApiService(this._storage)
      : _dio = Dio(BaseOptions(
          baseUrl: Config_URL.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _storage.token;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  final TokenStorage _storage;
  final Dio _dio;

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      throw ApiException(_messageOf(e));
    }
  }

  List<Json> _list(dynamic data) => (data as List).cast<Json>();

  Json _map(dynamic data) => Map<String, dynamic>.from(data as Map);

  String _messageOf(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      final errors = data['errors'];
      if (errors is Map && errors.values.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['title'] != null) return data['title'].toString();
    }
    switch (e.response?.statusCode) {
      case 401:
        return 'Sai thông tin đăng nhập hoặc phiên đã hết hạn.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
    }
    return 'Không kết nối được máy chủ.';
  }

  // Xác thực
  Future<Json> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    return _map(await _send(() => _dio.post('/api/auth/register', data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
        })));
  }

  Future<Json> verifyRegister(String username, String code) async {
    return _map(await _send(() => _dio.post('/api/auth/register/verify', data: {'username': username, 'code': code})));
  }

  Future<Json> login(String username, String password) async {
    return _map(await _send(() => _dio.post('/api/auth/login', data: {'username': username, 'password': password})));
  }

  Future<Json> verifyLogin(String username, String code) async {
    return _map(await _send(() => _dio.post('/api/auth/login/verify', data: {'username': username, 'code': code})));
  }

  // Lớp và buổi học
  Future<List<Json>> classes() async => _list(await _send(() => _dio.get('/api/classes')));

  Future<List<Json>> sessions(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/sessions')));

  Future<Json> createSession(int classId, {
    required String title,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    return _map(await _send(() => _dio.post('/api/classes/$classId/sessions', data: {
          'title': title,
          'startsAt': DateTime.now().toUtc().toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
        })));
  }

  Future<void> closeSession(int sessionId) async {
    await _send(() => _dio.post('/api/sessions/$sessionId/close'));
  }

  Future<List<Json>> attendances(int sessionId) async =>
      _list(await _send(() => _dio.get('/api/sessions/$sessionId/attendances')));

  Future<Json> checkIn({
    required int sessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
    String? photoPath,
  }) async {
    final form = FormData.fromMap({
      'qrToken': qrToken,
      'latitude': latitude,
      'longitude': longitude,
      if (photoPath != null) 'photo': await MultipartFile.fromFile(photoPath, filename: photoPath.split(RegExp(r'[\\/]')).last),
    });
    return _map(await _send(() => _dio.post('/api/sessions/$sessionId/check-in', data: form)));
  }

  // Đơn xin nghỉ
  Future<void> submitLeave({required int sessionId, required String reason, String? evidencePath}) async {
    final form = FormData.fromMap({
      'sessionId': sessionId,
      'reason': reason,
      if (evidencePath != null) 'evidence': await MultipartFile.fromFile(evidencePath, filename: evidencePath.split(RegExp(r'[\\/]')).last),
    });
    await _send(() => _dio.post('/api/leave-requests', data: form));
  }

  Future<List<Json>> myLeaves() async => _list(await _send(() => _dio.get('/api/leave-requests/mine')));

  Future<List<Json>> classLeaves(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/leave-requests')));

  Future<void> reviewLeave(int id, {required bool approve}) async {
    await _send(() => _dio.put('/api/leave-requests/$id/review', data: {'approve': approve}));
  }

  Future<List<Json>> absenceReport(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/absence-report')));

  Future<Json> sendWarnings(int classId) async =>
      _map(await _send(() => _dio.post('/api/classes/$classId/send-warnings')));

  // Sinh viên trong lớp
  Future<List<Json>> classStudents(int classId) async =>
      _list(await _send(() => _dio.get('/api/classes/$classId/students')));

  Future<void> enroll(int classId, int studentId) async {
    await _send(() => _dio.post('/api/classes/$classId/students', data: {'studentId': studentId}));
  }

  Future<void> unenroll(int classId, int studentId) async {
    await _send(() => _dio.delete('/api/classes/$classId/students/$studentId'));
  }

  // Quản trị
  Future<List<Json>> users() async => _list(await _send(() => _dio.get('/api/users')));

  Future<void> createUser({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await _send(() => _dio.post('/api/users', data: {
          'username': username,
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': role,
        }));
  }

  Future<void> deleteUser(int id) async {
    await _send(() => _dio.delete('/api/users/$id'));
  }

  Future<List<Json>> subjects() async => _list(await _send(() => _dio.get('/api/subjects')));

  Future<void> createSubject(String code, String name) async {
    await _send(() => _dio.post('/api/subjects', data: {'code': code, 'name': name}));
  }

  Future<void> deleteSubject(int id) async {
    await _send(() => _dio.delete('/api/subjects/$id'));
  }

  Future<void> createClass(String name, int subjectId, int teacherId) async {
    await _send(() => _dio.post('/api/classes', data: {'name': name, 'subjectId': subjectId, 'teacherId': teacherId}));
  }

  Future<void> deleteClass(int id) async {
    await _send(() => _dio.delete('/api/classes/$id'));
  }
}
