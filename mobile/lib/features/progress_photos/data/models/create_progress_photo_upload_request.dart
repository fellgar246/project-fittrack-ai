import 'json_parsing.dart';

class CreateProgressPhotoUploadRequest {
  const CreateProgressPhotoUploadRequest({
    required this.capturedAt,
    required this.contentType,
    required this.sizeBytes,
    this.notes,
  });

  final DateTime capturedAt;
  final String contentType;
  final int sizeBytes;
  final String? notes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'captured_at': dateOnly(capturedAt),
      'content_type': contentType,
      'size_bytes': sizeBytes,
    };
    if (notes != null) {
      json['notes'] = notes;
    }
    return json;
  }
}
