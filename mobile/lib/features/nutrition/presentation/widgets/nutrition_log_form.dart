import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../nutrition_form_validators.dart';

class NutritionLogForm extends StatelessWidget {
  const NutritionLogForm({
    required this.formKey,
    required this.date,
    required this.onPickDate,
    required this.caloriesController,
    required this.proteinController,
    required this.carbsController,
    required this.fatsController,
    required this.notesController,
    required this.isSubmitting,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final DateTime date;
  final VoidCallback onPickDate;
  final TextEditingController caloriesController;
  final TextEditingController proteinController;
  final TextEditingController carbsController;
  final TextEditingController fatsController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Log date'),
            subtitle: Text(_formatDate(date)),
            trailing: IconButton(
              onPressed: isSubmitting ? null : onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: 'Pick date',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: caloriesController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Calories',
              hintText: '2100',
            ),
            validator: NutritionFormValidators.requiredCalories,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: proteinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Protein (g)',
              hintText: '130',
            ),
            validator: NutritionFormValidators.requiredProtein,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: carbsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Carbs (g)',
              hintText: '250',
            ),
            validator: NutritionFormValidators.requiredCarbs,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: fatsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Fats (g)',
              hintText: '65',
            ),
            validator: NutritionFormValidators.requiredFats,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: notesController,
            textInputAction: TextInputAction.done,
            enabled: !isSubmitting,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
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
