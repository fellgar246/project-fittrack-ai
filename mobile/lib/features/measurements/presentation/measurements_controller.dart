import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/measurements_providers.dart';
import '../data/measurements_repository.dart';
import 'measurements_state.dart';

class MeasurementsController extends StateNotifier<MeasurementsState> {
  MeasurementsController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const MeasurementsState());

  final MeasurementsRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != MeasurementsStatus.initial) {
      return;
    }
    state = const MeasurementsState(status: MeasurementsStatus.loading);
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
        ? const MeasurementsState(status: MeasurementsStatus.loading)
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.data != null);
  }

  Future<void> retryProgress() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final progress = await _repository.loadProgress();
      state = state.copyWith(
        data: current.copyWith(
          progress: progress,
          clearProgressError: true,
        ),
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = state.copyWith(
        data: current.copyWith(progressError: _messageFor(error)),
      );
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> reloadAfterCreate() async {
    if (_requestInProgress) {
      return;
    }
    await _load(preserveData: true);
  }

  Future<void> _load({required bool preserveData}) async {
    _requestInProgress = true;
    try {
      final data = await _repository.loadMeasurements();
      state = MeasurementsState(
        status: MeasurementsStatus.loaded,
        data: data,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.data != null) {
        state = state.copyWith(
          status: MeasurementsStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = MeasurementsState(
          status: MeasurementsStatus.failure,
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
  return 'Measurements could not be loaded. Try again.';
}

final measurementsControllerProvider = StateNotifierProvider.autoDispose<
    MeasurementsController, MeasurementsState>((ref) {
  final controller = MeasurementsController(
    ref.watch(measurementsRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
