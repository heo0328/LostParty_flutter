import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:lost_party/features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import 'package:lost_party/features/account/data/gateways/equipment_verification_preview.dart';
import 'package:lost_party/features/account/domain/repositories/game_account_verification_gateway.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/lost_ark_api_client.dart';

void main() {
  const characterName = '인증캐릭터';
  final siblingsPath =
      '/characters/${Uri.encodeComponent(characterName)}/siblings';
  final armoryPath =
      '/armories/characters/${Uri.encodeComponent(characterName)}';

  late DioAdapter adapter;
  late EquipmentVerificationPreview gateway;

  setUp(() async {
    final dio = Dio();
    adapter = DioAdapter(dio: dio);
    final tokenStore = _InMemoryApiTokenStore();
    await tokenStore.write(ApiToken('token'));
    gateway = EquipmentVerificationPreview(
      remoteDataSource: LostArkCharacterRemoteDataSource(
        apiClient: LostArkApiClient(apiTokenStore: tokenStore, dio: dio),
      ),
    );
  });

  void replyWithArmory(List<Map<String, Object?>> equipment) {
    adapter.onGet(
      siblingsPath,
      (server) => server.reply(200, [
        {
          'ServerName': '루페온',
          'CharacterName': characterName,
          'CharacterLevel': 70,
          'CharacterClassName': '바드',
          'ItemAvgLevel': '1,700.00',
        },
      ]),
    );
    adapter.onGet(
      armoryPath,
      (server) => server.reply(200, {'ArmoryEquipment': equipment}),
    );
  }

  test(
    'starts a challenge when all six verification items are equipped',
    () async {
      replyWithArmory(_equipment());

      final challenge = await gateway.start(
        characterName: characterName,
        source: 'provisional',
      );

      expect(challenge.characterName, characterName);
      expect(challenge.requiredUnequippedSlots, isNotEmpty);
      expect(gateway.activeChallenge?.challengeId, challenge.challengeId);
    },
  );

  test(
    'reports incomplete equipment when one or more required items are missing',
    () async {
      for (final removeCount in [1, 3]) {
        replyWithArmory(_equipment().sublist(removeCount));

        await expectLater(
          gateway.start(characterName: characterName, source: 'provisional'),
          throwsA(
            isA<GameAccountVerificationStartException>().having(
              (error) => error.failure,
              'failure',
              GameAccountVerificationStartFailure.incompleteEquipment,
            ),
          ),
        );
      }
    },
  );

  test('keeps malformed equipment data as a format error', () async {
    replyWithArmory([
      {'Type': '무기', 'Name': 7, 'Grade': '고대'},
      ..._equipment().skip(1),
    ]);

    await expectLater(
      gateway.start(characterName: characterName, source: 'provisional'),
      throwsFormatException,
    );
  });
}

List<Map<String, Object?>> _equipment() => const [
  {'Type': '무기', 'Name': '무기 A', 'Grade': '고대'},
  {'Type': '투구', 'Name': '투구 A', 'Grade': '고대'},
  {'Type': '어깨', 'Name': '어깨 A', 'Grade': '고대'},
  {'Type': '상의', 'Name': '상의 A', 'Grade': '고대'},
  {'Type': '하의', 'Name': '하의 A', 'Grade': '고대'},
  {'Type': '장갑', 'Name': '장갑 A', 'Grade': '고대'},
];

class _InMemoryApiTokenStore implements ApiTokenStore {
  ApiToken? _token;

  @override
  Future<ApiToken?> read() async => _token;

  @override
  Future<void> write(ApiToken token) async => _token = token;

  @override
  Future<void> delete() async => _token = null;
}
