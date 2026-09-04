import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/domain/entities/character_build_snapshot.dart';
import 'package:lost_party/features/account/domain/entities/character_minimum_display_sync_result.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/character_minimum_display_sync_gateway.dart';
import 'package:lost_party/features/account/domain/services/character_minimum_display_sync_service.dart';

void main() {
  test('서버 Character ID가 없으면 동기화를 생략한다', () async {
    final service = CharacterMinimumDisplaySyncService(
      accountRepository: _Accounts(serverCharacterId: null),
      gateway: _Gateway(),
    );
    final result = await service.syncSnapshot(
      localCharacterId: 1,
      snapshot: _snapshot(),
    );
    expect(
      result.status,
      CharacterMinimumDisplaySyncStatus.skippedUnlinked,
    );
  });

  test('값이 없으면 게이트 요청을 보내지 않는다', () async {
    final gateway = _Gateway();
    final service = CharacterMinimumDisplaySyncService(
      accountRepository: _Accounts(),
      gateway: gateway,
    );
    final result = await service.syncSnapshot(
      localCharacterId: 1,
      snapshot: _snapshot(itemLevel: null, combatPower: null),
    );
    expect(result.status, CharacterMinimumDisplaySyncStatus.skippedNoValues);
    expect(gateway.calls, isEmpty);
  });

  test('동일값 생략과 갱신 결과를 구분한다', () async {
    final gateway = _Gateway()..wrote = false;
    final service = CharacterMinimumDisplaySyncService(
      accountRepository: _Accounts(),
      gateway: gateway,
    );
    expect(
      (await service.syncSnapshot(
        localCharacterId: 1,
        snapshot: _snapshot(),
      )).status,
      CharacterMinimumDisplaySyncStatus.skippedUnchanged,
    );

    gateway.wrote = true;
    expect(
      (await service.syncSnapshot(
        localCharacterId: 1,
        snapshot: _snapshot(),
      )).status,
      CharacterMinimumDisplaySyncStatus.updated,
    );
    expect(gateway.calls.last.itemLevel, 1700);
    expect(gateway.calls.last.combatPower, 300000);
  });

  test('게이트웨이 실패를 failed로 변환한다', () async {
    final service = CharacterMinimumDisplaySyncService(
      accountRepository: _Accounts(),
      gateway: _Gateway()..error = StateError('denied'),
    );
    final result = await service.syncSnapshot(
      localCharacterId: 1,
      snapshot: _snapshot(),
    );
    expect(result.status, CharacterMinimumDisplaySyncStatus.failed);
    expect(result.isSuccess, isFalse);
  });
}

CharacterBuildSnapshot _snapshot({
  double? itemLevel = 1700,
  double? combatPower = 300000,
}) {
  return CharacterBuildSnapshot(
    id: 1,
    characterId: 1,
    role: CharacterBuildRole.support,
    rawJson: '{}',
    itemLevel: itemLevel,
    combatPower: combatPower,
    capturedAt: DateTime.utc(2026, 9, 4),
    dataVersion: 1,
    analysis: const CharacterBuildAnalysis(
      runeCount: 8,
      gemEffects: [],
      arkGridConditions: [],
      arkGridCorePoints: [],
      notices: [],
    ),
  );
}

class _Accounts extends Fake implements AccountRepository {
  _Accounts({this.serverCharacterId = 'character-1'});
  final String? serverCharacterId;

  @override
  Future<List<LocalGameAccount>> loadAccounts() async => [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '캐릭터',
      representativeCharacterId: 1,
      displayLimit: 5,
      serverOwnershipStatus: 'active',
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: serverCharacterId,
          serverName: '서버',
          characterName: '캐릭터',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1700,
          combatPower: 300000,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];
}

class _Gateway implements CharacterMinimumDisplaySyncGateway {
  final calls = <CharacterMinimumDisplayPatch>[];
  bool wrote = true;
  Object? error;

  @override
  Future<bool> syncMinimumDisplay(CharacterMinimumDisplayPatch patch) async {
    if (error != null) throw error!;
    calls.add(patch);
    return wrote;
  }
}
