import '../../domain/entities/party_atomic_command.dart';
import 'party_atomic_membership_write_plan.dart';

class PartyAtomicApplicationWritePlan {
  PartyAtomicApplicationWritePlan.apply({
    required Map<String, Object?> application,
    required PartyCommandAggregate aggregate,
    required String applicantPlayerId,
    required bool applicantIsGroupMember,
    required Object serverTimestamp,
  }) : application = Map.unmodifiable({
         ...application,
         'countedAsNonGroupApplicant':
             aggregate.groupId != null && !applicantIsGroupMember,
       }),
       recruitmentPatch = _pendingPatch(
         aggregate: aggregate,
         countedAsNonGroupApplicant:
             aggregate.groupId != null && !applicantIsGroupMember,
         delta: 1,
         serverTimestamp: serverTimestamp,
       ),
       event = _event(
         aggregate: aggregate,
         applicantPlayerId: applicantPlayerId,
         type: 'applicationSubmitted',
         serverTimestamp: serverTimestamp,
       ) {
    _validateActive(aggregate);
    if (aggregate.partySlots.any(
      (slot) => slot.playerId == applicantPlayerId,
    )) {
      throw StateError('이미 참가 중인 Player는 신청할 수 없습니다.');
    }
  }

  PartyAtomicApplicationWritePlan.withdraw({
    required this.application,
    required PartyCommandAggregate aggregate,
    required String applicantPlayerId,
    required Object serverTimestamp,
  }) : recruitmentPatch = _pendingPatch(
         aggregate: aggregate,
         countedAsNonGroupApplicant: _countedAsNonGroup(application),
         delta: -1,
         serverTimestamp: serverTimestamp,
       ),
       event = _event(
         aggregate: aggregate,
         applicantPlayerId: applicantPlayerId,
         type: 'applicationWithdrawn',
         serverTimestamp: serverTimestamp,
       ) {
    _validateActive(aggregate);
    if (aggregate.pendingApplicationCount <= 0) {
      throw StateError('철회할 pending 신청 집계가 없습니다.');
    }
  }

  final Map<String, Object?> application;
  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> event;

  static void _validateActive(PartyCommandAggregate aggregate) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.currentCycleStatus != PartyRaidStateStatus.active ||
        aggregate.memberCount >= 8) {
      throw StateError('현재 모집에는 신청할 수 없습니다.');
    }
  }

  static Map<String, Object?> _pendingPatch({
    required PartyCommandAggregate aggregate,
    required bool countedAsNonGroupApplicant,
    required int delta,
    required Object serverTimestamp,
  }) {
    final pending = aggregate.pendingApplicationCount + delta;
    final pendingNonGroup =
        aggregate.pendingNonGroupApplicantCount +
        (countedAsNonGroupApplicant ? delta : 0);
    if (pending < 0 || pendingNonGroup < 0 || pendingNonGroup > pending) {
      throw StateError('신청 Aggregate 집계가 올바르지 않습니다.');
    }
    return Map.unmodifiable({
      'pendingApplicationCount': pending,
      'pendingNonGroupApplicantCount': pendingNonGroup,
      'revision': aggregate.revision + 1,
      'updatedAt': serverTimestamp,
    });
  }

  static bool _countedAsNonGroup(Map<String, Object?> application) {
    final value = application['countedAsNonGroupApplicant'];
    if (value is! bool) {
      throw const FormatException('신청 당시 그룹 집계 Snapshot이 없습니다.');
    }
    return value;
  }

  static Map<String, Object?> _event({
    required PartyCommandAggregate aggregate,
    required String applicantPlayerId,
    required String type,
    required Object serverTimestamp,
  }) {
    final revision = aggregate.revision + 1;
    final eventId = '${type}_${aggregate.recruitmentId}_$revision';
    return Map.unmodifiable({
      'schemaVersion': 1,
      'eventId': eventId,
      'recruitmentId': aggregate.recruitmentId,
      'type': type,
      'commandId': eventId,
      'commandRevision': revision,
      'audiencePlayerIds': {
        aggregate.leaderPlayerId,
        applicantPlayerId,
      }.toList(growable: false),
      'actorPlayerId': applicantPlayerId,
      'occurredAt': serverTimestamp,
    });
  }
}

