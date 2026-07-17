import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/create_progress_photo_upload_request.dart';
import '../data/models/progress_photo_constraints.dart';
import '../data/models/progress_photo_upload_authorization.dart';
import '../data/progress_photo_upload_exception.dart';
import '../data/progress_photos_providers.dart';
import '../data/progress_photos_repository.dart';
import 'create_progress_photo_state.dart';

class CreateProgressPhotoController
    extends StateNotifier<CreateProgressPhotoState> {
  CreateProgressPhotoController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const CreateProgressPhotoState());

  final ProgressPhotosRepository _repository;
  final Future<void> Function() _onUnauthorized;
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setSelecting() {
    if (state.isBusy) {
      return;
    }
    state = state.copyWith(
      status: CreateProgressPhotoStatus.selecting,
      clearError: true,
    );
  }

  void setSelectedFile(SelectedProgressPhotoFile file, {DateTime? capturedAt}) {
    if (_disposed) {
      return;
    }
    final now = DateTime.now();
    state = CreateProgressPhotoState(
      status: CreateProgressPhotoStatus.ready,
      previewPath: file.path,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
      capturedAt: capturedAt ?? DateTime(now.year, now.month, now.day),
      notes: state.notes,
      selectedFile: file,
    );
  }

  void clearSelection() {
    if (state.isBusy) {
      return;
    }
    state = const CreateProgressPhotoState();
  }

  void setCapturedDate(DateTime date) {
    state = state.copyWith(capturedAt: date);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  SelectedProgressPhotoFile validatePickedFile({
    required String path,
    String? reportedMimeType,
  }) {
    return _repository.validateSelectedFile(
      path: path,
      reportedMimeType: reportedMimeType,
    )!;
  }

  Future<bool> submit() async {
    if (!state.canSubmit || state.isBusy) {
      return false;
    }

    final file = state.selectedFile!;
    final capturedAt = state.capturedAt;
    if (capturedAt == null) {
      state = state.copyWith(
        status: CreateProgressPhotoStatus.failure,
        errorMessage: 'Captured date is required.',
      );
      return false;
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (capturedAt.isAfter(todayDate)) {
      state = state.copyWith(
        status: CreateProgressPhotoStatus.failure,
        errorMessage: 'Captured date cannot be in the future.',
      );
      return false;
    }

    final trimmedNotes = state.notes?.trim();
    if (trimmedNotes != null &&
        trimmedNotes.length > ProgressPhotoConstraints.maxNotesLength) {
      state = state.copyWith(
        status: CreateProgressPhotoStatus.failure,
        errorMessage:
            'Notes must be ${ProgressPhotoConstraints.maxNotesLength} characters or fewer.',
      );
      return false;
    }

    final request = CreateProgressPhotoUploadRequest(
      capturedAt: capturedAt,
      contentType: file.contentType,
      sizeBytes: file.sizeBytes,
      notes: trimmedNotes == null || trimmedNotes.isEmpty ? null : trimmedNotes,
    );

    state = state.copyWith(
      status: CreateProgressPhotoStatus.requestingAuthorization,
      clearError: true,
      uploadProgress: null,
      clearPhotoId: true,
    );

    ProgressPhotoUploadAuthorization? authorization;
    var uploadCompleted = false;
    try {
      authorization = await _repository.createUploadAuthorization(request);
      if (_disposed) {
        return false;
      }
      state = state.copyWith(
        status: CreateProgressPhotoStatus.uploading,
        photoId: authorization.photoId,
      );

      await _repository.uploadFile(
        authorization: authorization,
        bytes: file.bytes,
        onProgress: (sent, total) {
          if (_disposed || total <= 0) {
            return;
          }
          state = state.copyWith(uploadProgress: sent / total);
        },
      );
      uploadCompleted = true;
      if (_disposed) {
        return false;
      }

      state = state.copyWith(
        status: CreateProgressPhotoStatus.confirming,
        uploadProgress: 1,
      );
      await _repository.confirmUpload(authorization.photoId);
      if (_disposed) {
        return false;
      }
      state = state.copyWith(status: CreateProgressPhotoStatus.success);
      return true;
    } on ProgressPhotoUploadException catch (error) {
      if (_disposed) {
        return false;
      }
      if (error.statusCode == 403) {
        state = state.copyWith(
          status: CreateProgressPhotoStatus.failure,
          errorMessage:
              'Upload authorization expired. Select the image and try again.',
        );
        return false;
      }
      state = state.copyWith(
        status: CreateProgressPhotoStatus.failure,
        errorMessage: error.message,
      );
      return false;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      if (await _handleUnauthorized(error)) {
        return false;
      }

      if (uploadCompleted && authorization != null) {
        state = state.copyWith(
          status: CreateProgressPhotoStatus.awaitingConfirmRetry,
          photoId: authorization.photoId,
          errorMessage: _messageFor(error),
        );
        return false;
      }

      state = state.copyWith(
        status: CreateProgressPhotoStatus.failure,
        errorMessage: _messageFor(error),
      );
      return false;
    }
  }

  Future<bool> retryConfirm() async {
    final photoId = state.photoId;
    if (photoId == null || state.isBusy) {
      return false;
    }

    state = state.copyWith(
      status: CreateProgressPhotoStatus.confirming,
      clearError: true,
    );

    try {
      await _repository.retryConfirm(photoId);
      if (_disposed) {
        return false;
      }
      state = state.copyWith(status: CreateProgressPhotoStatus.success);
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      if (await _handleUnauthorized(error)) {
        return false;
      }
      state = state.copyWith(
        status: CreateProgressPhotoStatus.awaitingConfirmRetry,
        errorMessage: _messageFor(error),
      );
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> _handleUnauthorized(Object error) async {
    if (error is UnauthorizedException) {
      await _onUnauthorized();
      return true;
    }
    return false;
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  if (error is ProgressPhotoValidationFailure) {
    return error.message;
  }
  if (error is ProgressPhotoUploadException) {
    return error.message;
  }
  return 'Progress photo could not be uploaded. Try again.';
}

final createProgressPhotoControllerProvider = StateNotifierProvider.autoDispose<
    CreateProgressPhotoController, CreateProgressPhotoState>((ref) {
  return CreateProgressPhotoController(
    ref.watch(progressPhotosRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});
