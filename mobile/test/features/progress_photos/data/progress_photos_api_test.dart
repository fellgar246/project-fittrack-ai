import 'package:dio/dio.dart';
import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/core/network/api_client.dart';
import 'package:fittrack_ai/core/network/api_endpoints.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/create_progress_photo_upload_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeApiClient client;
  late ProgressPhotosApi api;

  setUp(() {
    client = _FakeApiClient();
    api = ProgressPhotosApi(client);
  });

  test('create upload request posts expected payload', () async {
    client.postResponses[ApiEndpoints.progressPhotoUploadRequests] =
        _uploadAuthorizationJson;

    final authorization = await api.createUploadRequest(
      CreateProgressPhotoUploadRequest(
        capturedAt: DateTime(2026, 7, 15),
        contentType: 'image/jpeg',
        sizeBytes: 123456,
        notes: 'Optional note',
      ),
    );

    expect(authorization.photoId, isNotEmpty);
    expect(client.lastPostBody?['captured_at'], '2026-07-15');
    expect(client.lastPostBody?['content_type'], 'image/jpeg');
  });

  test('list returns empty array', () async {
    client.responses[ApiEndpoints.progressPhotos] = <dynamic>[];
    expect(await api.listPhotos(), isEmpty);
  });

  test('confirm uses photo id path', () async {
    client.postResponses[ApiEndpoints.progressPhotoConfirm('photo-1')] =
        _photoJson;

    final photo = await api.confirmUpload('photo-1');
    expect(photo.status, 'active');
  });

  test('access returns temporary url', () async {
    client.postResponses[ApiEndpoints.progressPhotoAccess('photo-1')] =
        _accessJson;

    final access = await api.requestAccess('photo-1');
    expect(access.accessUrl, contains('storage.example.test'));
  });

  test('401 is propagated', () async {
    client.postErrors[ApiEndpoints.progressPhotoUploadRequests] =
        const UnauthorizedException();
    expect(
      api.createUploadRequest(
        CreateProgressPhotoUploadRequest(
          capturedAt: DateTime(2026, 7, 15),
          contentType: 'image/jpeg',
          sizeBytes: 1,
        ),
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('415 is propagated as unknown api exception path', () async {
    client.postErrors[ApiEndpoints.progressPhotoUploadRequests] =
        const UnknownApiException('Unsupported content type', 415);
    expect(
      api.createUploadRequest(
        CreateProgressPhotoUploadRequest(
          capturedAt: DateTime(2026, 7, 15),
          contentType: 'image/gif',
          sizeBytes: 1,
        ),
      ),
      throwsA(isA<UnknownApiException>()),
    );
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(Dio());

  final responses = <String, Object?>{};
  final errors = <String, Object>{};
  final postResponses = <String, Object?>{};
  final postErrors = <String, Object>{};
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final error = errors[path];
    if (error != null) throw error;
    return Response<T>(
      data: responses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
    );
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPostBody = data as Map<String, dynamic>?;
    final error = postErrors[path];
    if (error != null) throw error;
    return Response<T>(
      data: postResponses[path] as T,
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

const _uploadAuthorizationJson = {
  'photo_id': '11111111-1111-1111-1111-111111111111',
  'upload_url': 'https://storage.example.test/container/blob?<fake-sas>',
  'expires_at': '2026-07-15T12:00:00Z',
  'required_headers': {
    'Content-Type': 'image/jpeg',
    'x-ms-blob-type': 'BlockBlob',
    'Cache-Control': 'no-store',
  },
};

const _photoJson = {
  'id': '11111111-1111-1111-1111-111111111111',
  'captured_at': '2026-07-15',
  'content_type': 'image/jpeg',
  'size_bytes': 123456,
  'notes': null,
  'status': 'active',
  'created_at': '2026-07-15T10:00:00Z',
  'confirmed_at': '2026-07-15T10:05:00Z',
};

const _accessJson = {
  'photo_id': '11111111-1111-1111-1111-111111111111',
  'access_url': 'https://storage.example.test/container/blob?<fake-sas>',
  'expires_at': '2026-07-15T12:05:00Z',
};
