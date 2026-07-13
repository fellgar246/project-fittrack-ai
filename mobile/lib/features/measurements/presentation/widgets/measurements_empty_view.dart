import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

class MeasurementsEmptyView extends StatelessWidget {
  const MeasurementsEmptyView({
    required this.onAdd,
    super.key,
  });

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monitor_weight_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No measurements yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add your first measurement to start tracking progress.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onAdd,
            child: const Text('Add measurement'),
          ),
        ],
      ),
    );
  }
}
