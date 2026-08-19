import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
import '../mappers/sibling_character_mapper.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({
    required LostArkCharacterRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final LostArkCharacterRemoteDataSource _remoteDataSource;

  @override
  Future<List<CharacterSummary>> fetchCharacters(String characterName) async {
    final dtos = await _remoteDataSource.fetchSiblings(characterName);

    try {
      return dtos.map((dto) => dto.toDomain()).toList(growable: false);
    } on FormatException {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    }
  }
}
