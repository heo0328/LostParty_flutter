import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_join_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_request_character.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 9);
  final expiresAt = now.add(const Duration(hours: 24));

  const target = GroupRequestCharacter(
    characterId: 'character-9',
    ownerPlayerId: 'player-9',
    characterName: '초대대상',
    serverName: '루페온',
    characterClassName: '버서커',
    itemLevel: 1700.5,
    combatPower: 320.25,
  );

  GroupJoinRelation relation({
    GroupJoinRelationKind kind = GroupJoinRelationKind.invitation,
    GroupRequestStatus status = GroupRequestStatus.pending,
    int revision = 1,
    int applicationAttempt = 0,
    DateTime? expires,
    String requestedByPlayerId = 'player-1',
  }) => GroupJoinRelation(
    groupId: 'group-1',
    targetPlayerId: 'player-9',
    kind: kind,
    status: status,
    requestedByPlayerId: requestedByPlayerId,
    characterIdSnapshot: 'character-9',
    characterNameSnapshot: '초대대상',
    serverNameSnapshot: '루페온',
    characterClassNameSnapshot: '버서커',
    itemLevelSnapshot: 1700.5,
    combatPowerSnapshot: 320.25,
    applicationAttempt: applicationAttempt,
    revision: revision,
    createdAt: now,
    expiresAt: expires ?? expiresAt,
    updatedAt: now,
  );

  group('직접 초대', () {
    GroupJoinWritePlan plan({
      GroupJoinRelation? existingRelation,
      Object? serverTimestamp,
    }) => GroupJoinWritePlan.invitation(
      groupId: 'group-1',
      requestedByPlayerId: 'player-1',
      character: target,
      groupName: '로파길드',
      groupRevision: 7,
      existingRelation: existingRelation,
      serverTimestamp: serverTimestamp ?? Object(),
      now: now,
    );

    test('pending invitation 원본은 대상 Character Snapshot과 24시간 만료를 담는다', () {
      final timestamp = Object();
      final created = plan(serverTimestamp: timestamp).joinRelationDocument!;

      expect(created['schemaVersion'], 1);
      expect(created['groupId'], 'group-1');
      expect(created['targetPlayerId'], 'player-9');
      expect(created['kind'], 'invitation');
      expect(created['status'], 'pending');
      expect(created['requestedByPlayerId'], 'player-1');
      expect(created['characterIdSnapshot'], 'character-9');
      expect(created['characterNameSnapshot'], '초대대상');
      expect(created['serverNameSnapshot'], '루페온');
      expect(created['characterClassNameSnapshot'], '버서커');
      expect(created['itemLevelSnapshot'], 1700.5);
      expect(created['combatPowerSnapshot'], 320.25);
      expect(created['gemValidationSnapshot'], isNull);
      expect(created['revision'], 1);
      expect(created['decidedAt'], isNull);
      expect(created['createdAt'], same(timestamp));
      expect(created['updatedAt'], same(timestamp));
      expect(created['expiresAt'], expiresAt);
    });

    test('초대는 누적 신청 횟수를 증가시키지 않고 stats를 쓰지 않는다', () {
      final created = plan(
        existingRelation: relation(
          kind: GroupJoinRelationKind.application,
          status: GroupRequestStatus.rejected,
          revision: 4,
          applicationAttempt: 3,
        ),
      );

      expect(created.joinRelationDocument!['applicationAttempt'], 3);
      expect(created.applicantStats, isNull);
      expect(created.member, isNull);
      expect(created.membershipState, isNull);
    });

    test('만료·최종 relation을 재사용할 때 revision을 1 증가시킨다', () {
      final reused = plan(
        existingRelation: relation(
          status: GroupRequestStatus.pending,
          revision: 5,
          expires: now.subtract(const Duration(minutes: 1)),
        ),
      );

      expect(reused.joinRelationDocument!['revision'], 6);
      expect(reused.playerRelation['sourceRevision'], 6);
    });

    test('대상 Player Projection은 invited·pending과 같은 만료 시각을 담는다', () {
      final created = plan().playerRelation;

      expect(created['schemaVersion'], 1);
      expect(created['groupId'], 'group-1');
      expect(created['playerId'], 'player-9');
      expect(created['relation'], 'invited');
      expect(created['requestStatus'], 'pending');
      expect(created['groupNameSnapshot'], '로파길드');
      expect(created['displayCharacterNameSnapshot'], '초대대상');
      expect(created['expiresAt'], expiresAt);
      expect(created['sourceRevision'], 1);
    });

    test('그룹은 공개 필드를 그대로 두고 활동 시각과 revision만 갱신한다', () {
      final timestamp = Object();
      final patch = plan(serverTimestamp: timestamp).groupPatch;

      expect(patch.keys, ['revision', 'lastActivityAt', 'updatedAt']);
      expect(patch['revision'], 8);
      expect(patch['lastActivityAt'], same(timestamp));
      expect(patch['updatedAt'], same(timestamp));
    });

    test('자기 자신 초대와 유효 pending 관계는 쓰기 계획을 만들지 않는다', () {
      expect(
        () => GroupJoinWritePlan.invitation(
          groupId: 'group-1',
          requestedByPlayerId: 'player-9',
          character: target,
          groupName: '로파길드',
          groupRevision: 7,
          existingRelation: null,
          serverTimestamp: Object(),
          now: now,
        ),
        throwsArgumentError,
      );
      expect(
        () => plan(existingRelation: relation()),
        throwsStateError,
        reason: '유효 pending 관계는 종류가 달라도 덮어쓰지 않는다.',
      );
    });
  });

  group('가입 신청', () {
    const applicant = GroupRequestCharacter(
      characterId: 'character-2',
      ownerPlayerId: 'player-2',
      characterName: '신청캐릭터',
      serverName: '아만',
      characterClassName: '바드',
      itemLevel: 1680,
    );

    GroupJoinWritePlan plan({
      GroupJoinRelation? existingRelation,
      GroupApplicantStats? stats,
      Object? statsCreatedAt,
      Object? serverTimestamp,
    }) => GroupJoinWritePlan.application(
      groupId: 'group-1',
      character: applicant,
      groupName: '로파길드',
      groupRevision: 7,
      existingRelation: existingRelation,
      stats:
          stats ??
          const GroupApplicantStats.empty(
            groupId: 'group-1',
            playerId: 'player-2',
          ),
      serverTimestamp: serverTimestamp ?? Object(),
      now: now,
      statsCreatedAt: statsCreatedAt,
    );

    test('pending application은 본인이 요청자이며 attempt 1로 시작한다', () {
      final created = plan().joinRelationDocument!;

      expect(created['kind'], 'application');
      expect(created['targetPlayerId'], 'player-2');
      expect(created['requestedByPlayerId'], 'player-2');
      expect(created['applicationAttempt'], 1);
      expect(created['revision'], 1);
      expect(created['combatPowerSnapshot'], isNull);
    });

    test('신청 성공은 누적 횟수를 정확히 1 증가시키고 최신 Snapshot을 남긴다', () {
      final created = plan(
        stats: const GroupApplicantStats(
          groupId: 'group-1',
          playerId: 'player-2',
          applicationCount: 2,
          lastCharacterNameSnapshot: '이전캐릭터',
          lastItemLevelSnapshot: 1600,
        ),
      );

      expect(created.applicantStats!['applicationCount'], 3);
      expect(created.applicantStats!['lastCharacterNameSnapshot'], '신청캐릭터');
      expect(created.applicantStats!['lastItemLevelSnapshot'], 1680.0);
      expect(created.applicantStats!['lastCombatPowerSnapshot'], isNull);
      expect(
        created.joinRelationDocument!['applicationAttempt'],
        created.applicantStats!['applicationCount'],
        reason: 'relation attempt와 stats 횟수는 같은 값을 쓴다.',
      );
    });

    test('기존 stats의 createdAt은 유지하고 없으면 서버 시각을 쓴다', () {
      final timestamp = Object();
      final existingCreatedAt = DateTime.utc(2026, 1, 1);

      expect(
        plan(
          serverTimestamp: timestamp,
          statsCreatedAt: existingCreatedAt,
        ).applicantStats!['createdAt'],
        existingCreatedAt,
      );
      expect(
        plan(serverTimestamp: timestamp).applicantStats!['createdAt'],
        same(timestamp),
      );
    });

    test('Player Projection은 applied·pending으로 갱신된다', () {
      final created = plan().playerRelation;

      expect(created['relation'], 'applied');
      expect(created['requestStatus'], 'pending');
      expect(created['playerId'], 'player-2');
      expect(created['expiresAt'], expiresAt);
    });

    test('Character를 바꿔 재신청해도 같은 relation·stats 문서를 이어 쓴다', () {
      final created = plan(
        existingRelation: relation(
          kind: GroupJoinRelationKind.application,
          status: GroupRequestStatus.rejected,
          revision: 3,
          applicationAttempt: 1,
        ),
        stats: const GroupApplicantStats(
          groupId: 'group-1',
          playerId: 'player-2',
          applicationCount: 1,
        ),
      );

      expect(created.joinRelationDocument!['revision'], 4);
      expect(created.joinRelationDocument!['applicationAttempt'], 2);
      expect(created.applicantStats!['applicationCount'], 2);
    });
  });

  group('초대 수락', () {
    GroupJoinWritePlan plan({
      GroupMembershipState? membershipState,
      int groupMemberCount = 3,
      GroupJoinRelation? source,
      Object? serverTimestamp,
    }) => GroupJoinWritePlan.invitationAccepted(
      relation: source ?? relation(revision: 2),
      groupName: '로파길드',
      groupRevision: 7,
      groupMemberCount: groupMemberCount,
      membershipState:
          membershipState ?? const GroupMembershipState.empty('player-9'),
      serverTimestamp: serverTimestamp ?? Object(),
    );

    test('요청 원본은 accepted로 전이하고 revision·판정 시각만 바꾼다', () {
      final timestamp = Object();
      final patch = plan(serverTimestamp: timestamp).joinRelationPatch!;

      expect(patch.keys, ['status', 'revision', 'decidedAt', 'updatedAt']);
      expect(patch['status'], 'accepted');
      expect(patch['revision'], 3);
      expect(patch['decidedAt'], same(timestamp));
    });

    test('신규 membership은 읽은 인원 + 1을 joinSequence로 쓰고 invitation 경로를 남긴다', () {
      final member = plan(groupMemberCount: 12).member!;

      expect(member['role'], 'member');
      expect(member['joinedBy'], 'invitation');
      expect(member['joinSequence'], 13);
      expect(member['revision'], 1);
      expect(member['displayCharacterIdSnapshot'], 'character-9');
      expect(member['displayCharacterNameSnapshot'], '초대대상');
    });

    test('membership state에 Group ID 하나를 추가하고 revision을 1 올린다', () {
      final state = plan(
        membershipState: const GroupMembershipState(
          playerId: 'player-9',
          activeGroupIds: ['group-0'],
          revision: 4,
        ),
      ).membershipState!;

      expect(state['activeGroupIds'], ['group-0', 'group-1']);
      expect(state['activeGroupCount'], 2);
      expect(state['revision'], 5);
    });

    test('Player Projection은 member·accepted가 되고 만료 시각을 지운다', () {
      final created = plan().playerRelation;

      expect(created['relation'], 'member');
      expect(created['requestStatus'], 'accepted');
      expect(created['expiresAt'], isNull);
      expect(created['sourceRevision'], 1);
      expect(created['displayCharacterNameSnapshot'], '초대대상');
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

    test('정원 50명·그룹 50개 한도와 중복 가입은 쓰기 계획을 만들지 않는다', () {
      expect(
        () => plan(groupMemberCount: GroupMember.maxMemberCount),
        throwsStateError,
      );
      expect(
        () => plan(
          membershipState: GroupMembershipState(
            playerId: 'player-9',
            activeGroupIds: List.generate(50, (index) => 'joined-$index'),
            revision: 50,
          ),
        ),
        throwsStateError,
      );
      expect(
        () => plan(
          membershipState: const GroupMembershipState(
            playerId: 'player-9',
            activeGroupIds: ['group-1'],
            revision: 1,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('신청 관계는 초대 수락 경로로 처리하지 않는다', () {
      expect(
        () => plan(
          source: relation(kind: GroupJoinRelationKind.application),
        ),
        throwsArgumentError,
      );
    });
  });

  group('거절·취소', () {
    GroupJoinWritePlan plan(GroupRequestStatus status) =>
        GroupJoinWritePlan.decision(
          relation: relation(revision: 2),
          status: status,
          groupName: '로파길드',
          groupRevision: 7,
          serverTimestamp: Object(),
        );

    test('거절과 취소는 membership을 만들지 않는다', () {
      for (final status in [
        GroupRequestStatus.rejected,
        GroupRequestStatus.cancelled,
      ]) {
        final created = plan(status);

        expect(created.member, isNull);
        expect(created.membershipState, isNull);
        expect(created.applicantStats, isNull);
        expect(created.joinRelationDocument, isNull);
        expect(created.joinRelationPatch!['status'], status.name);
        expect(created.joinRelationPatch!['revision'], 3);
      }
    });

    test('Projection은 같은 sourceRevision과 요청 종류를 유지한다', () {
      final created = plan(GroupRequestStatus.rejected).playerRelation;

      expect(created['relation'], 'invited');
      expect(created['requestStatus'], 'rejected');
      expect(created['sourceRevision'], 3);
      expect(created['expiresAt'], expiresAt);
    });

    test('그룹 활동 시각만 갱신하고 인원은 바꾸지 않는다', () {
      final patch = plan(GroupRequestStatus.cancelled).groupPatch;

      expect(patch.containsKey('memberCount'), isFalse);
      expect(patch['revision'], 8);
    });

    test('accepted·expired·blocked는 거절·취소 계획으로 만들지 않는다', () {
      for (final status in [
        GroupRequestStatus.accepted,
        GroupRequestStatus.pending,
        GroupRequestStatus.expired,
        GroupRequestStatus.blocked,
      ]) {
        expect(() => plan(status), throwsArgumentError);
      }
    });
  });
}
