import 'dart:convert';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_build_draft.dart';
import '../../domain/entities/character_build_snapshot.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/server_account_identity_binding.dart';
import '../../domain/repositories/account_identity_gateway.dart';
import '../../domain/repositories/account_ownership_status_gateway.dart';
import '../../domain/repositories/account_repository.dart';
import '../datasources/local_account_data_source.dart';
import '../datasources/lost_ark_character_remote_data_source.dart';
import '../dtos/character_profile_dto.dart';
import '../mappers/character_profile_mapper.dart';
import '../mappers/sibling_character_mapper.dart';

class AccountRepositoryImpl
    implements
        AccountRepository,
        AccountManagementRepository,
        AccountIdentityMappingRepository {
  AccountRepositoryImpl({
    required LostArkCharacterRemoteDataSource remoteDataSource,
    required LocalAccountDataSource localDataSource,
    AccountOwnershipStatusGateway? ownershipStatusGateway,
  }) : _remoteDataSource = remoteDataSource,
       _localDataSource = localDataSource,
       _ownershipStatusGateway = ownershipStatusGateway;

  final LostArkCharacterRemoteDataSource _remoteDataSource;
  final LocalAccountDataSource _localDataSource;
  final AccountOwnershipStatusGateway? _ownershipStatusGateway;

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
  Future<List<LocalGameAccount>> loadAccounts() async {
    final accounts = await _localDataSource.loadAccounts();
    final gateway = _ownershipStatusGateway;
    if (gateway == null) return accounts;
    final boundAccounts = accounts.where(
      (account) => account.serverGameAccountId != null,
    );
    if (boundAccounts.isEmpty) return accounts;
    try {
      final statuses = await gateway.loadStatuses(
        boundAccounts.map((account) => account.serverGameAccountId!),
      );
      final localStatuses = <int, String>{};
      for (final account in boundAccounts) {
        final status = statuses[account.serverGameAccountId];
        if (status != null) {
          localStatuses[account.id] = status;
        }
      }
      await _localDataSource.updateServerOwnershipStatuses(localStatuses);
      return _localDataSource.loadAccounts();
    } on Object {
      return accounts;
    }
  }

  @override
  Future<LocalGameAccount> addAccount({
    required String label,
    required String lookupCharacterName,
  }) async {
    final normalizedName = lookupCharacterName.trim();
    final dtos = await _remoteDataSource.fetchSiblings(normalizedName);
    try {
      final characters = dtos.map((dto) => dto.toDomain()).toList();
      if (characters.isEmpty) {
        throw const LostArkApiException(
          type: LostArkApiErrorType.invalidResponse,
        );
      }
      final accountId = await _localDataSource.addAccount(
        label: label,
        lookupCharacterName: normalizedName,
        characters: characters,
      );
      return (await _localDataSource.loadAccounts()).singleWhere(
        (account) => account.id == accountId,
      );
    } on FormatException {
      throw const LostArkApiException(
        type: LostArkApiErrorType.invalidResponse,
      );
    }
  }

  @override
  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
  }) => _localDataSource.updateAccount(
    accountId: accountId,
    label: label,
    isMain: isMain,
  );

  @override
  Future<void> deleteAccount(int accountId) =>
      _localDataSource.deleteAccount(accountId);

  @override
  Future<void> deleteMissingCharacter({
    required int accountId,
    required int characterId,
  }) => _localDataSource.deleteMissingCharacter(
    accountId: accountId,
    characterId: characterId,
  );

  @override
  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding) =>
      _localDataSource.bindServerIdentity(binding);

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
  Future<CharacterBuildDraft> createCharacterBuildDraft({
    required int characterId,
    required String characterName,
  }) async {
    final response = await _remoteDataSource.fetchCharacterArmory(
      characterName,
    );
    try {
      final profileJson = response['ArmoryProfile'];
      final profile = CharacterProfileDto.fromJson(
        Map<String, dynamic>.from(profileJson as Map),
      ).toDomain();
      final analysis = await _localDataSource.analyzeCharacterBuild(response);
      return CharacterBuildDraft(
        characterId: characterId,
        rawJson: jsonEncode(response),
        profile: profile,
        analysis: analysis,
        fetchedAt: DateTime.now(),
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

  @override
  Future<CharacterBuildSnapshot> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) async {
    await _localDataSource.commitCharacterBuildDraft(draft: draft, role: role);
    final snapshots = await _localDataSource.loadCharacterBuildSnapshots(
      draft.characterId,
    );
    return snapshots.singleWhere((snapshot) => snapshot.role == role);
  }

  @override
  Future<CharacterBuildSnapshot> refreshCharacterBuildSnapshot({
    required int characterId,
    required String characterName,
    required CharacterBuildRole role,
  }) async {
    final draft = await createCharacterBuildDraft(
      characterId: characterId,
      characterName: characterName,
    );
    return commitCharacterBuildDraft(draft: draft, role: role);
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

  @override
  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) => _localDataSource.setPreferredCharacterRole(
    characterId: characterId,
    role: role,
  );
}
