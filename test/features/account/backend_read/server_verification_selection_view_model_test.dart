import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_account_verification.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_verification_selection_view_model.dart';

import '../../../support/server_account_read_fakes.dart';

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ReadSessionFake session;
  late ReadApiFake api;
  late ServerVerificationSelectionViewModel model;
  setUp(() {
    session = ReadSessionFake();
    api = ReadApiFake()
      ..onRegistrations = (_) async => ServerRegistrationPage.fromJson({
        'items': [
          registrationJson()
            ..['ownership_status'] = 'unverified'
            ..['verification_status'] = 'unverified',
          registrationJson()
            ..['registration_id'] = secondCharacterId
            ..['is_main'] = false
            ..['ownership_status'] = 'unverified'
            ..['verification_status'] = 'unverified',
        ],
        'next_cursor': null,
      });
    model = ServerVerificationSelectionViewModel(
      ServerAccountReadRepository(api, session),
      session,
    );
  });
  tearDown(() {
    model.dispose();
    session.dispose();
  });

  test(
    'current ownership disables verification but lost ownership remains eligible',
    () async {
      api.onRegistrations = (_) async =>
          ServerRegistrationPage.fromJson(registrationPageJson());
      await model.select(registrationId);
      expect(model.registrations, hasLength(1));
      expect(model.canVerify(model.registrations.single), isFalse);
      expect(model.registrationId, isNull);
      expect(model.canStart, isFalse);
      expect(api.characterCalls, 0);
      api.onRegistrations = (_) async => ServerRegistrationPage.fromJson({
        'items': [registrationJson()..['ownership_status'] = 'ownership_lost'],
        'next_cursor': null,
      });
      await model.select(registrationId);
      expect(model.canVerify(model.registrations.single), isTrue);
      model.choose(
        VerificationTarget(
          serverName: 'sample-server',
          characterName: 'sample',
        ),
      );
      expect(model.canStart, isTrue);
    },
  );

  test(
    'search preflight detects owned name and blocks stale registration start',
    () async {
      await model.select(registrationId);
      model.choose(
        VerificationTarget(
          serverName: 'sample-server',
          characterName: 'sample',
        ),
      );
      api.onRegistrations = (_) async =>
          ServerRegistrationPage.fromJson(registrationPageJson());
      expect(await model.checkStart(), isFalse);
      expect(model.failure!.code, 'ALREADY_VERIFIED');
      expect(model.target, isNull);
      expect(await model.checkStart(characterName: ' sample '), isFalse);
      expect(model.failure!.code, 'ALREADY_VERIFIED');
      expect(await model.checkStart(characterName: 'new-name'), isTrue);
    },
  );

  test('logout during search never authorizes a late start', () async {
    await settle();
    api.onRegistrations = (_) async =>
        ServerRegistrationPage.fromJson(registrationPageJson());
    final waiting = Completer<ServerCharactersResponse>();
    api.onCharacters = (_) => waiting.future;
    final running = model.checkStart(characterName: 'sample');
    await settle();
    session.change(authenticated: false);
    waiting.complete(ServerCharactersResponse.fromJson(charactersJson()));
    expect(await running, isFalse);
    expect(model.registrations, isEmpty);
    expect(model.failure, isNull);
    expect(model.checking, isFalse);
  });

  test(
    'preview UUID, low level and activity eligibility do not restrict selection',
    () async {
      api.onCharacters = (_) async => ServerCharactersResponse.fromJson(
        charactersJson()
          ..['characters'] = {
            'items': [
              characterJson()
                ..['character_id'] = null
                ..['roster_status'] = 'preview'
                ..['eligible'] = false
                ..['item_level'] = '100.00',
            ],
            'next_cursor': null,
          },
      );
      await model.select(registrationId);
      expect(model.roster!.characters.single.itemLevel, '100.00');
      expect(model.canStart, isFalse);
      model.choose(
        VerificationTarget(
          serverName: 'sample-server',
          characterName: 'sample',
        ),
      );
      expect(model.canStart, isTrue);
      expect(model.registration!.version, 1);
    },
  );

  test(
    'late roster for earlier registration cannot replace the new target',
    () async {
      await settle();
      final old = Completer<ServerCharactersResponse>();
      api.onCharacters = (id) async => id == registrationId
          ? old.future
          : ServerCharactersResponse.fromJson(charactersJson(name: 'new'));
      final first = model.select(registrationId);
      await settle();
      await model.select(secondCharacterId);
      model.choose(
        VerificationTarget(serverName: 'sample-server', characterName: 'new'),
      );
      old.complete(
        ServerCharactersResponse.fromJson(charactersJson(name: 'old')),
      );
      await first;
      expect(model.registration!.registrationId, secondCharacterId);
      expect(model.target!.characterName, 'new');
      expect(model.roster!.characters.single.characterName, 'new');
    },
  );

  test('logout fences late roster and clears private candidates', () async {
    await settle();
    final waiting = Completer<ServerCharactersResponse>();
    api.onCharacters = (_) => waiting.future;
    final running = model.select(registrationId);
    await settle();
    session.change(authenticated: false);
    waiting.complete(ServerCharactersResponse.fromJson(charactersJson()));
    await running;
    expect(model.registrations, isEmpty);
    expect(model.roster, isNull);
    expect(model.canStart, isFalse);
  });

  test(
    'failed refresh or invalidation cannot reuse an earlier selected target',
    () async {
      await model.select(registrationId);
      model.choose(
        VerificationTarget(
          serverName: 'sample-server',
          characterName: 'sample',
        ),
      );
      expect(model.canStart, isTrue);
      model.invalidate();
      expect(model.canStart, isFalse);
      api.onCharacters = (_) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await model.load();
      expect(model.target, isNull);
      expect(model.roster, isNull);
      expect(model.canStart, isFalse);
      expect(model.failure!.code, 'NETWORK_UNAVAILABLE');
    },
  );
}
