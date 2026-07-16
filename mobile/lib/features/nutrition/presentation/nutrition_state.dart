import '../data/models/nutrition_data.dart';

enum NutritionStatus {
  initial,
  loading,
  loaded,
  failure,
}

class NutritionState {
  const NutritionState({
    this.status = NutritionStatus.initial,
    this.data,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final NutritionStatus status;
  final NutritionData? data;
  final String? errorMessage;
  final bool isRefreshing;

  NutritionState copyWith({
    NutritionStatus? status,
    NutritionData? data,
    String? errorMessage,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return NutritionState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
