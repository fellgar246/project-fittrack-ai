import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/create_workout_log_request.dart';
import 'models/json_parsing.dart';
import 'models/workout_log.dart';
import 'models/workout_plan.dart';
import 'models/workout_plan_detail.dart';

class WorkoutsApi {
  WorkoutsApi(this._client);

  final ApiClient _client;

  Future<List<WorkoutPlan>> getWorkoutPlans() async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.workoutPlans,
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty workout plans list response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid workout plan item in list.');
      }
      return WorkoutPlan.fromJson(item);
    }).toList(growable: false);
  }

  Future<WorkoutPlanDetail> getWorkoutPlan(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.workoutPlanById(id),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty workout plan detail response.');
    }
    return WorkoutPlanDetail.fromJson(data);
  }

  Future<List<WorkoutLog>> getWorkoutLogs({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final response = await _client.get<List<dynamic>>(
      ApiEndpoints.workoutLogs,
      queryParameters: _dateRangeQuery(dateFrom, dateTo),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty workout logs list response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid workout log item in list.');
      }
      return WorkoutLog.fromJson(item);
    }).toList(growable: false);
  }

  Future<WorkoutLog> createWorkoutLog(CreateWorkoutLogRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.workoutLogs,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Empty create workout log response.');
    }
    return WorkoutLog.fromJson(data);
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
