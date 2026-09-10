import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/data/repositories/group_command_runner.dart';
import 'package:lost_party/features/group/domain/entities/group_create_result.dart';
import 'package:lost_party/features/group/domain/entities/group_join_command.dart';
import 'package:lost_party/features/group/domain/entities/group_relation.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_create_view_model.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_join_code_view_model.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_join_view_model.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_read_view_model.dart';

void main() {
  group('groupJoinFailureMessage', () {
    test('금지와 permission-denied는 가입 불가 문구만 보여 준다', () {
      expect(
        groupJoinFailureMessage(GroupJoinFailure.blocked),
        '이 그룹에 가입할 수 없습니다.',
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.permissionDenied),
        '이 그룹에 가입할 수 없습니다.',
      );
    });

    test('정원·revision·코드 폐기는 새로고침·재시도 안내를 포함한다', () {
      expect(
        groupJoinFailureMessage(GroupJoinFailure.groupCapacityFull),
        contains('새로고침'),
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.revisionConflict),
        contains('새로고침'),
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.joinCodeMissing),
        contains('새로고침'),
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.temporarilyUnavailable),
        contains('새로고침'),
      );
    });

    test('그룹장 탈퇴는 이전·해산 안내를 보여 준다', () {
      expect(
        groupJoinFailureMessage(GroupJoinFailure.leaderCannotLeave),
        contains('그룹장'),
      );
    });

    test('해산 차단은 정리할 항목을 안내한다', () {
      expect(
        groupJoinFailureMessage(GroupJoinFailure.disbandRequiresSoloGroup),
        contains('해산'),
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.pendingGroupRequests),
        contains('초대'),
      );
      expect(
        groupJoinFailureMessage(GroupJoinFailure.activeGroupRaidExists),
        contains('그룹만 공개'),
      );
      expect(
        groupDisbandFailureMessage(GroupJoinFailure.joinCodeActive),
        contains('초대코드 화면에서 폐기'),
      );
      expect(
        groupDisbandFailureMessage(GroupJoinFailure.permissionDenied),
        contains('그룹 해산 권한'),
      );
    });

    test('탈퇴 permission-denied는 가입 문구가 아닌 탈퇴 안내를 보여 준다', () {
      expect(
        groupLeaveFailureMessage(GroupJoinFailure.permissionDenied),
        contains('탈퇴'),
      );
      expect(
        groupLeaveFailureMessage(GroupJoinFailure.permissionDenied),
        isNot(contains('가입할 수 없습니다')),
      );
    });

    test('초대코드 전용 메시지는 공통 매핑을 재사용한다', () {
      expect(
        groupJoinCodeFailureMessage(GroupJoinFailure.joinCodeMissing),
        groupJoinFailureMessage(GroupJoinFailure.joinCodeMissing),
      );
      expect(
        groupJoinCodeFailureMessage(GroupJoinFailure.blocked),
        '이 그룹에 가입할 수 없습니다.',
      );
    });
  });

  group('groupFirebaseFailure', () {
    test('permission-denied / failed-precondition / unavailable을 구분한다', () {
      expect(
        groupFirebaseFailure('permission-denied'),
        GroupJoinFailure.permissionDenied,
      );
      expect(
        groupFirebaseFailure('failed-precondition'),
        GroupJoinFailure.revisionConflict,
      );
      expect(
        groupFirebaseFailure('unavailable'),
        GroupJoinFailure.temporarilyUnavailable,
      );
      expect(
        groupFirebaseFailure('aborted'),
        GroupJoinFailure.temporarilyUnavailable,
      );
    });
  });

  group('groupCreateFailureMessage', () {
    test('서버 Character 문서 소실을 일반 캐릭터 검증 실패와 구분한다', () {
      expect(
        groupCreateFailureMessage(GroupCreateFailure.serverDataMissing),
        '서버에서 캐릭터 정보를 찾지 못했습니다.',
      );
    });

    test('권한 거부와 일시 불가를 구분한다', () {
      expect(
        groupCreateFailureMessage(GroupCreateFailure.permissionDenied),
        '그룹 생성 권한을 확인하지 못했습니다.',
      );
      expect(
        groupCreateFailureMessage(GroupCreateFailure.temporarilyUnavailable),
        contains('새로고침'),
      );
    });
  });

  group('groupReadFailureMessage', () {
    test('권한·일시 불가·계약 오류를 구분한다', () {
      expect(
        groupReadFailureMessage(
          const GroupReadException(GroupReadFailureType.permissionDenied),
        ),
        '그룹 정보를 볼 권한을 확인하지 못했습니다.',
      );
      expect(
        groupReadFailureMessage(
          const GroupReadException(GroupReadFailureType.unavailable),
        ),
        contains('새로고침'),
      );
      expect(
        groupReadFailureMessage(
          const GroupReadException(GroupReadFailureType.contract),
        ),
        '그룹 데이터 형식이 올바르지 않습니다.',
      );
    });
  });

  group('groupRequestStatusLabel', () {
    test('만료 시각이 지난 pending은 쓰기 없이 만료로 표시한다', () {
      final relation = GroupRelation(
        groupId: 'g1',
        playerId: 'p1',
        relation: GroupRelationKind.invited,
        requestStatus: GroupRequestStatus.pending,
        groupNameSnapshot: '길드',
        displayCharacterNameSnapshot: '캐릭',
        sourceRevision: 1,
        expiresAt: DateTime(2020),
        createdAt: DateTime(2019),
        updatedAt: DateTime(2019),
      );
      expect(
        groupRequestStatusLabel(relation, now: DateTime(2026)),
        '만료',
      );
      expect(
        isActionableGroupInvitation(relation, now: DateTime(2026)),
        isFalse,
      );
    });

    test('유효 pending 초대만 수락·거절 가능하다', () {
      final relation = GroupRelation(
        groupId: 'g1',
        playerId: 'p1',
        relation: GroupRelationKind.invited,
        requestStatus: GroupRequestStatus.pending,
        groupNameSnapshot: '길드',
        displayCharacterNameSnapshot: '캐릭',
        sourceRevision: 1,
        expiresAt: DateTime(2100),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(
        groupRequestStatusLabel(relation, now: DateTime(2026)),
        '대기 중',
      );
      expect(
        isActionableGroupInvitation(relation, now: DateTime(2026)),
        isTrue,
      );
    });
  });
}
