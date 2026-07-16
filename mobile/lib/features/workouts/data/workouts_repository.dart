import '../../../core/errors/api_exception.dart';
import 'models/create_workout_log_request.dart';
import 'models/workout_log.dart';
import 'models/workout_plan.dart';
import 'models/workout_plan_detail.dart';
import 'models/workouts_data.dart';
import 'workouts_api.dart';

abstract interface class WorkoutsRepository {
  Future<WorkoutsData> loadWorkouts();
  Future<WorkoutPlanDetail> getWorkoutPlan(String id);
  Future<List<WorkoutPlan>> getWorkoutPlans();
  Future<WorkoutLog> createWorkoutLog(CreateWorkoutLogRequest request);
}

class WorkoutsRepositoryImpl implements WorkoutsRepository {
  WorkoutsRepositoryImpl({
    required WorkoutsApi api,
    DateTime Function()? now,
  })  : _api = api,
        _now = now ?? DateTime.now;

  final WorkoutsApi _api;
  final DateTime Function() _now;

  @override
  Future<WorkoutsData> loadWorkouts() async {
    final listFrom = _rollingListStart(_now());

    final results = await Future.wait<_Outcome<Object?>>([
      _capture<List<WorkoutPlan>>(_api.getWorkoutPlans()),
      _capture<List<WorkoutLog>>(
        _api.getWorkoutLogs(dateFrom: listFrom),
      ),
    ]);

    for (final result in results) {
      if (result.error is UnauthorizedException) {
        throw result.error!;
      }
    }

    final plans = results[0];
    if (plans.error != null) {
      throw plans.error!;
    }

    final logs = results[1];
    return WorkoutsData(
      plans: plans.value! as List<WorkoutPlan>,
      logs: logs.value as List<WorkoutLog>? ?? const [],
      logsError: logs.error == null ? null : _messageFor(logs.error!),
    );
  }

  @override
  Future<WorkoutPlanDetail> getWorkoutPlan(String id) {
    return _api.getWorkoutPlan(id);
  }

  @override
  Future<List<WorkoutPlan>> getWorkoutPlans() {
    return _api.getWorkoutPlans();
  }

  @override
  Future<WorkoutLog> createWorkoutLog(CreateWorkoutLogRequest request) {
    return _api.createWorkoutLog(request);
  }
}

DateTime _rollingListStart(DateTime value) {
  final localDate = DateTime(value.year, value.month, value.day);
  return localDate.subtract(const Duration(days: 29));
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
  return 'Recent workouts could not be loaded. Try again.';
}

class _Outcome<T> {
  const _Outcome({this.value, this.error});

  final T? value;
  final Object? error;
}
