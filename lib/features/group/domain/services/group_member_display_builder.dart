import '../entities/group_member.dart';
import '../entities/group_member_display.dart';
import 'group_display_value.dart';

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
      characterName:
          GroupDisplayValue.text(member.displayCharacterNameSnapshot) ??
          '알 수 없는 캐릭터',
      className:
          _firstNonEmpty([
            member.displayClassNameSnapshot,
            if (isActiveCharacter && legacyClassName is String) legacyClassName,
          ]) ??
          '-',
      itemLevel:
          GroupDisplayValue.number(member.itemLevelSnapshot) ??
          (isActiveCharacter
              ? _parseNumeric(characterData['itemAvgLevel'])
              : null),
      combatPower:
          GroupDisplayValue.number(member.combatPowerSnapshot) ??
          (isActiveCharacter
              ? _parseNumeric(characterData['combatPower'])
              : null),
      gemValidation: member.gemValidationSnapshot,
    );
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final clean = GroupDisplayValue.text(value);
      if (clean != null) return clean;
    }
    return null;
  }

  static double? _parseNumeric(Object? value) => GroupDisplayValue.number(
    value is String ? double.tryParse(value.replaceAll(',', '').trim()) : value,
  );
}
