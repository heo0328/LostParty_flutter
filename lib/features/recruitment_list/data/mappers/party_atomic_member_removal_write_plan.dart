import '../../domain/entities/party_atomic_command.dart';
import '../../domain/entities/party_create_command.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/party_composition_policy.dart';
import 'party_atomic_document_mapper.dart';
import 'party_atomic_lifecycle_marker_patch.dart';

class PartyLeaderSuccessorSnapshot {
  const PartyLeaderSuccessorSnapshot({
    required this.playerId,
    required this.characterName,
    required this.className,
  });

  final String playerId;
  final String characterName;
  final String className;
}

/// 탈퇴·추방과 필요한 경우 파티장 승계를 대상 중심으로 만드는 쓰기 계획.
///
/// [PartyCommandAggregate.partySlots]의 순서는 기존 `memberPlayerIds`와 같은
/// 가입 순서다. 파티장이 나가면 남은 첫 번째 슬롯의 Player만 후임으로
/// 갱신하며, 마지막 한 명은 이 계획이 아니라 원자 해산 명령을 사용한다.
class PartyAtomicMemberRemovalWritePlan {
  PartyAtomicMemberRemovalWritePlan({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String targetPlayerId,
    required String actorPlayerId,
    required PartyAtomicMemberRemovalType type,
    required String raidId,
    required Object serverTimestamp,
    bool actorCanResolveLostGroupQualification = false,
    PartyLeaderSuccessorSnapshot? successorSnapshot,
  }) : _values = _build(
         aggregate: aggregate,
         rules: rules,
         targetPlayerId: targetPlayerId,
         actorPlayerId: actorPlayerId,
         type: type,
         raidId: raidId,
         serverTimestamp: serverTimestamp,
         actorCanResolveLostGroupQualification:
             actorCanResolveLostGroupQualification,
         successorSnapshot: successorSnapshot,
       );

  final _PartyAtomicMemberRemovalValues _values;

  Map<String, Object?> get recruitmentPatch => _values.recruitmentPatch;

  Map<String, Object?> get event => _values.event;
  String get targetPlayerId => _values.targetPlayerId;
  String get targetRaidStateId => _values.targetRaidStateId;
  String? get successorPlayerId => _values.successorPlayerId;
  Map<String, Object?>? get successorMembershipPatch =>
      _values.successorMembershipPatch;

  int get maximumWriteCount => 4 + (successorPlayerId == null ? 0 : 1);

