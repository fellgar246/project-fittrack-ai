import '../data/models/measurements_data.dart';

enum MeasurementsStatus {
  initial,
  loading,
  loaded,
  failure,
}

class MeasurementsState {
  const MeasurementsState({
    this.status = MeasurementsStatus.initial,
    this.data,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final MeasurementsStatus status;
  final MeasurementsData? data;
  final String? errorMessage;
  final bool isRefreshing;

  MeasurementsState copyWith({
    MeasurementsStatus? status,
    MeasurementsData? data,
    String? errorMessage,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return MeasurementsState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
