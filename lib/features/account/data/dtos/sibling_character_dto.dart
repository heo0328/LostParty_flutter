import 'package:json_annotation/json_annotation.dart';

part 'sibling_character_dto.g.dart';

@JsonSerializable(createToJson: false)
class SiblingCharacterDto {
  const SiblingCharacterDto({
    required this.serverName,
    required this.characterName,
    required this.characterLevel,
    required this.characterClassName,
    required this.itemAvgLevel,
  });

  factory SiblingCharacterDto.fromJson(Map<String, dynamic> json) =>
      _$SiblingCharacterDtoFromJson(json);

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
}
