import 'dart:async';

import 'package:fittrack_ai/core/errors/api_exception.dart';
import 'package:fittrack_ai/features/workouts/data/models/create_workout_log_request.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_log.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_plan.dart';
import 'package:fittrack_ai/features/workouts/data/models/workout_plan_detail.dart';
import 'package:fittrack_ai/features/workouts/data/models/workouts_data.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_api.dart';
import 'package:fittrack_ai/features/workouts/data/workouts_repository.dart';

const testPlanId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const testDayId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const testExerciseId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

const testWorkoutPlan = WorkoutPlan(
  id: testPlanId,
  name: 'Strength Builder',
  goal: 'Build muscle',
  active: true,
  daysCount: 1,
  exercisesCount: 1,
);

const testWorkoutPlanDetail = WorkoutPlanDetail(
  id: testPlanId,
  name: 'Strength Builder',
  goal: 'Build muscle',
  active: true,
  days: [
    WorkoutDay(
      id: testDayId,
      dayOfWeek: 1,
      title: 'Push day',
      exercises: [
        WorkoutExercise(
          id: testExerciseId,
          name: 'Bench press',
          muscleGroup: 'Chest',
          targetSets: 3,
          targetReps: '10',
        ),
      ],
    ),
  ],
);

final testWorkoutLog = WorkoutLog(
  id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  exerciseId: testExerciseId,
  exerciseName: 'Bench press',
  performedAt: DateTime(2026, 7, 3, 10, 30),
  sets: 3,
  reps: 10,
  weight: 60,
  notes: 'Completed demo workout',
);

class FakeWorkoutsApi implements WorkoutsApi {
  List<WorkoutPlan> plans = [testWorkoutPlan];
  WorkoutPlanDetail planDetail = testWorkoutPlanDetail;
  List<WorkoutLog> logs = [testWorkoutLog];
  WorkoutLog? created;
  Object? plansError;
  Object? planDetailError;
  Object? logsError;
  Object? createError;
  Completer<void>? requestGate;
  var activeRequests = 0;
  var maxActiveRequests = 0;
  var plansCalls = 0;
  var planDetailCalls = 0;
  var logsCalls = 0;
  var createCalls = 0;
  DateTime? lastLogsFrom;
  String? lastPlanId;

  @override
  Future<List<WorkoutPlan>> getWorkoutPlans() {
    return _run(() {
      plansCalls++;
      if (plansError != null) throw plansError!;
      return plans;
    });
  }

  @override
  Future<WorkoutPlanDetail> getWorkoutPlan(String id) {
    return _run(() {
      planDetailCalls++;
      lastPlanId = id;
      if (planDetailError != null) throw planDetailError!;
      return planDetail;
    });
  }

  @override
  Future<List<WorkoutLog>> getWorkoutLogs({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return _run(() {
      logsCalls++;
      lastLogsFrom = dateFrom;
      if (logsError != null) throw logsError!;
      return logs;
    });
  }

  @override
  Future<WorkoutLog> createWorkoutLog(CreateWorkoutLogRequest request) {
    return _run(() {
      createCalls++;
      if (createError != null) throw createError!;
      created = WorkoutLog(
        id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        exerciseId: request.exerciseId,
        exerciseName: 'Bench press',
        performedAt: request.performedAt,
        sets: request.sets,
        reps: request.reps,
        weight: request.weight,
        notes: request.notes,
      );
      return created!;
    });
  }

  Future<T> _run<T>(T Function() result) async {
    activeRequests++;
    if (activeRequests > maxActiveRequests) {
      maxActiveRequests = activeRequests;
    }
    await requestGate?.future;
    try {
      return result();
    } finally {
      activeRequests--;
    }
  }
}

class FakeWorkoutsRepository implements WorkoutsRepository {
  List<WorkoutPlan> plans = [testWorkoutPlan];
  WorkoutPlanDetail planDetail = testWorkoutPlanDetail;
  List<WorkoutLog> logs = [testWorkoutLog];
  WorkoutLog? created;
  Object? loadError;
  Object? plansError;
  Object? planDetailError;
  Object? logsError;
  Object? createError;
  Completer<void>? loadGate;
  Completer<void>? createGate;
  var loadCalls = 0;
  var createCalls = 0;
  var planDetailCalls = 0;
  var plansCalls = 0;

  @override
  Future<WorkoutsData> loadWorkouts() async {
    loadCalls++;
    await loadGate?.future;
    if (loadError != null) throw loadError!;

    Object? localLogsError;
    List<WorkoutLog> localLogs = const [];
    try {
      if (logsError != null) throw logsError!;
      localLogs = logs;
    } catch (error) {
      if (error is UnauthorizedException) {
        rethrow;
      }
      localLogsError = error;
    }

    if (plansError != null) {
      throw plansError!;
    }

    return WorkoutsData(
      plans: plans,
      logs: localLogs,
      logsError: localLogsError == null
          ? null
          : localLogsError is ApiException
              ? localLogsError.message
              : 'Recent workouts could not be loaded. Try again.',
    );
  }

  @override
  Future<WorkoutPlanDetail> getWorkoutPlan(String id) async {
    planDetailCalls++;
    if (planDetailError != null) throw planDetailError!;
    return planDetail;
  }

  @override
  Future<List<WorkoutPlan>> getWorkoutPlans() async {
    plansCalls++;
    if (plansError != null) throw plansError!;
    return plans;
  }

  @override
  Future<WorkoutLog> createWorkoutLog(CreateWorkoutLogRequest request) async {
    createCalls++;
    await createGate?.future;
    if (createError != null) throw createError!;
    created = WorkoutLog(
      id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
      exerciseId: request.exerciseId,
      exerciseName: 'Bench press',
      performedAt: request.performedAt,
      sets: request.sets,
      reps: request.reps,
      weight: request.weight,
      notes: request.notes,
    );
    return created!;
  }
}
