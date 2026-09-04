import '../entities/character_build_snapshot.dart';
import '../entities/character_minimum_display_sync_result.dart';
import '../repositories/account_repository.dart';
import '../repositories/character_minimum_display_sync_gateway.dart';

/// 로컬 Build Snapshot의 최소 표시값을 Firestore Character에 맞춘다.
class CharacterMinimumDisplaySyncService {
  const CharacterMinimumDisplaySyncService({
    required AccountRepository accountRepository,
    required CharacterMinimumDisplaySyncGateway gateway,
  }) : _accountRepository = accountRepository,
       _gateway = gateway;

  final AccountRepository _accountRepository;
  final CharacterMinimumDisplaySyncGateway _gateway;

  Future<CharacterMinimumDisplaySyncResult> syncSnapshot({
    required int localCharacterId,
    required CharacterBuildSnapshot snapshot,
  }) async {
    final itemLevel = snapshot.itemLevel;
    final combatPower = snapshot.combatPower;
    if (itemLevel == null && combatPower == null) {
      return const CharacterMinimumDisplaySyncResult(
        status: CharacterMinimumDisplaySyncStatus.skippedNoValues,
      );
    }

    final serverCharacterId = await _serverCharacterId(localCharacterId);
    if (serverCharacterId == null) {
      return const CharacterMinimumDisplaySyncResult(
        status: CharacterMinimumDisplaySyncStatus.skippedUnlinked,
        message: '서버 Character ID가 없습니다.',
      );
    }

    try {
      final wrote = await _gateway.syncMinimumDisplay(
        CharacterMinimumDisplayPatch(
          serverCharacterId: serverCharacterId,
          itemLevel: itemLevel,
          combatPower: combatPower,
        ),
      );
      return CharacterMinimumDisplaySyncResult(
        status: wrote
            ? CharacterMinimumDisplaySyncStatus.updated
            : CharacterMinimumDisplaySyncStatus.skippedUnchanged,
      );
    } on Object {
      return const CharacterMinimumDisplaySyncResult(
        status: CharacterMinimumDisplaySyncStatus.failed,
        message: '서버 최소 표시값 동기화에 실패했습니다.',
      );
    }
  }

  Future<String?> _serverCharacterId(int localCharacterId) async {
    for (final account in await _accountRepository.loadAccounts()) {
      for (final character in account.characters) {
        if (character.id != localCharacterId) continue;
        final serverCharacterId = character.serverCharacterId?.trim();
        if (serverCharacterId == null || serverCharacterId.isEmpty) {
          return null;
        }
        return serverCharacterId;
      }
    }
    return null;
  }
}
