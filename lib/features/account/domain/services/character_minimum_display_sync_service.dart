import '../entities/character_build_snapshot.dart';
import '../entities/character_minimum_display_sync_result.dart';
import '../repositories/account_repository.dart';
import '../repositories/character_minimum_display_sync_gateway.dart';
import 'build_integrity_snapshot_mapper.dart';

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
    final context = await _displayContext(localCharacterId, snapshot);
    final itemLevel = context.snapshot.itemLevel;
    final combatPower = context.useCombatPower
        ? context.snapshot.combatPower
        : null;
    if (itemLevel == null && combatPower == null) {
      return const CharacterMinimumDisplaySyncResult(
        status: CharacterMinimumDisplaySyncStatus.skippedNoValues,
      );
    }

    final serverCharacterId = context.serverCharacterId;
    if (serverCharacterId == null) {
      return const CharacterMinimumDisplaySyncResult(
        status: CharacterMinimumDisplaySyncStatus.skippedUnlinked,
        message: '서버 Character ID가 없습니다.',
      );
    }

    final buildIntegritySnapshot = context.useCombatPower
        ? buildIntegritySnapshotFromBuild(context.snapshot)
        : null;

    try {
      final wrote = await _gateway.syncMinimumDisplay(
        CharacterMinimumDisplayPatch(
          serverCharacterId: serverCharacterId,
          itemLevel: itemLevel,
          combatPower: combatPower,
          buildIntegritySnapshot: buildIntegritySnapshot,
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

  Future<
    ({
      String? serverCharacterId,
      CharacterBuildSnapshot snapshot,
      bool useCombatPower,
    })
  >
  _displayContext(
    int localCharacterId,
    CharacterBuildSnapshot refreshedSnapshot,
  ) async {
    for (final account in await _accountRepository.loadAccounts()) {
      for (final character in account.characters) {
        if (character.id != localCharacterId) continue;
        final serverCharacterId = character.serverCharacterId?.trim();
        var displaySnapshot = refreshedSnapshot;
        var useCombatPower = true;
        final preferredRole = character.preferredRole;
        if (preferredRole != null && refreshedSnapshot.role != preferredRole) {
          final preferredSnapshots =
              (await _accountRepository.loadCharacterBuildSnapshots(
                    localCharacterId,
                  ))
                  .where((candidate) => candidate.role == preferredRole)
                  .toList()
                ..sort(
                  (left, right) => right.capturedAt.compareTo(left.capturedAt),
                );
          if (preferredSnapshots.isNotEmpty) {
            displaySnapshot = preferredSnapshots.first;
          } else {
            useCombatPower = false;
          }
        }
        return (
          serverCharacterId:
              serverCharacterId == null || serverCharacterId.isEmpty
              ? null
              : serverCharacterId,
          snapshot: displaySnapshot,
          useCombatPower: useCombatPower,
        );
      }
    }
    return (
      serverCharacterId: null,
      snapshot: refreshedSnapshot,
      useCombatPower: true,
    );
  }
}
