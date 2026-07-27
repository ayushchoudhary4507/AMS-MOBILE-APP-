import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/storage_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static void init() {
    // Request Interceptor — attach token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            await StorageService.clearAll();
          }
          return handler.next(e);
        },
      ),
    );
  }

  static Dio get dio => _dio;

  // GET request
  static Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    return await _dio.get(path, queryParameters: queryParams);
  }

  // POST request
  static Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
  }) async {
    return await _dio.post(path, data: data, queryParameters: queryParams);
  }

  // PUT request
  static Future<Response> put(
    String path, {
    dynamic data,
  }) async {
    return await _dio.put(path, data: data);
  }

  // DELETE request
  static Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  // PATCH request
  static Future<Response> patch(
    String path, {
    dynamic data,
  }) async {
    return await _dio.patch(path, data: data);
  }
}
