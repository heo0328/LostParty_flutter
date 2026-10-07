import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_snapshot.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/raid_state_availability.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_ownership_record_policy.dart';

void main() {
  final start = DateTime.utc(2026, 10, 6, 21);
  Map<String, dynamic> stub() => {
    'playerId': 'owner',
    'characterId': 'abcdefghijklmnopqrst',
    'raidId': 'raid',
    'ownershipRevision': 3,
    'guardSchemaVersion': 1,
    'guardRecruitmentId': 'room',
    'guardRoomRevision': 8,
    'guardCycleKey': '2026-10-07',
    'guardSlotIndex': 7,
    'guardCycleStartedAt': Timestamp.fromDate(start),
    'guardCycleEndsAt': Timestamp.fromDate(start.add(const Duration(days: 7))),
    'guardCheckedAt': Timestamp.fromDate(start),
  };
  final owner = GameAccountOwnershipSnapshot.inspect(
    playerId: 'owner',
    gameAccountId: 'account',
    account: {
      'status': 'active',
      'ownerPlayerId': 'owner',
      'ownershipRevision': 3,
    },
    character: {
      'status': 'active',
      'ownerPlayerId': 'owner',
      'ownershipRevision': 3,
      'gameAccountId': 'account',
    },
  );
  test(
    'availability cannot masquerade as an active/completed or damaged record',
    () {
      expect(RaidStateAvailability.isStub(stub()), isTrue);
      for (final patch in <Map<String, dynamic>>[
        {'status': 'active'},
        {'status': 'completed'},
        {'revision': 1},
        {'guardCheckedAt': null},
        {'guardSlotIndex': 8},
        {'guardCycleEndsAt': Timestamp.fromDate(start)},
      ]) {
        expect(RaidStateAvailability.isStub({...stub(), ...patch}), isFalse);
      }
      expect(
        RaidStateAvailability.isStub(stub()..remove('guardSchemaVersion')),
        isFalse,
      );
    },
  );
  test(
    'availability never bypasses identity or live ownership classification',
    () {
      GameAccountOwnershipCondition classify(
        Map<String, dynamic> data,
        GameAccountOwnershipSnapshot authority,
      ) => PartyOwnershipRecordPolicy.classify(
        ownership: authority,
        data: data,
        playerId: 'owner',
        characterId: 'abcdefghijklmnopqrst',
        raidId: 'raid',
        isRaidState: true,
        availabilityOnly: RaidStateAvailability.isStub(data),
      );
      expect(classify(stub(), owner), GameAccountOwnershipCondition.current);
      expect(
        classify({...stub(), 'ownershipRevision': 2}, owner),
        GameAccountOwnershipCondition.ownershipChanged,
      );
      expect(
        classify({...stub(), 'playerId': 'other'}, owner),
        GameAccountOwnershipCondition.unknown,
      );
      expect(
        classify(stub(), const GameAccountOwnershipSnapshot.unknown()),
        GameAccountOwnershipCondition.unknown,
      );
      expect(
        classify({...stub(), 'ownershipRevision': 4}, owner),
        GameAccountOwnershipCondition.unknown,
      );
    },
  );
}
