import 'package:dio/dio.dart';

import '../errors/api_exception.dart';
import 'error_mapper.dart';

/// Thin wrapper around Dio with normalized error mapping.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _request(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
    );
  }

  Future<Response<T>> _request<T>(
    Future<Response<T>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw mapDioException(error);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw UnknownApiException(error.toString());
    }
  }
}
