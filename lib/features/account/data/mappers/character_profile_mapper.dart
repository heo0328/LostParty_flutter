import '../../domain/entities/character_profile.dart';
import '../dtos/character_profile_dto.dart';

extension CharacterProfileMapper on CharacterProfileDto {
  CharacterProfile toDomain() {
    return CharacterProfile(
      serverName: serverName,
      characterName: characterName,
      characterLevel: characterLevel,
      characterClassName: characterClassName,
      itemLevel: _parseNumber(itemAvgLevel, 'item average level'),
      combatPower: _parseNumber(combatPower, 'combat power'),
    );
  }

  double? _parseNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsedValue = double.tryParse(value.replaceAll(',', '').trim());
    if (parsedValue == null) {
      throw FormatException('Invalid $fieldName.');
    }

    return parsedValue;
  }
}
