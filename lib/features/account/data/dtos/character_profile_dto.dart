import 'package:json_annotation/json_annotation.dart';

part 'character_profile_dto.g.dart';

@JsonSerializable(createToJson: false)
class CharacterProfileDto {
  const CharacterProfileDto({
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    required this.itemAvgLevel,
    required this.combatPower,
  });

  factory CharacterProfileDto.fromJson(Map<String, dynamic> json) =>
      _$CharacterProfileDtoFromJson(json);

  @JsonKey(name: 'ServerName')
  final String serverName;

  @JsonKey(name: 'CharacterName')
  final String characterName;

  @JsonKey(name: 'CharacterLevel')
  final int characterLevel;

  @JsonKey(name: 'CharacterClassName')
  final String characterClassName;

  @JsonKey(name: 'ItemAvgLevel')
  final String? itemAvgLevel;

  @JsonKey(name: 'CombatPower')
  final String? combatPower;
}
