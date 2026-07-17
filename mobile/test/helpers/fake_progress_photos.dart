import 'dart:async';
import 'dart:typed_data';

import 'package:fittrack_ai/features/progress_photos/data/models/create_progress_photo_upload_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_access_authorization.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_upload_authorization.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_repository.dart';

final testProgressPhoto = ProgressPhoto(
  id: '11111111-1111-1111-1111-111111111111',
  capturedAt: DateTime(2026, 7, 15),
  contentType: 'image/jpeg',
  sizeBytes: 123456,
  notes: 'Optional note',
  status: 'active',
  createdAt: DateTime(2026, 7, 15, 10),
  confirmedAt: DateTime(2026, 7, 15, 10, 5),
);

class FakeProgressPhotosRepository implements ProgressPhotosRepository {
  List<ProgressPhoto> photos = [testProgressPhoto];
  Object? listError;
  Object? createError;
  Object? uploadError;
  Object? confirmError;
  Object? accessError;
  Completer<void>? createGate;
  var listCalls = 0;
  var uploadCalls = 0;
  var confirmCalls = 0;
  var accessCalls = 0;
  String? lastConfirmedPhotoId;

  @override
  Future<ProgressPhotoUploadAuthorization> createUploadAuthorization(
    CreateProgressPhotoUploadRequest request,
  ) async {
    await createGate?.future;
    if (createError != null) throw createError!;
    return ProgressPhotoUploadAuthorization(
      photoId: '22222222-2222-2222-2222-222222222222',
      uploadUrl: 'https://storage.example.test/container/blob?<fake-sas>',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      requiredHeaders: {
        'Content-Type': request.contentType,
        'x-ms-blob-type': 'BlockBlob',
      },
    );
  }

  @override
  Future<void> uploadFile({
    required ProgressPhotoUploadAuthorization authorization,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    uploadCalls++;
    if (uploadError != null) throw uploadError!;
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<ProgressPhoto> confirmUpload(String photoId) async {
    confirmCalls++;
    lastConfirmedPhotoId = photoId;
    if (confirmError != null) throw confirmError!;
    return testProgressPhoto.copyWith(id: photoId);
  }

  @override
  Future<ProgressPhoto> retryConfirm(String photoId) => confirmUpload(photoId);

  @override
  Future<List<ProgressPhoto>> listPhotos() async {
    listCalls++;
    if (listError != null) throw listError!;
    return photos;
  }

  @override
  Future<ProgressPhotoAccessAuthorization> requestPhotoAccess(
    String photoId,
  ) async {
    accessCalls++;
    if (accessError != null) throw accessError!;
    return ProgressPhotoAccessAuthorization(
      photoId: photoId,
      accessUrl: 'https://storage.example.test/container/blob?<fake-sas>',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<String> getPhotoAccessUrl(String photoId) async {
    final authorization = await requestPhotoAccess(photoId);
    return authorization.accessUrl;
  }

  @override
  void invalidatePhotoAccess(String photoId) {}

  @override
  void clearAccessCache() {}

  @override
  Future<ProgressPhoto> uploadProgressPhoto({
    required CreateProgressPhotoUploadRequest request,
    required Uint8List bytes,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    uploadCalls++;
    final authorization = await createUploadAuthorization(request);
    await uploadFile(
      authorization: authorization,
      bytes: bytes,
      onProgress: onUploadProgress,
    );
    return confirmUpload(authorization.photoId);
  }

  @override
  SelectedProgressPhotoFile? validateSelectedFile({
    required String path,
    String? reportedMimeType,
  }) {
    return null;
  }
}

extension on ProgressPhoto {
  ProgressPhoto copyWith({String? id}) {
    return ProgressPhoto(
      id: id ?? this.id,
      capturedAt: capturedAt,
      contentType: contentType,
      sizeBytes: sizeBytes,
      notes: notes,
      status: status,
      createdAt: createdAt,
      confirmedAt: confirmedAt,
    );
  }
}
