import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/data/mappers/group_document_mapper.dart';
import 'package:lost_party/features/group/domain/entities/group_blocked_player.dart';
import 'package:lost_party/features/group/domain/entities/group_join_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/entities/group_summary.dart';

void main() {
  final mapper = GroupDocumentMapper(
    toDateTime: (value) => value is DateTime
        ? value
        : throw const FormatException('Expected DateTime.'),
  );
  final createdAt = DateTime.utc(2026, 8, 1, 12);
  final lastActivityAt = DateTime.utc(2026, 8, 20, 9, 30);

  Map<String, Object?> groupData({Object? status = 'active'}) => {
    'schemaVersion': 1,
    'status': status,
    'name': '로파길드',
    'normalizedName': '로파길드',
    'representativeCharacterId': 'character-1',
    'representativeCharacterNameSnapshot': '검증된캐릭터',
    'normalizedRepresentativeCharacterName': '검증된캐릭터',
    'representativeServerNameSnapshot': '루페온',
    'leaderPlayerId': 'player-1',
    'leaderDisplayCharacterNameSnapshot': '검증된캐릭터',
    'memberCount': 3,
    'revision': 7,
    'hasActiveJoinCode': false,
    'joinCodeVisibleToMembers': false,
    'lastActivityAt': lastActivityAt,
    'createdAt': createdAt,
    'updatedAt': lastActivityAt,
    'deletedAt': null,
  };

  test('공개 요약은 계약 §4.2 공개 필드만 담는다', () {
    final summary = mapper.toPublicSummary(
      GroupDocumentDto(id: 'group-1', data: groupData()),
    );

    expect(summary.groupId, 'group-1');
    expect(summary.name, '로파길드');
    expect(summary.status, GroupStatus.active);
    expect(summary.isActive, isTrue);
    expect(summary.representativeCharacterNameSnapshot, '검증된캐릭터');
    expect(summary.representativeServerNameSnapshot, '루페온');
    expect(summary.leaderDisplayCharacterNameSnapshot, '검증된캐릭터');
    expect(summary.memberCount, 3);
    expect(summary.revision, 7);
    expect(summary.hasActiveJoinCode, isFalse);
    expect(summary.activeJoinCode, isNull);
    expect(summary.joinCodeVisibleToMembers, isFalse);
    expect(summary.createdAt, createdAt);
    expect(summary.lastActivityAt, lastActivityAt);
  });

  test('공개 요약은 활성 코드 플래그와 멤버 표시 정책을 읽는다', () {
    final summary = mapper.toPublicSummary(
      GroupDocumentDto(
        id: 'group-1',
        data: {
          ...groupData(),
          'hasActiveJoinCode': true,
          'activeJoinCode': 'ABC234',
          'joinCodeVisibleToMembers': true,
        },
      ),
    );

    expect(summary.hasActiveJoinCode, isTrue);
    expect(summary.activeJoinCode, 'ABC234');
    expect(summary.joinCodeVisibleToMembers, isTrue);
  });

  test('softDeleted 그룹은 상태를 그대로 노출하고 active로 취급하지 않는다', () {
    final summary = mapper.toPublicSummary(
      GroupDocumentDto(id: 'group-1', data: groupData(status: 'softDeleted')),
    );

    expect(summary.status, GroupStatus.softDeleted);
    expect(summary.isActive, isFalse);
  });

  test('schemaVersion과 상태 값이 계약을 벗어나면 계약 오류로 올린다', () {
    expect(
      () => mapper.toPublicSummary(
        GroupDocumentDto(
          id: 'group-1',
          data: {...groupData(), 'schemaVersion': 2},
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
    expect(
      () => mapper.toPublicSummary(
        GroupDocumentDto(id: 'group-1', data: groupData(status: 'archived')),
      ),
      throwsA(isA<GroupContractException>()),
    );
  });

  test('필수 문자열·숫자·시각 누락을 계약 오류로 구분한다', () {
    for (final field in [
      'name',
      'representativeCharacterNameSnapshot',
      'representativeServerNameSnapshot',
      'leaderDisplayCharacterNameSnapshot',
    ]) {
      expect(
        () => mapper.toPublicSummary(
          GroupDocumentDto(id: 'group-1', data: {...groupData(), field: ''}),
        ),
        throwsA(isA<GroupContractException>()),
        reason: '$field는 비어 있을 수 없다.',
      );
    }
    expect(
      () => mapper.toPublicSummary(
        GroupDocumentDto(
          id: 'group-1',
          data: {...groupData(), 'memberCount': 'three'},
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
    expect(
      () => mapper.toPublicSummary(
        GroupDocumentDto(
          id: 'group-1',
          data: {...groupData(), 'lastActivityAt': 'now'},
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
  });

  test('membership 문서는 Player ID를 문서 ID에서 읽는다', () {
    final member = mapper.toMember(
      GroupDocumentDto(
        id: 'player-1',
        data: {
          'schemaVersion': 1,
          'groupId': 'group-1',
          'playerId': 'player-1',
          'role': 'leader',
          'joinedAt': createdAt,
          'joinSequence': 1,
          'joinedBy': 'created',
          'displayCharacterIdSnapshot': 'character-1',
          'displayCharacterNameSnapshot': '검증된캐릭터',
          'revision': 1,
          'createdAt': createdAt,
          'updatedAt': createdAt,
        },
      ),
    );

    expect(member.playerId, 'player-1');
    expect(member.role, GroupMemberRole.leader);
    expect(member.isLeader, isTrue);
    expect(member.joinedBy, GroupJoinedBy.created);
    expect(member.joinSequence, 1);
    expect(member.gemValidationSnapshot, isNull);
  });

  test('relation Projection은 Group ID를 문서 ID에서 읽고 선택 필드를 허용한다', () {
    final relation = mapper.toRelation(
      GroupDocumentDto(
        id: 'group-1',
        data: {
          'schemaVersion': 1,
          'groupId': 'group-1',
          'playerId': 'player-1',
          'relation': 'member',
          'requestStatus': null,
          'groupNameSnapshot': '로파길드',
          'displayCharacterNameSnapshot': '검증된캐릭터',
          'expiresAt': null,
          'sourceRevision': 1,
          'createdAt': createdAt,
          'updatedAt': lastActivityAt,
        },
      ),
    );

    expect(relation.groupId, 'group-1');
    expect(relation.relation, GroupRelationKind.member);
    expect(relation.isMember, isTrue);
    expect(relation.requestStatus, isNull);
    expect(relation.expiresAt, isNull);
    expect(relation.isExpiredAt(lastActivityAt), isFalse);
  });

  Map<String, Object?> joinRelationData({
    Object? kind = 'invitation',
    Object? status = 'pending',
    Object? targetPlayerId = 'player-9',
    Object? itemLevelSnapshot = 1700.5,
    Object? decidedAt,
  }) => {
    'schemaVersion': 1,
    'groupId': 'group-1',
    'targetPlayerId': targetPlayerId,
    'kind': kind,
    'status': status,
    'requestedByPlayerId': 'player-1',
    'characterIdSnapshot': 'character-9',
    'characterNameSnapshot': '초대대상',
    'serverNameSnapshot': '루페온',
    'characterClassNameSnapshot': '버서커',
    'itemLevelSnapshot': itemLevelSnapshot,
    'combatPowerSnapshot': null,
    'applicationAttempt': 0,
    'revision': 2,
    'createdAt': createdAt,
    'expiresAt': createdAt.add(const Duration(hours: 24)),
    'decidedAt': decidedAt,
    'updatedAt': createdAt,
  };

  test('join relation은 문서 ID를 대상 Player ID로 읽고 선택 숫자를 허용한다', () {
    final relation = mapper.toJoinRelation(
      GroupDocumentDto(id: 'player-9', data: joinRelationData()),
    );

    expect(relation.groupId, 'group-1');
    expect(relation.targetPlayerId, 'player-9');
    expect(relation.kind, GroupJoinRelationKind.invitation);
    expect(relation.isInvitation, isTrue);
    expect(relation.status, GroupRequestStatus.pending);
    expect(relation.requestedByPlayerId, 'player-1');
    expect(relation.itemLevelSnapshot, 1700.5);
    expect(relation.combatPowerSnapshot, isNull);
    expect(relation.gemValidationSnapshot, isNull);
    expect(relation.decidedAt, isNull);
    expect(relation.revision, 2);
  });

  test('membership·join relation의 보석 맵은 방어적으로 읽는다', () {
    final gem = {
      'gemValidationStatus': 'foreignClass',
      'foreignClassGemCount': 2,
      'unverifiedSameClassGemCount': 0,
      'gemValidatedAt': createdAt,
      'catalogVersion': '2026.09.08',
    };
    final member = mapper.toMember(
      GroupDocumentDto(
        id: 'player-1',
        data: {
          'schemaVersion': 1,
          'groupId': 'group-1',
          'playerId': 'player-1',
          'role': 'member',
          'joinedAt': createdAt,
          'joinSequence': 2,
          'joinedBy': 'application',
          'displayCharacterIdSnapshot': 'character-1',
          'displayCharacterNameSnapshot': '검증된캐릭터',
          'displayClassNameSnapshot': '바드',
          'itemLevelSnapshot': 1700,
          'combatPowerSnapshot': 2500,
          'gemValidationSnapshot': gem,
          'revision': 1,
          'createdAt': createdAt,
          'updatedAt': createdAt,
        },
      ),
    );
    expect(member.gemValidationSnapshot?.status.name, 'foreignClass');
    expect(member.gemValidationSnapshot?.foreignClassGemCount, 2);

    final incomplete = mapper.toMember(
      GroupDocumentDto(
        id: 'player-2',
        data: {
          'schemaVersion': 1,
          'groupId': 'group-1',
          'playerId': 'player-2',
          'role': 'member',
          'joinedAt': createdAt,
          'joinSequence': 3,
          'joinedBy': 'joinCode',
          'displayCharacterIdSnapshot': 'character-2',
          'displayCharacterNameSnapshot': '다른캐릭터',
          'gemValidationSnapshot': {
            'gemValidationStatus': 'foreignClass',
            'foreignClassGemCount': 1,
          },
          'revision': 1,
          'createdAt': createdAt,
          'updatedAt': createdAt,
        },
      ),
    );
    expect(incomplete.gemValidationSnapshot, isNull);

    final relation = mapper.toJoinRelation(
      GroupDocumentDto(
        id: 'player-9',
        data: {...joinRelationData(), 'gemValidationSnapshot': gem},
      ),
    );
    expect(relation.gemValidationSnapshot?.catalogVersion, '2026.09.08');
  });

  test('만료 시각이 지난 pending relation은 유효 요청으로 취급하지 않는다', () {
    final relation = mapper.toJoinRelation(
      GroupDocumentDto(id: 'player-9', data: joinRelationData()),
    );

    expect(relation.isPendingAt(createdAt.add(const Duration(hours: 23))), isTrue);
    expect(relation.isPendingAt(createdAt.add(const Duration(hours: 24))), isFalse);
    expect(relation.isExpiredAt(createdAt.add(const Duration(hours: 24))), isTrue);
  });

  test('join relation 문서 ID와 targetPlayerId 불일치를 계약 오류로 올린다', () {
    expect(
      () => mapper.toJoinRelation(
        GroupDocumentDto(
          id: 'player-9',
          data: joinRelationData(targetPlayerId: 'player-8'),
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
  });

  test('join relation 종류·상태·숫자 형식 오류를 계약 오류로 구분한다', () {
    expect(
      () => mapper.toJoinRelation(
        GroupDocumentDto(id: 'player-9', data: joinRelationData(kind: 'joinCode')),
      ),
      throwsA(isA<GroupContractException>()),
    );
    expect(
      () => mapper.toJoinRelation(
        GroupDocumentDto(id: 'player-9', data: joinRelationData(status: 'done')),
      ),
      throwsA(isA<GroupContractException>()),
    );
    expect(
      () => mapper.toJoinRelation(
        GroupDocumentDto(
          id: 'player-9',
          data: joinRelationData(itemLevelSnapshot: '1,700.50'),
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
  });

  test('applicant stats 문서가 없으면 신청 횟수 0으로 취급한다', () {
    final stats = mapper.toApplicantStats(
      groupId: 'group-1',
      playerId: 'player-2',
      data: null,
    );

    expect(stats.applicationCount, 0);
    expect(stats.nextApplicationAttempt, 1);
    expect(stats.lastCharacterNameSnapshot, isNull);
  });

  test('applicant stats는 누적 횟수와 최신 Snapshot을 읽는다', () {
    final stats = mapper.toApplicantStats(
      groupId: 'group-1',
      playerId: 'player-2',
      data: {
        'schemaVersion': 1,
        'groupId': 'group-1',
        'playerId': 'player-2',
        'applicationCount': 3,
        'lastCharacterNameSnapshot': '신청캐릭터',
        'lastItemLevelSnapshot': 1680,
        'lastCombatPowerSnapshot': null,
        'createdAt': createdAt,
        'updatedAt': lastActivityAt,
      },
    );

    expect(stats.applicationCount, 3);
    expect(stats.nextApplicationAttempt, 4);
    expect(stats.lastCharacterNameSnapshot, '신청캐릭터');
    expect(stats.lastItemLevelSnapshot, 1680.0);
    expect(stats.lastCombatPowerSnapshot, isNull);
  });

  Map<String, Object?> blockedPlayerData({
    Object? playerId = 'player-2',
    Object? reason = 'applicationRejected',
  }) => {
    'schemaVersion': 1,
    'groupId': 'group-1',
    'playerId': playerId,
    'blockedByPlayerId': 'player-1',
    'reason': reason,
    'characterNameSnapshot': '신청캐릭터',
    'applicationCountSnapshot': 3,
    'itemLevelSnapshot': 1680,
    'combatPowerSnapshot': null,
    'createdAt': createdAt,
    'updatedAt': lastActivityAt,
  };

  test('금지 문서는 Player 단위 사유와 신청 횟수 Snapshot을 읽는다', () {
    final blocked = mapper.toBlockedPlayer(
      GroupDocumentDto(id: 'player-2', data: blockedPlayerData()),
    );

    expect(blocked.groupId, 'group-1');
    expect(blocked.playerId, 'player-2');
    expect(blocked.blockedByPlayerId, 'player-1');
    expect(blocked.reason, GroupBlockReason.applicationRejected);
    expect(blocked.characterNameSnapshot, '신청캐릭터');
    expect(blocked.applicationCountSnapshot, 3);
    expect(blocked.itemLevelSnapshot, 1680.0);
    expect(blocked.combatPowerSnapshot, isNull);
    expect(blocked.createdAt, createdAt);
  });

  test('금지 문서 ID 불일치와 알 수 없는 사유를 계약 오류로 올린다', () {
    expect(
      () => mapper.toBlockedPlayer(
        GroupDocumentDto(
          id: 'player-2',
          data: blockedPlayerData(playerId: 'player-3'),
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
    expect(
      () => mapper.toBlockedPlayer(
        GroupDocumentDto(
          id: 'player-2',
          data: blockedPlayerData(reason: 'kicked'),
        ),
      ),
      throwsA(isA<GroupContractException>()),
    );
  });

  test('membership state 문서가 없으면 빈 상태로 취급한다', () {
    final state = mapper.toMembershipState(playerId: 'player-1', data: null);

    expect(state.activeGroupIds, isEmpty);
    expect(state.activeGroupCount, 0);
    expect(state.revision, 0);
    expect(state.isAtLimit, isFalse);
  });

  test('membership state는 가입 그룹 ID와 revision을 읽는다', () {
    final state = mapper.toMembershipState(
      playerId: 'player-1',
      data: {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'activeGroupIds': ['group-1', 'group-2'],
        'activeGroupCount': 2,
        'revision': 2,
        'updatedAt': lastActivityAt,
      },
    );

    expect(state.activeGroupIds, ['group-1', 'group-2']);
    expect(state.activeGroupCount, 2);
    expect(state.revision, 2);
    expect(state.contains('group-2'), isTrue);
    expect(state.isAtLimit, isFalse);
  });

  test('50개 가입 상태를 한도로 판정한다', () {
    final state = mapper.toMembershipState(
      playerId: 'player-1',
      data: {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'activeGroupIds': List.generate(50, (index) => 'group-$index'),
        'activeGroupCount': 50,
        'revision': 50,
        'updatedAt': lastActivityAt,
      },
    );

    expect(state.isAtLimit, isTrue);
  });

  test('activeGroupIds 형식 오류는 빈 상태로 복구한다', () {
    final brokenType = mapper.toMembershipState(
      playerId: 'player-1',
      data: {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'activeGroupIds': 'group-1',
        'activeGroupCount': 1,
        'revision': 1,
        'updatedAt': lastActivityAt,
      },
    );
    expect(brokenType.activeGroupIds, isEmpty);
    expect(brokenType.revision, 0);

    final mixed = mapper.toMembershipState(
      playerId: 'player-1',
      data: {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'activeGroupIds': ['group-1', 2],
        'activeGroupCount': 2,
        'revision': 1,
        'updatedAt': lastActivityAt,
      },
    );
    expect(mixed.activeGroupIds, isEmpty);
    expect(mixed.revision, 0);

    final missingRevision = mapper.toMembershipState(
      playerId: 'player-1',
      data: {
        'schemaVersion': 1,
        'playerId': 'player-1',
        'activeGroupIds': <String>[],
        'updatedAt': lastActivityAt,
      },
    );
    expect(missingRevision.activeGroupIds, isEmpty);
    expect(missingRevision.revision, 0);
  });
}
