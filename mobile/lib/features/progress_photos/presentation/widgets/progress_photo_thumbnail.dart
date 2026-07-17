import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';

class ProgressPhotoThumbnail extends StatefulWidget {
  const ProgressPhotoThumbnail({
    required this.accessUrl,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String? accessUrl;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  State<ProgressPhotoThumbnail> createState() => _ProgressPhotoThumbnailState();
}

class _ProgressPhotoThumbnailState extends State<ProgressPhotoThumbnail> {
  var _imageFailed = false;

  @override
  void didUpdateWidget(covariant ProgressPhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessUrl != widget.accessUrl) {
      _imageFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.errorMessage != null || _imageFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.errorMessage ?? 'Image unavailable.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (widget.accessUrl == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Image.network(
      widget.accessUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_imageFailed) {
            setState(() => _imageFailed = true);
          }
        });
        return const Center(child: Icon(Icons.broken_image_outlined));
      },
    );
  }
}
