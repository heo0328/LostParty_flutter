/// 1차 해산의 활성 그룹 전용 레이드 판정.
///
/// `raidListings`는 생성 시점 스냅샷이고 자리·상태 변경 때 갱신하지 않는다.
/// 레이드방을 해산해도 listing의 `status`는 `active`로 남을 수 있으므로
/// 해산 차단은 모집 원본의 `visibility`·`groupId`·`status`만 본다.
bool isBlockingActiveGroupRaid({
  required String groupId,
  required Map<String, dynamic> listing,
  Map<String, dynamic>? recruitment,
}) {
  if (listing['visibility'] != 'group') return false;
  if (recruitment == null) return false;
  return recruitment['visibility'] == 'group' &&
      recruitment['groupId'] == groupId &&
      recruitment['status'] == 'active';
}
