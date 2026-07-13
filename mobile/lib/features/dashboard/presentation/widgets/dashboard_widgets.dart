import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/authenticated_user.dart';
import '../../../measurements/data/models/measurement_progress.dart';
import '../../data/models/recommendation_summary.dart';
import '../../data/models/weekly_summary.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({required this.user, super.key});

  final AuthenticatedUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim().split(RegExp(r'\s+')).first
        : user?.email ?? 'there';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, $displayName', style: theme.textTheme.headlineMedium),
        if (user?.goal.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Goal: ${user!.goal}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class DashboardLoadingView extends StatelessWidget {
  const DashboardLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Loading your fitness overview…'),
        ],
      ),
    );
  }
}

class DashboardErrorView extends StatelessWidget {
  const DashboardErrorView({
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
                'Dashboard unavailable',
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

class RefreshErrorBanner extends StatelessWidget {
  const RefreshErrorBanner({
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

class WeeklyStatusCard extends StatelessWidget {
  const WeeklyStatusCard({required this.summary, super.key});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = summary.isReadyForRecommendation;
    return _DashboardCard(
      title: 'This week',
      subtitle: '${_shortDate(summary.weekStart)} – '
          '${_shortDate(summary.weekEnd)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle_outline : Icons.pending_outlined,
                color: ready
                    ? theme.colorScheme.primary
                    : theme.colorScheme.tertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ready ? 'Ready for recommendation' : 'More data needed',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricChip(
                icon: Icons.fitness_center,
                label: '${summary.workoutLogs} workout logs',
              ),
              _MetricChip(
                icon: Icons.restaurant_outlined,
                label: '${summary.nutritionDaysLogged} nutrition days',
              ),
              _MetricChip(
                icon: Icons.monitor_weight_outlined,
                label: '${summary.measurements.measurementsCount} measurements',
              ),
            ],
          ),
          if (!ready && summary.missingData.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Still needed: ${summary.missingData.map(_missingLabel).join(', ')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProgressSummaryCard extends StatelessWidget {
  const ProgressSummaryCard({
    this.progress,
    this.errorMessage,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  final MeasurementProgress? progress;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _SectionErrorCard(
        title: 'Progress',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    final data = progress;
    if (data == null || data.isEmpty) {
      return _DashboardCard(
        title: 'Progress',
        child: _EmptySection(
          icon: Icons.monitor_weight_outlined,
          title: 'No measurements yet',
          message: 'Start tracking your progress.',
          actionLabel: 'Measurements',
          onAction: onOpen,
        ),
      );
    }

    return _DashboardCard(
      title: 'Recent progress',
      subtitle: data.endDate == null
          ? null
          : 'Latest measurement ${_shortDate(data.endDate!)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              if (data.endWeight != null)
                _ValueLabel(
                  value: '${_number(data.endWeight!)} kg',
                  label: 'Weight',
                ),
              if (data.endWaist != null)
                _ValueLabel(
                  value: '${_number(data.endWaist!)} cm',
                  label: 'Waist',
                ),
              if (data.endBodyFatEstimate != null)
                _ValueLabel(
                  value: '${_number(data.endBodyFatEstimate!)}%',
                  label: 'Body fat',
                ),
            ],
          ),
          if (data.measurementsCount > 1 && data.weightChange != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Weight change: ${_signedNumber(data.weightChange!)} kg',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    required this.isReady,
    this.recommendation,
    this.errorMessage,
    required this.onRetry,
    required this.onOpen,
    super.key,
  });

  final bool isReady;
  final RecommendationSummary? recommendation;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return _SectionErrorCard(
        title: 'Weekly recommendation',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }
    final data = recommendation;
    if (data == null) {
      return _DashboardCard(
        title: 'Weekly recommendation',
        child: _EmptySection(
          icon: isReady ? Icons.auto_awesome : Icons.hourglass_empty,
          title: 'No weekly recommendation yet',
          message: isReady
              ? 'Your weekly data is ready. Recommendation generation is '
                  'available in a later flow.'
              : 'Add enough weekly data to become ready.',
          actionLabel: 'View recommendation',
          onAction: onOpen,
        ),
      );
    }

    return _DashboardCard(
      title: 'Weekly recommendation',
      subtitle: 'Week of ${_shortDate(data.weekStart)} · AI-powered guidance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.summary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(data.recommendation),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onOpen,
            child: const Text('View details'),
          ),
        ],
      ),
    );
  }
}

class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 76,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return Semantics(
              button: true,
              label: 'Open ${action.label}',
              child: OutlinedButton.icon(
                onPressed: action.onTap,
                icon: Icon(action.icon),
                label: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ValueLabel extends StatelessWidget {
  const _ValueLabel({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(message),
              const SizedBox(height: AppSpacing.xs),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionErrorCard extends StatelessWidget {
  const _SectionErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      title: title,
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
  return '${months[date.month - 1]} ${date.day}';
}

String _missingLabel(String value) {
  switch (value) {
    case 'workout_logs':
      return 'a workout log';
    case 'nutrition_logs':
      return 'nutrition logs';
    case 'body_measurements':
      return 'a measurement';
    default:
      return value.replaceAll('_', ' ');
  }
}

String _number(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _signedNumber(double value) {
  final formatted = _number(value);
  return value > 0 ? '+$formatted' : formatted;
}
