import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/weekly_recommendation.dart';
import '../data/weekly_summary_providers.dart';
import '../data/weekly_summary_repository.dart';
import 'weekly_summary_state.dart';

class WeeklySummaryController extends StateNotifier<WeeklySummaryState> {
  WeeklySummaryController(
    this._repository, {
    required Future<void> Function() onUnauthorized,
  })  : _onUnauthorized = onUnauthorized,
        super(const WeeklySummaryState());

  final WeeklySummaryRepository _repository;
  final Future<void> Function() _onUnauthorized;
  bool _requestInProgress = false;

  Future<void> load() async {
    if (_requestInProgress || state.status != WeeklySummaryStatus.initial) {
      return;
    }
    final weekStart = _repository.currentWeekStart;
    state = WeeklySummaryState(
      status: WeeklySummaryStatus.loading,
      weekStart: weekStart,
    );
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
        ? WeeklySummaryState(
            status: WeeklySummaryStatus.loading,
            weekStart: state.weekStart ?? _repository.currentWeekStart,
          )
        : state.copyWith(isRefreshing: true, clearError: true);
    await _load(preserveData: state.data != null);
  }

  Future<void> retryRecommendation() async {
    final current = state.data;
    if (_requestInProgress || current == null) {
      return;
    }
    _requestInProgress = true;
    try {
      final recommendation = await _repository.loadLatestRecommendation();
      state = state.copyWith(
        data: current.copyWith(
          latestRecommendation: recommendation,
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

  void applyRecommendation(WeeklyRecommendation recommendation) {
    final current = state.data;
    if (current == null) {
      return;
    }
    state = state.copyWith(
      data: current.copyWith(
        latestRecommendation: recommendation,
        clearRecommendationError: true,
      ),
    );
  }

  Future<void> reloadAfterDataChange() async {
    if (_requestInProgress) {
      return;
    }
    await _load(preserveData: true);
  }

  Future<void> _load({required bool preserveData}) async {
    _requestInProgress = true;
    final weekStart = state.weekStart ?? _repository.currentWeekStart;
    try {
      final data = await _repository.loadWeek(weekStart);
      state = WeeklySummaryState(
        status: WeeklySummaryStatus.loaded,
        weekStart: weekStart,
        data: data,
      );
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      final message = _messageFor(error);
      if (preserveData && state.data != null) {
        state = state.copyWith(
          status: WeeklySummaryStatus.loaded,
          errorMessage: message,
          isRefreshing: false,
        );
      } else {
        state = WeeklySummaryState(
          status: WeeklySummaryStatus.failure,
          weekStart: weekStart,
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
  return 'Weekly summary could not be loaded. Try again.';
}

final weeklySummaryControllerProvider = StateNotifierProvider.autoDispose<
    WeeklySummaryController, WeeklySummaryState>((ref) {
  final controller = WeeklySummaryController(
    ref.watch(weeklySummaryRepositoryProvider),
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
  controller.load();
  return controller;
});
