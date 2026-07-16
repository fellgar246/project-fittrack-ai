import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';

class MissingDataCard extends StatelessWidget {
  const MissingDataCard({
    required this.missingData,
    super.key,
  });

  final List<String> missingData;

  @override
  Widget build(BuildContext context) {
    if (missingData.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Card(
      key: const Key('missing-data-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To unlock your recommendation',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            for (final item in missingData) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(_missingMessage(item))),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (missingData.contains('workout_logs'))
                  OutlinedButton(
                    onPressed: () =>
                        _openAndRefresh(context, AppRoutes.workouts),
                    child: const Text('Open Workouts'),
                  ),
                if (missingData.contains('nutrition_logs'))
                  OutlinedButton(
                    onPressed: () =>
                        _openAndRefresh(context, AppRoutes.nutrition),
                    child: const Text('Open Nutrition'),
                  ),
                if (missingData.contains('body_measurements'))
                  OutlinedButton(
                    onPressed: () =>
                        _openAndRefresh(context, AppRoutes.measurements),
                    child: const Text('Open Measurements'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAndRefresh(BuildContext context, String route) async {
  final changed = await context.push<bool>(route);
  if (changed == true && context.mounted) {
    context.pop(true);
  }
}

String _missingMessage(String value) {
  switch (value) {
    case 'workout_logs':
      return 'Add at least one workout log for this week.';
    case 'nutrition_logs':
      return 'Log nutrition on more days this week.';
    case 'body_measurements':
      return 'Add a body measurement for this week.';
    default:
      return value.replaceAll('_', ' ');
  }
}
