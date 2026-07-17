import 'json_parsing.dart';

class ProgressPhotoAccessAuthorization {
  const ProgressPhotoAccessAuthorization({
    required this.photoId,
    required this.accessUrl,
    required this.expiresAt,
  });

  final String photoId;
  final String accessUrl;
  final DateTime expiresAt;

  factory ProgressPhotoAccessAuthorization.fromJson(Map<String, dynamic> json) {
    return ProgressPhotoAccessAuthorization(
      photoId: requiredString(json, 'photo_id'),
      accessUrl: requiredString(json, 'access_url'),
      expiresAt: requiredDateTime(json, 'expires_at'),
    );
  }
}
