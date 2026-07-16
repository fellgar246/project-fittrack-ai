import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/data/models/authenticated_user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'dashboard_controller.dart';
import 'dashboard_state.dart';
import 'widgets/dashboard_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final dashboardState = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

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
      body: switch (dashboardState.status) {
        DashboardStatus.initial ||
        DashboardStatus.loading =>
          const DashboardLoadingView(),
        DashboardStatus.failure => DashboardErrorView(
            message: dashboardState.errorMessage ??
                'Dashboard data could not be loaded.',
            onRetry: controller.retry,
          ),
        DashboardStatus.loaded => _DashboardContent(
            state: dashboardState,
            user: authState.user,
            onRefresh: controller.refresh,
            onRetry: controller.retry,
            onRetryMeasurement: controller.retryMeasurement,
            onRetryRecommendation: controller.retryRecommendation,
            onOpenMeasurements: () => _openMeasurements(context, controller),
            onOpenNutrition: () => _openNutrition(context, controller),
            onOpenWorkouts: () => _openWorkouts(context, controller),
          ),
      },
    );
  }
}

Future<void> _openMeasurements(
  BuildContext context,
  DashboardController controller,
) async {
  final created = await context.push<bool>(AppRoutes.measurements);
  if (created == true) {
    await controller.refresh();
  }
}

Future<void> _openNutrition(
  BuildContext context,
  DashboardController controller,
) async {
  final created = await context.push<bool>(AppRoutes.nutrition);
  if (created == true) {
    await controller.refresh();
  }
}

Future<void> _openWorkouts(
  BuildContext context,
  DashboardController controller,
) async {
  final created = await context.push<bool>(AppRoutes.workouts);
  if (created == true) {
    await controller.refresh();
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.state,
    required this.user,
    required this.onRefresh,
    required this.onRetry,
    required this.onRetryMeasurement,
    required this.onRetryRecommendation,
    required this.onOpenMeasurements,
    required this.onOpenNutrition,
    required this.onOpenWorkouts,
  });

  final DashboardState state;
  final AuthenticatedUser? user;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onRetryMeasurement;
  final VoidCallback onRetryRecommendation;
  final Future<void> Function() onOpenMeasurements;
  final Future<void> Function() onOpenNutrition;
  final Future<void> Function() onOpenWorkouts;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('dashboard-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.isRefreshing) const LinearProgressIndicator(),
          DashboardHeader(user: user),
          const SizedBox(height: AppSpacing.lg),
          if (state.errorMessage != null) ...[
            RefreshErrorBanner(
              message: state.errorMessage!,
              onRetry: onRetry,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          WeeklyStatusCard(summary: data.weeklySummary),
          const SizedBox(height: AppSpacing.sm),
          ProgressSummaryCard(
            progress: data.measurement,
            errorMessage: data.measurementError,
            onRetry: onRetryMeasurement,
            onOpen: onOpenMeasurements,
          ),
          const SizedBox(height: AppSpacing.sm),
          RecommendationCard(
            recommendation: data.recommendation,
            errorMessage: data.recommendationError,
            isReady: data.weeklySummary.isReadyForRecommendation,
            onRetry: onRetryRecommendation,
            onOpen: () => context.push(AppRoutes.recommendations),
          ),
          const SizedBox(height: AppSpacing.lg),
          QuickActionsGrid(
            actions: [
              QuickAction(
                label: 'Measurements',
                icon: Icons.monitor_weight_outlined,
                onTap: onOpenMeasurements,
              ),
              QuickAction(
                label: 'Nutrition',
                icon: Icons.restaurant_outlined,
                onTap: onOpenNutrition,
              ),
              QuickAction(
                label: 'Workouts',
                icon: Icons.fitness_center,
                onTap: onOpenWorkouts,
              ),
              QuickAction(
                label: 'Weekly summary',
                icon: Icons.calendar_view_week_outlined,
                onTap: () => context.push(AppRoutes.weeklySummary),
              ),
              QuickAction(
                label: 'Recommendation',
                icon: Icons.auto_awesome,
                onTap: () => context.push(AppRoutes.recommendations),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
