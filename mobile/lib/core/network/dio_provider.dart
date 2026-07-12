import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../config/environment.dart';
import '../storage/secure_token_storage.dart';
import '../storage/token_storage.dart';
import 'api_endpoints.dart';
import 'secure_log_interceptor.dart';

const _connectTimeout = Duration(seconds: 10);
const _sendTimeout = Duration(seconds: 15);
const _receiveTimeout = Duration(seconds: 30);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: _connectTimeout,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    SecureLogInterceptor(
      enabled: config.environment == AppEnvironment.development,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.path;
        final isPublicAuth =
            path == ApiEndpoints.login || path == ApiEndpoints.register;

        if (!isPublicAuth) {
          final token = await tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }

        handler.next(options);
      },
    ),
  );

  return dio;
});
