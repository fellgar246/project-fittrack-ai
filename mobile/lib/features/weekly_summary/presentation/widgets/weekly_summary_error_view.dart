import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

class WeeklySummaryErrorView extends StatelessWidget {
  const WeeklySummaryErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Weekly summary unavailable',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklySummaryRefreshBanner extends StatelessWidget {
  const WeeklySummaryRefreshBanner({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colors.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
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

class RecommendationSectionError extends StatelessWidget {
  const RecommendationSectionError({
    required this.message,
    required this.onRetry,
    super.key,
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
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class EmptyRecommendationCard extends StatelessWidget {
  const EmptyRecommendationCard({required this.isReady, super.key});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isReady ? Icons.auto_awesome : Icons.hourglass_empty),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No weekly recommendation yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isReady
                        ? 'Your weekly data is ready. Generate your first '
                            'recommendation.'
                        : 'Complete the required weekly data to generate one.',
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

class GenerationFeedbackBanner extends StatelessWidget {
  const GenerationFeedbackBanner({
    required this.message,
    this.onCheckSaved,
    super.key,
  });

  final String message;
  final VoidCallback? onCheckSaved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (onCheckSaved != null) ...[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: onCheckSaved,
                child: const Text('Check saved result'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
