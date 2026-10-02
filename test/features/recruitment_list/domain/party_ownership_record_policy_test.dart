import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_snapshot.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_ownership_record_policy.dart';

void main() {
  final ownership = GameAccountOwnershipSnapshot.inspect(
    playerId: 'A',
    gameAccountId: 'roster',
    account: {'ownerPlayerId': 'A', 'status': 'active', 'ownershipRevision': 3},
    character: {
      'ownerPlayerId': 'A',
      'status': 'active',
      'ownershipRevision': 3,
      'gameAccountId': 'roster',
    },
  );
  final record = <String, dynamic>{
    'playerId': 'A',
    'characterId': 'char',
    'raidId': 'raid',
    'cycleKey': 'week',
    'status': 'active',
    'revision': 7,
    'ownershipRevision': 1,
  };
  GameAccountOwnershipCondition classify(
    Map<String, dynamic> data, {
    bool state = true,
    GameAccountOwnershipSnapshot? authority,
  }) => PartyOwnershipRecordPolicy.classify(
    ownership: authority ?? ownership,
    data: data,
    playerId: 'A',
    characterId: 'char',
    raidId: 'raid',
    isRaidState: state,
    claimCycleKey: 'week',
  );
  test(
    'reacquisition excludes only valid old active/completed or legacy state',
    () {
      for (final status in ['active', 'completed']) {
        expect(
          classify({...record, 'status': status}),
          GameAccountOwnershipCondition.ownershipChanged,
        );
        expect(
          classify({...record, 'status': status}..remove('ownershipRevision')),
          GameAccountOwnershipCondition.ownershipChanged,
        );
        expect(
          classify({...record, 'status': status, 'ownershipRevision': 3}),
          GameAccountOwnershipCondition.current,
        );
      }
    },
  );
  test(
    'unknown authority and damaged identity/state cannot authorize replacement',
    () {
      expect(
        classify(
          record,
          authority: const GameAccountOwnershipSnapshot.unknown(),
        ),
        GameAccountOwnershipCondition.unknown,
      );
      for (final patch in <Map<String, dynamic>>[
        {'playerId': 'B'},
        {'characterId': 'other'},
        {'raidId': 'other'},
        {'revision': 0},
        {'status': 'broken'},
        {'cycleKey': ''},
        {'ownershipRevision': null},
        {'ownershipRevision': -1},
        {'ownershipRevision': 1.5},
        {'ownershipRevision': 4},
      ]) {
        expect(
          classify({...record, ...patch}),
          GameAccountOwnershipCondition.unknown,
        );
      }
    },
  );
  test(
    'claim generation uses the same policy and requires exact cycle identity',
    () {
      expect(
        classify(record, state: false),
        GameAccountOwnershipCondition.ownershipChanged,
      );
      expect(
        classify({...record, 'ownershipRevision': 3}, state: false),
        GameAccountOwnershipCondition.current,
      );
      expect(
        classify({...record, 'cycleKey': 'other'}, state: false),
        GameAccountOwnershipCondition.unknown,
      );
      expect(
        classify({...record, 'ownershipRevision': null}, state: false),
        GameAccountOwnershipCondition.unknown,
      );
    },
  );
}
