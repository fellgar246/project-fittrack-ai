import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/models/create_measurement_request.dart';
import 'create_measurement_controller.dart';
import 'measurement_form_validators.dart';
import 'widgets/measurement_form.dart';

class CreateMeasurementScreen extends ConsumerStatefulWidget {
  const CreateMeasurementScreen({super.key});

  @override
  ConsumerState<CreateMeasurementScreen> createState() =>
      _CreateMeasurementScreenState();
}

class _CreateMeasurementScreenState
    extends ConsumerState<CreateMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _bodyFatController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    ref.read(createMeasurementControllerProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final weight =
        MeasurementFormValidators.parsePositiveNumber(_weightController.text)!;
    final waistText = _waistController.text.trim();
    final bodyFatText = _bodyFatController.text.trim();
    final notesText = _notesController.text.trim();

    final request = CreateMeasurementRequest(
      date: _selectedDate,
      weight: weight,
      waist: waistText.isEmpty
          ? null
          : MeasurementFormValidators.parsePositiveNumber(waistText),
      bodyFatEstimate: bodyFatText.isEmpty
          ? null
          : MeasurementFormValidators.parseBodyFat(bodyFatText),
      notes: notesText.isEmpty ? null : notesText,
    );

    final measurement = await ref
        .read(createMeasurementControllerProvider.notifier)
        .submit(request);

    if (!mounted || measurement == null) {
      return;
    }

    ref.read(appRouterProvider).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createMeasurementControllerProvider);
    final isSubmitting = state.isSubmitting;

    return AppScaffold(
      title: 'Add measurement',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: MeasurementForm(
                formKey: _formKey,
                date: _selectedDate,
                onPickDate: _pickDate,
                weightController: _weightController,
                waistController: _waistController,
                bodyFatController: _bodyFatController,
                notesController: _notesController,
                isSubmitting: isSubmitting,
                errorMessage: state.errorMessage,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: isSubmitting ? null : _submit,
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save measurement'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: isSubmitting ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
