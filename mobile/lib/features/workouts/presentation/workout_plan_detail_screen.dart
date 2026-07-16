import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/models/workout_plan_detail.dart';
import 'workout_plan_detail_controller.dart';
import 'workout_plan_detail_state.dart';
import 'widgets/workouts_error_view.dart';

class WorkoutPlanDetailScreen extends ConsumerStatefulWidget {
  const WorkoutPlanDetailScreen({
    required this.planId,
    super.key,
  });

  final String planId;

  @override
  ConsumerState<WorkoutPlanDetailScreen> createState() =>
      _WorkoutPlanDetailScreenState();
}

class _WorkoutPlanDetailScreenState
    extends ConsumerState<WorkoutPlanDetailScreen> {
  var _createdDuringVisit = false;

  void _handleBack() {
    context.pop(_createdDuringVisit ? true : null);
  }

  Future<void> _openCreate() async {
    final created = await context.push<bool>(
      '${AppRoutes.newWorkoutLog}?planId=${widget.planId}',
    );
    if (created == true && mounted) {
      setState(() => _createdDuringVisit = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout log saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workoutPlanDetailControllerProvider(widget.planId));
    final controller =
        ref.read(workoutPlanDetailControllerProvider(widget.planId).notifier);

    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: AppScaffold(
        title: 'Workout plan',
        onBack: _handleBack,
        body: switch (state.status) {
          WorkoutPlanDetailStatus.initial ||
          WorkoutPlanDetailStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          WorkoutPlanDetailStatus.failure => WorkoutsErrorView(
              message:
                  state.errorMessage ?? 'Workout plan could not be loaded.',
              onRetry: controller.retry,
            ),
          WorkoutPlanDetailStatus.loaded => _PlanDetailContent(
              plan: state.plan!,
              onLogExercise: _openCreate,
            ),
        },
      ),
    );
  }
}

class _PlanDetailContent extends StatelessWidget {
  const _PlanDetailContent({
    required this.plan,
    required this.onLogExercise,
  });

  final WorkoutPlanDetail plan;
  final VoidCallback onLogExercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('workout-plan-detail-scroll-view'),
      children: [
        Text(plan.name, style: theme.textTheme.headlineSmall),
        if (plan.goal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(plan.goal, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          plan.active ? 'Active plan' : 'Inactive plan',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (plan.days.isEmpty)
          const Text('No days defined for this plan.')
        else
          ...plan.days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _DaySection(day: day),
            ),
          ),
        if (plan.exercisesCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onLogExercise,
            child: const Text('Log exercise'),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final WorkoutDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_dayLabel(day.dayOfWeek)} — ${day.title}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (day.exercises.isEmpty)
              Text(
                'No exercises for this day.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...day.exercises.map(
                (exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        exercise.muscleGroup,
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${exercise.targetSets} sets × ${exercise.targetReps} reps',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _dayLabel(int dayOfWeek) {
  return switch (dayOfWeek) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Day $dayOfWeek',
  };
}
