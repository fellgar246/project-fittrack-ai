import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/nutrition_summary.dart';

class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({
    this.summary,
    this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final NutritionSummary? summary;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly nutrition summary',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(errorMessage!),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = summary;
    if (data == null || data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly nutrition summary',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No nutrition data for this week.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add your first nutrition log.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly nutrition summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${data.daysLogged} day${data.daysLogged == 1 ? '' : 's'} logged',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _ValueLabel(
                  value: _number(data.avgCalories),
                  label: 'Avg calories',
                ),
                _ValueLabel(
                  value: '${_number(data.avgProtein)} g',
                  label: 'Avg protein',
                ),
                _ValueLabel(
                  value: '${_number(data.avgCarbs)} g',
                  label: 'Avg carbs',
                ),
                _ValueLabel(
                  value: '${_number(data.avgFats)} g',
                  label: 'Avg fats',
                ),
                _ValueLabel(
                  value: data.totalCalories.toString(),
                  label: 'Total calories',
                ),
                _ValueLabel(
                  value: '${_number(data.totalProtein)} g',
                  label: 'Total protein',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

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

String _number(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
