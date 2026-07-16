import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../measurements/data/models/json_parsing.dart';
import 'models/generate_recommendation_request.dart';
import 'models/weekly_recommendation.dart';
import 'models/weekly_summary.dart';

/// Receive timeout for Azure OpenAI-backed recommendation generation.
///
/// Backend provider timeout is 20s; cloud validation observed ~24s end-to-end.
/// 60s leaves margin for network variance without changing global Dio timeouts.
const recommendationGenerationReceiveTimeout = Duration(seconds: 60);

class WeeklySummaryApi {
  WeeklySummaryApi(this._client);

  final ApiClient _client;

  Future<WeeklySummary> getWeeklySummary(DateTime weekStart) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.weeklySummary,
      queryParameters: {'week_start': dateOnly(weekStart)},
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty weekly summary response.');
    }
    return WeeklySummary.fromJson(data);
  }

  Future<WeeklyRecommendation> generateRecommendation(
    GenerateRecommendationRequest request,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.weeklyRecommendation,
      data: request.toJson(),
      options: Options(
        receiveTimeout: recommendationGenerationReceiveTimeout,
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty recommendation response.');
    }
    return WeeklyRecommendation.fromJson(data);
  }

  Future<WeeklyRecommendation?> getLatestRecommendation() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.latestRecommendation,
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException('Empty latest recommendation response.');
      }
      return WeeklyRecommendation.fromJson(data);
    } on NotFoundException {
      return null;
    }
  }
}
