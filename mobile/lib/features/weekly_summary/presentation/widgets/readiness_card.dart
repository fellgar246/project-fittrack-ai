import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/weekly_summary.dart';

class ReadinessCard extends StatelessWidget {
  const ReadinessCard({required this.summary, super.key});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = summary.isReadyForRecommendation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ready ? Icons.check_circle_outline : Icons.pending_outlined,
              color: ready
                  ? theme.colorScheme.primary
                  : theme.colorScheme.tertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'Ready for recommendation' : 'More data needed',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ready
                        ? 'Your weekly data meets the backend readiness '
                            'requirements.'
                        : 'Complete the missing weekly data to unlock '
                            'recommendation generation.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
