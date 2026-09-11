import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';

/// 계약 §6·§8.3 초대·신청에 사용하는 서버 Character Snapshot.
///
/// 초대 검색 결과와 신청에 사용한 인증 Character가 같은 모양을 공유한다. 대상
/// Player는 항상 이 Character의 [ownerPlayerId]로 확정하며 캐릭터명은 표시값이다.
class GroupRequestCharacter {
  const GroupRequestCharacter({
    required this.characterId,
    required this.ownerPlayerId,
    required this.characterName,
    required this.serverName,
    required this.characterClassName,
    this.itemLevel,
    this.combatPower,
    this.gemValidation,
  });

  final String characterId;
  final String ownerPlayerId;
  final String characterName;
  final String serverName;
  final String characterClassName;
  final double? itemLevel;
  final double? combatPower;
  final PartyGemValidationSnapshot? gemValidation;
}
