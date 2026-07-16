import 'workout_log.dart';
import 'workout_plan.dart';

class WorkoutsData {
  const WorkoutsData({
    required this.plans,
    required this.logs,
    this.logsError,
  });

  final List<WorkoutPlan> plans;
  final List<WorkoutLog> logs;
  final String? logsError;

  bool get hasPlans => plans.isNotEmpty;
  bool get hasLogs => logs.isNotEmpty;

  WorkoutsData copyWith({
    List<WorkoutPlan>? plans,
    List<WorkoutLog>? logs,
    String? logsError,
    bool clearLogsError = false,
  }) {
    return WorkoutsData(
      plans: plans ?? this.plans,
      logs: logs ?? this.logs,
      logsError: clearLogsError ? null : logsError ?? this.logsError,
    );
  }
}
