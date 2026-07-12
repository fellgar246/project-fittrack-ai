import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/placeholder_feature_card.dart';
import '../../auth/presentation/auth_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _features = [
    (
      title: 'Measurements',
      description: 'Coming in Block 5.4',
    ),
    (
      title: 'Nutrition',
      description: 'Coming in Block 5.5',
    ),
    (
      title: 'Workouts',
      description: 'Coming in Block 5.6',
    ),
    (
      title: 'Weekly Summary',
      description: 'Coming in Block 5.7',
    ),
    (
      title: 'AI Recommendation',
      description: 'Coming in Block 5.7',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Dashboard',
      actions: [
        TextButton(
          onPressed: () {
            ref.read(authControllerProvider.notifier).logout();
          },
          child: const Text('Log out'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Fitness overview',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (user != null) ...[
            Text(
              'Signed in as ${user.email}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${user.name} · ${user.goal}',
              style: theme.textTheme.bodyMedium,
            ),
          ] else
            Text(
              'Authenticated session active.',
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView.separated(
              itemCount: _features.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final feature = _features[index];
                return PlaceholderFeatureCard(
                  title: feature.title,
                  description: feature.description,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
