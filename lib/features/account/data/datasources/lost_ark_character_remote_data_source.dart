import '../../../../shared/lost_ark_api/client/lost_ark_api_client.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../dtos/character_profile_dto.dart';
import '../dtos/sibling_character_dto.dart';

class LostArkCharacterRemoteDataSource {
  LostArkCharacterRemoteDataSource({required LostArkApiClient apiClient})
    : _apiClient = apiClient;

  final LostArkApiClient _apiClient;

  Future<List<SiblingCharacterDto>> fetchSiblings(String characterName) async {
    final encodedName = _normalizeAndEncodeName(characterName);
    final response = await _apiClient.get<List<dynamic>>(
      '/characters/$encodedName/siblings',
    );

    try {
      return response
          .map(
            (item) => SiblingCharacterDto.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
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

  Future<CharacterProfileDto> fetchCharacterProfile(
    String characterName,
  ) async {
    final encodedName = _normalizeAndEncodeName(characterName);
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/armories/characters/$encodedName',
    );

    try {
      final profile = response['ArmoryProfile'];
      return CharacterProfileDto.fromJson(
        Map<String, dynamic>.from(profile as Map),
      );
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

  String _normalizeAndEncodeName(String characterName) {
    final normalizedName = characterName.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(
        characterName,
        'characterName',
        'Character name must not be empty.',
      );
    }

    return Uri.encodeComponent(normalizedName);
  }
}
