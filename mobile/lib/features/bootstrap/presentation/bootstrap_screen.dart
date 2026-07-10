import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';

class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'FitTrack AI',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Backend & cloud ready',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Flutter mobile foundation',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(
            label: 'Environment',
            value: config.environment.displayName,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoRow(
            label: 'API',
            value: 'configured',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            config.apiBaseUrl.toString(),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'This screen validates app startup, environment configuration, theme, '
            'and navigation. Feature flows arrive in later blocks.',
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Open login'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.dashboard),
            child: const Text('Open dashboard'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.labelLarge,
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
