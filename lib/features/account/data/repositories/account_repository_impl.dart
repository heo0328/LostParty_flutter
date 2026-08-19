import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/local_account_data_source.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
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
}
