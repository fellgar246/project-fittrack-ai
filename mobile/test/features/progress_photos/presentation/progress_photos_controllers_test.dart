import 'dart:async';
import 'dart:typed_data';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photo_upload_exception.dart';
import 'package:fittrack_ai/features/progress_photos/data/progress_photos_repository.dart';
import 'package:fittrack_ai/features/progress_photos/presentation/create_progress_photo_controller.dart';
import 'package:fittrack_ai/features/progress_photos/presentation/create_progress_photo_state.dart';
import 'package:fittrack_ai/features/progress_photos/presentation/progress_photos_controller.dart';
import 'package:fittrack_ai/features/progress_photos/presentation/progress_photos_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_progress_photos.dart';

void main() {
  group('ProgressPhotosController', () {
    late FakeProgressPhotosRepository repository;
    late ProgressPhotosController controller;
    late int unauthorizedCalls;

    setUp(() {
      repository = FakeProgressPhotosRepository();
      unauthorizedCalls = 0;
      controller = ProgressPhotosController(
        repository,
        onUnauthorized: () async => unauthorizedCalls++,
      );
    });

    tearDown(() => controller.dispose());

    test('loads photos', () async {
      await controller.load();
      expect(controller.state.status, ProgressPhotosStatus.loaded);
      expect(controller.state.photos, hasLength(1));
    });

    test('refresh preserves photos on failure', () async {
      await controller.load();
      repository.listError = const ServerException();
      await controller.refresh();
      expect(controller.state.photos, hasLength(1));
      expect(controller.state.errorMessage, isNotNull);
    });

    test('partial access failure does not fail gallery', () async {
      await controller.load();
      repository.accessError = const ServerException();
      await controller.ensurePhotoAccess(testProgressPhoto.id);
      expect(controller.state.status, ProgressPhotosStatus.loaded);
      expect(controller.state.accessErrors[testProgressPhoto.id], isNotNull);
    });

    test('401 triggers logout callback', () async {
      repository.listError = const UnauthorizedException();
      await controller.load();
      expect(unauthorizedCalls, 1);
    });
  });

  group('CreateProgressPhotoController', () {
    late FakeProgressPhotosRepository repository;
    late CreateProgressPhotoController controller;

    setUp(() {
      repository = FakeProgressPhotosRepository();
      controller = CreateProgressPhotoController(
        repository,
        onUnauthorized: () async {},
      );
    });

    tearDown(() => controller.dispose());

    test('submit prevents double submit', () async {
      controller.setSelectedFile(
        SelectedProgressPhotoFile(
          path: '/tmp/test.jpg',
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
          contentType: 'image/jpeg',
          sizeBytes: 4,
        ),
      );

      repository.createGate = Completer<void>();
      final first = controller.submit();
      await Future<void>.delayed(Duration.zero);
      final second = await controller.submit();
      expect(second, isFalse);
      repository.createGate!.complete();
      await first;
      expect(repository.uploadCalls, 1);
    });

    test('retry confirm after upload without repeating put', () async {
      controller.setSelectedFile(
        SelectedProgressPhotoFile(
          path: '/tmp/test.jpg',
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
          contentType: 'image/jpeg',
          sizeBytes: 4,
        ),
      );

      repository.confirmError = const ServerException();
      await controller.submit();
      expect(controller.state.status,
          CreateProgressPhotoStatus.awaitingConfirmRetry);

      repository.confirmError = null;
      final success = await controller.retryConfirm();
      expect(success, isTrue);
      expect(repository.uploadCalls, 1);
      expect(repository.confirmCalls, 2);
    });

    test('blob 403 does not trigger unauthorized callback', () async {
      var unauthorized = 0;
      controller = CreateProgressPhotoController(
        repository,
        onUnauthorized: () async => unauthorized++,
      );
      controller.setSelectedFile(
        SelectedProgressPhotoFile(
          path: '/tmp/test.jpg',
          bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]),
          contentType: 'image/jpeg',
          sizeBytes: 4,
        ),
      );
      repository.uploadError = const ProgressPhotoUploadException(
        'Upload authorization expired or invalid.',
        statusCode: 403,
      );

      await controller.submit();
      expect(unauthorized, 0);
      expect(controller.state.errorMessage, contains('expired'));
    });
  });
}
