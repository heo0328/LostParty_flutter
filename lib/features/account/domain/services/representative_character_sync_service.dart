import '../entities/local_game_account.dart';
import '../repositories/account_repository.dart';
import '../repositories/representative_character_sync_gateway.dart';

class RepresentativeCharacterSyncService {
  RepresentativeCharacterSyncService({
    required AccountRepository accountRepository,
    required RepresentativeCharacterSyncGateway gateway,
  }) : _accountRepository = accountRepository,
       _gateway = gateway;

  final AccountRepository _accountRepository;
  final RepresentativeCharacterSyncGateway _gateway;
  final Set<String> _preparedGameAccountIds = {};
  final Set<String> _inFlightGameAccountIds = {};

  Future<void> synchronizeAccounts(List<LocalGameAccount> accounts) async {
    for (final account in accounts) {
      final gameAccountId = account.serverGameAccountId;
      if (!account.hasActiveOwnership || gameAccountId == null) {
        continue;
      }
      if (account.hasReconciledServerRepresentative ||
          _preparedGameAccountIds.contains(gameAccountId)) {
        continue;
      }
      if (!_inFlightGameAccountIds.add(gameAccountId)) {
        continue;
      }
      try {
        await _synchronizeAccount(account, gameAccountId);
      } on Object {
        // Account screen remains usable when Firebase is offline or rejects a
        // legacy binding. The character management page surfaces retry state.
      } finally {
        _inFlightGameAccountIds.remove(gameAccountId);
      }
    }
  }

  Future<void> _synchronizeAccount(
    LocalGameAccount account,
    String gameAccountId,
  ) async {
    final state = await _gateway.loadState(gameAccountId: gameAccountId);
    final serverRepresentativeId = state.representativeCharacterId;
    if (serverRepresentativeId != null) {
      final localCharacter = account.characters
          .where(
            (character) => character.serverCharacterId == serverRepresentativeId,
          )
          .firstOrNull;
      if (localCharacter != null &&
          account.representativeCharacterId != localCharacter.id) {
        await _accountRepository.setRepresentativeCharacter(
          accountId: account.id,
          characterId: localCharacter.id,
        );
      }
      await _accountRepository.markRepresentativeReconciled(
        accountId: account.id,
        serverCharacterId: serverRepresentativeId,
      );
      _preparedGameAccountIds.add(gameAccountId);
      return;
    }

    final localRepresentative = account.characters
        .where((character) => character.id == account.representativeCharacterId)
        .firstOrNull;
    final serverCharacterId = localRepresentative?.serverCharacterId;
    if (serverCharacterId == null) return;
    await _gateway.seedRepresentative(
      gameAccountId: gameAccountId,
      characterId: serverCharacterId,
    );
    await _accountRepository.markRepresentativeReconciled(
      accountId: account.id,
      serverCharacterId: serverCharacterId,
    );
    _preparedGameAccountIds.add(gameAccountId);
  }
}
