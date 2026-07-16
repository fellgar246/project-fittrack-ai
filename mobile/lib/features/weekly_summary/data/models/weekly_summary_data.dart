import 'weekly_recommendation.dart';
import 'weekly_summary.dart';

class WeeklySummaryData {
  const WeeklySummaryData({
    required this.summary,
    this.latestRecommendation,
    this.recommendationError,
  });

  final WeeklySummary summary;
  final WeeklyRecommendation? latestRecommendation;
  final String? recommendationError;

  WeeklySummaryData copyWith({
    WeeklySummary? summary,
    WeeklyRecommendation? latestRecommendation,
    String? recommendationError,
    bool clearRecommendation = false,
    bool clearRecommendationError = false,
  }) {
    return WeeklySummaryData(
      summary: summary ?? this.summary,
      latestRecommendation: clearRecommendation
          ? null
          : latestRecommendation ?? this.latestRecommendation,
      recommendationError: clearRecommendationError
          ? null
          : recommendationError ?? this.recommendationError,
    );
  }
}
