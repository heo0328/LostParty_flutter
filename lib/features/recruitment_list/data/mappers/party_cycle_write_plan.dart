class PartyCycleWritePlan {
  const PartyCycleWritePlan._();

  static Map<String, Object?> completedCycle({required String recruitmentId, required String cycleKey, required String completedByPlayerId, required List<Map<String, Object?>> memberSnapshot, required Object serverTimestamp}) => {
    'schemaVersion': 1, 'recruitmentId': recruitmentId, 'cycleKey': cycleKey,
    'status': 'completed', 'completedAt': serverTimestamp,
    'completedByPlayerId': completedByPlayerId, 'completionRevision': 1,
    'memberPlayerIds': memberSnapshot.map((member) => member['playerId']).toList(growable: false),
    'completedMemberSnapshot': memberSnapshot,
    'createdAt': serverTimestamp, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> incompleteCycle({required String recruitmentId, required String cycleKey, required List<Map<String, Object?>> memberSnapshot, required Object serverTimestamp}) => {
    'schemaVersion': 1, 'recruitmentId': recruitmentId, 'cycleKey': cycleKey,
    'status': 'incompleteEnded', 'completedAt': null,
    'completedByPlayerId': null, 'completionRevision': 1,
    'memberPlayerIds': memberSnapshot.map((member) => member['playerId']).toList(growable: false),
    'completedMemberSnapshot': memberSnapshot,
    'createdAt': serverTimestamp, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> recompleteCycle({required String completedByPlayerId, required int completionRevision, required List<Map<String, Object?>> memberSnapshot, required Object serverTimestamp}) => {
    'status': 'completed', 'completedAt': serverTimestamp,
    'completedByPlayerId': completedByPlayerId,
    'completionRevision': completionRevision + 1,
    'memberPlayerIds': memberSnapshot.map((member) => member['playerId']).toList(growable: false),
    'completedMemberSnapshot': memberSnapshot, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> endCancelledCycle({required int completionRevision, required List<Map<String, Object?>> memberSnapshot, required Object serverTimestamp}) => {
    'status': 'incompleteEnded', 'completedAt': null,
    'completedByPlayerId': null, 'completionRevision': completionRevision + 1,
    'memberPlayerIds': memberSnapshot.map((member) => member['playerId']).toList(growable: false),
    'completedMemberSnapshot': memberSnapshot, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> completeRecruitment({required bool continueTogether, required String completedByPlayerId, required int revision, required Object serverTimestamp}) => {
    'status': continueTogether ? 'active' : 'completed',
    'currentCycleStatus': 'completed',
    'manualRecruitmentEnabled': continueTogether,
    'completedAt': serverTimestamp, 'completedByPlayerId': completedByPlayerId,
    'revision': revision + 1, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> cancelCycle({required int completionRevision, required Object serverTimestamp}) => {
    'status': 'completionCancelled', 'completionRevision': completionRevision + 1,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> cancelRecruitment({required int revision, required bool hasAvailableSlot, required Object serverTimestamp}) => {
    'status': 'active', 'currentCycleStatus': 'active',
    'manualRecruitmentEnabled': true, 'hasAvailableSlot': hasAvailableSlot,
    'completedAt': null, 'completedByPlayerId': null,
    'revision': revision + 1, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> recurrence({required bool continueTogether, required int revision, required Object serverTimestamp}) => {
    'continueTogether': continueTogether,
    'revision': revision + 1, 'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> advanceRecruitment({required bool continueTogether, required String nextCycleKey, required DateTime nextStartedAt, required DateTime nextEndsAt, required int revision, required bool hasAvailableSlot, required Object serverTimestamp, required Object Function(DateTime) timestamp}) => continueTogether
      ? {
          'status': 'active', 'currentCycleStatus': 'active',
          'currentCycleKey': nextCycleKey, 'targetCycleKey': nextCycleKey,
          'cycleStartedAt': timestamp(nextStartedAt), 'cycleEndsAt': timestamp(nextEndsAt),
          'completedAt': null, 'completedByPlayerId': null,
          'hasAvailableSlot': hasAvailableSlot,
          'revision': revision + 1, 'updatedAt': serverTimestamp,
        }
      : {
          'status': 'incompleteEnded', 'currentCycleStatus': 'incompleteEnded',
          'manualRecruitmentEnabled': false, 'hasAvailableSlot': false,
          'revision': revision + 1, 'updatedAt': serverTimestamp,
        };
}
