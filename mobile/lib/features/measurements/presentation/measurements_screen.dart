import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'measurements_controller.dart';
import 'measurements_state.dart';
import 'widgets/measurement_card.dart';
import 'widgets/measurement_progress_card.dart';
import 'widgets/measurements_empty_view.dart';
import 'widgets/measurements_error_view.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  var _createdDuringVisit = false;

  void _handleBack() {
    context.pop(_createdDuringVisit ? true : null);
  }

  Future<void> _openCreate() async {
    final created = await context.push<bool>(AppRoutes.newMeasurement);
    if (created == true && mounted) {
      setState(() => _createdDuringVisit = true);
      await ref
          .read(measurementsControllerProvider.notifier)
          .reloadAfterCreate();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Measurement saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(measurementsControllerProvider);
    final controller = ref.read(measurementsControllerProvider.notifier);
    final showFab = state.status == MeasurementsStatus.loaded &&
        (state.data?.isEmpty == false);

    return AppScaffold(
      title: 'Measurements',
      onBack: _handleBack,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: switch (state.status) {
        MeasurementsStatus.initial ||
        MeasurementsStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        MeasurementsStatus.failure => MeasurementsErrorView(
            message: state.errorMessage ?? 'Measurements could not be loaded.',
            onRetry: controller.retry,
          ),
        MeasurementsStatus.loaded => _MeasurementsContent(
            state: state,
            onRefresh: controller.refresh,
            onRetry: controller.retry,
            onRetryProgress: controller.retryProgress,
            onAdd: _openCreate,
          ),
      },
    );
  }
}

class _MeasurementsContent extends StatelessWidget {
  const _MeasurementsContent({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onRetryProgress,
    required this.onAdd,
  });

  final MeasurementsState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onRetryProgress;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final data = state.data!;
    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          key: const Key('measurements-scroll-view'),
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
            MeasurementProgressCard(
              progress: data.progress,
              errorMessage: data.progressError,
              onRetry: onRetryProgress,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: MeasurementsEmptyView(onAdd: onAdd),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('measurements-scroll-view'),
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
          MeasurementProgressCard(
            progress: data.progress,
            errorMessage: data.progressError,
            onRetry: onRetryProgress,
          ),
          const SizedBox(height: AppSpacing.md),
          ...data.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: MeasurementCard(measurement: item),
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
