import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/storage_service.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 130),
      sendTimeout: const Duration(seconds: 45),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static void init() {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await StorageService.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}
          // Debug Logging
          // ignore: avoid_print
          print('--> ${options.method.toUpperCase()} ${options.uri}');
          if (options.data != null) {
            // ignore: avoid_print
            print('BODY: ${options.data}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Truncated safe logging
          // ignore: avoid_print
          print('<-- ${response.statusCode} ${response.requestOptions.uri}');
          final resStr = response.data?.toString() ?? '';
          if (resStr.length > 200) {
            // ignore: avoid_print
            print('RESPONSE: ${resStr.substring(0, 200)}... [truncated]');
          } else if (resStr.isNotEmpty) {
            // ignore: avoid_print
            print('RESPONSE: $resStr');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          // ignore: avoid_print
          print('<-- ERROR ${e.response?.statusCode} ${e.requestOptions.uri}');
          final errStr = e.response?.data?.toString() ?? '';
          if (errStr.length > 200) {
            // ignore: avoid_print
            print('ERROR BODY: ${errStr.substring(0, 200)}... [truncated]');
          } else if (errStr.isNotEmpty) {
            // ignore: avoid_print
            print('ERROR BODY: $errStr');
          }
          try {
            final statusCode = e.response?.statusCode;
            final bodyStr = e.response?.data?.toString().toLowerCase() ?? '';
            if (statusCode == 401 ||
                bodyStr.contains('jwt') ||
                bodyStr.contains('malformed') ||
                bodyStr.contains('invalid token')) {
              await StorageService.clearAll();
            }
          } catch (_) {}
          return handler.next(e);
        },
      ),
    );
  }

  static Dio get dio => _dio;

  // Helper to safely convert response data to Map<String, dynamic>
  static Map<String, dynamic> toMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else if (data is List) {
      return {
        'data': data,
        'attendance': data,
        'employees': data,
        'leaves': data,
        'records': data,
        'result': data,
      };
    }
    return {};
  }

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
  static Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  // DELETE request
  static Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }

  // PATCH request
  static Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }
}
