// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sibling_character_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SiblingCharacterDto _$SiblingCharacterDtoFromJson(Map<String, dynamic> json) =>
    SiblingCharacterDto(
      serverName: json['ServerName'] as String,
      characterName: json['CharacterName'] as String,
      characterLevel: (json['CharacterLevel'] as num).toInt(),
      characterClassName: json['CharacterClassName'] as String,
      itemAvgLevel: json['ItemAvgLevel'] as String?,
    );
