import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/create_workout_log_request.dart';
import '../data/models/workout_log.dart';
import '../data/workouts_providers.dart';
import '../data/workouts_repository.dart';
import 'create_workout_log_state.dart';

class CreateWorkoutLogController extends StateNotifier<CreateWorkoutLogState> {
  CreateWorkoutLogController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const CreateWorkoutLogState());

  final WorkoutsRepository _repository;
  final Future<void> Function() _onUnauthorized;

  Future<WorkoutLog?> submit(CreateWorkoutLogRequest request) async {
    if (state.isSubmitting) {
      return null;
    }

    state = state.copyWith(
      status: CreateWorkoutLogStatus.submitting,
      clearError: true,
    );

    try {
      final log = await _repository.createWorkoutLog(request);
      state = const CreateWorkoutLogState(
        status: CreateWorkoutLogStatus.success,
      );
      return log;
    } catch (error) {
      if (error is UnauthorizedException) {
        await _onUnauthorized();
        return null;
      }
      state = CreateWorkoutLogState(
        status: CreateWorkoutLogStatus.failure,
        errorMessage: _messageFor(error),
      );
      return null;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Workout log could not be saved. Try again.';
}

final createWorkoutLogControllerProvider = StateNotifierProvider.autoDispose<
    CreateWorkoutLogController, CreateWorkoutLogState>((ref) {
  return CreateWorkoutLogController(
    ref.watch(workoutsRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});
