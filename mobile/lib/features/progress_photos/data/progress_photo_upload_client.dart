import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'progress_photo_upload_exception.dart';

const _connectTimeout = Duration(seconds: 15);
const _sendTimeout = Duration(seconds: 120);
const _receiveTimeout = Duration(seconds: 30);

/// Direct blob upload client — intentionally separate from authenticated backend Dio.
class ProgressPhotoUploadClient {
  ProgressPhotoUploadClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> uploadFile({
    required String uploadUrl,
    required Map<String, String> requiredHeaders,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      await _dio.put<void>(
        uploadUrl,
        data: bytes,
        options: Options(
          headers: requiredHeaders,
          contentType: requiredHeaders['Content-Type'],
          sendTimeout: _sendTimeout,
          receiveTimeout: _receiveTimeout,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
        onSendProgress: onProgress,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw mapBlobTimeout();
      }
      if (error.type == DioExceptionType.connectionError) {
        throw mapBlobConnection();
      }
      throw mapBlobUploadError(
        statusCode: error.response?.statusCode,
        dioMessage: error.message,
      );
    }
  }

  Dio get dio => _dio;
}

ProgressPhotoUploadClient createProgressPhotoUploadClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: _connectTimeout,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
    ),
  );
  return ProgressPhotoUploadClient(dio: dio);
}
