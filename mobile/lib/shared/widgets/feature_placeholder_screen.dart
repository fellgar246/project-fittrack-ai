import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'app_scaffold.dart';

class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({
    required this.title,
    required this.nextBlock,
    super.key,
  });

  final String title;
  final String nextBlock;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.construction_outlined, size: 40),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$title flow',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This screen is intentionally a placeholder. '
                  'Full functionality is planned for $nextBlock.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
