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
    expect(gateway.savedCharacterIds, ['server-character-1']);
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
    expect(gateway.savedCharacterIds, isEmpty);
  });
}

LocalGameAccount _account() {
  return const LocalGameAccount(
    id: 10,
    serverGameAccountId: 'server-account-1',
    serverOwnershipStatus: 'active',
    label: '메인',
    isMain: true,
    lookupCharacterName: '첫번째',
    representativeCharacterId: 1,
    displayLimit: 2,
    characters: [
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

  @override
  Future<void> setRepresentativeCharacter({
    required int accountId,
    required int characterId,
  }) async {
    savedCharacterId = characterId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGateway implements RepresentativeCharacterSyncGateway {
  _FakeGateway(this.state);

  RepresentativeCharacterSyncState state;
  int loadCount = 0;
  final List<String> savedCharacterIds = [];

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
}
