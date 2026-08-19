// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_profile_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterProfileDto _$CharacterProfileDtoFromJson(Map<String, dynamic> json) =>
    CharacterProfileDto(
      serverName: json['ServerName'] as String,
      characterName: json['CharacterName'] as String,
      characterLevel: (json['CharacterLevel'] as num).toInt(),
      characterClassName: json['CharacterClassName'] as String,
      itemAvgLevel: json['ItemAvgLevel'] as String?,
      combatPower: json['CombatPower'] as String?,
    );
