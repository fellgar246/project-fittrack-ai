import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/measurement.dart';

class MeasurementCard extends StatelessWidget {
  const MeasurementCard({
    required this.measurement,
    super.key,
  });

  final Measurement measurement;

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
              _formatDate(measurement.date),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _MetricChip(
                  label: 'Weight',
                  value: '${_number(measurement.weight)} kg',
                ),
                if (measurement.waist != null)
                  _MetricChip(
                    label: 'Waist',
                    value: '${_number(measurement.waist!)} cm',
                  ),
                if (measurement.bodyFatEstimate != null)
                  _MetricChip(
                    label: 'Body fat',
                    value: '${_number(measurement.bodyFatEstimate!)}%',
                  ),
              ],
            ),
            if (measurement.notes != null && measurement.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                measurement.notes!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
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
        Text(
          value,
          style: theme.textTheme.titleSmall,
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
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
