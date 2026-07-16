import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/weekly_recommendation.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    required this.recommendation,
    super.key,
  });

  final WeeklyRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly recommendation', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Week of ${_shortDate(recommendation.weekStart)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Generated with Azure OpenAI',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Summary', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(recommendation.summary),
            const SizedBox(height: AppSpacing.md),
            Text('Recommendation', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(recommendation.recommendation),
            if (recommendation.insights.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Key insights', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              for (final insight in recommendation.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(insight)),
                    ],
                  ),
                ),
            ],
            if (recommendation.safetyNotes != null &&
                recommendation.safetyNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safety notes', style: theme.textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(recommendation.safetyNotes!),
                  ],
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
