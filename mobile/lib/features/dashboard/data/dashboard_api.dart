import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/measurement_progress.dart';
import 'models/recommendation_summary.dart';
import 'models/weekly_summary.dart';

class DashboardApi {
  DashboardApi(this._client);

  final ApiClient _client;

  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.weeklySummary,
      queryParameters: {'week_start': _dateOnly(weekStart)},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty weekly summary response.');
    }
    return WeeklySummary.fromJson(data);
  }

  Future<MeasurementProgress> getMeasurementProgress() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.measurementProgress,
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty measurement progress response.');
    }
    return MeasurementProgress.fromJson(data);
  }

  Future<RecommendationSummary?> getLatestRecommendation() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.latestRecommendation,
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty latest recommendation response.');
      }
      return RecommendationSummary.fromJson(data);
    } on NotFoundException {
      return null;
    }
  }
}

String _dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
