import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/progress_photo.dart';
import 'progress_photo_thumbnail.dart';

class ProgressPhotoCard extends StatelessWidget {
  const ProgressPhotoCard({
    required this.photo,
    required this.accessUrl,
    required this.isLoadingAccess,
    required this.accessError,
    required this.onTap,
    required this.onRetryAccess,
    super.key,
  });

  final ProgressPhoto photo;
  final String? accessUrl;
  final bool isLoadingAccess;
  final String? accessError;
  final VoidCallback onTap;
  final VoidCallback onRetryAccess;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(photo.capturedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ProgressPhotoThumbnail(
                accessUrl: accessUrl,
                isLoading: isLoadingAccess,
                errorMessage: accessError,
                onRetry: onRetryAccess,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (photo.notes != null && photo.notes!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      photo.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
