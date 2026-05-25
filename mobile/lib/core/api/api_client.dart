import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParams, required T Function(dynamic) fromJson}) async {
    final res = await _dio.get(path, queryParameters: queryParams);
    return fromJson(res.data);
  }

  Future<T> post<T>(String path, {required dynamic body, required T Function(dynamic) fromJson}) async {
    final res = await _dio.post(path, data: body);
    return fromJson(res.data);
  }

  Future<T> put<T>(String path, {required dynamic body, required T Function(dynamic) fromJson}) async {
    final res = await _dio.put(path, data: body);
    return fromJson(res.data);
  }

  Future<void> delete(String path) async {
    await _dio.delete(path);
  }

  Future<Map<String, dynamic>> uploadFile(
    String path,
    FormData formData, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
      // Do NOT set contentType or Content-Type header here —
      // Dio auto-generates the correct multipart/form-data; boundary=... value.
      // Overriding it strips the boundary, breaking the multipart body.
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _tokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> hasToken() async {
    final t = await _storage.read(key: _tokenKey);
    return t != null && t.isNotEmpty;
  }
}

class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          final res = await _dio.post(
            '/v1/auth/refresh',
            data: {'refresh_token': refreshToken},
            options: Options(headers: {}),
          );
          final newToken = res.data['access_token'] as String;
          await _storage.write(key: 'access_token', value: newToken);
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retried = await _dio.fetch(err.requestOptions);
          return handler.resolve(retried);
        } catch (_) {
          await _storage.deleteAll();
        }
      }
    }
    handler.next(err);
  }
}
