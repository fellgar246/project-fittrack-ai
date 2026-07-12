import '../../../core/errors/api_exception.dart';
import 'dashboard_api.dart';
import 'models/dashboard_data.dart';
import 'models/measurement_progress.dart';
import 'models/recommendation_summary.dart';
import 'models/weekly_summary.dart';

abstract interface class DashboardRepository {
  Future<DashboardData> loadDashboard();
  Future<MeasurementProgress> loadMeasurement();
  Future<RecommendationSummary?> loadRecommendation();
}

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required DashboardApi api,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final DashboardApi _api;
  final DateTime Function() _now;

  @override
  Future<DashboardData> loadDashboard() async {
    final weekStart = _startOfWeek(_now());

    final results = await Future.wait<_Outcome<Object?>>([
      _capture<WeeklySummary>(_api.getWeeklySummary(weekStart)),
      _capture<MeasurementProgress>(_api.getMeasurementProgress()),
      _capture<RecommendationSummary?>(_api.getLatestRecommendation()),
    ]);

    for (final result in results) {
      if (result.error is UnauthorizedException) {
        throw result.error!;
      }
    }

    final weekly = results[0];
    if (weekly.error != null) {
      throw weekly.error!;
    }

    final measurement = results[1];
    final recommendation = results[2];
    return DashboardData(
      weeklySummary: weekly.value! as WeeklySummary,
      measurement: measurement.value as MeasurementProgress?,
      recommendation: recommendation.value as RecommendationSummary?,
      measurementError:
          measurement.error == null ? null : _messageFor(measurement.error!),
      recommendationError: recommendation.error == null
          ? null
          : _messageFor(recommendation.error!),
    );
  }

  @override
  Future<MeasurementProgress> loadMeasurement() {
    return _api.getMeasurementProgress();
  }

  @override
  Future<RecommendationSummary?> loadRecommendation() {
    return _api.getLatestRecommendation();
  }
}

DateTime _startOfWeek(DateTime value) {
  final localDate = DateTime(value.year, value.month, value.day);
  return localDate
      .subtract(Duration(days: localDate.weekday - DateTime.monday));
}

Future<_Outcome<T>> _capture<T>(Future<T> request) async {
  try {
    return _Outcome<T>(value: await request);
  } catch (error) {
    return _Outcome<T>(error: error);
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'This section could not be loaded. Try again.';
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final Object? error;
}
