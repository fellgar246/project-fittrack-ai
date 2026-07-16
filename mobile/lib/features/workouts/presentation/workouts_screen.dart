import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'workouts_controller.dart';
import 'workouts_state.dart';
import 'widgets/workout_log_card.dart';
import 'widgets/workout_plan_card.dart';
import 'widgets/workouts_empty_view.dart';
import 'widgets/workouts_error_view.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  var _createdDuringVisit = false;

  void _handleBack() {
    context.pop(_createdDuringVisit ? true : null);
  }

  Future<void> _openCreate({String? planId}) async {
    final location = planId == null
        ? AppRoutes.newWorkoutLog
        : '${AppRoutes.newWorkoutLog}?planId=$planId';
    final created = await context.push<bool>(location);
    if (created == true && mounted) {
      setState(() => _createdDuringVisit = true);
      await ref.read(workoutsControllerProvider.notifier).reloadAfterCreate();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout log saved.')),
      );
    }
  }

  void _openPlan(String planId) {
    context.push(AppRoutes.workoutPlanDetail(planId));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutsControllerProvider);
    final controller = ref.read(workoutsControllerProvider.notifier);
    final showFab =
        state.status == WorkoutsStatus.loaded && (state.data?.hasPlans == true);

    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: AppScaffold(
        title: 'Workouts',
        onBack: _handleBack,
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                onPressed: () => _openCreate(),
                icon: const Icon(Icons.add),
                label: const Text('Log exercise'),
              )
            : null,
        body: switch (state.status) {
          WorkoutsStatus.initial ||
          WorkoutsStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          WorkoutsStatus.failure => WorkoutsErrorView(
              message:
                  state.errorMessage ?? 'Workout data could not be loaded.',
              onRetry: controller.retry,
            ),
          WorkoutsStatus.loaded => _WorkoutsContent(
              state: state,
              onRefresh: controller.refresh,
              onRetry: controller.retry,
              onRetryLogs: controller.retryLogs,
              onAdd: () => _openCreate(),
              onViewPlan: _openPlan,
            ),
        },
      ),
    );
  }
}

class _WorkoutsContent extends StatelessWidget {
  const _WorkoutsContent({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onRetryLogs,
    required this.onAdd,
    required this.onViewPlan,
  });

  final WorkoutsState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onRetryLogs;
  final VoidCallback onAdd;
  final void Function(String planId) onViewPlan;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('workouts-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.isRefreshing) const LinearProgressIndicator(),
          if (state.errorMessage != null) ...[
            _RefreshErrorBanner(
              message: state.errorMessage!,
              onRetry: onRetry,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text('Workout plans', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (!data.hasPlans)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.25,
              child: const WorkoutsEmptyView(
                title: 'No workout plans available',
                message:
                    'Create or assign a workout plan through the backend workflow first.',
              ),
            )
          else
            ...data.plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: WorkoutPlanCard(
                  plan: plan,
                  onView: () => onViewPlan(plan.id),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Recent workouts', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (data.logsError != null) ...[
            _PartialErrorBanner(
              message: data.logsError!,
              onRetry: onRetryLogs,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!data.hasLogs)
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: WorkoutsEmptyView(
                title: 'No workouts logged yet',
                message: data.hasPlans
                    ? 'Register your first completed workout.'
                    : 'Complete your first workout to build weekly progress.',
                actionLabel: data.hasPlans ? 'Log exercise' : null,
                onAction: data.hasPlans ? onAdd : null,
              ),
            )
          else
            ...data.logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: WorkoutLogCard(log: log),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartialErrorBanner extends StatelessWidget {
  const _PartialErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry logs'),
            ),
          ],
        ),
      ),
    );
  }
}
