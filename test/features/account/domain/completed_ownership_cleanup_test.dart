import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/completed_ownership_cleanup.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_snapshot.dart';

void main() {
  final room = <String, dynamic>{
    'recruitmentId': 'room',
    'schemaVersion': 2,
    'revision': 7,
    'raidId': 'raid',
    'status': 'active',
    'currentCycleStatus': 'completed',
    'continueTogether': true,
    'leaderPlayerId': 'p0',
    'memberCount': 8,
    'dealerCount': 6,
    'supportCount': 2,
    'nonGroupMemberCount': 1,
    'partySlots': [
      for (var i = 0; i < 8; i++)
        {
          'playerId': 'p$i',
          'characterId': 'c$i',
          'role': i < 6 ? 'dealer' : 'support',
          'ownershipRevision': 1,
          'countedAsNonGroupMember': i == 7,
        },
    ],
    'memberPlayerIds': [for (var i = 0; i < 8; i++) 'p$i'],
    'raidStateTargets': [
      for (var i = 0; i < 8; i++) {'playerId': 'p$i', 'stateId': 'c${i}_raid'},
    ],
  };
  CompletedOwnershipCleanup observation({
    String actor = 'p0',
    int ai = 0,
    int ti = 7,
  }) => CompletedOwnershipCleanup(
    roomId: 'room',
    actorId: actor,
    targetId: 'p$ti',
    characterId: 'c$ti',
    revision: 7,
    targetIndex: ti,
    actorIndex: ai,
    observedRevision: 3,
    memberUpdatedAt: 100,
    eventId: 'event',
  );
  test(
    'max eight cleanup removes exact member preserving order and completion metadata',
    () {
      final command = observation(), patch = command.patch(room, 200);
      expect(patch['memberCount'], 7);
      expect(patch['supportCount'], 1);
      expect(patch['dealerCount'], 6);
      expect(patch['nonGroupMemberCount'], 0);
      expect(
        patch['memberPlayerIds'],
        (room['memberPlayerIds'] as List).take(7).toList(),
      );
      expect(
        patch['partySlots'],
        (room['partySlots'] as List).take(7).toList(),
      );
      expect(
        patch['raidStateTargets'],
        (room['raidStateTargets'] as List).take(7).toList(),
      );
      expect(patch.containsKey('currentCycleStatus'), isFalse);
      expect(patch.containsKey('leaderPlayerId'), isFalse);
      expect(command.listingPatch(patch)['sourceRevision'], 8);
      expect(
        command.listingPatch(patch).containsKey('ownershipCleanup'),
        isFalse,
      );
      expect(
        command.event(room, 200)['audiencePlayerIds'],
        room['memberPlayerIds'],
      );
      expect((room['partySlots'] as List).length, 8);
      expect(
        observation(actor: 'p7', ai: 7).patch(room, 200)['memberCount'],
        7,
      );
    },
  );
  test(
    'reject active room changed revision leader target and unrelated actor',
    () {
      expect(
        () => observation().patch({...room, 'revision': 8}, 200),
        throwsStateError,
      );
      expect(
        () =>
            observation().patch({...room, 'currentCycleStatus': 'active'}, 200),
        throwsStateError,
      );
      expect(() => observation(ti: 0).patch(room, 200), throwsStateError);
      expect(
        () => observation(actor: 'p1', ai: 1).patch(room, 200),
        throwsStateError,
      );
      expect(
        () => observation().patch({...room, 'continueTogether': false}, 200),
        throwsStateError,
      );
    },
  );
  test(
    'receipt binds actor target observed generation command and revision',
    () {
      final c = observation(),
          receipt = Map<String, dynamic>.from(c.event(room, 200));
      expect(c.matchesReceipt(receipt), isTrue);
      for (final key in [
        'eventId',
        'commandId',
        'actorPlayerId',
        'targetPlayerId',
        'targetCharacterId',
        'observedOwnershipRevision',
        'commandRevision',
        'expectedRevision',
      ]) {
        expect(
          c.matchesReceipt({...receipt, key: 'changed'}),
          isFalse,
          reason: key,
        );
      }
      expect(c.matchesReceipt(null), isFalse);
    },
  );
  test(
    'stale requires coherent authority with strictly increasing generation including reacquisition',
    () {
      GameAccountOwnershipSnapshot authority(String owner) =>
          GameAccountOwnershipSnapshot.inspect(
            playerId: 'old',
            gameAccountId: 'account',
            account: {
              'ownerPlayerId': owner,
              'ownershipRevision': 3,
              'status': 'active',
            },
            character: {
              'ownerPlayerId': owner,
              'ownershipRevision': 3,
              'status': 'active',
              'gameAccountId': 'account',
            },
          );
      for (final owner in ['new', 'old']) {
        expect(CompletedOwnershipCleanup.isStale(authority(owner), 1), isTrue);
        for (final value in [3, 4, null, -1, 1.5]) {
          expect(
            CompletedOwnershipCleanup.isStale(authority(owner), value),
            isFalse,
          );
        }
      }
      expect(
        CompletedOwnershipCleanup.isStale(
          const GameAccountOwnershipSnapshot.unknown(),
          1,
        ),
        isFalse,
      );
    },
  );
}
