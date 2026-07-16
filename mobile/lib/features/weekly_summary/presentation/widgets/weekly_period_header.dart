import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/weekly_summary.dart';

class WeeklyPeriodHeader extends StatelessWidget {
  const WeeklyPeriodHeader({
    required this.summary,
    required this.isCurrentWeek,
    super.key,
  });

  final WeeklySummary summary;
  final bool isCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly period', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_shortDate(summary.weekStart)} – ${_shortDate(summary.weekEnd)}',
              style: theme.textTheme.titleMedium,
            ),
            if (isCurrentWeek) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Current week',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
