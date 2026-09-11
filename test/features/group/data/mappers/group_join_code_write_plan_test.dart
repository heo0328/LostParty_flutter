import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_join_code_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_join_code.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 9);
  final expiresAt = now.add(const Duration(hours: 24));
  final code = GroupJoinCode.tryParse('23456789ABCDEFGHJKMN')!;

  const character = GroupRequestCharacter(
    characterId: 'character-9',
    ownerPlayerId: 'player-9',
    characterName: '코드가입자',
    serverName: '루페온',
    characterClassName: '버서커',
    itemLevel: 1700.5,
    combatPower: 320.25,
  );

  GroupJoinRelation pendingRelation({
    GroupJoinRelationKind kind = GroupJoinRelationKind.invitation,
  }) => GroupJoinRelation(
    groupId: 'group-1',
    targetPlayerId: 'player-9',
    kind: kind,
    status: GroupRequestStatus.pending,
    requestedByPlayerId: kind == GroupJoinRelationKind.invitation
        ? 'player-1'
        : 'player-9',
    characterIdSnapshot: 'character-old',
    characterNameSnapshot: '옛스냅샷',
    serverNameSnapshot: '루페온',
    characterClassNameSnapshot: '버서커',
    itemLevelSnapshot: 1600,
    combatPowerSnapshot: 300,
    applicationAttempt: kind == GroupJoinRelationKind.application ? 2 : 0,
    revision: 3,
    createdAt: now,
    expiresAt: expiresAt,
    updatedAt: now,
  );

  group('생성', () {
    test('코드 문서와 hasActiveJoinCode true 패치를 만든다', () {
      final timestamp = Object();
      final plan = GroupJoinCodeWritePlan.created(
        groupId: 'group-1',
        code: code,
        createdByPlayerId: 'player-1',
        groupRevision: 7,
        serverTimestamp: timestamp,
      );

      expect(plan.joinCodeDocument!['schemaVersion'], 1);
      expect(plan.joinCodeDocument!['groupId'], 'group-1');
      expect(plan.joinCodeDocument!['status'], 'active');
      expect(plan.joinCodeDocument!['createdByPlayerId'], 'player-1');
      expect(plan.joinCodeDocument!['createdAt'], same(timestamp));
    expect(plan.groupPatch['hasActiveJoinCode'], isTrue);
    expect(plan.groupPatch['activeJoinCode'], code.value);
      expect(plan.groupPatch['revision'], 8);
      expect(plan.member, isNull);
    });
  });

  group('폐기', () {
    test('hasActiveJoinCode false와 활동 시각만 담는다', () {
      final timestamp = Object();
      final plan = GroupJoinCodeWritePlan.revoked(
        groupRevision: 7,
        serverTimestamp: timestamp,
      );

    expect(plan.groupPatch['hasActiveJoinCode'], isFalse);
    expect(plan.groupPatch['activeJoinCode'], isNull);
      expect(plan.groupPatch['revision'], 8);
      expect(plan.groupPatch['lastActivityAt'], same(timestamp));
      expect(plan.joinCodeDocument, isNull);
    });
  });

  group('표시 정책', () {
    test('joinCodeVisibleToMembers만 바꾼다', () {
      final plan = GroupJoinCodeWritePlan.visibility(
        visibleToMembers: true,
        groupRevision: 4,
        serverTimestamp: Object(),
      );

      expect(plan.groupPatch['joinCodeVisibleToMembers'], isTrue);
      expect(plan.groupPatch.containsKey('hasActiveJoinCode'), isFalse);
      expect(plan.groupPatch['revision'], 5);
    });
  });

  group('코드 가입', () {
    test('membership은 joinCode와 선택한 Character Snapshot을 쓴다', () {
      final timestamp = Object();
      final plan = GroupJoinCodeWritePlan.joined(
        groupId: 'group-1',
        playerId: 'player-9',
        character: character,
        groupName: '로파길드',
        groupRevision: 7,
        groupMemberCount: 3,
        membershipState: const GroupMembershipState(
          playerId: 'player-9',
          activeGroupIds: ['other'],
          revision: 1,
        ),
        existingRelation: null,
        serverTimestamp: timestamp,
        now: now,
      );

      expect(plan.member!['joinedBy'], 'joinCode');
      expect(plan.member!['joinSequence'], 4);
      expect(plan.member!['displayCharacterIdSnapshot'], 'character-9');
      expect(plan.member!['displayCharacterNameSnapshot'], '코드가입자');
      expect(plan.member!['gemValidationSnapshot'], isNull);
      expect(plan.playerRelation!['relation'], 'member');
      expect(plan.playerRelation!['requestStatus'], isNull);
      expect(plan.joinRelationPatch, isNull);
      expect(plan.groupPatch['memberCount'], 4);
      expect(plan.membershipState!['activeGroupIds'], ['other', 'group-1']);
    });

    test('pending relation이 있으면 accepted로만 바꾸고 stats는 쓰지 않는다', () {
      final plan = GroupJoinCodeWritePlan.joined(
        groupId: 'group-1',
        playerId: 'player-9',
        character: character,
        groupName: '로파길드',
        groupRevision: 7,
        groupMemberCount: 3,
        membershipState: const GroupMembershipState.empty('player-9'),
        existingRelation: pendingRelation(
          kind: GroupJoinRelationKind.application,
        ),
        serverTimestamp: Object(),
        now: now,
      );

      expect(plan.joinRelationPatch!['status'], 'accepted');
      expect(plan.joinRelationPatch!['revision'], 4);
      expect(plan.playerRelation!['requestStatus'], 'accepted');
      expect(plan.member!['displayCharacterNameSnapshot'], '코드가입자');
      expect(
        plan.member!['displayCharacterNameSnapshot'],
        isNot('옛스냅샷'),
        reason: '표시 Snapshot은 relation이 아니라 선택한 Character에서 온다.',
      );
    });

    test('정원·가입 한도·타 Player Character는 거절한다', () {
      expect(
        () => GroupJoinCodeWritePlan.joined(
          groupId: 'group-1',
          playerId: 'player-9',
          character: character,
          groupName: '로파길드',
          groupRevision: 1,
          groupMemberCount: GroupMember.maxMemberCount,
          membershipState: const GroupMembershipState.empty('player-9'),
          existingRelation: null,
          serverTimestamp: Object(),
          now: now,
        ),
        throwsStateError,
      );
      expect(
        () => GroupJoinCodeWritePlan.joined(
          groupId: 'group-1',
          playerId: 'player-9',
          character: const GroupRequestCharacter(
            characterId: 'character-x',
            ownerPlayerId: 'other',
            characterName: '남의캐릭',
            serverName: '루페온',
            characterClassName: '버서커',
            itemLevel: null,
            combatPower: null,
          ),
          groupName: '로파길드',
          groupRevision: 1,
          groupMemberCount: 1,
          membershipState: const GroupMembershipState.empty('player-9'),
          existingRelation: null,
          serverTimestamp: Object(),
          now: now,
        ),
        throwsArgumentError,
      );
    });
  });
}