class PartyAtomicApplicationRejectWritePlan {
  PartyAtomicApplicationRejectWritePlan({
    required Map<String, Object?> application,
    required PartyCommandAggregate aggregate,
    required String applicantPlayerId,
    required String actorPlayerId,
    required int applicationRevision,
    required Object serverTimestamp,
  }) : recruitmentPatch = PartyAtomicApplicationWritePlan._pendingPatch(
         aggregate: aggregate,
         countedAsNonGroupApplicant:
             PartyAtomicApplicationWritePlan._countedAsNonGroup(application),
         delta: -1,
         serverTimestamp: serverTimestamp,
       ),
       applicationPatch = Map.unmodifiable({
         'status': 'rejected',
         'resolutionReason': 'rejectedByApprover',
         'rejectionCount': (application['rejectionCount'] as int? ?? 0) + 1,
         'revision': applicationRevision + 1,
         'decidedAt': serverTimestamp,
         'updatedAt': serverTimestamp,
       }),
       event = _rejectEvent(
         aggregate: aggregate,
         applicantPlayerId: applicantPlayerId,
         actorPlayerId: actorPlayerId,
         serverTimestamp: serverTimestamp,
       ) {
    PartyAtomicApplicationWritePlan._validateActive(aggregate);
    if (aggregate.pendingApplicationCount <= 0) {
      throw StateError('거절할 pending 신청 집계가 없습니다.');
    }
  }

  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> applicationPatch;
  final Map<String, Object?> event;

  static Map<String, Object?> _rejectEvent({
    required PartyCommandAggregate aggregate,
    required String applicantPlayerId,
    required String actorPlayerId,
    required Object serverTimestamp,
  }) {
    final revision = aggregate.revision + 1;
    final eventId = 'applicationRejected_${aggregate.recruitmentId}_$revision';
    return Map.unmodifiable({
      'schemaVersion': 1,
      'eventId': eventId,
      'recruitmentId': aggregate.recruitmentId,
      'type': 'applicationRejected',
      'commandId': eventId,
      'commandRevision': revision,
      'audiencePlayerIds': {
        aggregate.leaderPlayerId,
        applicantPlayerId,
      }.toList(growable: false),
      'actorPlayerId': actorPlayerId,
      'occurredAt': serverTimestamp,
    });
  }
}

class PartyAtomicApprovalWritePlan {
  PartyAtomicApprovalWritePlan({
    required PartyAtomicJoinWritePlan join,
    required PartyCommandAggregate aggregate,
    required bool applicantCountedAsNonGroup,
    required int applicationRevision,
    required Object serverTimestamp,
  }) : membership = join.membership,
       raidState = join.raidState,
       raidStateId = join.raidStateId,
       event = join.event,
       recruitmentPatch = _recruitmentPatch(
         join: join,
         aggregate: aggregate,
         applicantCountedAsNonGroup: applicantCountedAsNonGroup,
       ),
       applicationPatch = Map.unmodifiable({
         'status': 'approved',
         'resolutionReason': 'approved',
         'revision': applicationRevision + 1,
         'decidedAt': serverTimestamp,
         'updatedAt': serverTimestamp,
       }) {
    if (aggregate.pendingApplicationCount <= 0) {
      throw StateError('승인할 pending 신청 집계가 없습니다.');
    }
  }

  final Map<String, Object?> recruitmentPatch;
  final Map<String, Object?> applicationPatch;
  final Map<String, Object?> membership;
  final Map<String, Object?> raidState;
  final Map<String, Object?> event;
  final String raidStateId;

  static Map<String, Object?> _recruitmentPatch({
    required PartyAtomicJoinWritePlan join,
    required PartyCommandAggregate aggregate,
    required bool applicantCountedAsNonGroup,
  }) {
    final pendingNonGroup =
        aggregate.pendingNonGroupApplicantCount -
        (applicantCountedAsNonGroup ? 1 : 0);
    if (pendingNonGroup < 0) {
      throw StateError('비그룹 신청 집계가 올바르지 않습니다.');
    }
    return Map.unmodifiable({
      ...join.recruitmentPatch,
      'pendingApplicationCount': aggregate.pendingApplicationCount - 1,
      'pendingNonGroupApplicantCount': pendingNonGroup,
    });
  }
}
