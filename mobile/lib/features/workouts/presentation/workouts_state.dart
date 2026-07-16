import '../data/models/workouts_data.dart';

enum WorkoutsStatus {
  initial,
  loading,
  loaded,
  failure,
}

class WorkoutsState {
  const WorkoutsState({
    this.status = WorkoutsStatus.initial,
    this.data,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final WorkoutsStatus status;
  final WorkoutsData? data;
  final String? errorMessage;
  final bool isRefreshing;

  WorkoutsState copyWith({
    WorkoutsStatus? status,
    WorkoutsData? data,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return WorkoutsState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
