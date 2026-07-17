import 'package:fittrack_ai/features/progress_photos/data/models/create_progress_photo_upload_request.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_access_authorization.dart';
import 'package:fittrack_ai/features/progress_photos/data/models/progress_photo_upload_authorization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upload request serializes date notes and omits null notes', () {
    final withNotes = CreateProgressPhotoUploadRequest(
      capturedAt: DateTime(2026, 7, 15),
      contentType: 'image/jpeg',
      sizeBytes: 123456,
      notes: 'After workout',
    ).toJson();

    expect(withNotes['captured_at'], '2026-07-15');
    expect(withNotes['content_type'], 'image/jpeg');
    expect(withNotes['size_bytes'], 123456);
    expect(withNotes['notes'], 'After workout');

    final withoutNotes = CreateProgressPhotoUploadRequest(
      capturedAt: DateTime(2026, 7, 15),
      contentType: 'image/png',
      sizeBytes: 100,
    ).toJson();
    expect(withoutNotes.containsKey('notes'), isFalse);
  });

  test('upload authorization parses required headers and expiry', () {
    final authorization = ProgressPhotoUploadAuthorization.fromJson({
      'photo_id': '11111111-1111-1111-1111-111111111111',
      'upload_url': 'https://storage.example.test/container/blob?<fake-sas>',
      'expires_at': '2026-07-15T12:00:00Z',
      'required_headers': {
        'Content-Type': 'image/jpeg',
        'x-ms-blob-type': 'BlockBlob',
        'Cache-Control': 'no-store',
      },
    });

    expect(authorization.photoId, isNotEmpty);
    expect(authorization.requiredHeaders['x-ms-blob-type'], 'BlockBlob');
    expect(authorization.expiresAt.toUtc(), isNotNull);
  });

  test('progress photo parses optional confirmed_at', () {
    final photo = ProgressPhoto.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'captured_at': '2026-07-15',
      'content_type': 'image/jpeg',
      'size_bytes': 123456,
      'notes': null,
      'status': 'active',
      'created_at': '2026-07-15T10:00:00Z',
      'confirmed_at': '2026-07-15T10:05:00Z',
    });

    expect(photo.status, 'active');
    expect(photo.confirmedAt, isNotNull);
  });

  test('access authorization parses access url', () {
    final access = ProgressPhotoAccessAuthorization.fromJson({
      'photo_id': '11111111-1111-1111-1111-111111111111',
      'access_url': 'https://storage.example.test/container/blob?<fake-sas>',
      'expires_at': '2026-07-15T12:05:00Z',
    });

    expect(access.accessUrl, contains('storage.example.test'));
  });

  test('invalid payload throws instead of defaulting', () {
    expect(
      () => ProgressPhoto.fromJson({'id': '', 'captured_at': 'bad'}),
      throwsFormatException,
    );
  });
}
