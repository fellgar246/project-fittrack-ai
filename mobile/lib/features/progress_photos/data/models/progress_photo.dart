import 'json_parsing.dart';

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.capturedAt,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
    required this.createdAt,
    this.notes,
    this.confirmedAt,
  });

  final String id;
  final DateTime capturedAt;
  final String contentType;
  final int sizeBytes;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: requiredString(json, 'id'),
      capturedAt: requiredDate(json, 'captured_at'),
      contentType: requiredString(json, 'content_type'),
      sizeBytes: requiredInt(json, 'size_bytes'),
      notes: optionalString(json, 'notes'),
      status: requiredString(json, 'status'),
      createdAt: requiredDateTime(json, 'created_at'),
      confirmedAt: optionalDateTime(json, 'confirmed_at'),
    );
  }
}
