import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_client.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upload uses PUT with required headers and no bearer token', () async {
    final adapter = _RecordingAdapter(statusCode: 201);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ProgressPhotoUploadClient(dio: dio);
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);

    await client.uploadFile(
      uploadUrl: 'https://storage.example.test/container/blob?<fake-sas>',
      requiredHeaders: const {
        'Content-Type': 'image/jpeg',
        'x-ms-blob-type': 'BlockBlob',
        'Cache-Control': 'no-store',
      },
      bytes: bytes,
      onProgress: (sent, total) {
        expect(sent, lessThanOrEqualTo(total));
      },
    );

    expect(adapter.lastRequest?.method, 'PUT');
    expect(adapter.lastRequest?.uri.host, 'storage.example.test');
    expect(adapter.lastRequest?.uri.path, '/container/blob');
    expect(adapter.lastRequest?.headers['Authorization'], isNull);
    expect(adapter.lastRequest?.headers['x-ms-blob-type'], 'BlockBlob');
    expect(adapter.lastRequest?.headers['Content-Type'], 'image/jpeg');
  });

  test('403 maps to upload authorization expired message', () async {
    final adapter = _RecordingAdapter(statusCode: 403);
    final client =
        ProgressPhotoUploadClient(dio: Dio()..httpClientAdapter = adapter);

    expect(
      client.uploadFile(
        uploadUrl: 'https://storage.example.test/container/blob?<fake-sas>',
        requiredHeaders: const {'Content-Type': 'image/jpeg'},
        bytes: Uint8List(1),
      ),
      throwsA(
        isA<ProgressPhotoUploadException>().having(
          (error) => error.message,
          'message',
          contains('expired'),
        ),
      ),
    );
  });

  test('exception message does not include sas token', () async {
    final adapter = _RecordingAdapter(statusCode: 403);
    final client =
        ProgressPhotoUploadClient(dio: Dio()..httpClientAdapter = adapter);

    try {
      await client.uploadFile(
        uploadUrl:
            'https://storage.example.test/container/blob?sig=super-secret',
        requiredHeaders: const {'Content-Type': 'image/jpeg'},
        bytes: Uint8List(1),
      );
      fail('Expected ProgressPhotoUploadException');
    } on ProgressPhotoUploadException catch (error) {
      expect(error.message.contains('sig='), isFalse);
      expect(error.message.contains('super-secret'), isFalse);
    }
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode});

  final int statusCode;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString('', statusCode);
  }
}
