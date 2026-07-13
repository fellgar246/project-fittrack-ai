import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../measurement_form_validators.dart';

class MeasurementForm extends StatelessWidget {
  const MeasurementForm({
    required this.formKey,
    required this.date,
    required this.onPickDate,
    required this.weightController,
    required this.waistController,
    required this.bodyFatController,
    required this.notesController,
    required this.isSubmitting,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final DateTime date;
  final VoidCallback onPickDate;
  final TextEditingController weightController;
  final TextEditingController waistController;
  final TextEditingController bodyFatController;
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
            title: const Text('Measurement date'),
            subtitle: Text(_formatDate(date)),
            trailing: IconButton(
              onPressed: isSubmitting ? null : onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: 'Pick date',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Weight (kg)',
              hintText: '70.0',
            ),
            validator: MeasurementFormValidators.requiredWeight,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: waistController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Waist (cm, optional)',
              hintText: '80.0',
            ),
            validator: MeasurementFormValidators.optionalWaist,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: bodyFatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Body fat estimate (%, optional)',
              hintText: '20.0',
            ),
            validator: MeasurementFormValidators.optionalBodyFat,
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
