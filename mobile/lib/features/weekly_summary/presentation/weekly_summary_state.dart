import '../data/models/weekly_recommendation.dart';
import '../data/models/weekly_summary_data.dart';

enum WeeklySummaryStatus {
  initial,
  loading,
  loaded,
  failure,
}

class WeeklySummaryState {
  const WeeklySummaryState({
    this.status = WeeklySummaryStatus.initial,
    this.weekStart,
    this.data,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final WeeklySummaryStatus status;
  final DateTime? weekStart;
  final WeeklySummaryData? data;
  final String? errorMessage;
  final bool isRefreshing;

  WeeklySummaryState copyWith({
    WeeklySummaryStatus? status,
    DateTime? weekStart,
    WeeklySummaryData? data,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return WeeklySummaryState(
      status: status ?? this.status,
      weekStart: weekStart ?? this.weekStart,
      data: data ?? this.data,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

enum RecommendationGenerationStatus {
  idle,
  submitting,
  success,
  failure,
  uncertain,
}

class RecommendationGenerationState {
  const RecommendationGenerationState({
    this.status = RecommendationGenerationStatus.idle,
    this.result,
    this.errorMessage,
  });

  final RecommendationGenerationStatus status;
  final WeeklyRecommendation? result;
  final String? errorMessage;

  bool get isSubmitting => status == RecommendationGenerationStatus.submitting;

  RecommendationGenerationState copyWith({
    RecommendationGenerationStatus? status,
    WeeklyRecommendation? result,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return RecommendationGenerationState(
      status: status ?? this.status,
      result: clearResult ? null : result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
