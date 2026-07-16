import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

class NutritionEmptyView extends StatelessWidget {
  const NutritionEmptyView({
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
            Icons.restaurant_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No nutrition logs yet',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add your first daily nutrition log to build your weekly summary.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onAdd,
            child: const Text('Add nutrition log'),
          ),
        ],
      ),
    );
  }
}
