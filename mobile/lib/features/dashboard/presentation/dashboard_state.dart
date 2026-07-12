import '../data/models/dashboard_data.dart';

enum DashboardStatus {
  initial,
  loading,
  loaded,
  failure,
}

class DashboardState {
  const DashboardState({
    this.status = DashboardStatus.initial,
    this.data,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final DashboardStatus status;
  final DashboardData? data;
  final String? errorMessage;
  final bool isRefreshing;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardData? data,
    String? errorMessage,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return DashboardState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
