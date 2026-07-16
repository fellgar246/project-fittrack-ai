import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/models/create_workout_log_request.dart';
import '../data/models/workout_plan.dart';
import '../data/models/workout_plan_detail.dart';
import '../data/workouts_providers.dart';
import 'create_workout_log_controller.dart';
import 'workout_form_validators.dart';
import 'widgets/create_workout_log_form.dart';

class CreateWorkoutLogScreen extends ConsumerStatefulWidget {
  const CreateWorkoutLogScreen({
    this.initialPlanId,
    this.initialExerciseId,
    super.key,
  });

  final String? initialPlanId;
  final String? initialExerciseId;

  @override
  ConsumerState<CreateWorkoutLogScreen> createState() =>
      _CreateWorkoutLogScreenState();
}

class _CreateWorkoutLogScreenState
    extends ConsumerState<CreateWorkoutLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  List<WorkoutPlan> _plans = const [];
  WorkoutPlanDetail? _planDetail;
  String? _selectedPlanId;
  String? _selectedDayId;
  String? _selectedExerciseId;
  late DateTime _performedAt;
  var _isLoadingPlans = true;
  String? _plansError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _performedAt = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _selectedPlanId = widget.initialPlanId;
    _selectedExerciseId = widget.initialExerciseId;
    _loadPlans();
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });
    try {
      final plans =
          await ref.read(workoutsRepositoryProvider).getWorkoutPlans();
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = plans;
        _isLoadingPlans = false;
        if (_selectedPlanId == null && plans.isNotEmpty) {
          _selectedPlanId = plans.first.id;
        }
      });
      if (_selectedPlanId != null) {
        await _loadPlanDetail(_selectedPlanId!);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingPlans = false;
        _plansError = 'Workout plans could not be loaded. Try again.';
      });
    }
  }

  Future<void> _loadPlanDetail(String planId) async {
    try {
      final detail =
          await ref.read(workoutsRepositoryProvider).getWorkoutPlan(planId);
      if (!mounted) {
        return;
      }
      setState(() {
        _planDetail = detail;
        if (_selectedDayId == null ||
            !detail.days.any((day) => day.id == _selectedDayId)) {
          _selectedDayId = detail.days.isNotEmpty ? detail.days.first.id : null;
        }
        final selectedDay =
            detail.days.where((day) => day.id == _selectedDayId).firstOrNull;
        final exercises = selectedDay?.exercises ?? const [];
        if (_selectedExerciseId == null ||
            !exercises.any((item) => item.id == _selectedExerciseId)) {
          _selectedExerciseId =
              exercises.isNotEmpty ? exercises.first.id : null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _planDetail = null;
        _selectedDayId = null;
        _selectedExerciseId = null;
        _plansError = 'Workout plan details could not be loaded. Try again.';
      });
    }
  }

  Future<void> _onPlanChanged(String? planId) async {
    if (planId == null) {
      return;
    }
    setState(() {
      _selectedPlanId = planId;
      _selectedDayId = null;
      _selectedExerciseId = null;
      _planDetail = null;
    });
    await _loadPlanDetail(planId);
  }

  void _onDayChanged(String? dayId) {
    if (dayId == null || _planDetail == null) {
      return;
    }
    final day = _planDetail!.days.firstWhere((item) => item.id == dayId);
    setState(() {
      _selectedDayId = dayId;
      _selectedExerciseId =
          day.exercises.isNotEmpty ? day.exercises.first.id : null;
    });
  }

  void _onExerciseChanged(String? exerciseId) {
    setState(() => _selectedExerciseId = exerciseId);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _performedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _performedAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _performedAt.hour,
          _performedAt.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_performedAt),
    );
    if (picked != null) {
      setState(() {
        _performedAt = DateTime(
          _performedAt.year,
          _performedAt.month,
          _performedAt.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    ref.read(createWorkoutLogControllerProvider.notifier).clearError();

    if (_plans.isEmpty || _selectedExerciseId == null) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sets = WorkoutFormValidators.parsePositiveInt(_setsController.text)!;
    final reps = WorkoutFormValidators.parsePositiveInt(_repsController.text)!;
    final weightText = _weightController.text.trim();
    final weight = weightText.isEmpty
        ? null
        : WorkoutFormValidators.parseNonNegativeNumber(weightText);
    final notesText = _notesController.text.trim();

    final request = CreateWorkoutLogRequest(
      exerciseId: _selectedExerciseId!,
      performedAt: _performedAt,
      sets: sets,
      reps: reps,
      weight: weight,
      notes: notesText.isEmpty ? null : notesText,
    );

    final log = await ref
        .read(createWorkoutLogControllerProvider.notifier)
        .submit(request);

    if (!mounted || log == null) {
      return;
    }

    ref.read(appRouterProvider).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createWorkoutLogControllerProvider);
    final isSubmitting = state.isSubmitting;

    return AppScaffold(
      title: 'Log exercise',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: CreateWorkoutLogForm(
                formKey: _formKey,
                plans: _plans,
                planDetail: _planDetail,
                selectedPlanId: _selectedPlanId,
                selectedDayId: _selectedDayId,
                selectedExerciseId: _selectedExerciseId,
                onPlanChanged: _onPlanChanged,
                onDayChanged: _onDayChanged,
                onExerciseChanged: _onExerciseChanged,
                performedAt: _performedAt,
                onPickDate: _pickDate,
                onPickTime: _pickTime,
                setsController: _setsController,
                repsController: _repsController,
                weightController: _weightController,
                notesController: _notesController,
                isSubmitting: isSubmitting,
                isLoadingPlans: _isLoadingPlans,
                plansError: _plansError,
                errorMessage: state.errorMessage,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: isSubmitting || _plans.isEmpty ? null : _submit,
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save workout log'),
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
