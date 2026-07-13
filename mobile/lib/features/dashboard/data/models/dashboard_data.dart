import '../../../measurements/data/models/measurement_progress.dart';
import 'recommendation_summary.dart';
import 'weekly_summary.dart';

class DashboardData {
  const DashboardData({
    required this.weeklySummary,
    this.measurement,
    this.recommendation,
    this.measurementError,
    this.recommendationError,
  });

  final WeeklySummary weeklySummary;
  final MeasurementProgress? measurement;
  final RecommendationSummary? recommendation;
  final String? measurementError;
  final String? recommendationError;

  bool get isPartial => measurementError != null || recommendationError != null;

  DashboardData copyWith({
    MeasurementProgress? measurement,
    RecommendationSummary? recommendation,
    String? measurementError,
    String? recommendationError,
    bool clearMeasurement = false,
    bool clearRecommendation = false,
    bool clearMeasurementError = false,
    bool clearRecommendationError = false,
  }) {
    return DashboardData(
      weeklySummary: weeklySummary,
      measurement: clearMeasurement ? null : measurement ?? this.measurement,
      recommendation:
          clearRecommendation ? null : recommendation ?? this.recommendation,
      measurementError: clearMeasurementError
          ? null
          : measurementError ?? this.measurementError,
      recommendationError: clearRecommendationError
          ? null
          : recommendationError ?? this.recommendationError,
    );
  }
}
