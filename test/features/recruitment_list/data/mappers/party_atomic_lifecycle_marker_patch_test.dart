import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_atomic_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';

void main() {
  test('advanceCycle 마커는 다음 정상 Aggregate 명령에서만 소진한다', () {
    final patch = lifecycleMarkerConsumptionPatch(
      _aggregate(PartyAtomicCommandType.advanceCycle),
    );

    expect(patch['commandTargets'], isEmpty);
    expect(patch['lastCommandId'], isNull);
    expect(patch['lastCommandType'], isNull);
    expect(patch['lastCommandActorPlayerId'], isNull);
    expect(patch['lastCommandAt'], isNull);
  });

  test('일반방과 personalComplete 마커는 lifecycle 소진 대상으로 바꾸지 않는다', () {
    expect(lifecycleMarkerConsumptionPatch(_aggregate(null)), isEmpty);
    expect(
      lifecycleMarkerConsumptionPatch(
        _aggregate(PartyAtomicCommandType.personalComplete),
      ),
      isEmpty,
    );
  });
}

PartyCommandAggregate _aggregate(PartyAtomicCommandType? lastCommandType) {
  return PartyCommandAggregate(
    recruitmentId: 'recruitment-1',
    raidId: 'raid-1',
    difficultyId: 'hard',
    leaderPlayerId: 'leader',
    currentCycleKey: '2026-09-23',
    currentCycleStatus: PartyRaidStateStatus.active,
    revision: 4,
    partySlots: [
      PartyAggregateSlot(
        playerId: 'leader',
        characterId: 'character-1',
        role: PartyRole.dealer,
        classKey: '데모닉',
        partyIndex: 0,
        slotIndex: 0,
        countedAsNonGroupMember: false,
      ),
    ],
    nonGroupMemberCount: 0,
    pendingApplicationCount: 0,
    pendingNonGroupApplicantCount: 0,
    lastCommandId: lastCommandType == null ? null : 'command-4',
    lastCommandType: lastCommandType,
  );
}
