import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'models/create_progress_photo_upload_request.dart';
import 'models/progress_photo.dart';
import 'models/progress_photo_access_authorization.dart';
import 'models/progress_photo_constraints.dart';
import 'models/progress_photo_upload_authorization.dart';
import 'progress_photo_access_cache.dart';
import 'progress_photo_upload_client.dart';
import 'progress_photos_api.dart';

class SelectedProgressPhotoFile {
  const SelectedProgressPhotoFile({
    required this.path,
    required this.bytes,
    required this.contentType,
    required this.sizeBytes,
  });

  final String path;
  final Uint8List bytes;
  final String contentType;
  final int sizeBytes;
}

class ProgressPhotoValidationFailure implements Exception {
  const ProgressPhotoValidationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ProgressPhotosRepository {
  Future<ProgressPhotoUploadAuthorization> createUploadAuthorization(
    CreateProgressPhotoUploadRequest request,
  );
  Future<void> uploadFile({
    required ProgressPhotoUploadAuthorization authorization,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  });
  Future<ProgressPhoto> confirmUpload(String photoId);
  Future<ProgressPhoto> retryConfirm(String photoId);
  Future<List<ProgressPhoto>> listPhotos();
  Future<ProgressPhotoAccessAuthorization> requestPhotoAccess(String photoId);
  Future<String> getPhotoAccessUrl(String photoId);
  void invalidatePhotoAccess(String photoId);
  void clearAccessCache();
  Future<ProgressPhoto> uploadProgressPhoto({
    required CreateProgressPhotoUploadRequest request,
    required Uint8List bytes,
    void Function(int sent, int total)? onUploadProgress,
  });
  SelectedProgressPhotoFile? validateSelectedFile({
    required String path,
    String? reportedMimeType,
  });
}

class ProgressPhotosRepositoryImpl implements ProgressPhotosRepository {
  ProgressPhotosRepositoryImpl({
    required ProgressPhotosApi api,
    required ProgressPhotoUploadClient uploadClient,
    ProgressPhotoAccessCache? accessCache,
  })  : _api = api,
        _uploadClient = uploadClient,
        _accessCache = accessCache ?? ProgressPhotoAccessCache();

  final ProgressPhotosApi _api;
  final ProgressPhotoUploadClient _uploadClient;
  final ProgressPhotoAccessCache _accessCache;

  @override
  Future<ProgressPhotoUploadAuthorization> createUploadAuthorization(
    CreateProgressPhotoUploadRequest request,
  ) {
    return _api.createUploadRequest(request);
  }

  @override
  Future<void> uploadFile({
    required ProgressPhotoUploadAuthorization authorization,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) {
    return _uploadClient.uploadFile(
      uploadUrl: authorization.uploadUrl,
      requiredHeaders: authorization.requiredHeaders,
      bytes: bytes,
      onProgress: onProgress,
    );
  }

  @override
  Future<ProgressPhoto> confirmUpload(String photoId) {
    return _api.confirmUpload(photoId);
  }

  @override
  Future<ProgressPhoto> retryConfirm(String photoId) {
    return _api.confirmUpload(photoId);
  }

  @override
  Future<List<ProgressPhoto>> listPhotos() {
    return _api.listPhotos();
  }

  @override
  Future<ProgressPhotoAccessAuthorization> requestPhotoAccess(
    String photoId,
  ) async {
    final authorization = await _api.requestAccess(photoId);
    _accessCache.put(authorization);
    return authorization;
  }

  @override
  Future<String> getPhotoAccessUrl(String photoId) async {
    final cached = _accessCache.get(photoId);
    if (cached != null) {
      return cached.accessUrl;
    }
    final authorization = await requestPhotoAccess(photoId);
    return authorization.accessUrl;
  }

  @override
  void invalidatePhotoAccess(String photoId) {
    _accessCache.invalidate(photoId);
  }

  @override
  void clearAccessCache() {
    _accessCache.clear();
  }

  @override
  Future<ProgressPhoto> uploadProgressPhoto({
    required CreateProgressPhotoUploadRequest request,
    required Uint8List bytes,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
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
    final file = File(path);
    if (!file.existsSync()) {
      throw const ProgressPhotoValidationFailure(
          'Selected file is unavailable.');
    }

    final bytes = file.readAsBytesSync();
    final sizeBytes = bytes.length;
    if (sizeBytes <= 0) {
      throw const ProgressPhotoValidationFailure('Selected file is empty.');
    }
    if (sizeBytes > ProgressPhotoConstraints.maxBytes) {
      throw const ProgressPhotoValidationFailure(
        'File exceeds maximum size of 5 MiB.',
      );
    }

    final contentType = _resolveContentType(path, reportedMimeType, bytes);
    if (!ProgressPhotoConstraints.allowedContentTypes.contains(contentType)) {
      throw const ProgressPhotoValidationFailure(
        'Unsupported image format. Use JPEG, PNG, or WebP.',
      );
    }

    return SelectedProgressPhotoFile(
      path: path,
      bytes: bytes,
      contentType: contentType,
      sizeBytes: sizeBytes,
    );
  }

  String _resolveContentType(
    String path,
    String? reportedMimeType,
    Uint8List bytes,
  ) {
    final normalizedReported = reportedMimeType?.trim().toLowerCase();
    if (normalizedReported != null &&
        ProgressPhotoConstraints.allowedContentTypes
            .contains(normalizedReported)) {
      return normalizedReported;
    }

    final fromMagic = _detectFromMagicBytes(bytes);
    if (fromMagic != null) {
      return fromMagic;
    }

    final fromPath = lookupMimeType(path)?.toLowerCase();
    if (fromPath != null &&
        ProgressPhotoConstraints.allowedContentTypes.contains(fromPath)) {
      return fromPath;
    }

    throw const ProgressPhotoValidationFailure(
      'Could not determine a supported image format.',
    );
  }

  String? _detectFromMagicBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }
}
