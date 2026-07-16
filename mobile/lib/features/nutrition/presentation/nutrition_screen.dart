import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'nutrition_controller.dart';
import 'nutrition_state.dart';
import 'widgets/nutrition_empty_view.dart';
import 'widgets/nutrition_error_view.dart';
import 'widgets/nutrition_log_card.dart';
import 'widgets/nutrition_summary_card.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  var _createdDuringVisit = false;

  void _handleBack() {
    context.pop(_createdDuringVisit ? true : null);
  }

  Future<void> _openCreate() async {
    final created = await context.push<bool>(AppRoutes.newNutritionLog);
    if (created == true && mounted) {
      setState(() => _createdDuringVisit = true);
      await ref.read(nutritionControllerProvider.notifier).reloadAfterCreate();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nutrition log saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nutritionControllerProvider);
    final controller = ref.read(nutritionControllerProvider.notifier);
    final showFab = state.status == NutritionStatus.loaded &&
        (state.data?.isEmpty == false);

    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: AppScaffold(
        title: 'Nutrition',
        onBack: _handleBack,
        floatingActionButton: showFab
            ? FloatingActionButton.extended(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              )
            : null,
        body: switch (state.status) {
          NutritionStatus.initial ||
          NutritionStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          NutritionStatus.failure => NutritionErrorView(
              message:
                  state.errorMessage ?? 'Nutrition logs could not be loaded.',
              onRetry: controller.retry,
            ),
          NutritionStatus.loaded => _NutritionContent(
              state: state,
              onRefresh: controller.refresh,
              onRetry: controller.retry,
              onRetrySummary: controller.retrySummary,
              onAdd: _openCreate,
            ),
        },
      ),
    );
  }
}

class _NutritionContent extends StatelessWidget {
  const _NutritionContent({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onRetrySummary,
    required this.onAdd,
  });

  final NutritionState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onRetrySummary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: const Key('nutrition-scroll-view'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isRefreshing) const LinearProgressIndicator(),
            if (state.errorMessage != null) ...[
              _RefreshErrorBanner(
                message: state.errorMessage!,
                onRetry: onRetry,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            NutritionSummaryCard(
              summary: data.summary,
              errorMessage: data.summaryError,
              onRetry: onRetrySummary,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: NutritionEmptyView(onAdd: onAdd),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('nutrition-scroll-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.isRefreshing) const LinearProgressIndicator(),
          if (state.errorMessage != null) ...[
            _RefreshErrorBanner(
              message: state.errorMessage!,
              onRetry: onRetry,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          NutritionSummaryCard(
            summary: data.summary,
            errorMessage: data.summaryError,
            onRetry: onRetrySummary,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.logs.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: NutritionLogCard(log: item),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({
    required this.message,
    required this.onRetry,
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
            Expanded(child: Text(message)),
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
