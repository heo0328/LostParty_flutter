/// 그룹 전용 레이드의 참가 자격 상실 판정.
///
/// 그룹 membership 삭제는 레이드 membership을 지우지 않는다. 자격 상실은
/// 현재 모집이 그룹 전용인지와 대상이 그 그룹의 현재 멤버인지로만 계산한다.
/// 전체 공개 그룹 연결 레이드와 활동 Character 해제는 자격 상실이 아니다.
class GroupRaidQualification {
  const GroupRaidQualification._();

  static bool isGroupOnlyRaid({
    required String? visibility,
    required String? groupId,
  }) {
    final trimmedGroupId = groupId?.trim() ?? '';
    return visibility == 'group' && trimmedGroupId.isNotEmpty;
  }

  static bool hasLostQualification({
    required bool isGroupOnlyRaid,
    required bool isCurrentGroupMember,
  }) => isGroupOnlyRaid && !isCurrentGroupMember;

  static Set<String> lostPlayerIds({
    required bool isGroupOnlyRaid,
    required Iterable<String> raidMemberPlayerIds,
    required Set<String> currentGroupMemberPlayerIds,
  }) {
    if (!isGroupOnlyRaid) return const {};
    return {
      for (final playerId in raidMemberPlayerIds)
        if (!currentGroupMemberPlayerIds.contains(playerId)) playerId,
    };
  }

  /// 그룹원 목록을 읽을 수 없으면 호출자만 자격 상실로 본다.
  static Set<String> lostPlayerIdsWhenGroupUnreadable({
    required bool isGroupOnlyRaid,
    required String? currentPlayerId,
  }) {
    if (!isGroupOnlyRaid) return const {};
    final playerId = currentPlayerId?.trim() ?? '';
    if (playerId.isEmpty) return const {};
    return {playerId};
  }
}
