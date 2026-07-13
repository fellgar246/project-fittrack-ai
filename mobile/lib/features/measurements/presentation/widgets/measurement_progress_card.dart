import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/measurement_progress.dart';

class MeasurementProgressCard extends StatelessWidget {
  const MeasurementProgressCard({
    this.progress,
    this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final MeasurementProgress? progress;
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
                'Progress summary',
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

    final data = progress;
    if (data == null || data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Not enough data to show a trend.',
            style: Theme.of(context).textTheme.bodyMedium,
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
              'Progress summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (data.endDate != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Latest measurement ${_formatDate(data.endDate!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                if (data.endWeight != null)
                  _ValueLabel(
                    value: '${_number(data.endWeight!)} kg',
                    label: 'Latest weight',
                  ),
                if (data.endWaist != null)
                  _ValueLabel(
                    value: '${_number(data.endWaist!)} cm',
                    label: 'Latest waist',
                  ),
                if (data.endBodyFatEstimate != null)
                  _ValueLabel(
                    value: '${_number(data.endBodyFatEstimate!)}%',
                    label: 'Latest body fat',
                  ),
                _ValueLabel(
                  value: data.measurementsCount.toString(),
                  label: 'Measurements',
                ),
              ],
            ),
            if (data.hasTrend) ...[
              const SizedBox(height: AppSpacing.md),
              if (data.weightChange != null)
                Text('Weight change: ${_signedNumber(data.weightChange!)} kg'),
              if (data.waistChange != null)
                Text('Waist change: ${_signedNumber(data.waistChange!)} cm'),
              if (data.bodyFatChange != null)
                Text(
                  'Body fat change: ${_signedNumber(data.bodyFatChange!)}%',
                ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Not enough data to show a trend.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
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

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _number(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

String _signedNumber(double value) {
  final prefix = value > 0 ? '+' : '';
  return '$prefix${_number(value)}';
}
