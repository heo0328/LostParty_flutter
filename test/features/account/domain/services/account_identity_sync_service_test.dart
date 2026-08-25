import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/server_account_identity_binding.dart';
import 'package:lost_party/features/account/domain/repositories/account_identity_gateway.dart';
import 'package:lost_party/features/account/domain/services/account_identity_sync_service.dart';

void main() {
  test('persists a complete server identity response', () async {
    final gateway = _FakeGateway(
      ServerAccountIdentityBinding(
        localAccountId: 1,
        serverGameAccountId: 'game-account-1',
        serverCharacterIdsByLocalId: const {
          10: 'character-10',
          11: 'character-11',
        },
      ),
    );
    final mappingRepository = _FakeMappingRepository();
    final service = AccountIdentitySyncService(
      gateway: gateway,
      mappingRepository: mappingRepository,
    );

    final result = await service.synchronize(_account);

    expect(result.serverGameAccountId, 'game-account-1');
    expect(mappingRepository.saved, same(result));
  });

  test('rejects a response for another local account', () async {
    final mappingRepository = _FakeMappingRepository();
    final service = AccountIdentitySyncService(
      gateway: _FakeGateway(
        ServerAccountIdentityBinding(
          localAccountId: 2,
          serverGameAccountId: 'game-account-1',
          serverCharacterIdsByLocalId: const {
            10: 'character-10',
            11: 'character-11',
          },
        ),
      ),
      mappingRepository: mappingRepository,
    );

    await expectLater(service.synchronize(_account), throwsStateError);
    expect(mappingRepository.saved, isNull);
  });

  test('rejects a partial or unexpected character mapping', () async {
    final mappingRepository = _FakeMappingRepository();
    final service = AccountIdentitySyncService(
      gateway: _FakeGateway(
        ServerAccountIdentityBinding(
          localAccountId: 1,
          serverGameAccountId: 'game-account-1',
          serverCharacterIdsByLocalId: const {
            10: 'character-10',
            99: 'character-99',
          },
        ),
      ),
      mappingRepository: mappingRepository,
    );

    await expectLater(service.synchronize(_account), throwsStateError);
    expect(mappingRepository.saved, isNull);
  });
}

class _FakeGateway implements AccountIdentityGateway {
  _FakeGateway(this.binding);

  final ServerAccountIdentityBinding binding;

  @override
  Future<ServerAccountIdentityBinding> getOrCreateIdentity(
    LocalGameAccount account,
  ) async => binding;
}

class _FakeMappingRepository implements AccountIdentityMappingRepository {
  ServerAccountIdentityBinding? saved;

  @override
  Future<void> bindServerIdentity(ServerAccountIdentityBinding binding) async {
    saved = binding;
  }
}

const _account = LocalGameAccount(
  id: 1,
  label: '본계정',
  isMain: true,
  lookupCharacterName: '조회캐릭터',
  representativeCharacterId: 10,
  displayLimit: 6,
  characters: [
    LocalAccountCharacter(
      id: 10,
      serverName: '루페온',
      characterName: '조회캐릭터',
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1760,
      combatPower: 3000,
      isVisible: true,
      displayOrder: 0,
    ),
    LocalAccountCharacter(
      id: 11,
      serverName: '루페온',
      characterName: '부캐릭터',
      characterLevel: 70,
      characterClassName: '바드',
      itemLevel: 1750,
      combatPower: 2900,
      isVisible: true,
      displayOrder: 1,
    ),
  ],
);
