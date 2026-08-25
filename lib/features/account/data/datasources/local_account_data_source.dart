import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import '../../../../shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_draft.dart';
import '../../domain/entities/character_build_snapshot.dart';
import '../../domain/entities/character_profile.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/server_account_identity_binding.dart';
import '../local/account_database.dart';
import '../mappers/character_build_analysis_mapper.dart';

class LocalAccountDataSource {
  LocalAccountDataSource({
    required AccountDatabase database,
    required GameCatalogRepository gameCatalogRepository,
  }) : _database = database,
       _gameCatalogRepository = gameCatalogRepository;

  final AccountDatabase _database;
  final GameCatalogRepository _gameCatalogRepository;
  Future<GameCatalog>? _catalog;

  Future<int> saveMainAccount({
    required String lookupCharacterName,
    required List<CharacterSummary> characters,
    DateTime? fetchedAt,
  }) {
    final timestamp = fetchedAt ?? DateTime.now();
    return _database.saveMainAccountSnapshot(
      lookupCharacterName: lookupCharacterName,
      now: timestamp,
      characters: characters
          .map(
            (character) => AccountCharacterSnapshot(
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: character.itemLevel,
              fetchedAt: timestamp,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> saveCharacterProfile(CharacterProfile profile) async {
    final account = await (_database.select(
      _database.gameAccounts,
    )..where((table) => table.isMain.equals(true))).getSingleOrNull();
    if (account == null) {
      return;
    }

    await (_database.update(_database.accountCharacters)..where(
          (table) =>
              table.accountId.equals(account.id) &
              table.characterName.equals(profile.characterName),
        ))
        .write(
          AccountCharactersCompanion(
            serverName: Value(profile.serverName),
            characterLevel: Value(profile.characterLevel),
            characterClassName: Value(profile.characterClassName),
            itemLevel: Value(profile.itemLevel),
            combatPower: Value(profile.combatPower),
          ),
        );
  }

  Future<CharacterBuildAnalysis> analyzeCharacterBuild(
    Map<String, dynamic> rawJson,
  ) async {
    final catalog = await (_catalog ??= _gameCatalogRepository.loadCatalog());
    return const CharacterBuildAnalysisMapper().fromJson(
      rawJson,
      catalog: catalog,
    );
  }

  Future<LocalGameAccount?> loadMainAccount() async {
    final account = await (_database.select(
      _database.gameAccounts,
    )..where((table) => table.isMain.equals(true))).getSingleOrNull();
    if (account == null) {
      return null;
    }

    return _loadAccount(account);
  }

  Future<List<LocalGameAccount>> loadAccounts() async {
    final accounts = await _database.select(_database.gameAccounts).get();
    accounts.sort((left, right) {
      if (left.isMain != right.isMain) return left.isMain ? -1 : 1;
      return left.id.compareTo(right.id);
    });
    final result = <LocalGameAccount>[];
    for (final account in accounts) {
      result.add(await _loadAccount(account));
    }
    return List.unmodifiable(result);
  }

  Future<int> addAccount({
    required String label,
    required String lookupCharacterName,
    required List<CharacterSummary> characters,
    DateTime? fetchedAt,
  }) {
    final timestamp = fetchedAt ?? DateTime.now();
    return _database.addAccountSnapshot(
      label: label,
      lookupCharacterName: lookupCharacterName,
      now: timestamp,
      characters: characters
          .map(
            (character) => AccountCharacterSnapshot(
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: character.itemLevel,
              fetchedAt: timestamp,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> updateAccount({
    required int accountId,
    required String label,
    required bool isMain,
  }) => _database.updateAccount(
    accountId: accountId,
    label: label,
    isMain: isMain,
  );

  Future<void> deleteAccount(int accountId) =>
      _database.deleteAccount(accountId);

  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding) {
    return _database.bindServerIdentity(
      localAccountId: binding.localAccountId,
      serverGameAccountId: binding.serverGameAccountId,
      serverCharacterIdsByLocalId: binding.serverCharacterIdsByLocalId,
    );
  }

  Future<LocalGameAccount> _loadAccount(GameAccount account) async {
    final characters = await (_database.select(
      _database.accountCharacters,
    )..where((table) => table.accountId.equals(account.id))).get();
    return LocalGameAccount(
      id: account.id,
      serverGameAccountId: account.serverGameAccountId,
      label: account.label,
      isMain: account.isMain,
      lookupCharacterName: account.lookupCharacterName,
      representativeCharacterId: account.representativeCharacterId,
      displayLimit: account.displayLimit,
      characters: characters
          .map(
            (character) => LocalAccountCharacter(
              id: character.id,
              serverCharacterId: character.serverCharacterId,
              serverName: character.serverName,
              characterName: character.characterName,
              characterLevel: character.characterLevel,
              characterClassName: character.characterClassName,
              itemLevel: character.itemLevel,
              combatPower: character.combatPower,
              isVisible: character.isVisible,
              displayOrder: character.displayOrder,
              preferredRole: character.preferredRole == null
                  ? null
                  : CharacterBuildRole.values.byName(character.preferredRole!),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> saveCharacterBuildSnapshot({
    required int characterId,
    required CharacterBuildRole role,
    required String rawJson,
    required double? itemLevel,
    required double? combatPower,
    required DateTime capturedAt,
  }) {
    return _database.saveCharacterBuildSnapshot(
      characterId: characterId,
      role: role.name,
      rawJson: rawJson,
      itemLevel: itemLevel,
      combatPower: combatPower,
      capturedAt: capturedAt,
    );
  }

  Future<void> commitCharacterBuildDraft({
    required CharacterBuildDraft draft,
    required CharacterBuildRole role,
  }) {
    final profile = draft.profile;
    return _database.commitCharacterBuildSnapshot(
      characterId: draft.characterId,
      characterName: profile.characterName,
      serverName: profile.serverName,
      characterLevel: profile.characterLevel,
      characterClassName: profile.characterClassName,
      role: role.name,
      rawJson: draft.rawJson,
      itemLevel: profile.itemLevel,
      combatPower: profile.combatPower,
      capturedAt: draft.fetchedAt,
    );
  }

  Future<List<CharacterBuildSnapshot>> loadCharacterBuildSnapshots(
    int characterId,
  ) async {
    final rows = await _database.loadCharacterBuildSnapshots(characterId);
    if (rows.isEmpty) {
      return const [];
    }
    final catalog = await (_catalog ??= _gameCatalogRepository.loadCatalog());
    return rows
        .map(
          (row) => CharacterBuildSnapshot(
            id: row.id,
            characterId: row.characterId,
            role: CharacterBuildRole.values.byName(row.role),
            rawJson: row.rawJson,
            itemLevel: row.itemLevel,
            combatPower: row.combatPower,
            capturedAt: row.capturedAt,
            dataVersion: row.dataVersion,
            analysis: const CharacterBuildAnalysisMapper().fromJson(
              Map<String, dynamic>.from(jsonDecode(row.rawJson) as Map),
              catalog: catalog,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) {
    return _database.setRepresentativeCharacter(
      accountId: accountId,
      characterId: characterId,
    );
  }

  Future<void> updateDisplayLimit({
    required int accountId,
    required int displayLimit,
  }) {
    return _database.updateDisplayLimit(
      accountId: accountId,
      displayLimit: displayLimit,
    );
  }

  Future<void> updateCharacterVisibility({
    required int accountId,
    required int characterId,
    required bool isVisible,
  }) {
    return _database.updateCharacterVisibility(
      accountId: accountId,
      characterId: characterId,
      isVisible: isVisible,
    );
  }

  Future<void> updateCharacterDisplayOrder({
    required int accountId,
    required List<int> characterIds,
  }) {
    return _database.updateCharacterDisplayOrder(
      accountId: accountId,
      characterIds: characterIds,
    );
  }

  Future<void> setPreferredCharacterRole({
    required int characterId,
    required CharacterBuildRole role,
  }) => _database.setPreferredCharacterRole(
    characterId: characterId,
    role: role.name,
  );
}
