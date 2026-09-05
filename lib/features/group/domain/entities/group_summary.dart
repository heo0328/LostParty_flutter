enum GroupStatus { active, softDeleted }

/// 계약 §4.2 공개 읽기 범위. 멤버 Player ID 배열과 금지 정보는 담지 않는다.
class GroupPublicSummary {
  const GroupPublicSummary({
    required this.groupId,
    required this.name,
    required this.status,
    required this.representativeCharacterNameSnapshot,
    required this.representativeServerNameSnapshot,
    required this.leaderDisplayCharacterNameSnapshot,
    required this.memberCount,
    required this.revision,
    required this.hasActiveJoinCode,
    required this.joinCodeVisibleToMembers,
    this.activeJoinCode,
    required this.createdAt,
    required this.lastActivityAt,
  });

  final String groupId;
  final String name;
  final GroupStatus status;
  final String representativeCharacterNameSnapshot;
  final String representativeServerNameSnapshot;
  final String leaderDisplayCharacterNameSnapshot;
  final int memberCount;
  final int revision;

  /// 계약 §7. 활성 코드 존재 여부다.
  final bool hasActiveJoinCode;

  /// 멤버 화면 공개 정책. 코드를 아는 Player의 가입 가능 여부는 바꾸지 않는다.
  final bool joinCodeVisibleToMembers;

  /// 단순 초대 수단인 현재 코드. 이전 문서에는 없을 수 있다.
  final String? activeJoinCode;

  final DateTime createdAt;
  final DateTime lastActivityAt;

  bool get isActive => status == GroupStatus.active;
}
