import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/weekly_summary.dart';

class WeeklyMetricsCard extends StatelessWidget {
  const WeeklyMetricsCard({required this.summary, super.key});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workouts = summary.workouts;
    final nutrition = summary.nutrition;
    final measurements = summary.measurements;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly metrics', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _MetricRow(
              icon: Icons.fitness_center,
              label: 'Workout logs',
              value: '${workouts.totalLogs}',
            ),
            _MetricRow(
              icon: Icons.calendar_today_outlined,
              label: 'Workout days',
              value: '${workouts.workoutDays}',
            ),
            _MetricRow(
              icon: Icons.repeat,
              label: 'Total sets',
              value: '${workouts.totalSets}',
            ),
            _MetricRow(
              icon: Icons.restaurant_outlined,
              label: 'Nutrition days logged',
              value: '${nutrition.daysLogged}',
            ),
            if (nutrition.avgCalories != null)
              _MetricRow(
                icon: Icons.local_fire_department_outlined,
                label: 'Average calories',
                value: _number(nutrition.avgCalories!),
              ),
            _MetricRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Measurements',
              value: '${measurements.measurementsCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
