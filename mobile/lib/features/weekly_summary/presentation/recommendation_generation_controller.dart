import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/weekly_recommendation.dart';
import '../data/weekly_summary_providers.dart';
import '../data/weekly_summary_repository.dart';
import 'weekly_summary_controller.dart';
import 'weekly_summary_state.dart';

class RecommendationGenerationController
    extends StateNotifier<RecommendationGenerationState> {
  RecommendationGenerationController(
    this._repository, {
    required WeeklySummaryController weeklySummaryController,
    required Future<void> Function() onUnauthorized,
  })  : _weeklySummaryController = weeklySummaryController,
        _onUnauthorized = onUnauthorized,
        super(const RecommendationGenerationState());

  final WeeklySummaryRepository _repository;
  final WeeklySummaryController _weeklySummaryController;
  final Future<void> Function() _onUnauthorized;
  bool _submitInProgress = false;

  Future<WeeklyRecommendation?> generate(DateTime weekStart) async {
    if (_submitInProgress || state.isSubmitting) {
      return null;
    }
    _submitInProgress = true;
    state = const RecommendationGenerationState(
      status: RecommendationGenerationStatus.submitting,
    );

    try {
      final recommendation =
          await _repository.generateRecommendation(weekStart);
      state = RecommendationGenerationState(
        status: RecommendationGenerationStatus.success,
        result: recommendation,
      );
      _weeklySummaryController.applyRecommendation(recommendation);
      return recommendation;
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return null;
      }

      if (error is TimeoutApiException) {
        final persisted = await _tryRecoverPersistedRecommendation(weekStart);
        if (persisted != null) {
          state = RecommendationGenerationState(
            status: RecommendationGenerationStatus.success,
            result: persisted,
          );
          _weeklySummaryController.applyRecommendation(persisted);
          return persisted;
        }
        state = const RecommendationGenerationState(
          status: RecommendationGenerationStatus.uncertain,
          errorMessage: _timeoutMessage,
        );
        return null;
      }

      if (error is ConflictException) {
        final persisted = await _tryRecoverPersistedRecommendation(weekStart);
        if (persisted != null) {
          state = RecommendationGenerationState(
            status: RecommendationGenerationStatus.success,
            result: persisted,
          );
          _weeklySummaryController.applyRecommendation(persisted);
          return persisted;
        }
      }

      if (error is ValidationException) {
        await _weeklySummaryController.reloadAfterDataChange();
      }

      state = RecommendationGenerationState(
        status: RecommendationGenerationStatus.failure,
        errorMessage: _messageFor(error),
      );
      return null;
    } finally {
      _submitInProgress = false;
    }
  }

  Future<void> checkPersistedResult(DateTime weekStart) async {
    if (_submitInProgress) {
      return;
    }
    _submitInProgress = true;
    state = state.copyWith(clearError: true);
    try {
      final persisted = await _tryRecoverPersistedRecommendation(weekStart);
      if (persisted != null) {
        state = RecommendationGenerationState(
          status: RecommendationGenerationStatus.success,
          result: persisted,
        );
        _weeklySummaryController.applyRecommendation(persisted);
      } else {
        state = const RecommendationGenerationState(
          status: RecommendationGenerationStatus.idle,
        );
      }
    } catch (error) {
      if (await _handleUnauthorized(error)) {
        return;
      }
      state = RecommendationGenerationState(
        status: RecommendationGenerationStatus.failure,
        errorMessage: _messageFor(error),
      );
    } finally {
      _submitInProgress = false;
    }
  }

  void reset() {
    if (_submitInProgress) {
      return;
    }
    state = const RecommendationGenerationState();
  }

  Future<WeeklyRecommendation?> _tryRecoverPersistedRecommendation(
    DateTime weekStart,
  ) async {
    try {
      final latest = await _repository.loadLatestRecommendation();
      if (latest == null) {
        return null;
      }
      if (_sameWeek(latest.weekStart, weekStart)) {
        return latest;
      }
      return null;
    } catch (_) {
      return null;
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

bool _sameWeek(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _messageFor(Object error) {
  if (error is ValidationException) {
    return error.message;
  }
  if (error is ConflictException) {
    return 'A recommendation already exists for this week.';
  }
  if (error is ServerException) {
    final code = error.statusCode;
    if (code == 502) {
      return 'The AI recommendation service could not complete the request.';
    }
    if (code == 503) {
      return 'The recommendation service is temporarily unavailable.';
    }
  }
  if (error is RateLimitedException) {
    return 'Too many requests. Try again later.';
  }
  if (error is ApiException) {
    return error.message;
  }
  return 'Recommendation generation failed. Try again.';
}

const _timeoutMessage =
    'The recommendation is taking longer than expected. Try again.';

final recommendationGenerationControllerProvider =
    StateNotifierProvider.autoDispose<RecommendationGenerationController,
        RecommendationGenerationState>((ref) {
  final weeklyController = ref.watch(weeklySummaryControllerProvider.notifier);
  return RecommendationGenerationController(
    ref.watch(weeklySummaryRepositoryProvider),
    weeklySummaryController: weeklyController,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
  );
});
