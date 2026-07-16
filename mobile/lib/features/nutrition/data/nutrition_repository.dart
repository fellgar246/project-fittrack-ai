import '../../../core/errors/api_exception.dart';
import 'models/create_nutrition_log_request.dart';
import 'models/nutrition_data.dart';
import 'models/nutrition_log.dart';
import 'models/nutrition_summary.dart';
import 'nutrition_api.dart';

abstract interface class NutritionRepository {
  Future<NutritionData> loadNutrition();
  Future<NutritionLog> createNutritionLog(CreateNutritionLogRequest request);
  Future<NutritionSummary> loadSummary();
}

class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl({
    required NutritionApi api,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final NutritionApi _api;
  final DateTime Function() _now;

  @override
  Future<NutritionData> loadNutrition() async {
    final listFrom = _rollingListStart(_now());
    final summaryRange = _currentWeekRange(_now());

    final results = await Future.wait<_Outcome<Object?>>([
      _capture<List<NutritionLog>>(
        _api.getNutritionLogs(dateFrom: listFrom),
      ),
      _capture<NutritionSummary>(
        _api.getNutritionSummary(
          dateFrom: summaryRange.start,
          dateTo: summaryRange.end,
        ),
      ),
    ]);

    for (final result in results) {
      if (result.error is UnauthorizedException) {
        throw result.error!;
      }
    }

    final list = results[0];
    if (list.error != null) {
      throw list.error!;
    }

    final summary = results[1];
    return NutritionData(
      logs: list.value! as List<NutritionLog>,
      summary: summary.value as NutritionSummary?,
      summaryError: summary.error == null ? null : _messageFor(summary.error!),
    );
  }

  @override
  Future<NutritionLog> createNutritionLog(
    CreateNutritionLogRequest request,
  ) {
    return _api.createNutritionLog(request);
  }

  @override
  Future<NutritionSummary> loadSummary() {
    final range = _currentWeekRange(_now());
    return _api.getNutritionSummary(
      dateFrom: range.start,
      dateTo: range.end,
    );
  }
}

DateTime _rollingListStart(DateTime value) {
  final localDate = DateTime(value.year, value.month, value.day);
  return localDate.subtract(const Duration(days: 29));
}

({DateTime start, DateTime end}) _currentWeekRange(DateTime value) {
  final localDate = DateTime(value.year, value.month, value.day);
  final start =
      localDate.subtract(Duration(days: localDate.weekday - DateTime.monday));
  return (start: start, end: start.add(const Duration(days: 6)));
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
  return 'Nutrition summary could not be loaded. Try again.';
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final Object? error;
}
