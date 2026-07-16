import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/nutrition_providers.dart';
import '../data/nutrition_repository.dart';
import 'nutrition_state.dart';

class NutritionController extends StateNotifier<NutritionState> {
  NutritionController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const NutritionState());

  final NutritionRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;
  bool _reloadQueued = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != NutritionStatus.initial) {
      return;
    }
    state = const NutritionState(status: NutritionStatus.loading);
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
        ? const NutritionState(status: NutritionStatus.loading)
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.data != null);
  }

  Future<void> retrySummary() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final summary = await _repository.loadSummary();
      state = state.copyWith(
        data: current.copyWith(
          summary: summary,
          clearSummaryError: true,
        ),
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = state.copyWith(
        data: current.copyWith(summaryError: _messageFor(error)),
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
    if (_reloadQueued) {
      _reloadQueued = false;
      await _load(preserveData: true);
    }
  }

  Future<void> _load({required bool preserveData}) async {
    _requestInProgress = true;
    try {
      final data = await _repository.loadNutrition();
      state = NutritionState(
        status: NutritionStatus.loaded,
        data: data,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.data != null) {
        state = state.copyWith(
          status: NutritionStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = NutritionState(
          status: NutritionStatus.failure,
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
  return 'Nutrition logs could not be loaded. Try again.';
}

final nutritionControllerProvider =
    StateNotifierProvider.autoDispose<NutritionController, NutritionState>(
        (ref) {
  final controller = NutritionController(
    ref.watch(nutritionRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
