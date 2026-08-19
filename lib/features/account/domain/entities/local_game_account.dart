class LocalGameAccount {
  const LocalGameAccount({
    required this.id,
    required this.label,
    required this.isMain,
    required this.lookupCharacterName,
    required this.representativeCharacterId,
    required this.displayLimit,
    required this.characters,
  });

  final int id;
  final String label;
  final bool isMain;
  final String lookupCharacterName;
  final int? representativeCharacterId;
  final int displayLimit;
  final List<LocalAccountCharacter> characters;

  List<LocalAccountCharacter> get visibleCharacters {
    final visible =
        characters.where((character) => character.isVisible).toList()
          ..sort((left, right) {
            final leftIsRepresentative = left.id == representativeCharacterId;
            final rightIsRepresentative = right.id == representativeCharacterId;
            if (leftIsRepresentative != rightIsRepresentative) {
              return leftIsRepresentative ? -1 : 1;
            }

            final leftOrder = left.displayOrder;
            final rightOrder = right.displayOrder;
            if (leftOrder != null || rightOrder != null) {
              if (leftOrder == null) {
                return 1;
              }
              if (rightOrder == null) {
                return -1;
              }
              final orderComparison = leftOrder.compareTo(rightOrder);
              if (orderComparison != 0) {
                return orderComparison;
              }
            }

            final leftItemLevel = left.itemLevel ?? -1;
            final rightItemLevel = right.itemLevel ?? -1;
            final itemLevelComparison = rightItemLevel.compareTo(leftItemLevel);
            if (itemLevelComparison != 0) {
              return itemLevelComparison;
            }
            return left.characterName.compareTo(right.characterName);
          });
    return visible.take(displayLimit).toList(growable: false);
  }
}

class LocalAccountCharacter {
  const LocalAccountCharacter({
    required this.id,
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    required this.itemLevel,
    required this.combatPower,
    required this.isVisible,
    required this.displayOrder,
  });

  final int id;
  final String serverName;
  final String characterName;
  final int characterLevel;
  final String characterClassName;
  final double? itemLevel;
  final double? combatPower;
  final bool isVisible;
  final int? displayOrder;
}
