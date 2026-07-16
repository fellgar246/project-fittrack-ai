import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/models/workout_plan.dart';
import '../../data/models/workout_plan_detail.dart';
import '../workout_form_validators.dart';

class CreateWorkoutLogForm extends StatelessWidget {
  const CreateWorkoutLogForm({
    required this.formKey,
    required this.plans,
    required this.planDetail,
    required this.selectedPlanId,
    required this.selectedDayId,
    required this.selectedExerciseId,
    required this.onPlanChanged,
    required this.onDayChanged,
    required this.onExerciseChanged,
    required this.performedAt,
    required this.onPickDate,
    required this.onPickTime,
    required this.setsController,
    required this.repsController,
    required this.weightController,
    required this.notesController,
    required this.isSubmitting,
    required this.isLoadingPlans,
    this.plansError,
    this.errorMessage,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final List<WorkoutPlan> plans;
  final WorkoutPlanDetail? planDetail;
  final String? selectedPlanId;
  final String? selectedDayId;
  final String? selectedExerciseId;
  final ValueChanged<String?> onPlanChanged;
  final ValueChanged<String?> onDayChanged;
  final ValueChanged<String?> onExerciseChanged;
  final DateTime performedAt;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final TextEditingController notesController;
  final bool isSubmitting;
  final bool isLoadingPlans;
  final String? plansError;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = planDetail?.days ?? const [];
    final selectedDay =
        days.where((day) => day.id == selectedDayId).firstOrNull;
    final exercises = selectedDay?.exercises ?? const [];

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoadingPlans)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (plansError != null)
            Text(
              plansError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else if (plans.isEmpty)
            Text(
              'No workout plans available. Create or assign a workout plan through the backend workflow first.',
              style: theme.textTheme.bodyMedium,
            )
          else ...[
            DropdownButtonFormField<String>(
              value: selectedPlanId,
              decoration: const InputDecoration(labelText: 'Workout plan'),
              items: plans
                  .map(
                    (plan) => DropdownMenuItem(
                      value: plan.id,
                      child: Text(plan.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isSubmitting ? null : onPlanChanged,
              validator: (value) =>
                  value == null ? 'Select a workout plan.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: selectedDayId,
              decoration: const InputDecoration(labelText: 'Day'),
              items: days
                  .map(
                    (day) => DropdownMenuItem(
                      value: day.id,
                      child: Text('${_dayLabel(day.dayOfWeek)} — ${day.title}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: isSubmitting || days.isEmpty ? null : onDayChanged,
              validator: (value) =>
                  value == null ? 'Select a workout day.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              value: selectedExerciseId,
              decoration: const InputDecoration(labelText: 'Exercise'),
              items: exercises
                  .map(
                    (exercise) => DropdownMenuItem(
                      value: exercise.id,
                      child: Text(exercise.name),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  isSubmitting || exercises.isEmpty ? null : onExerciseChanged,
              validator: (value) =>
                  value == null ? 'Select an exercise.' : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Performed date'),
            subtitle: Text(_formatDate(performedAt)),
            trailing: IconButton(
              onPressed: isSubmitting ? null : onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: 'Pick date',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Performed time'),
            subtitle: Text(_formatTime(performedAt)),
            trailing: IconButton(
              onPressed: isSubmitting ? null : onPickTime,
              icon: const Icon(Icons.access_time_outlined),
              tooltip: 'Pick time',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: setsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Sets',
              hintText: '3',
            ),
            validator: WorkoutFormValidators.requiredSets,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: repsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Reps',
              hintText: '10',
            ),
            validator: WorkoutFormValidators.requiredReps,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Weight (kg, optional)',
              hintText: 'Leave empty for bodyweight',
            ),
            validator: WorkoutFormValidators.optionalWeight,
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

String _dayLabel(int dayOfWeek) {
  return switch (dayOfWeek) {
    1 => 'Monday',
    2 => 'Tuesday',
    3 => 'Wednesday',
    4 => 'Thursday',
    5 => 'Friday',
    6 => 'Saturday',
    7 => 'Sunday',
    _ => 'Day $dayOfWeek',
  };
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
