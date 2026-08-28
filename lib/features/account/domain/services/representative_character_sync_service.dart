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

  Future<void> synchronizeAccounts(List<LocalGameAccount> accounts) async {
    for (final account in accounts) {
      final gameAccountId = account.serverGameAccountId;
      if (!account.hasActiveOwnership ||
          gameAccountId == null ||
          _preparedGameAccountIds.contains(gameAccountId)) {
        continue;
      }
      try {
        final state = await _gateway.loadState(gameAccountId: gameAccountId);
        final serverRepresentativeId = state.representativeCharacterId;
        if (serverRepresentativeId != null) {
          final localCharacter = account.characters
              .where(
                (character) =>
                    character.serverCharacterId == serverRepresentativeId,
              )
              .firstOrNull;
          if (localCharacter != null &&
              account.representativeCharacterId != localCharacter.id) {
            await _accountRepository.setRepresentativeCharacter(
              accountId: account.id,
              characterId: localCharacter.id,
            );
          }
          _preparedGameAccountIds.add(gameAccountId);
          continue;
        }

        final localRepresentative = account.characters
            .where(
              (character) => character.id == account.representativeCharacterId,
            )
            .firstOrNull;
        final serverCharacterId = localRepresentative?.serverCharacterId;
        if (serverCharacterId == null) continue;
        await _gateway.setRepresentative(
          gameAccountId: gameAccountId,
          characterId: serverCharacterId,
        );
        _preparedGameAccountIds.add(gameAccountId);
      } on Object {
        // Account screen remains usable when Firebase is offline or rejects a
        // legacy binding. The character management page surfaces retry state.
      }
    }
  }
}
