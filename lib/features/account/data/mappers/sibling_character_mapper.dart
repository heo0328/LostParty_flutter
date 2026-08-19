import '../../domain/entities/character_summary.dart';
import '../dtos/sibling_character_dto.dart';

extension SiblingCharacterMapper on SiblingCharacterDto {
  CharacterSummary toDomain() {
    return CharacterSummary(
      serverName: serverName,
      characterName: characterName,
      characterLevel: characterLevel,
      characterClassName: characterClassName,
      itemLevel: _parseItemLevel(itemAvgLevel),
    );
  }

  double? _parseItemLevel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(value.replaceAll(',', '').trim());
    if (parsedValue == null) {
      throw const FormatException('Invalid item average level.');
    }

    return parsedValue;
  }
}
