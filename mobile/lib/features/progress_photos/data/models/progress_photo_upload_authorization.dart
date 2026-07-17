import 'json_parsing.dart';

class ProgressPhotoUploadAuthorization {
  const ProgressPhotoUploadAuthorization({
    required this.photoId,
    required this.uploadUrl,
    required this.expiresAt,
    required this.requiredHeaders,
  });

  final String photoId;
  final String uploadUrl;
  final DateTime expiresAt;
  final Map<String, String> requiredHeaders;

  factory ProgressPhotoUploadAuthorization.fromJson(Map<String, dynamic> json) {
    return ProgressPhotoUploadAuthorization(
      photoId: requiredString(json, 'photo_id'),
      uploadUrl: requiredString(json, 'upload_url'),
      expiresAt: requiredDateTime(json, 'expires_at'),
      requiredHeaders: requiredStringMap(json, 'required_headers'),
    );
  }
}
