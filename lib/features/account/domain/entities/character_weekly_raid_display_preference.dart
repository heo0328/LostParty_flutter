/// 캐릭터 카드에 표시할 주간 레이드 로컬 설정.
///
/// 설정이 없으면 기본 3개(골드 추천)를 쓴다. 저장 시 [displayCount]와
/// [raidIds] 길이는 같아야 한다.
class CharacterWeeklyRaidDisplayPreference {
  const CharacterWeeklyRaidDisplayPreference({
    required this.characterId,
    required this.displayCount,
    required this.raidIds,
  });

  final int characterId;
  final int displayCount;
  final List<String> raidIds;

  bool get isValid =>
      displayCount >= 0 &&
      displayCount <= 5 &&
      raidIds.length == displayCount &&
      raidIds.toSet().length == raidIds.length;
}
