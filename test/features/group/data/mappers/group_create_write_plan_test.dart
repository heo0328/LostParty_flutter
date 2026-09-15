import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_create_write_plan.dart';
import 'package:lost_party/features/group/domain/entities/group_create_command.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';

void main() {
  GroupCreateCommand command({String? name}) => GroupCreateCommand(
    representativeCharacterId: 'character-1',
    representativeCharacterName: '검증된캐릭터',
    representativeServerName: '루페온',
    name: name,
  );

  GroupCreateWritePlan plan({
    String? name,
    GroupMembershipState? membershipState,
    Object? serverTimestamp,
  }) => GroupCreateWritePlan.fromCommand(
    command: command(name: name),
    groupId: 'group-1',
    playerId: 'player-1',
    serverTimestamp: serverTimestamp ?? Object(),
    verifiedCharacterName: '검증된캐릭터',
    verifiedServerName: '루페온',
    verifiedClassName: '버서커',
    verifiedItemLevel: 1700,
    verifiedCombatPower: 320,
    membershipState:
        membershipState ?? const GroupMembershipState.empty('player-1'),
  );

  test('신규 그룹은 active·인원 1·revision 1·초대코드 없음으로 만든다', () {
    final timestamp = Object();
    final created = plan(serverTimestamp: timestamp);

    expect(created.group['schemaVersion'], 1);
    expect(created.group['status'], 'active');
    expect(created.group['leaderPlayerId'], 'player-1');
    expect(created.group['memberCount'], 1);
    expect(created.group['activeRecruitmentCount'], 0);
    expect(created.group['revision'], 1);
    expect(created.group['hasActiveJoinCode'], isFalse);
    expect(created.group.containsKey('activeJoinCode'), isFalse);
    expect(created.group['joinCodeVisibleToMembers'], isFalse);
    expect(created.group['deletedAt'], isNull);
    expect(created.group['createdAt'], same(timestamp));
    expect(created.group['updatedAt'], same(timestamp));
    expect(created.group['lastActivityAt'], same(timestamp));
  });

  test('그룹명 미입력은 대표 캐릭터명 기반 기본값을 사용한다', () {
    expect(plan().group['name'], '검증된캐릭터의 그룹');
    expect(plan(name: '  ').group['name'], '검증된캐릭터의 그룹');
    expect(plan(name: ' 로파길드 ').group['name'], '로파길드');
  });

  test('검색 Projection은 정규화한 그룹명과 대표 캐릭터명을 담는다', () {
    final created = plan(name: 'LostParty Guild');

    expect(created.group['normalizedName'], 'lostparty guild');
    expect(created.group['normalizedRepresentativeCharacterName'], '검증된캐릭터');
    expect(created.group['representativeCharacterNameSnapshot'], '검증된캐릭터');
    expect(created.group['representativeServerNameSnapshot'], '루페온');
    expect(
      created.group['leaderDisplayCharacterNameSnapshot'],
      created.group['representativeCharacterNameSnapshot'],
    );
  });

  test('생성자 membership은 leader·joinSequence 1·created 경로를 남긴다', () {
    final created = plan();

    expect(created.leaderMember['schemaVersion'], 1);
    expect(created.leaderMember['groupId'], 'group-1');
    expect(created.leaderMember['playerId'], 'player-1');
    expect(created.leaderMember['role'], 'leader');
    expect(created.leaderMember['joinSequence'], 1);
    expect(created.leaderMember['joinedBy'], 'created');
    expect(created.leaderMember['displayCharacterIdSnapshot'], 'character-1');
    expect(created.leaderMember['displayCharacterNameSnapshot'], '검증된캐릭터');
    expect(created.leaderMember['displayClassNameSnapshot'], '버서커');
    expect(created.leaderMember['itemLevelSnapshot'], 1700);
    expect(created.leaderMember['combatPowerSnapshot'], 320);
    expect(created.leaderMember['gemValidationSnapshot'], isNull);
    expect(created.leaderMember['revision'], 1);
  });

  test('최초 membership state는 Group ID 하나와 revision 1로 만든다', () {
    final created = plan();

    expect(created.membershipState['playerId'], 'player-1');
    expect(created.membershipState['activeGroupIds'], ['group-1']);
    expect(created.membershipState['activeGroupCount'], 1);
    expect(created.membershipState['revision'], 1);
  });

  test('기존 membership state에는 Group ID를 정확히 하나 추가하고 revision을 1 올린다', () {
    final created = plan(
      membershipState: const GroupMembershipState(
        playerId: 'player-1',
        activeGroupIds: ['group-0'],
        revision: 4,
      ),
    );

    expect(created.membershipState['activeGroupIds'], ['group-0', 'group-1']);
    expect(created.membershipState['activeGroupCount'], 2);
    expect(created.membershipState['revision'], 5);
  });

  test('Player relation Projection은 member·요청 상태 없음으로 만든다', () {
    final created = plan(name: '로파길드');

    expect(created.memberRelation['schemaVersion'], 1);
    expect(created.memberRelation['groupId'], 'group-1');
    expect(created.memberRelation['playerId'], 'player-1');
    expect(created.memberRelation['relation'], 'member');
    expect(created.memberRelation['requestStatus'], isNull);
    expect(created.memberRelation['expiresAt'], isNull);
    expect(created.memberRelation['groupNameSnapshot'], '로파길드');
    expect(created.memberRelation['displayCharacterNameSnapshot'], '검증된캐릭터');
    expect(created.memberRelation['sourceRevision'], 1);
  });

  test('그룹명 Snapshot은 그룹 원본과 같은 값을 사용한다', () {
    final created = plan();

    expect(created.memberRelation['groupNameSnapshot'], created.group['name']);
  });

  test('이미 가입한 그룹과 50개 한도는 쓰기 계획을 만들지 않는다', () {
    expect(
      () => plan(
        membershipState: const GroupMembershipState(
          playerId: 'player-1',
          activeGroupIds: ['group-1'],
          revision: 1,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => plan(
        membershipState: GroupMembershipState(
          playerId: 'player-1',
          activeGroupIds: List.generate(50, (index) => 'joined-$index'),
          revision: 50,
        ),
      ),
      throwsStateError,
    );
  });

  test('잘못된 Group ID와 Player ID를 거절한다', () {
    expect(
      () => GroupCreateWritePlan.fromCommand(
        command: command(),
        groupId: 'groups/group-1',
        playerId: 'player-1',
        serverTimestamp: Object(),
        verifiedCharacterName: '검증된캐릭터',
        verifiedServerName: '루페온',
        verifiedClassName: '버서커',
        membershipState: const GroupMembershipState.empty('player-1'),
      ),
      throwsArgumentError,
    );
    expect(
      () => GroupCreateWritePlan.fromCommand(
        command: command(),
        groupId: 'group-1',
        playerId: '  ',
        serverTimestamp: Object(),
        verifiedCharacterName: '검증된캐릭터',
        verifiedServerName: '루페온',
        verifiedClassName: '버서커',
        membershipState: const GroupMembershipState.empty('  '),
      ),
      throwsArgumentError,
    );
  });
}
