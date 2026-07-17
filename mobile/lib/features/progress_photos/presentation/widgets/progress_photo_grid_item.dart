import 'package:flutter/material.dart';

import '../../data/models/progress_photo.dart';
import 'progress_photo_card.dart';

class ProgressPhotoGridItem extends StatefulWidget {
  const ProgressPhotoGridItem({
    required this.photo,
    required this.accessUrl,
    required this.isLoadingAccess,
    required this.accessError,
    required this.onTap,
    required this.onRetryAccess,
    required this.onRequestAccess,
    super.key,
  });

  final ProgressPhoto photo;
  final String? accessUrl;
  final bool isLoadingAccess;
  final String? accessError;
  final VoidCallback onTap;
  final VoidCallback onRetryAccess;
  final VoidCallback onRequestAccess;

  @override
  State<ProgressPhotoGridItem> createState() => _ProgressPhotoGridItemState();
}

class _ProgressPhotoGridItemState extends State<ProgressPhotoGridItem> {
  @override
  void initState() {
    super.initState();
    _scheduleAccessRequest();
  }

  @override
  void didUpdateWidget(covariant ProgressPhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id ||
        (oldWidget.accessUrl == null && widget.accessUrl == null)) {
      _scheduleAccessRequest();
    }
  }

  void _scheduleAccessRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onRequestAccess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProgressPhotoCard(
      photo: widget.photo,
      accessUrl: widget.accessUrl,
      isLoadingAccess: widget.isLoadingAccess,
      accessError: widget.accessError,
      onTap: widget.onTap,
      onRetryAccess: widget.onRetryAccess,
    );
  }
}
