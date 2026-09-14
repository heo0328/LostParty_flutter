class GroupActiveRecruitmentWritePlan {
  const GroupActiveRecruitmentWritePlan._({required this.groupPatch});

  factory GroupActiveRecruitmentWritePlan.open({
    required String recruitmentId,
    required int currentCount,
    required int groupRevision,
    required Object serverTimestamp,
  }) {
    if (recruitmentId.isEmpty || currentCount < 0 || groupRevision < 0) {
      throw ArgumentError('활성 모집 증가 입력이 올바르지 않습니다.');
    }
    return GroupActiveRecruitmentWritePlan._(
      groupPatch: Map.unmodifiable({
        'activeRecruitmentCount': currentCount + 1,
        'lastRecruitmentId': recruitmentId,
        'revision': groupRevision + 1,
        'updatedAt': serverTimestamp,
      }),
    );
  }

  factory GroupActiveRecruitmentWritePlan.close({
    required String recruitmentId,
    required int currentCount,
    required int groupRevision,
    required Object serverTimestamp,
  }) {
    if (recruitmentId.isEmpty || currentCount <= 0 || groupRevision < 0) {
      throw ArgumentError('활성 모집 감소 입력이 올바르지 않습니다.');
    }
    return GroupActiveRecruitmentWritePlan._(
      groupPatch: Map.unmodifiable({
        'activeRecruitmentCount': currentCount - 1,
        'lastRecruitmentId': recruitmentId,
        'revision': groupRevision + 1,
        'updatedAt': serverTimestamp,
      }),
    );
  }

  static void validateDisband({required int activeRecruitmentCount}) {
    if (activeRecruitmentCount < 0) {
      throw ArgumentError.value(
        activeRecruitmentCount,
        'activeRecruitmentCount',
      );
    }
    if (activeRecruitmentCount != 0) {
      throw StateError('활성 그룹 모집이 있으면 그룹을 해산할 수 없습니다.');
    }
  }

  final Map<String, Object?> groupPatch;
}
