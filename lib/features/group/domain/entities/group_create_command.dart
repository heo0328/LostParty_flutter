/// 계약 §8.1 그룹 생성 명령. 그룹명 미입력은 [name] == null로 전달한다.
class GroupCreateCommand {
  const GroupCreateCommand({
    required this.representativeCharacterId,
    required this.representativeCharacterName,
    required this.representativeServerName,
    this.name,
  });

  static const minNameLength = 1;
  static const maxNameLength = 20;

  /// 서버 Character 문서 ID다. 로컬 캐릭터 ID나 캐릭터명이 아니다.
  final String representativeCharacterId;
  final String representativeCharacterName;
  final String representativeServerName;
  final String? name;

  bool get usesDefaultName => (name ?? '').trim().isEmpty;
}
