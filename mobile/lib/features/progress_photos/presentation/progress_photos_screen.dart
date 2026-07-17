import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/models/progress_photo.dart';
import 'progress_photos_controller.dart';
import 'progress_photos_state.dart';
import 'widgets/progress_photo_grid_item.dart';
import 'widgets/progress_photos_empty_view.dart';
import 'widgets/progress_photos_error_view.dart';

class ProgressPhotosScreen extends ConsumerStatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  ConsumerState<ProgressPhotosScreen> createState() =>
      _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends ConsumerState<ProgressPhotosScreen> {
  var _createdDuringVisit = false;

  void _handleBack() {
    context.pop(_createdDuringVisit ? true : null);
  }

  Future<void> _openCreate() async {
    final created = await context.push<bool>(AppRoutes.newProgressPhoto);
    if (created == true && mounted) {
      setState(() => _createdDuringVisit = true);
      await ref
          .read(progressPhotosControllerProvider.notifier)
          .reloadAfterCreate();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress photo saved.')),
      );
    }
  }

  void _openDetail(ProgressPhoto photo) {
    context.push(AppRoutes.progressPhotoDetail(photo.id), extra: photo);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(progressPhotosControllerProvider);
    final controller = ref.read(progressPhotosControllerProvider.notifier);
    final showFab =
        state.status == ProgressPhotosStatus.loaded && state.photos.isNotEmpty;

    return AppScaffold(
      title: 'Progress photos',
      onBack: _handleBack,
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
      body: switch (state.status) {
        ProgressPhotosStatus.initial ||
        ProgressPhotosStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        ProgressPhotosStatus.failure => ProgressPhotosErrorView(
            message:
                state.errorMessage ?? 'Progress photos could not be loaded.',
            onRetry: controller.retry,
          ),
        ProgressPhotosStatus.loaded => _ProgressPhotosContent(
            state: state,
            onRefresh: controller.refresh,
            onRetry: controller.retry,
            onAdd: _openCreate,
            onOpenDetail: _openDetail,
            onEnsureAccess: controller.ensurePhotoAccess,
            onRetryAccess: controller.retryPhotoAccess,
          ),
      },
    );
  }
}

class _ProgressPhotosContent extends StatelessWidget {
  const _ProgressPhotosContent({
    required this.state,
    required this.onRefresh,
    required this.onRetry,
    required this.onAdd,
    required this.onOpenDetail,
    required this.onEnsureAccess,
    required this.onRetryAccess,
  });

  final ProgressPhotosState state;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onAdd;
  final void Function(ProgressPhoto photo) onOpenDetail;
  final Future<void> Function(String photoId) onEnsureAccess;
  final Future<void> Function(String photoId) onRetryAccess;

  @override
  Widget build(BuildContext context) {
    if (state.photos.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (state.isRefreshing) const LinearProgressIndicator(),
            if (state.errorMessage != null)
              _RefreshErrorBanner(
                message: state.errorMessage!,
                onRetry: onRetry,
              ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: ProgressPhotosEmptyView(onAdd: onAdd),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (state.isRefreshing)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Progress photos are private to your account.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _RefreshErrorBanner(
                  message: state.errorMessage!,
                  onRetry: onRetry,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final photo = state.photos[index];
                  return ProgressPhotoGridItem(
                    photo: photo,
                    accessUrl: state.accessUrls[photo.id],
                    isLoadingAccess: state.loadingAccess.contains(photo.id),
                    accessError: state.accessErrors[photo.id],
                    onTap: () => onOpenDetail(photo),
                    onRetryAccess: () => onRetryAccess(photo.id),
                    onRequestAccess: () => onEnsureAccess(photo.id),
                  );
                },
                childCount: state.photos.length,
              ),
            ),
          ),
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
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
