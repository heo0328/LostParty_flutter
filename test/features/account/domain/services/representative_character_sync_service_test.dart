import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/account/domain/repositories/representative_character_sync_gateway.dart';
import 'package:lost_party/features/account/domain/services/representative_character_sync_service.dart';

void main() {
  test('내 계정 반복 진입에서도 active 계정 보강은 프로세스당 한 번만 수행한다', () async {
    final repository = _RepresentativeOnlyAccountRepository();
    final gateway = _FakeGateway(
      const RepresentativeCharacterSyncState(
        representativeCharacterId: null,
        updatedAt: null,
      ),
    );
    final service = RepresentativeCharacterSyncService(
      accountRepository: repository,
      gateway: gateway,
    );
    final account = _account();

    await service.synchronizeAccounts([account]);
    await service.synchronizeAccounts([account]);

    expect(gateway.loadCount, 1);
    expect(gateway.seededCharacterIds, ['server-character-1']);
    expect(gateway.savedCharacterIds, isEmpty);
    expect(repository.reconciledServerCharacterId, 'server-character-1');
  });

  test('로컬 맞춤 기록이 있으면 네트워크를 호출하지 않는다', () async {
    final repository = _RepresentativeOnlyAccountRepository();
    final gateway = _FakeGateway(
      const RepresentativeCharacterSyncState(
        representativeCharacterId: null,
        updatedAt: null,
      ),
    );
    final service = RepresentativeCharacterSyncService(
      accountRepository: repository,
      gateway: gateway,
    );

    await service.synchronizeAccounts([
      _account(
        serverRepresentativeCharacterId: 'server-character-1',
        representativeReconciledAt: DateTime.utc(2026, 8, 29),
      ),
    ]);

    expect(gateway.loadCount, 0);
    expect(gateway.seededCharacterIds, isEmpty);
    expect(gateway.savedCharacterIds, isEmpty);
  });

  test('서버 대표가 있으면 로컬 대표를 서버 캐릭터에 맞춘다', () async {
    final repository = _RepresentativeOnlyAccountRepository();
    final gateway = _FakeGateway(
      const RepresentativeCharacterSyncState(
        representativeCharacterId: 'server-character-2',
        updatedAt: null,
      ),
    );
    final service = RepresentativeCharacterSyncService(
      accountRepository: repository,
      gateway: gateway,
    );

    await service.synchronizeAccounts([_account()]);

    expect(repository.savedCharacterId, 2);
    expect(repository.reconciledServerCharacterId, 'server-character-2');
    expect(gateway.seededCharacterIds, isEmpty);
    expect(gateway.savedCharacterIds, isEmpty);
  });
}

LocalGameAccount _account({
  String? serverRepresentativeCharacterId,
  DateTime? representativeReconciledAt,
}) {
  return LocalGameAccount(
    id: 10,
    serverGameAccountId: 'server-account-1',
    serverOwnershipStatus: 'active',
    label: '메인',
    isMain: true,
    lookupCharacterName: '첫번째',
    representativeCharacterId: 1,
    serverRepresentativeCharacterId: serverRepresentativeCharacterId,
    representativeReconciledAt: representativeReconciledAt,
    displayLimit: 2,
    characters: const [
      LocalAccountCharacter(
        id: 1,
        serverCharacterId: 'server-character-1',
        serverName: '루페온',
        characterName: '첫번째',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1700,
        combatPower: null,
        isVisible: true,
        displayOrder: 0,
      ),
      LocalAccountCharacter(
        id: 2,
        serverCharacterId: 'server-character-2',
        serverName: '루페온',
        characterName: '두번째',
        characterLevel: 70,
        characterClassName: '바드',
        itemLevel: 1690,
        combatPower: null,
        isVisible: true,
        displayOrder: 1,
      ),
    ],
  );
}

class _RepresentativeOnlyAccountRepository implements AccountRepository {
  int? savedCharacterId;
  String? reconciledServerCharacterId;

  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) async {
    savedCharacterId = characterId;
  }

  @override
  Future<void> markRepresentativeReconciled({
    required int accountId,
    required String serverCharacterId,
  }) async {
    reconciledServerCharacterId = serverCharacterId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGateway implements RepresentativeCharacterSyncGateway {
  _FakeGateway(this.state);

  RepresentativeCharacterSyncState state;
  int loadCount = 0;
  final List<String> savedCharacterIds = [];
  final List<String> seededCharacterIds = [];

  @override
  Future<RepresentativeCharacterSyncState> loadState({
    required String gameAccountId,
  }) async {
    loadCount++;
    return state;
  }

  @override
  Future<RepresentativeCharacterSyncState> setRepresentative({
    required String gameAccountId,
    required String characterId,
  }) async {
    savedCharacterIds.add(characterId);
    state = RepresentativeCharacterSyncState(
      representativeCharacterId: characterId,
      updatedAt: DateTime.utc(2026, 8, 28),
    );
    return state;
  }

  @override
  Future<RepresentativeCharacterSyncState> seedRepresentative({
    required String gameAccountId,
    required String characterId,
  }) async {
    seededCharacterIds.add(characterId);
    state = RepresentativeCharacterSyncState(
      representativeCharacterId: characterId,
      updatedAt: null,
    );
    return state;
  }
}
