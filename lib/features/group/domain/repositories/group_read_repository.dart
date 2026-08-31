import '../entities/group_blocked_player.dart';
import '../entities/group_join_relation.dart';
import '../entities/group_member.dart';
import '../entities/group_member_display.dart';
import '../entities/group_relation.dart';
import '../entities/group_summary.dart';

enum GroupReadFailureType {
  permissionDenied,
  unavailable,
  contract,
  unknown,
}

class GroupReadException implements Exception {
  const GroupReadException(this.type);

  final GroupReadFailureType type;

  @override
  String toString() => 'GroupReadException: $type';
}

class GroupReadSnapshot<T> {
  const GroupReadSnapshot({required this.items, required this.isFromCache});

  final List<T> items;
  final bool isFromCache;
}

/// 검색 1페이지는 정규화 필드별 query 각각 최대 [groupSearchPageSize]개이며
/// Group ID로 중복을 제거한 뒤 화면 결과가 더 적을 수 있다.
const groupSearchPageSize = 20;

abstract interface class GroupReadRepository {
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId);

  /// 계약 §11 요청 현황 탭. `invited`와 `applied` Projection만 구독한다.
  Stream<GroupReadSnapshot<GroupRelation>> watchMyRequests(String playerId);

  Future<List<GroupPublicSummary>> searchGroups({
    required String query,
    int limit,
  });

  Future<GroupPublicSummary?> loadGroup(String groupId);

  /// 상세 화면이 초대·신청 버튼을 고르기 위해 읽는 내 Projection 단건이다.
  Future<GroupRelation?> loadMyRelation({
    required String playerId,
    required String groupId,
  });

  /// 그룹원만 읽을 수 있는 요청 원본 목록이다. 그룹장 신청 관리 화면과
  /// 초대 취소 화면이 사용한다.
  Future<List<GroupJoinRelation>> loadGroupJoinRelations({
    required String groupId,
    required GroupJoinRelationKind kind,
    int limit,
  });

  /// 그룹원만 읽는 membership 단건이다. 화면은 이 결과로 그룹장 전용 행동을
  /// 노출할지 정하고, 권한은 Rules가 최종 판정한다.
  Future<GroupMember?> loadGroupMember({
    required String groupId,
    required String playerId,
  });

  /// 그룹원만 읽는 membership 목록이다. 그룹장 우선·joinSequence 오름차순 정렬은
  /// presentation에서 수행한다.
  Future<List<GroupMember>> loadGroupMembers(String groupId);

  /// 멤버 카드 표시용 Snapshot을 만든다. 캐릭터 문서가 없으면 membership Snapshot만
  /// 사용한다.
  Future<List<GroupMemberDisplay>> loadGroupMemberDisplays(String groupId);

  /// 계약 §10. 금지 목록은 현재 그룹장만 읽는다. 금지된 당사자가 호출하면
  /// `permission-denied`가 되고 존재 여부도 알 수 없다.
  Future<List<GroupBlockedPlayer>> loadBlockedPlayers({
    required String groupId,
    int limit,
  });
}
