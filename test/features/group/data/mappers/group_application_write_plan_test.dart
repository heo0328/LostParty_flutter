import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_application_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 9);
  final expiresAt = now.add(const Duration(hours: 24));

  GroupJoinRelation relation({
    GroupJoinRelationKind kind = GroupJoinRelationKind.application,
    GroupRequestStatus status = GroupRequestStatus.pending,
    int revision = 3,
    int applicationAttempt = 2,
    DateTime? expires,
  }) => GroupJoinRelation(
    groupId: 'group-1',
    targetPlayerId: 'player-2',
    kind: kind,
    status: status,
    requestedByPlayerId: 'player-2',
    characterIdSnapshot: 'character-2',
    characterNameSnapshot: '신청캐릭터',
    serverNameSnapshot: '아만',
    characterClassNameSnapshot: '바드',
    itemLevelSnapshot: 1680,
    combatPowerSnapshot: 310.5,
    applicationAttempt: applicationAttempt,
    revision: revision,
    createdAt: now,
    expiresAt: expires ?? expiresAt,
    updatedAt: now,
  );

  group('신청 승인', () {
    GroupApplicationWritePlan plan({
      GroupJoinRelation? source,
      int groupMemberCount = 4,
      Object? serverTimestamp,
      Object? union,
      Object? increment,
    }) => GroupApplicationWritePlan.approved(
      relation: source ?? relation(),
      groupName: '로파길드',
      groupRevision: 7,
      groupMemberCount: groupMemberCount,
      serverTimestamp: serverTimestamp ?? Object(),
      addedGroupIdUnion: union ?? Object(),
      incrementByOne: increment ?? Object(),
      now: now,
    );

    test('요청 원본은 accepted로 전이하고 revision·판정 시각만 바꾼다', () {
      final timestamp = Object();
      final patch = plan(serverTimestamp: timestamp).joinRelationPatch!;

      expect(patch.keys, ['status', 'revision', 'decidedAt', 'updatedAt']);
      expect(patch['status'], 'accepted');
      expect(patch['revision'], 4);
      expect(patch['decidedAt'], same(timestamp));
    });

    test('membership은 application 경로로 읽은 인원 + 1을 joinSequence로 쓴다', () {
      final member = plan(groupMemberCount: 12).member!;

      expect(member['role'], 'member');
      expect(member['joinedBy'], 'application');
      expect(member['joinSequence'], 13);
      expect(member['revision'], 1);
      expect(member['playerId'], 'player-2');
      expect(member['displayCharacterIdSnapshot'], 'character-2');
      expect(member['displayCharacterNameSnapshot'], '신청캐릭터');
    });

    test('대상 요약은 배열 합집합과 증가 연산으로만 병합한다', () {
      final union = Object();
      final increment = Object();
      final state = plan(union: union, increment: increment)
          .membershipStatePatch!;

      expect(state['playerId'], 'player-2');
      expect(state['activeGroupIds'], same(union));
      expect(state['activeGroupCount'], same(increment));
      expect(state['revision'], same(increment));
    });

    test('대상 Projection은 member·accepted가 되고 createdAt을 보존한다', () {
      final projection = plan().playerRelationPatch!;

      expect(projection['relation'], 'member');
      expect(projection['requestStatus'], 'accepted');
      expect(projection['expiresAt'], isNull);
      expect(projection['sourceRevision'], 1);
      expect(projection['displayCharacterNameSnapshot'], '신청캐릭터');
      expect(
        projection.containsKey('createdAt'),
        isFalse,
        reason: '그룹장은 대상 Projection을 읽지 못하므로 createdAt을 병합으로 남긴다.',
      );
    });

    test('그룹은 인원과 revision을 각각 1 증가시킨다', () {
      final patch = plan(groupMemberCount: 12).groupPatch;

      expect(patch.keys, [
        'memberCount',
        'revision',
        'lastActivityAt',
        'updatedAt',
      ]);
      expect(patch['memberCount'], 13);
      expect(patch['revision'], 8);
    });

    test('정원 50명과 만료·비pending 신청은 쓰기 계획을 만들지 않는다', () {
      expect(
        () => plan(groupMemberCount: GroupMember.maxMemberCount),
        throwsStateError,
      );
      expect(
        () => plan(source: relation(expires: now)),
        throwsStateError,
        reason: '정확히 만료 이후 승인은 거절한다.',
      );
      expect(
        () => plan(source: relation(status: GroupRequestStatus.rejected)),
        throwsStateError,
      );
    });

    test('초대 관계는 신청 승인 경로로 처리하지 않는다', () {
      expect(
        () => plan(source: relation(kind: GroupJoinRelationKind.invitation)),
        throwsArgumentError,
      );
    });
  });

  group('신청 거절', () {
    GroupApplicationWritePlan plan({GroupJoinRelation? source}) =>
        GroupApplicationWritePlan.rejected(
          relation: source ?? relation(),
          groupName: '로파길드',
          groupRevision: 7,
          serverTimestamp: Object(),
        );

    test('거절은 membership과 금지 문서를 만들지 않는다', () {
      final created = plan();

      expect(created.member, isNull);
      expect(created.membershipStatePatch, isNull);
      expect(created.blockDocument, isNull);
      expect(created.joinRelationPatch!['status'], 'rejected');
      expect(created.joinRelationPatch!['revision'], 4);
    });

    test('Projection은 applied를 유지하고 누적 신청 횟수를 건드리지 않는다', () {
      final projection = plan().playerRelationPatch!;

      expect(projection['relation'], 'applied');
      expect(projection['requestStatus'], 'rejected');
      expect(projection['sourceRevision'], 4);
      expect(projection['expiresAt'], expiresAt);
      expect(projection.containsKey('createdAt'), isFalse);
    });

    test('그룹은 활동 시각만 갱신하고 인원을 바꾸지 않는다', () {
      final patch = plan().groupPatch;

      expect(patch.keys, ['revision', 'lastActivityAt', 'updatedAt']);
      expect(patch['revision'], 8);
    });
  });

  group('신청 거절과 금지', () {
    GroupApplicationWritePlan plan({
      GroupJoinRelation? source,
      String blockedByPlayerId = 'player-1',
      int applicationCount = 2,
    }) => GroupApplicationWritePlan.blocked(
      relation: source ?? relation(),
      groupName: '로파길드',
      groupRevision: 7,
      blockedByPlayerId: blockedByPlayerId,
      applicationCount: applicationCount,
      serverTimestamp: Object(),
      now: now,
    );

    test('pending 신청은 blocked로 전이하고 같은 계획에 block 문서를 담는다', () {
      final created = plan();

      expect(created.joinRelationPatch!['status'], 'blocked');
      expect(created.playerRelationPatch!['requestStatus'], 'blocked');
      expect(created.blockDocument!['reason'], 'applicationRejected');
      expect(created.blockDocument!['playerId'], 'player-2');
      expect(created.blockDocument!['blockedByPlayerId'], 'player-1');
      expect(created.blockDocument!['characterNameSnapshot'], '신청캐릭터');
      expect(created.blockDocument!['applicationCountSnapshot'], 2);
      expect(created.blockDocument!['itemLevelSnapshot'], 1680.0);
      expect(created.blockDocument!['combatPowerSnapshot'], 310.5);
    });

    test('이미 끝난 신청은 relation을 두고 manual 금지만 만든다', () {
      final created = plan(
        source: relation(status: GroupRequestStatus.rejected),
      );

      expect(created.joinRelationPatch, isNull);
      expect(created.playerRelationPatch, isNull);
      expect(created.blockDocument!['reason'], 'manual');
      expect(created.groupPatch['revision'], 8);
    });

    test('금지는 membership을 만들지 않는다', () {
      final created = plan();

      expect(created.member, isNull);
      expect(created.membershipStatePatch, isNull);
    });

    test('만료된 pending 신청과 이미 수락된 신청은 금지 계획을 만들지 않는다', () {
      expect(() => plan(source: relation(expires: now)), throwsStateError);
      expect(
        () => plan(source: relation(status: GroupRequestStatus.accepted)),
        throwsStateError,
      );
    });

    test('자기 자신을 금지하는 계획은 만들지 않는다', () {
      expect(() => plan(blockedByPlayerId: 'player-2'), throwsArgumentError);
    });
  });

  test('금지 해제는 그룹 활동 시각만 남기고 관계를 복원하지 않는다', () {
    final created = GroupApplicationWritePlan.blockReleased(
      groupRevision: 7,
      serverTimestamp: Object(),
    );

    expect(created.groupPatch.keys, ['revision', 'lastActivityAt', 'updatedAt']);
    expect(created.groupPatch['revision'], 8);
    expect(created.joinRelationPatch, isNull);
    expect(created.playerRelationPatch, isNull);
    expect(created.blockDocument, isNull);
    expect(created.member, isNull);
    expect(created.membershipStatePatch, isNull);
  });
}
