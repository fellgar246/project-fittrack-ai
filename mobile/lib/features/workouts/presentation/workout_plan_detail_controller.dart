import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/workouts_providers.dart';
import '../data/workouts_repository.dart';
import 'workout_plan_detail_state.dart';

class WorkoutPlanDetailController
    extends StateNotifier<WorkoutPlanDetailState> {
  WorkoutPlanDetailController(
    this._repository,
    this._planId, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const WorkoutPlanDetailState());

  final WorkoutsRepository _repository;
  final String _planId;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != WorkoutPlanDetailStatus.initial) {
      return;
    }
    state = const WorkoutPlanDetailState(
      status: WorkoutPlanDetailStatus.loading,
    );
    await _fetch();
  }

  Future<void> retry() async {
    if (_requestInProgress) {
      return;
    }
    state = const WorkoutPlanDetailState(
      status: WorkoutPlanDetailStatus.loading,
    );
    await _fetch();
  }

  Future<void> _fetch() async {
    _requestInProgress = true;
    try {
      final plan = await _repository.getWorkoutPlan(_planId);
      state = WorkoutPlanDetailState(
        status: WorkoutPlanDetailStatus.loaded,
        plan: plan,
      );
    } catch (error) {
      if (error is UnauthorizedException) {
        await _onUnauthorized();
        return;
      }
      state = WorkoutPlanDetailState(
        status: WorkoutPlanDetailStatus.failure,
        errorMessage: _messageFor(error),
      );
    } finally {
      _requestInProgress = false;
    }
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Workout plan could not be loaded. Try again.';
}

final workoutPlanDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<WorkoutPlanDetailController, WorkoutPlanDetailState, String>(
        (ref, planId) {
  final controller = WorkoutPlanDetailController(
    ref.watch(workoutsRepositoryProvider),
    planId,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
