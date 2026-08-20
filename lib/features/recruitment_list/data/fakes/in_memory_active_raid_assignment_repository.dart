import '../../domain/entities/active_raid_assignment.dart';
import '../../domain/policies/participation_conflict_policy.dart';
import '../../domain/repositories/active_raid_assignment_repository.dart';

class InMemoryActiveRaidAssignmentRepository
    implements ActiveRaidAssignmentRepository {
  InMemoryActiveRaidAssignmentRepository({
    this.conflictPolicy = const ParticipationConflictPolicy(),
  });

  final ParticipationConflictPolicy conflictPolicy;
  final Map<String, ActiveRaidAssignment> _store = {};

  void seed(ActiveRaidAssignment assignment) {
    _store[assignment.characterRaidKey] = assignment;
  }

  @override
  Future<List<ActiveRaidAssignment>> getByUser(String userId) async =>
      List.unmodifiable(
        _store.values.where((assignment) => assignment.userId == userId),
      );

  @override
  Future<ActiveRaidAssignmentAcquireResult> acquire(
    ActiveRaidAssignment assignment,
  ) async {
    final decision = conflictPolicy.evaluate(
      proposed: assignment,
      activeAssignments: _store.values,
    );
    if (!decision.canConfirm) {
      return ActiveRaidAssignmentAcquireResult.rejected(decision);
    }
    _store[assignment.characterRaidKey] = assignment;
    return ActiveRaidAssignmentAcquireResult.acquired(assignment);
  }

  @override
  Future<ActiveRaidAssignmentAcquireResult> replace({
    required ActiveRaidAssignment current,
    required ActiveRaidAssignment replacement,
  }) async {
    final stored = _store[current.characterRaidKey];
    if (stored == null || stored.recruitmentId != current.recruitmentId) {
      return ActiveRaidAssignmentAcquireResult.rejected(
        const ParticipationConflictDecision([]),
      );
    }
    final remaining = _store.values
        .where((assignment) => assignment.characterRaidKey != current.characterRaidKey)
        .toList(growable: false);
    final decision = conflictPolicy.evaluate(
      proposed: replacement,
      activeAssignments: remaining,
    );
    if (!decision.canConfirm) {
      return ActiveRaidAssignmentAcquireResult.rejected(decision);
    }
    _store.remove(current.characterRaidKey);
    _store[replacement.characterRaidKey] = replacement;
    return ActiveRaidAssignmentAcquireResult.acquired(replacement);
  }

  @override
  Future<bool> release({
    required String userId,
    required String characterId,
    required String raidId,
    required String recruitmentId,
  }) async {
    final key = '$userId::$characterId::$raidId';
    final current = _store[key];
    if (current == null || current.recruitmentId != recruitmentId) return false;
    _store.remove(key);
    return true;
  }
}
