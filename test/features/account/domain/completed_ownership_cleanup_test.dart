import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/completed_ownership_cleanup.dart';
import 'package:lost_party/features/account/domain/game_account_ownership_snapshot.dart';

void main() {
  test('eight member peer cleanup converges to first remaining successor', () {
    var current = <String, dynamic>{
      'recruitmentId': 'room',
      'schemaVersion': 2,
      'revision': 1,
      'raidId': 'raid',
      'status': 'active',
      'currentCycleStatus': 'completed',
      'continueTogether': true,
      'leaderPlayerId': 'p0',
      'memberCount': 8,
      'dealerCount': 8,
      'supportCount': 0,
      'nonGroupMemberCount': 0,
      'partySlots': [
        for (var i = 0; i < 8; i++)
          {
            'playerId': 'p$i',
            'characterId': 'c$i',
            'role': 'dealer',
            'countedAsNonGroupMember': false,
          },
      ],
      'memberPlayerIds': [for (var i = 0; i < 8; i++) 'p$i'],
      'raidStateTargets': [
        for (var i = 0; i < 8; i++)
          {'playerId': 'p$i', 'stateId': 'c${i}_raid'},
      ],
    };
    for (var i = 1; i < 7; i++) {
      final command = CompletedOwnershipCleanup(
        roomId: 'room',
        actorId: 'p7',
        targetId: 'p$i',
        characterId: 'c$i',
        revision: current['revision'] as int,
        targetIndex: 1,
        actorIndex: (current['memberCount'] as int) - 1,
        observedRevision: 3,
        memberUpdatedAt: 100,
        eventId: 'peer$i',
        kind: CompletedCleanupKind.peer,
        leaderIndex: 0,
        observedLeaderRevision: 3,
      );
      final patch = command.patch(current, 200);
      expect(patch['lastCommandType'], 'cleanupCompletedPeerOwnership');
      final event = Map<String, dynamic>.from(command.event(current, 200));
      expect(command.matchesReceipt(event), isTrue);
      expect(
        command.matchesReceipt({...event, 'observedLeaderRevision': 4}),
        isFalse,
      );
      current = {...current, ...patch};
    }
    final leader = CompletedOwnershipCleanup(
      roomId: 'room',
      actorId: 'p7',
      targetId: 'p0',
      characterId: 'c0',
      revision: 7,
      targetIndex: 0,
      actorIndex: 1,
      observedRevision: 3,
      memberUpdatedAt: 100,
      eventId: 'leader',
      kind: CompletedCleanupKind.leader,
      successorIndex: 1,
      successorId: 'p7',
      successorName: '후임',
      successorClass: '클래스',
    );
    final patch = leader.patch(current, 200);
    expect(patch['memberPlayerIds'], ['p7']);
    expect(patch['leaderPlayerId'], 'p7');
    expect(leader.listingPatch(patch)['leaderCharacterNameSnapshot'], '후임');
    expect(patch.containsKey('currentCycleStatus'), isFalse);
    final event = Map<String, dynamic>.from(leader.event(current, 200));
    expect(leader.matchesReceipt(event), isTrue);
    expect(
      leader.matchesReceipt({...event, 'successorPlayerId': 'other'}),
      isFalse,
    );
  });
  test('succession refuses skipping the first remaining member', () {
    final command = CompletedOwnershipCleanup(
      roomId: 'r',
      actorId: 'p2',
      targetId: 'p0',
      characterId: 'c0',
      revision: 1,
      targetIndex: 0,
      actorIndex: 2,
      observedRevision: 2,
      memberUpdatedAt: 1,
      eventId: 'e',
      kind: CompletedCleanupKind.leader,
      successorIndex: 2,
      successorId: 'p2',
      successorName: 'n',
      successorClass: 'c',
    );
    expect(
      () => command.patch({
        'recruitmentId': 'r',
        'revision': 1,
        'schemaVersion': 2,
        'status': 'active',
        'currentCycleStatus': 'completed',
        'continueTogether': true,
        'memberCount': 3,
        'leaderPlayerId': 'p0',
        'partySlots': [
          for (var i = 0; i < 3; i++) {'playerId': 'p$i', 'characterId': 'c$i'},
        ],
      }, 1),
      throwsStateError,
    );
  });
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

// Deliberately uses each current aggregate as the next command boundary.
