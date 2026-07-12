import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_providers.dart';
import '../data/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const DashboardState());

  final DashboardRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != DashboardStatus.initial) {
      return;
    }
    state = const DashboardState(status: DashboardStatus.loading);
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
        ? const DashboardState(status: DashboardStatus.loading)
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.data != null);
  }

  Future<void> retryMeasurement() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final measurement = await _repository.loadMeasurement();
      state = state.copyWith(
        data: current.copyWith(
          measurement: measurement,
          clearMeasurementError: true,
        ),
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = state.copyWith(
        data: current.copyWith(measurementError: _messageFor(error)),
      );
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> retryRecommendation() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final recommendation = await _repository.loadRecommendation();
      state = state.copyWith(
        data: current.copyWith(
          recommendation: recommendation,
          clearRecommendation: recommendation == null,
          clearRecommendationError: true,
        ),
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = state.copyWith(
        data: current.copyWith(recommendationError: _messageFor(error)),
      );
    } finally {
      _requestInProgress = false;
    }
  }

  Future<void> _load({required bool preserveData}) async {
    _requestInProgress = true;
    try {
      final data = await _repository.loadDashboard();
      state = DashboardState(
        status: DashboardStatus.loaded,
        data: data,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.data != null) {
        state = state.copyWith(
          status: DashboardStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = DashboardState(
          status: DashboardStatus.failure,
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
  return 'Dashboard data could not be loaded. Try again.';
}

final dashboardControllerProvider =
    StateNotifierProvider.autoDispose<DashboardController, DashboardState>(
        (ref) {
  final controller = DashboardController(
    ref.watch(dashboardRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