  static _PartyAtomicMemberRemovalValues _build({
    required PartyCommandAggregate aggregate,
    required RecruitmentPartyRules rules,
    required String targetPlayerId,
    required String actorPlayerId,
    required PartyAtomicMemberRemovalType type,
    required String raidId,
    required Object serverTimestamp,
    required bool actorCanResolveLostGroupQualification,
    required PartyLeaderSuccessorSnapshot? successorSnapshot,
  }) {
    if (aggregate.status != PartyRecruitmentStatus.active ||
        aggregate.currentCycleStatus != PartyRaidStateStatus.active) {
      throw StateError('활성 모집에서만 탈퇴하거나 추방할 수 있습니다.');
    }
    if (type == PartyAtomicMemberRemovalType.leave &&
        actorPlayerId != targetPlayerId) {
      throw StateError('본인만 탈퇴할 수 있습니다.');
    }
    if (type == PartyAtomicMemberRemovalType.kick &&
        (actorPlayerId != aggregate.leaderPlayerId ||
            targetPlayerId == aggregate.leaderPlayerId)) {
      throw StateError('파티장만 다른 파티원을 추방할 수 있습니다.');
    }
    if (type == PartyAtomicMemberRemovalType.lostGroupQualification &&
        (aggregate.visibility != RecruitmentVisibility.group ||
            actorPlayerId == targetPlayerId ||
            !actorCanResolveLostGroupQualification)) {
      throw StateError('그룹 자격 상실 파티원을 정리할 권한이 없습니다.');
    }
    final targetIndex = aggregate.partySlots.indexWhere(
      (slot) => slot.playerId == targetPlayerId,
    );
    if (targetIndex < 0) throw StateError('대상 파티원이 없습니다.');
    if (aggregate.memberCount == 1) {
      throw StateError('마지막 파티원은 원자 해산 명령을 사용해야 합니다.');
    }
    final target = aggregate.partySlots[targetIndex];
    if (target.countedAsNonGroupMember && aggregate.nonGroupMemberCount == 0) {
      throw StateError('비그룹 파티원 집계가 일치하지 않습니다.');
    }
    final remaining = [...aggregate.partySlots]..removeAt(targetIndex);
    final leaderLeaves = targetPlayerId == aggregate.leaderPlayerId;
    final successor = leaderLeaves ? remaining.first : null;
    if (leaderLeaves &&
        (successorSnapshot == null ||
            successorSnapshot.playerId != successor!.playerId)) {
      throw StateError('가입 순서상 후임 파티장 Snapshot이 필요합니다.');
    }
    if (!leaderLeaves && successorSnapshot != null) {
      throw ArgumentError('파티장이 남는 명령에는 후임 Snapshot이 필요 없습니다.');
    }

    final nextRevision = aggregate.revision + 1;
    final eventType = type == PartyAtomicMemberRemovalType.leave
        ? 'memberLeft'
        : 'memberKicked';
    final eventId = '${eventType}_${aggregate.recruitmentId}_$nextRevision';
    final nextNonGroupMemberCount =
        aggregate.nonGroupMemberCount -
        (target.countedAsNonGroupMember ? 1 : 0);
    final patch = <String, Object?>{
      ...lifecycleMarkerConsumptionPatch(aggregate),
      'memberPlayerIds': [for (final slot in remaining) slot.playerId],
      'memberCount': remaining.length,
      'dealerCount': remaining
          .where((slot) => slot.role == PartyRole.dealer)
          .length,
      'supportCount': remaining
          .where((slot) => slot.role == PartyRole.support)
          .length,
      'partySlots': [
        for (final slot in remaining) PartyAtomicDocumentMapper.slot(slot),
      ],
      'raidStateTargets': [
        for (final slot in remaining)
          {
            'playerId': slot.playerId,
            'stateId': PartyRaidState.documentIdFor(
              characterId: slot.characterId,
              raidId: raidId,
            ),
          },
      ],
      'nonGroupMemberCount': nextNonGroupMemberCount,
      'hasAvailableSlot': remaining.length < rules.totalMembers,
      'revision': nextRevision,
      'updatedAt': serverTimestamp,
    };
    if (leaderLeaves) {
      patch.addAll({
        'leaderPlayerId': successor!.playerId,
        'leaderCharacterNameSnapshot': successorSnapshot!.characterName,
        'leaderClassNameSnapshot': successorSnapshot.className,
      });
    }

    return _PartyAtomicMemberRemovalValues(
      recruitmentPatch: Map.unmodifiable(patch),
      targetPlayerId: targetPlayerId,
      targetRaidStateId: PartyRaidState.documentIdFor(
        characterId: target.characterId,
        raidId: raidId,
      ),
      successorPlayerId: successor?.playerId,
      successorMembershipPatch: successor == null
          ? null
          : Map.unmodifiable({
              'canApproveApplications': true,
              'updatedAt': serverTimestamp,
            }),
      event: Map.unmodifiable({
        'schemaVersion': 1,
        'eventId': eventId,
        'recruitmentId': aggregate.recruitmentId,
        'type': eventType,
        'commandId': eventId,
        'commandRevision': nextRevision,
        'audiencePlayerIds': [
          for (final slot in aggregate.partySlots) slot.playerId,
        ],
        'actorPlayerId': actorPlayerId,
        'targetPlayerId': targetPlayerId,
        'occurredAt': serverTimestamp,
      }),
    );
  }
}

class _PartyAtomicMemberRemovalValues {
  const _PartyAtomicMemberRemovalValues({
    required this.recruitmentPatch,
    required this.targetPlayerId,
    required this.targetRaidStateId,
    required this.successorPlayerId,
    required this.successorMembershipPatch,
    required this.event,
  });

  final Map<String, Object?> recruitmentPatch;
  final String targetPlayerId;
  final String targetRaidStateId;
  final String? successorPlayerId;
  final Map<String, Object?>? successorMembershipPatch;
  final Map<String, Object?> event;
}
