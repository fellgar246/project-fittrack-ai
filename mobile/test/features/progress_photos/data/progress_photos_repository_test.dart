import 'dart:typed_data';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/create_progress_photo_upload_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_access_authorization.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_upload_authorization.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_access_cache.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_client.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_exception.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_api.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeProgressPhotosApi api;
  late FakeProgressPhotoUploadClient uploadClient;
  late ProgressPhotosRepositoryImpl repository;

  setUp(() {
    api = FakeProgressPhotosApi();
    uploadClient = FakeProgressPhotoUploadClient();
    repository = ProgressPhotosRepositoryImpl(
      api: api,
      uploadClient: uploadClient,
      accessCache: ProgressPhotoAccessCache(),
    );
  });

  test('full upload lifecycle succeeds', () async {
    final photo = await repository.uploadProgressPhoto(
      request: CreateProgressPhotoUploadRequest(
        capturedAt: DateTime(2026, 7, 15),
        contentType: 'image/jpeg',
        sizeBytes: 4,
      ),
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(photo.status, 'active');
    expect(api.createCalls, 1);
    expect(uploadClient.uploadCalls, 1);
    expect(api.confirmCalls, 1);
  });

  test('retry confirm does not repeat upload', () async {
    api.confirmError = const ConflictException('Upload authorization expired');
    final authorization = await repository.createUploadAuthorization(
      CreateProgressPhotoUploadRequest(
        capturedAt: DateTime(2026, 7, 15),
        contentType: 'image/jpeg',
        sizeBytes: 4,
      ),
    );
    await repository.uploadFile(
      authorization: authorization,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );

    expect(
      repository.retryConfirm(authorization.photoId),
      throwsA(isA<ConflictException>()),
    );
    expect(uploadClient.uploadCalls, 1);

    api.confirmError = null;
    final confirmed = await repository.retryConfirm(authorization.photoId);
    expect(confirmed.status, 'active');
    expect(uploadClient.uploadCalls, 1);
  });

  test('access cache reuses valid url', () async {
    api.accessAuthorization = ProgressPhotoAccessAuthorization(
      photoId: '11111111-1111-1111-1111-111111111111',
      accessUrl: 'https://storage.example.test/container/blob?<fake-sas>',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    final first = await repository.getPhotoAccessUrl(
      '11111111-1111-1111-1111-111111111111',
    );
    final second = await repository.getPhotoAccessUrl(
      '11111111-1111-1111-1111-111111111111',
    );

    expect(first, second);
    expect(api.accessCalls, 1);
  });

  test('blob 403 does not propagate as unauthorized', () async {
    uploadClient.error = const ProgressPhotoUploadException(
      'Upload authorization expired or invalid.',
      statusCode: 403,
    );

    expect(
      repository.uploadProgressPhoto(
        request: CreateProgressPhotoUploadRequest(
          capturedAt: DateTime(2026, 7, 15),
          contentType: 'image/jpeg',
          sizeBytes: 4,
        ),
        bytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsA(isA<ProgressPhotoUploadException>()),
    );
  });
}

class FakeProgressPhotosApi implements ProgressPhotosApi {
  var createCalls = 0;
  var confirmCalls = 0;
  var listCalls = 0;
  var accessCalls = 0;
  Object? confirmError;
  ProgressPhotoAccessAuthorization? accessAuthorization;

  @override
  Future<ProgressPhotoUploadAuthorization> createUploadRequest(
    CreateProgressPhotoUploadRequest request,
  ) async {
    createCalls++;
    return ProgressPhotoUploadAuthorization(
      photoId: '11111111-1111-1111-1111-111111111111',
      uploadUrl: 'https://storage.example.test/container/blob?<fake-sas>',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      requiredHeaders: {
        'Content-Type': request.contentType,
        'x-ms-blob-type': 'BlockBlob',
      },
    );
  }

  @override
  Future<ProgressPhoto> confirmUpload(String photoId) async {
    confirmCalls++;
    if (confirmError != null) {
      throw confirmError!;
    }
    return ProgressPhoto(
      id: photoId,
      capturedAt: DateTime(2026, 7, 15),
      contentType: 'image/jpeg',
      sizeBytes: 4,
      status: 'active',
      createdAt: DateTime(2026, 7, 15, 10),
      confirmedAt: DateTime(2026, 7, 15, 10, 5),
    );
  }

  @override
  Future<List<ProgressPhoto>> listPhotos() async {
    listCalls++;
    return const [];
  }

  @override
  Future<ProgressPhotoAccessAuthorization> requestAccess(String photoId) async {
    accessCalls++;
    return accessAuthorization ??
        ProgressPhotoAccessAuthorization(
          photoId: photoId,
          accessUrl: 'https://storage.example.test/container/blob?<fake-sas>',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        );
  }
}

class FakeProgressPhotoUploadClient extends ProgressPhotoUploadClient {
  var uploadCalls = 0;
  ProgressPhotoUploadException? error;

  @override
  Future<void> uploadFile({
    required String uploadUrl,
    required Map<String, String> requiredHeaders,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadCalls++;
    if (error != null) {
      throw error!;
    }
    onProgress?.call(bytes.length, bytes.length);
  }
}
