import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/progress_photo_constraints.dart';
import '../create_progress_photo_state.dart';

class CreateProgressPhotoForm extends StatelessWidget {
  const CreateProgressPhotoForm({
    required this.formKey,
    required this.state,
    required this.notesController,
    required this.onPickImage,
    required this.onClearImage,
    required this.onPickDate,
    required this.isSubmitting,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final CreateProgressPhotoState state;
  final TextEditingController notesController;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final VoidCallback onPickDate;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.previewPath == null)
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : onPickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Select from gallery'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Image.file(
                      File(state.previewPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : onPickImage,
                      child: const Text('Change image'),
                    ),
                    TextButton(
                      onPressed: isSubmitting ? null : onClearImage,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
                if (state.contentType != null && state.sizeBytes != null)
                  Text(
                    '${state.contentType} · ${_formatSize(state.sizeBytes!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Captured date'),
            subtitle: Text(
              state.capturedAt == null
                  ? 'Select a date'
                  : _formatDate(state.capturedAt!),
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: isSubmitting ? null : onPickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: notesController,
            enabled: !isSubmitting,
            maxLength: ProgressPhotoConstraints.maxNotesLength,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 4,
          ),
          if (state.uploadProgress != null && state.isBusy) ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(value: state.uploadProgress),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
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

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KiB';
}
