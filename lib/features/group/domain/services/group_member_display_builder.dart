import '../entities/group_member.dart';
import '../entities/group_member_display.dart';

/// membership Snapshot과 Character 문서를 합쳐 그룹원 카드 표시값을 만든다.
abstract final class GroupMemberDisplayBuilder {
  static GroupMemberDisplay fromMember({
    required GroupMember member,
    Map<String, Object?>? characterData,
  }) {
    final isActiveCharacter =
        characterData != null && characterData['status'] == 'active';
    final legacyClassName = characterData?['characterClassName'];

    return GroupMemberDisplay(
      member: member,
      characterName: member.displayCharacterNameSnapshot,
      className: _firstNonEmpty([
            member.displayClassNameSnapshot,
            if (isActiveCharacter && legacyClassName is String)
              legacyClassName,
          ]) ??
          '-',
      itemLevel:
          member.itemLevelSnapshot ??
          (isActiveCharacter
              ? _parseNumeric(characterData['itemAvgLevel'])
              : null),
      combatPower:
          member.combatPowerSnapshot ??
          (isActiveCharacter
              ? _parseNumeric(characterData['combatPower'])
              : null),
    );
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static double? _parseNumeric(Object? value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.replaceAll(',', '').trim())
      : null;
}
