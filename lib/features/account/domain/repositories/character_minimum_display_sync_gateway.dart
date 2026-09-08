/// 교류 직전 Character 최소 표시값(itemAvgLevel·combatPower)만 서버에 반영한다.
/// 값이 같으면 쓰지 않으며, null로는 기존 서버 값을 지우지 않는다.
class CharacterMinimumDisplayPatch {
  const CharacterMinimumDisplayPatch({
    required this.serverCharacterId,
    this.itemLevel,
    this.combatPower,
  });

  final String serverCharacterId;
  final double? itemLevel;
  final double? combatPower;

  bool get hasValues => itemLevel != null || combatPower != null;
}

abstract interface class CharacterMinimumDisplaySyncGateway {
  /// 변경된 필드만 갱신한다. 동일값이면 쓰기를 생략하고 false를 반환한다.
  Future<bool> syncMinimumDisplay(CharacterMinimumDisplayPatch patch);
}
