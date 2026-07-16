import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/models/create_nutrition_log_request.dart';
import 'create_nutrition_log_controller.dart';
import 'nutrition_form_validators.dart';
import 'widgets/nutrition_log_form.dart';

class CreateNutritionLogScreen extends ConsumerStatefulWidget {
  const CreateNutritionLogScreen({super.key});

  @override
  ConsumerState<CreateNutritionLogScreen> createState() =>
      _CreateNutritionLogScreenState();
}

class _CreateNutritionLogScreenState
    extends ConsumerState<CreateNutritionLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
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
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
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
    ref.read(createNutritionLogControllerProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final calories =
        NutritionFormValidators.parseNonNegativeInt(_caloriesController.text)!;
    final protein = NutritionFormValidators.parseNonNegativeNumber(
        _proteinController.text)!;
    final carbs =
        NutritionFormValidators.parseNonNegativeNumber(_carbsController.text)!;
    final fats =
        NutritionFormValidators.parseNonNegativeNumber(_fatsController.text)!;
    final notesText = _notesController.text.trim();

    final request = CreateNutritionLogRequest(
      date: _selectedDate,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
      notes: notesText.isEmpty ? null : notesText,
    );

    final log = await ref
        .read(createNutritionLogControllerProvider.notifier)
        .submit(request);

    if (!mounted || log == null) {
      return;
    }

    ref.read(appRouterProvider).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createNutritionLogControllerProvider);
    final isSubmitting = state.isSubmitting;

    return AppScaffold(
      title: 'Add nutrition log',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: NutritionLogForm(
                formKey: _formKey,
                date: _selectedDate,
                onPickDate: _pickDate,
                caloriesController: _caloriesController,
                proteinController: _proteinController,
                carbsController: _carbsController,
                fatsController: _fatsController,
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
                : const Text('Save nutrition log'),
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
