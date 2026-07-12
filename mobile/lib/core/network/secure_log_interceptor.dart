import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Development-only request logging with sensitive data redacted.
class SecureLogInterceptor extends Interceptor {
  SecureLogInterceptor({required this.enabled});

  final bool enabled;

  static const _redactedKeys = {
    'authorization',
    'password',
    'access_token',
    'token',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      debugPrint('[HTTP] ${options.method} ${options.uri}');
      if (options.headers.isNotEmpty) {
        debugPrint('[HTTP] headers: ${_redactMap(options.headers)}');
      }
      if (options.data != null) {
        debugPrint('[HTTP] body: ${_redactData(options.data)}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      debugPrint(
          '[HTTP] ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      debugPrint(
        '[HTTP] error ${err.response?.statusCode ?? 'unknown'} '
        '${err.requestOptions.uri}',
      );
    }
    handler.next(err);
  }

  static Map<String, dynamic> _redactMap(Map<String, dynamic> input) {
    return input.map((key, value) {
      if (_redactedKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }

  static dynamic _redactData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data.map((key, value) {
        if (_redactedKeys.contains(key.toLowerCase())) {
          return MapEntry(key, '[REDACTED]');
        }
        return MapEntry(key, value);
      });
    }
    return data;
  }
}
