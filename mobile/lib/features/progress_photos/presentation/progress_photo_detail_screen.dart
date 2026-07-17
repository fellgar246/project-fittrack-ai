import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/api_exception.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/progress_photo.dart';
import '../data/progress_photos_providers.dart';
import 'widgets/progress_photo_thumbnail.dart';

class ProgressPhotoDetailScreen extends ConsumerStatefulWidget {
  const ProgressPhotoDetailScreen({
    required this.photoId,
    this.initialPhoto,
    super.key,
  });

  final String photoId;
  final ProgressPhoto? initialPhoto;

  @override
  ConsumerState<ProgressPhotoDetailScreen> createState() =>
      _ProgressPhotoDetailScreenState();
}

class _ProgressPhotoDetailScreenState
    extends ConsumerState<ProgressPhotoDetailScreen> {
  ProgressPhoto? _photo;
  String? _accessUrl;
  String? _errorMessage;
  var _isLoading = true;
  var _isLoadingAccess = false;
  var _retriedOnce = false;

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _photo == null;
      _errorMessage = null;
    });

    try {
      if (_photo == null) {
        final photos =
            await ref.read(progressPhotosRepositoryProvider).listPhotos();
        ProgressPhoto? found;
        for (final item in photos) {
          if (item.id == widget.photoId) {
            found = item;
            break;
          }
        }
        _photo = found;
        if (_photo == null) {
          if (mounted) {
            context.pop();
          }
          return;
        }
      }
      await _loadAccess(forceRefresh: false);
    } catch (error) {
      if (error is UnauthorizedException) {
        await ref.read(authControllerProvider.notifier).logout();
        return;
      }
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Progress photo could not be loaded.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAccess({required bool forceRefresh}) async {
    if (_photo == null) {
      return;
    }
    setState(() {
      _isLoadingAccess = true;
      _errorMessage = null;
    });

    final repository = ref.read(progressPhotosRepositoryProvider);
    if (forceRefresh) {
      repository.invalidatePhotoAccess(_photo!.id);
    }

    try {
      final url = await repository.getPhotoAccessUrl(_photo!.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _accessUrl = url;
        _isLoading = false;
        _isLoadingAccess = false;
      });
    } catch (error) {
      if (error is UnauthorizedException) {
        await ref.read(authControllerProvider.notifier).logout();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Image access could not be loaded.';
        _isLoading = false;
        _isLoadingAccess = false;
      });
    }
  }

  Future<void> _retryAccess() async {
    if (_retriedOnce) {
      await _loadAccess(forceRefresh: true);
      return;
    }
    _retriedOnce = true;
    await _loadAccess(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _photo == null) {
      return const AppScaffold(
        title: 'Progress photo',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final photo = _photo;
    if (photo == null) {
      return const AppScaffold(
        title: 'Progress photo',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AppScaffold(
      title: 'Progress photo',
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ProgressPhotoThumbnail(
              accessUrl: _accessUrl,
              isLoading: _isLoadingAccess,
              errorMessage: _errorMessage,
              onRetry: _retryAccess,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Captured ${_formatDate(photo.capturedAt)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (photo.confirmedAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Uploaded ${_formatDateTime(photo.confirmedAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (photo.notes != null && photo.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    photo.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Progress photos are private to your account.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDateTime(DateTime value) {
  return '${_formatDate(value)} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
