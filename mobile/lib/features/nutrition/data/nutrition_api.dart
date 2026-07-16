import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/create_nutrition_log_request.dart';
import 'models/json_parsing.dart';
import 'models/nutrition_log.dart';
import 'models/nutrition_summary.dart';

class NutritionApi {
  NutritionApi(this._client);

  final ApiClient _client;

  Future<List<NutritionLog>> getNutritionLogs({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.nutritionLogs,
      queryParameters: _dateRangeQuery(dateFrom, dateTo),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty nutrition logs list response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid nutrition log item in list.');
      }
      return NutritionLog.fromJson(item);
    }).toList(growable: false);
  }

  Future<NutritionLog> createNutritionLog(
    CreateNutritionLogRequest request,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.nutritionLogs,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty create nutrition log response.');
    }
    return NutritionLog.fromJson(data);
  }

  Future<NutritionSummary> getNutritionSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.nutritionSummary,
      queryParameters: _dateRangeQuery(dateFrom, dateTo),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty nutrition summary response.');
    }
    return NutritionSummary.fromJson(data);
  }
}

Map<String, String>? _dateRangeQuery(DateTime? dateFrom, DateTime? dateTo) {
  if (dateFrom == null && dateTo == null) {
    return null;
  }

  return {
    if (dateFrom != null) 'date_from': dateOnly(dateFrom),
    if (dateTo != null) 'date_to': dateOnly(dateTo),
  };
}
