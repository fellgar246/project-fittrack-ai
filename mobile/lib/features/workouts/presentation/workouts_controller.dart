import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/workouts_providers.dart';
import '../data/workouts_repository.dart';
import 'workouts_state.dart';

class WorkoutsController extends StateNotifier<WorkoutsState> {
  WorkoutsController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const WorkoutsState());

  final WorkoutsRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;
  bool _reloadQueued = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != WorkoutsStatus.initial) {
      return;
    }
    state = const WorkoutsState(status: WorkoutsStatus.loading);
    await _load(preserveData: false);
  }

  Future<void> refresh() async {
    if (_requestInProgress) {
      return;
    }
    state = state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: true);
  }

  Future<void> retry() async {
    if (_requestInProgress) {
      return;
    }
    state = state.data == null
        ? const WorkoutsState(status: WorkoutsStatus.loading)
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.data != null);
  }

  Future<void> retryLogs() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final data = await _repository.loadWorkouts();
      state = state.copyWith(
        data: current.copyWith(
          logs: data.logs,
          clearLogsError: true,
        ),
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = state.copyWith(
        data: current.copyWith(logsError: _messageFor(error)),
      );
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> reloadAfterCreate() async {
    if (_requestInProgress) {
      _reloadQueued = true;
      return;
    }
    await _load(preserveData: true);
    while (_reloadQueued) {
      _reloadQueued = false;
      await _load(preserveData: true);
    }
  }

  Future<void> _load({required bool preserveData}) async {
    _requestInProgress = true;
    try {
      final data = await _repository.loadWorkouts();
      state = WorkoutsState(
        status: WorkoutsStatus.loaded,
        data: data,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.data != null) {
        state = state.copyWith(
          status: WorkoutsStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = WorkoutsState(
          status: WorkoutsStatus.failure,
          errorMessage: message,
        );
      }
    } finally {
      _requestInProgress = false;
    }
  }

  Future<bool> _handleUnauthorized(Object error) async {
    if (error is UnauthorizedException) {
      await _onUnauthorized();
      return true;
    }
    return false;
  }
}

String _messageFor(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return 'Workout data could not be loaded. Try again.';
}

final workoutsControllerProvider =
    StateNotifierProvider.autoDispose<WorkoutsController, WorkoutsState>((ref) {
  final controller = WorkoutsController(
    ref.watch(workoutsRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
