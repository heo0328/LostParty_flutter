/// 소유 캐릭터의 로컬 표시 전투력을 공유 Character 문서에 반영한다.
/// 값이 없는 캐릭터는 보내지 않는다. API 검증값이나 참가 자격 판정값이 아니다.
abstract interface class CharacterCombatPowerSyncGateway {
  Future<void> updateCombatPowers(Map<String, double> powersByCharacterId);
}
