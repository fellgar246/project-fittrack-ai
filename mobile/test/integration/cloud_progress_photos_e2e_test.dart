import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/config/app_config.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/features/auth/data/auth_api.dart';
import 'package:fittrack_ai/features/auth/data/models/login_request.dart';
import 'package:fittrack_ai/features/auth/data/models/register_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/create_progress_photo_upload_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_client.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_api.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Block 5.10 cloud E2E using Flutter data layer against the deployed API.
///
/// Run:
/// ```bash
/// flutter test test/integration/cloud_progress_photos_e2e_test.dart \
///   --dart-define=RUN_CLOUD_E2E=true \
///   --dart-define=APP_ENV=development \
///   --dart-define=API_BASE_URL=https://ca-fittrack-ai-api-dev.wittydune-377fa2b0.eastus.azurecontainerapps.io
/// ```
const _runCloudE2e = bool.fromEnvironment('RUN_CLOUD_E2E', defaultValue: false);

Uint8List _fixtureJpegBytes() {
  return Uint8List.fromList(
    base64Decode(
      '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof'
      'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh'
      'MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR'
      'CAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAA'
      'AAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oA'
      'DAMBAAIRAxEAPwCwAA8A/9k=',
    ),
  );
}

void main() {
  test(
    'cloud progress photos full lifecycle via Flutter repository',
    () async {
      final config = AppConfig.fromEnvironment();
      final runId = DateTime.now().millisecondsSinceEpoch;
      final email = 'flutter-cloud-e2e-$runId@example.com';
      const password = 'DemoPass123!';

      final authDio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl.toString(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final authApi = AuthApi(ApiClient(authDio));

      await authApi.register(
        RegisterRequest(
          email: email,
          password: password,
          name: 'Flutter Cloud E2E',
          goal: 'strength',
        ),
      );
      final login = await authApi.login(
        LoginRequest(email: email, password: password),
      );

      final apiDio = Dio(
        BaseOptions(
          baseUrl: config.apiBaseUrl.toString(),
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {'Authorization': 'Bearer ${login.accessToken}'},
        ),
      );
      final api = ProgressPhotosApi(ApiClient(apiDio));

      String? blobAuthorizationHeader;
      final uploadDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      uploadDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            blobAuthorizationHeader =
                options.headers['Authorization']?.toString();
            handler.next(options);
          },
        ),
      );
      final uploadClient = ProgressPhotoUploadClient(dio: uploadDio);
      final repository = ProgressPhotosRepositoryImpl(
        api: api,
        uploadClient: uploadClient,
      );

      final bytes = _fixtureJpegBytes();
      final photo = await repository.uploadProgressPhoto(
        request: CreateProgressPhotoUploadRequest(
          capturedAt: DateTime.utc(2026, 7, 17),
          contentType: 'image/jpeg',
          sizeBytes: bytes.length,
          notes: 'Flutter cloud E2E fixture',
        ),
        bytes: bytes,
      );

      expect(photo.status, 'active');
      expect(blobAuthorizationHeader, isNull);

      final listed = await repository.listPhotos();
      expect(listed.any((item) => item.id == photo.id), isTrue);

      final accessUrl1 = await repository.getPhotoAccessUrl(photo.id);
      expect(accessUrl1, startsWith('https://'));

      repository.invalidatePhotoAccess(photo.id);
      final accessUrl2 = await repository.getPhotoAccessUrl(photo.id);
      expect(accessUrl2, startsWith('https://'));

      final readResponse = await Dio().get<Uint8List>(
        accessUrl2,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(readResponse.statusCode, 200);
      expect(readResponse.data?.length, greaterThan(0));
    },
    skip: !_runCloudE2e,
  );
}
