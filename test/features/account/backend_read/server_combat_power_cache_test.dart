import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/character_build_role.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_registration_view_model.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_combat_power_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

LocalAccountCharacter local({
  String server = 'sample-server',
  CharacterBuildRole? role,
}) => LocalAccountCharacter(
  id: 1,
  serverName: server,
  characterName: 'sample',
  characterLevel: 70,
  characterClassName: 'sample-class',
  itemLevel: 1700,
  combatPower: 5,
  isVisible: true,
  displayOrder: null,
  preferredRole: role,
);

void main() {
  late ReadSessionFake session;
  late ReadApiFake api;
  late Dio dio;
  late ServerRegistrationViewModel writes;
  late ServerCombatPowerViewModel model;
  setUp(() {
    session = ReadSessionFake();
    api = ReadApiFake();
    dio = Dio();
    final reads = ServerAccountReadRepository(api, session);
    writes = ServerRegistrationViewModel(
      DioBackendAccountReadApi(dio, session),
      reads,
      session,
    );
    model = ServerCombatPowerViewModel(reads, writes, session);
  });
  tearDown(() {
    model.dispose();
    writes.dispose();
    session.dispose();
    dio.close();
  });
  ServerAccountRoster roster({String power = '12', bool stale = false}) {
    final json = charactersJson();
    (json['characters'] as Map)['items'] = [
      characterJson()
        ..['combat_power'] = power
        ..['power_status'] = 'available'
        ..['power_stale'] = stale
        ..['power_fetched_at'] = serverTime,
    ];
    return ServerAccountRoster(
      ServerCharactersResponse.fromJson(json),
      ServerCharactersResponse.fromJson(json).characters.items,
    );
  }

  test(
    'server/name exact match and preferred role snapshot always wins',
    () async {
      await Future<void>.delayed(Duration.zero);
      model.store(registrationId, roster(power: '0'));
      expect(model.displayPowerFor(local(), null), 0);
      expect(model.displayPowerFor(local(server: 'other-server'), null), 5);
      expect(
        model.displayPowerFor(local(role: CharacterBuildRole.support), 99),
        99,
      );
      expect(
        model.displayPowerFor(local(role: CharacterBuildRole.support), null),
        isNull,
      );
      session.change(authenticated: false);
      expect(model.powerFor(local()), isNull);
      expect(model.displayPowerFor(local(), null), 5);
    },
  );
  test('late GET from previous member never fills new member cache', () async {
    await Future<void>.delayed(Duration.zero);
    final old = Completer<ServerCharactersResponse>();
    api.onRegistrations = (_) async =>
        ServerRegistrationPage.fromJson(registrationPageJson());
    api.onCharacters = (_) => old.future;
    final read = model.reload();
    await Future<void>.delayed(Duration.zero);
    session.change(authenticated: false, user: 'new-member');
    final response = charactersJson();
    (response['characters'] as Map)['items'] = [
      characterJson()..['combat_power'] = '100',
    ];
    old.complete(ServerCharactersResponse.fromJson(response));
    await read;
    expect(model.powerFor(local()), isNull);
    expect(model.registrations, isEmpty);
  });
  test(
    '1700 minimum excludes null/low/missing and next tap prioritizes deferred',
    () {
      final rows = List.generate(
        25,
        (i) => ServerAccountCharacter.fromJson(
          characterJson(name: 'c$i')
            ..['item_level'] = i == 0
                ? null
                : i == 1
                ? '1699'
                : '1700'
            ..['roster_status'] = i == 2 ? 'missing' : 'preview',
        ),
      );
      final first = ServerCombatPowerViewModel.targets(rows);
      expect(first.length, 20);
      expect(
        first.any((t) => ['c0', 'c1', 'c2'].contains(t['character_name'])),
        false,
      );
      final completed = ServerAccountCharacter.fromJson(
        characterJson(name: first.first['character_name']!)
          ..['power_status'] = 'available'
          ..['power_stale'] = false,
      );
      final next = ServerCombatPowerViewModel.targets([
        completed,
        ...rows.where((r) => r.characterName != completed.characterName),
      ]);
      expect(
        next.any((t) => t['character_name'] == completed.characterName),
        false,
      );
    },
  );
  test('new registration is looked up before its power POST', () async {
    await Future<void>.delayed(Duration.zero);
    api.onRegistrations = (_) async =>
        ServerRegistrationPage.fromJson(registrationPageJson());
    var sent = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          sent++;
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'items': [
                  {
                    'server_name': 'sample-server',
                    'character_name': 'sample',
                    'combat_power': '12',
                    'power_fetched_at': serverTime,
                    'power_checked_at': serverTime,
                    'power_stale': false,
                    'power_status': 'available',
                    'power_reason': null,
                    'status': 'updated',
                    'reason': null,
                  },
                ],
              },
            ),
          );
        },
      ),
    );
    await model.refreshServerRoster(registrationId, roster().characters);
    expect(sent, 1);
    expect(writes.failure, isNull);
    expect(writes.powerResults.single.power.value, 12);
  });
  test(
    'member change during new registration lookup prevents power POST',
    () async {
      await Future<void>.delayed(Duration.zero);
      final gate = Completer<ServerRegistrationPage>();
      api.onRegistrations = (_) => gate.future;
      var sent = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            sent++;
            h.reject(DioException(requestOptions: o));
          },
        ),
      );
      final work = model.refreshServerRoster(
        registrationId,
        roster().characters,
      );
      await Future<void>.delayed(Duration.zero);
      session.change(authenticated: false, user: 'new-member');
      gate.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
      await work;
      expect(sent, 0);
      expect(writes.hasPending, false);
    },
  );
}
