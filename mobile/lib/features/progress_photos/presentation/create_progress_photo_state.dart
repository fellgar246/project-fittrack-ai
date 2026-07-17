import '../data/progress_photos_repository.dart';

enum CreateProgressPhotoStatus {
  idle,
  selecting,
  ready,
  requestingAuthorization,
  uploading,
  confirming,
  success,
  failure,
  awaitingConfirmRetry,
}

class CreateProgressPhotoState {
  const CreateProgressPhotoState({
    this.status = CreateProgressPhotoStatus.idle,
    this.previewPath,
    this.contentType,
    this.sizeBytes,
    this.capturedAt,
    this.notes,
    this.uploadProgress,
    this.photoId,
    this.errorMessage,
    this.selectedFile,
  });

  final CreateProgressPhotoStatus status;
  final String? previewPath;
  final String? contentType;
  final int? sizeBytes;
  final DateTime? capturedAt;
  final String? notes;
  final double? uploadProgress;
  final String? photoId;
  final String? errorMessage;
  final SelectedProgressPhotoFile? selectedFile;

  bool get canSubmit =>
      status == CreateProgressPhotoStatus.ready && selectedFile != null;

  bool get canRetryConfirm =>
      status == CreateProgressPhotoStatus.awaitingConfirmRetry &&
      photoId != null;

  bool get isBusy =>
      status == CreateProgressPhotoStatus.requestingAuthorization ||
      status == CreateProgressPhotoStatus.uploading ||
      status == CreateProgressPhotoStatus.confirming;

  CreateProgressPhotoState copyWith({
    CreateProgressPhotoStatus? status,
    String? previewPath,
    String? contentType,
    int? sizeBytes,
    DateTime? capturedAt,
    String? notes,
    double? uploadProgress,
    String? photoId,
    String? errorMessage,
    SelectedProgressPhotoFile? selectedFile,
    bool clearPreview = false,
    bool clearError = false,
    bool clearSelectedFile = false,
    bool clearPhotoId = false,
  }) {
    return CreateProgressPhotoState(
      status: status ?? this.status,
      previewPath: clearPreview ? null : previewPath ?? this.previewPath,
      contentType: clearPreview ? null : contentType ?? this.contentType,
      sizeBytes: clearPreview ? null : sizeBytes ?? this.sizeBytes,
      capturedAt: capturedAt ?? this.capturedAt,
      notes: notes ?? this.notes,
      uploadProgress: uploadProgress,
      photoId: clearPhotoId ? null : photoId ?? this.photoId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      selectedFile:
          clearSelectedFile ? null : selectedFile ?? this.selectedFile,
    );
  }
}
