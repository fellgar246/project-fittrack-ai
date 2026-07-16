import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../data/models/weekly_recommendation.dart';
import 'recommendation_generation_controller.dart';
import 'weekly_summary_controller.dart';
import 'weekly_summary_state.dart';
import 'widgets/missing_data_card.dart';
import 'widgets/readiness_card.dart';
import 'widgets/recommendation_card.dart';
import 'widgets/recommendation_loading_view.dart';
import 'widgets/weekly_metrics_card.dart';
import 'widgets/weekly_period_header.dart';
import 'widgets/weekly_summary_error_view.dart';

class WeeklySummaryScreen extends ConsumerStatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  ConsumerState<WeeklySummaryScreen> createState() =>
      _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends ConsumerState<WeeklySummaryScreen> {
  var _changedDuringVisit = false;

  void _handleBack() {
    context.pop(_changedDuringVisit ? true : null);
  }

  Future<void> _generate() async {
    final summaryState = ref.read(weeklySummaryControllerProvider);
    final data = summaryState.data;
    final weekStart = summaryState.weekStart;
    if (data == null || weekStart == null) {
      return;
    }
    if (!data.summary.isReadyForRecommendation) {
      return;
    }

    final generationController =
        ref.read(recommendationGenerationControllerProvider.notifier);
    final result = await generationController.generate(weekStart);
    if (!mounted) {
      return;
    }
    if (result != null) {
      setState(() => _changedDuringVisit = true);
      await ref.read(dashboardControllerProvider.notifier).refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weekly recommendation generated.')),
      );
    }
  }

  Future<void> _checkSavedResult() async {
    final weekStart = ref.read(weeklySummaryControllerProvider).weekStart;
    if (weekStart == null) {
      return;
    }
    final generationController =
        ref.read(recommendationGenerationControllerProvider.notifier);
    await generationController.checkPersistedResult(weekStart);
    if (!mounted) {
      return;
    }
    final generationState =
        ref.read(recommendationGenerationControllerProvider);
    if (generationState.status == RecommendationGenerationStatus.success) {
      setState(() => _changedDuringVisit = true);
      await ref.read(dashboardControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryState = ref.watch(weeklySummaryControllerProvider);
    final generationState =
        ref.watch(recommendationGenerationControllerProvider);
    final summaryController =
        ref.read(weeklySummaryControllerProvider.notifier);

    return AppScaffold(
      title: 'Weekly summary',
      onBack: _handleBack,
      body: switch (summaryState.status) {
        WeeklySummaryStatus.initial ||
        WeeklySummaryStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        WeeklySummaryStatus.failure => WeeklySummaryErrorView(
            message: summaryState.errorMessage ??
                'Weekly summary could not be loaded.',
            onRetry: summaryController.retry,
          ),
        WeeklySummaryStatus.loaded => _WeeklySummaryContent(
            summaryState: summaryState,
            generationState: generationState,
            onRefresh: summaryController.refresh,
            onRetry: summaryController.retry,
            onRetryRecommendation: summaryController.retryRecommendation,
            onGenerate: _generate,
            onCheckSavedResult: _checkSavedResult,
          ),
      },
    );
  }
}

class _WeeklySummaryContent extends StatelessWidget {
  const _WeeklySummaryContent({
    required this.summaryState,
    required this.generationState,
    required this.onRefresh,
    required this.onRetry,
    required this.onRetryRecommendation,
    required this.onGenerate,
    required this.onCheckSavedResult,
  });

  final WeeklySummaryState summaryState;
  final RecommendationGenerationState generationState;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onRetryRecommendation;
  final Future<void> Function() onGenerate;
  final Future<void> Function() onCheckSavedResult;

  @override
  Widget build(BuildContext context) {
    final data = summaryState.data!;
    final summary = data.summary;
    final recommendation = _displayRecommendation(
      data.latestRecommendation,
      generationState.result,
    );
    final isGenerating = generationState.isSubmitting;
    final canGenerate = summary.isReadyForRecommendation && !isGenerating;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('weekly-summary-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (summaryState.isRefreshing) const LinearProgressIndicator(),
          if (summaryState.errorMessage != null) ...[
            WeeklySummaryRefreshBanner(
              message: summaryState.errorMessage!,
              onRetry: onRetry,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          WeeklyPeriodHeader(
            summary: summary,
            isCurrentWeek: _isSameDate(
              summary.weekStart,
              summaryState.weekStart ?? summary.weekStart,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReadinessCard(summary: summary),
          const SizedBox(height: AppSpacing.sm),
          WeeklyMetricsCard(summary: summary),
          if (!summary.isReadyForRecommendation) ...[
            const SizedBox(height: AppSpacing.sm),
            MissingDataCard(missingData: summary.missingData),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (data.recommendationError != null)
            RecommendationSectionError(
              message: data.recommendationError!,
              onRetry: onRetryRecommendation,
            )
          else if (recommendation != null)
            RecommendationCard(recommendation: recommendation)
          else
            EmptyRecommendationCard(isReady: summary.isReadyForRecommendation),
          if (isGenerating) ...[
            const SizedBox(height: AppSpacing.sm),
            const RecommendationLoadingView(),
          ],
          if (generationState.status ==
              RecommendationGenerationStatus.failure) ...[
            const SizedBox(height: AppSpacing.sm),
            GenerationFeedbackBanner(message: generationState.errorMessage!),
          ],
          if (generationState.status ==
              RecommendationGenerationStatus.uncertain) ...[
            const SizedBox(height: AppSpacing.sm),
            GenerationFeedbackBanner(
              message: generationState.errorMessage!,
              onCheckSaved: onCheckSavedResult,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('generate-weekly-recommendation-button'),
            onPressed: canGenerate ? onGenerate : null,
            icon: isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              isGenerating
                  ? 'Generating your recommendation…'
                  : 'Generate weekly recommendation',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

WeeklyRecommendation? _displayRecommendation(
  WeeklyRecommendation? latest,
  WeeklyRecommendation? generated,
) {
  if (generated != null) {
    return generated;
  }
  return latest;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
