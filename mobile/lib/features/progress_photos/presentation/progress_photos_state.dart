import '../data/models/progress_photo.dart';

enum ProgressPhotosStatus {
  initial,
  loading,
  loaded,
  failure,
}

class ProgressPhotosState {
  const ProgressPhotosState({
    this.status = ProgressPhotosStatus.initial,
    this.photos = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.accessErrors = const {},
    this.accessUrls = const {},
    this.loadingAccess = const {},
  });

  final ProgressPhotosStatus status;
  final List<ProgressPhoto> photos;
  final String? errorMessage;
  final bool isRefreshing;
  final Map<String, String> accessErrors;
  final Map<String, String> accessUrls;
  final Set<String> loadingAccess;

  bool get isEmpty => photos.isEmpty;

  ProgressPhotosState copyWith({
    ProgressPhotosStatus? status,
    List<ProgressPhoto>? photos,
    String? errorMessage,
    bool? isRefreshing,
    Map<String, String>? accessErrors,
    Map<String, String>? accessUrls,
    Set<String>? loadingAccess,
    bool clearError = false,
    bool clearAccess = false,
  }) {
    return ProgressPhotosState(
      status: status ?? this.status,
      photos: photos ?? this.photos,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      accessErrors: clearAccess ? const {} : accessErrors ?? this.accessErrors,
      accessUrls: clearAccess ? const {} : accessUrls ?? this.accessUrls,
      loadingAccess:
          clearAccess ? const {} : loadingAccess ?? this.loadingAccess,
    );
  }
}
