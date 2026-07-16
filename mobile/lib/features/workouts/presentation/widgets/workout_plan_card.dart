import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/workout_plan.dart';

class WorkoutPlanCard extends StatelessWidget {
  const WorkoutPlanCard({
    required this.plan,
    required this.onView,
    super.key,
  });

  final WorkoutPlan plan;
  final VoidCallback onView;

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
              plan.name,
              style: theme.textTheme.titleMedium,
            ),
            if (plan.goal.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                plan.goal,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                if (plan.daysCount > 0)
                  _MetricChip(
                    label: 'Days',
                    value: '${plan.daysCount}',
                  ),
                if (plan.exercisesCount > 0)
                  _MetricChip(
                    label: 'Exercises',
                    value: '${plan.exercisesCount}',
                  ),
                _MetricChip(
                  label: 'Status',
                  value: plan.active ? 'Active' : 'Inactive',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onView,
                child: const Text('View plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: theme.textTheme.titleSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
