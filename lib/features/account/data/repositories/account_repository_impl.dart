import 'dart:convert';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_build_snapshot.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/local_account_data_source.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
import '../dtos/character_profile_dto.dart';
import '../mappers/character_profile_mapper.dart';
import '../mappers/sibling_character_mapper.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required LostArkCharacterRemoteDataSource remoteDataSource,
    required LocalAccountDataSource localDataSource,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource;

  final LostArkCharacterRemoteDataSource _remoteDataSource;
  final LocalAccountDataSource _localDataSource;

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) async {
    final dtos = await _remoteDataSource.fetchSiblings(characterName);

    try {
      final characters = dtos
          .map((dto) => dto.toDomain())
          .toList(growable: false);
      if (characters.isEmpty) {
        throw const LostArkApiException(
          type: LostArkApiErrorType.invalidResponse,
        );
      }
      try {
        await _localDataSource.saveMainAccount(
          lookupCharacterName: characterName.trim(),
          characters: characters,
        );
      } on StateError {
        throw const LostArkApiException(
          type: LostArkApiErrorType.invalidResponse,
        );
      }
      return characters;
    } on FormatException {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    }
  }

  @override
  Future<CharacterProfile> fetchCharacterProfile(String characterName) async {
    final dto = await _remoteDataSource.fetchCharacterProfile(characterName);

    try {
      final profile = dto.toDomain();
      await _localDataSource.saveCharacterProfile(profile);
      return profile;
    } on FormatException {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    }
  }

  @override
  Future<LocalGameAccount?> loadMainAccount() {
    return _localDataSource.loadMainAccount();
  }

  @override
  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  }) {
    return _localDataSource.saveCharacterBuildSnapshot(
      characterId: characterId,
      role: role,
      rawJson: rawJson,
      itemLevel: itemLevel,
      combatPower: combatPower,
      capturedAt: capturedAt,
    );
  }

  @override
  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) {
    return _localDataSource.loadCharacterBuildSnapshots(characterId);
  }

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) async {
    final response = await _remoteDataSource.fetchCharacterArmory(
      characterName,
    );
    try {
      final profileJson = response['ArmoryProfile'];
      final profile = CharacterProfileDto.fromJson(
        Map<String, dynamic>.from(profileJson as Map),
      ).toDomain();
      final capturedAt = DateTime.now();
      await _localDataSource.saveCharacterBuildSnapshot(
        characterId: characterId,
        role: role,
        rawJson: jsonEncode(response),
        itemLevel: profile.itemLevel,
        combatPower: profile.combatPower,
        capturedAt: capturedAt,
      );
      await _localDataSource.saveCharacterProfile(profile);
      final snapshots = await _localDataSource.loadCharacterBuildSnapshots(
        characterId,
      );
      return snapshots.singleWhere((snapshot) => snapshot.role == role);
    } on TypeError {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    } on FormatException {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    }
  }

  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) {
    return _localDataSource.setRepresentativeCharacter(
      accountId: accountId,
      characterId: characterId,
    );
  }

  @override
  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) {
    return _localDataSource.updateDisplayLimit(
      accountId: accountId,
      displayLimit: displayLimit,
    );
  }

  @override
  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) {
    return _localDataSource.updateCharacterVisibility(
      accountId: accountId,
      characterId: characterId,
      isVisible: isVisible,
    );
  }

  @override
  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) {
    return _localDataSource.updateCharacterDisplayOrder(
      accountId: accountId,
      characterIds: characterIds,
    );
  }
}
