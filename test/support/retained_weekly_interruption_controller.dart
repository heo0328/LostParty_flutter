import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';

/// Exercises retained legacy contracts without enabling production entry points.
class RetainedWeeklyInterruptionController
    extends CycleParticipationController {
  RetainedWeeklyInterruptionController({
    required super.gateway,
    required super.session,
    required super.changes,
    required super.scopeKey,
    super.now,
    super.onMutation,
  });

  bool enabled = true;

  @override
  bool get weeklyInterruptionEnabled => enabled;
}
