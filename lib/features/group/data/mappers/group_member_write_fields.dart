import '../../domain/entities/group_join_relation.dart';
import '../../domain/entities/group_request_character.dart';

/// membership 문서에 저장하는 표시 Snapshot 필드. 가입 Transaction 시점 값만 담는다.
abstract final class GroupMemberWriteFields {
  static Map<String, Object?> displaySnapshots({
    required String className,
    double? itemLevel,
    double? combatPower,
  }) => {
    'displayClassNameSnapshot': className,
    'itemLevelSnapshot': itemLevel,
    'combatPowerSnapshot': combatPower,
  };

  static Map<String, Object?> fromJoinRelation(GroupJoinRelation relation) =>
      displaySnapshots(
        className: relation.characterClassNameSnapshot,
        itemLevel: relation.itemLevelSnapshot,
        combatPower: relation.combatPowerSnapshot,
      );

  static Map<String, Object?> fromCharacter(GroupRequestCharacter character) =>
      displaySnapshots(
        className: character.characterClassName,
        itemLevel: character.itemLevel,
        combatPower: character.combatPower,
      );
}
