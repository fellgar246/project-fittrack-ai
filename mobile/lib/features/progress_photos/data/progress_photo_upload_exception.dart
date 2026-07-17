import '../../../core/network/redact_signed_url.dart';

/// Errors from direct blob upload (not backend JWT auth).
class ProgressPhotoUploadException implements Exception {
  const ProgressPhotoUploadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

ProgressPhotoUploadException mapBlobUploadError({
  required int? statusCode,
  required String? dioMessage,
}) {
  switch (statusCode) {
    case 403:
      return const ProgressPhotoUploadException(
        'Upload authorization expired or invalid.',
        statusCode: 403,
      );
    case 404:
      return const ProgressPhotoUploadException(
        'Upload destination unavailable.',
        statusCode: 404,
      );
    case 409:
      return const ProgressPhotoUploadException(
        'Blob state conflict.',
        statusCode: 409,
      );
    default:
      if (statusCode != null && statusCode >= 500) {
        return ProgressPhotoUploadException(
          'Storage temporarily unavailable.',
          statusCode: statusCode,
        );
      }
      if (statusCode != null && statusCode >= 400) {
        return ProgressPhotoUploadException(
          'Upload rejected.',
          statusCode: statusCode,
        );
      }
      return ProgressPhotoUploadException(
        dioMessage ?? 'Upload failed. Try again.',
        statusCode: statusCode,
      );
  }
}

ProgressPhotoUploadException mapBlobTimeout() {
  return const ProgressPhotoUploadException('Upload timed out.');
}

ProgressPhotoUploadException mapBlobConnection() {
  return const ProgressPhotoUploadException(
    'Could not connect to storage.',
  );
}

/// Safe message for logging blob failures without exposing SAS tokens.
String safeBlobErrorMessage(Object error, {String? uploadUrl}) {
  if (error is ProgressPhotoUploadException) {
    return error.message;
  }
  if (uploadUrl != null) {
    return 'Blob upload failed for ${redactSignedUrl(uploadUrl)}';
  }
  return 'Blob upload failed.';
}
