import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/progress_photos_repository.dart';
import 'create_progress_photo_controller.dart';
import 'widgets/create_progress_photo_form.dart';

class CreateProgressPhotoScreen extends ConsumerStatefulWidget {
  const CreateProgressPhotoScreen({super.key});

  @override
  ConsumerState<CreateProgressPhotoScreen> createState() =>
      _CreateProgressPhotoScreenState();
}

class _CreateProgressPhotoScreenState
    extends ConsumerState<CreateProgressPhotoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final controller = ref.read(createProgressPhotoControllerProvider.notifier);
    controller.setSelecting();

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (!mounted || picked == null) {
      return;
    }

    try {
      final file = controller.validatePickedFile(
        path: picked.path,
        reportedMimeType: picked.mimeType,
      );
      controller.setSelectedFile(file);
    } on ProgressPhotoValidationFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  Future<void> _pickDate() async {
    final state = ref.read(createProgressPhotoControllerProvider);
    final initial = state.capturedAt ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(createProgressPhotoControllerProvider.notifier).setCapturedDate(
            DateTime(picked.year, picked.month, picked.day),
          );
    }
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    final state = ref.read(createProgressPhotoControllerProvider);
    if (!state.isBusy) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload in progress'),
        content: const Text(
          'Leaving now may interrupt the upload. Continue anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(createProgressPhotoControllerProvider.notifier);
    controller.clearError();
    controller.setNotes(
      _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final success = await controller.submit();
    if (!mounted || !success) {
      return;
    }
    ref.read(appRouterProvider).pop(true);
  }

  Future<void> _retryConfirm() async {
    final controller = ref.read(createProgressPhotoControllerProvider.notifier);
    final success = await controller.retryConfirm();
    if (!mounted || !success) {
      return;
    }
    ref.read(appRouterProvider).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createProgressPhotoControllerProvider);
    final isSubmitting = state.isBusy;

    return WillPopScope(
      onWillPop: () async {
        if (!isSubmitting) {
          return true;
        }
        return _confirmDiscardIfNeeded();
      },
      child: AppScaffold(
        title: 'Add progress photo',
        onBack: () async {
          if (await _confirmDiscardIfNeeded() && context.mounted) {
            context.pop();
          }
        },
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: CreateProgressPhotoForm(
                  formKey: _formKey,
                  state: state,
                  notesController: _notesController,
                  onPickImage: _pickImage,
                  onClearImage: () => ref
                      .read(createProgressPhotoControllerProvider.notifier)
                      .clearSelection(),
                  onPickDate: _pickDate,
                  isSubmitting: isSubmitting,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.canRetryConfirm)
              FilledButton(
                onPressed: isSubmitting ? null : _retryConfirm,
                child: const Text('Retry confirmation'),
              )
            else
              FilledButton(
                onPressed: state.canSubmit && !isSubmitting ? _submit : null,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload photo'),
              ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (await _confirmDiscardIfNeeded() && context.mounted) {
                        context.pop();
                      }
                    },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
