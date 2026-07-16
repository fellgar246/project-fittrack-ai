import '../../../core/errors/api_exception.dart';
import 'models/generate_recommendation_request.dart';
import 'models/weekly_recommendation.dart';
import 'models/weekly_summary.dart';
import 'models/weekly_summary_data.dart';
import 'weekly_summary_api.dart';

abstract interface class WeeklySummaryRepository {
  DateTime get currentWeekStart;

  Future<WeeklySummaryData> loadWeek(DateTime weekStart);

  Future<WeeklyRecommendation> generateRecommendation(DateTime weekStart);

  Future<WeeklyRecommendation?> loadLatestRecommendation();
}

class WeeklySummaryRepositoryImpl implements WeeklySummaryRepository {
  WeeklySummaryRepositoryImpl({
    required WeeklySummaryApi api,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final WeeklySummaryApi _api;
  final DateTime Function() _now;

  @override
  DateTime get currentWeekStart => _startOfWeek(_now());

  @override
  Future<WeeklySummaryData> loadWeek(DateTime weekStart) async {
    final results = await Future.wait<_Outcome<Object?>>([
      _capture<WeeklySummary>(_api.getWeeklySummary(weekStart)),
      _capture<WeeklyRecommendation?>(_api.getLatestRecommendation()),
    ]);

    for (final result in results) {
      if (result.error is UnauthorizedException) {
        throw result.error!;
      }
    }

    final summaryResult = results[0];
    if (summaryResult.error != null) {
      throw summaryResult.error!;
    }

    final recommendationResult = results[1];
    return WeeklySummaryData(
      summary: summaryResult.value! as WeeklySummary,
      latestRecommendation: recommendationResult.value as WeeklyRecommendation?,
      recommendationError: recommendationResult.error == null
          ? null
          : _messageFor(recommendationResult.error!),
    );
  }

  @override
  Future<WeeklyRecommendation> generateRecommendation(
    DateTime weekStart,
  ) async {
    return _api.generateRecommendation(
      GenerateRecommendationRequest(weekStart: weekStart),
    );
  }

  @override
  Future<WeeklyRecommendation?> loadLatestRecommendation() {
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
  return 'The recommendation could not be loaded. Try again.';
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final Object? error;
}
