import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/presentation/viewmodels/server_account_read_view_model.dart';
import '../../../support/server_account_read_fakes.dart';

void main() {
  late ReadSessionFake session;
  late ReadApiFake api;
  late ServerAccountReadRepository repository;
  setUp(() {
    session = ReadSessionFake();
    api = ReadApiFake();
    repository = ServerAccountReadRepository(api, session);
  });
  tearDown(() => session.dispose());
  Matcher code(String expected) => isA<AccountReadException>().having(
    (error) => error.code,
    'code',
    expected,
  );

  test('guest has no private requests', () async {
    session.change(authenticated: false);
    await expectLater(
      repository.loadRegistrations(),
      throwsA(code('LOGIN_REQUIRED')),
    );
    await expectLater(
      repository.loadCharacters(registrationId),
      throwsA(code('LOGIN_REQUIRED')),
    );
    expect(api.registrationCalls + api.characterCalls, 0);
  });
  test(
    'collects all pages and preserves full settings and null power',
    () async {
      api.onCharacters = (cursor) async => ServerCharactersResponse.fromJson(
        cursor == null
            ? charactersJson(cursor: 'next')
            : charactersJson(id: secondCharacterId, name: 'second'),
      );
      final roster = await repository.loadCharacters(registrationId);
      expect(roster.characters.length, 2);
      expect(roster.settings.activityCharacterIds, [characterId]);
      expect(roster.characters.first.combatPower, isNull);
      expect(api.characterCalls, 2);
    },
  );
  for (final key in [
    'roster_revision',
    'settings_version',
    'ownership_revision',
  ]) {
    test(
      'rejects changed $key instead of publishing a mixed snapshot',
      () async {
        api.onCharacters = (cursor) async {
          final json = cursor == null
              ? charactersJson(cursor: 'next')
              : charactersJson(id: secondCharacterId, name: 'second');
          if (cursor != null) {
            if (key == 'roster_revision') {
              json[key] = 3;
            } else {
              (json['settings'] as Map)[key] = 2;
            }
          }
          return ServerCharactersResponse.fromJson(json);
        };
        await expectLater(
          repository.loadCharacters(registrationId),
          throwsA(code('CURSOR_STALE')),
        );
      },
    );
  }
  test('same versions with different full settings are rejected', () async {
    api.onCharacters = (cursor) async {
      final json = cursor == null
          ? charactersJson(cursor: 'next')
          : charactersJson(id: secondCharacterId, name: 'second');
      if (cursor != null) {
        (json['settings'] as Map)['activity_character_ids'] = [
          secondCharacterId,
        ];
      }
      return ServerCharactersResponse.fromJson(json);
    };
    await expectLater(
      repository.loadCharacters(registrationId),
      throwsA(code('CURSOR_STALE')),
    );
  });
  test('failed later page never publishes the first page', () async {
    api.onCharacters = (cursor) async {
      if (cursor != null) {
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      return ServerCharactersResponse.fromJson(charactersJson(cursor: 'next'));
    };
    final vm = ServerAccountReadViewModel(
      repository,
      session,
      registrationId: registrationId,
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.roster, isNull);
    expect(vm.loaded, isFalse);
    expect(vm.failure?.code, 'NETWORK_UNAVAILABLE');
    vm.dispose();
  });
  test('duplicate cursor and duplicate identities are rejected', () async {
    api.onCharacters = (_) async =>
        ServerCharactersResponse.fromJson(charactersJson(cursor: 'same'));
    await expectLater(
      repository.loadCharacters(registrationId),
      throwsA(code('INVALID_RESPONSE')),
    );
    api.onRegistrations = (_) async =>
        ServerRegistrationPage.fromJson(registrationPageJson(cursor: 'same'));
    await expectLater(
      repository.loadRegistrations(),
      throwsA(code('INVALID_RESPONSE')),
    );
  });
  test(
    'more than 200 unique characters is rejected without truncation',
    () async {
      api.onCharacters = (cursor) async {
        final json = charactersJson(cursor: cursor == null ? 'next' : null);
        (json['characters']
            as Map)['items'] = List.generate(cursor == null ? 100 : 101, (
          offset,
        ) {
          final index = offset + (cursor == null ? 0 : 100);
          return characterJson(
            id: '${index.toRadixString(16).padLeft(8, '0')}-0000-4000-8000-000000000000',
            name: 'sample-$index',
          );
        });
        return ServerCharactersResponse.fromJson(json);
      };
      await expectLater(
        repository.loadCharacters(registrationId),
        throwsA(code('INVALID_RESPONSE')),
      );
    },
  );

  test('empty nonterminal page is rejected', () async {
    api.onRegistrations = (_) async => ServerRegistrationPage.fromJson(
      registrationPageJson(cursor: 'next', empty: true),
    );
    await expectLater(
      repository.loadRegistrations(),
      throwsA(code('INVALID_RESPONSE')),
    );
  });
  test('malformed IDs and incomplete settings are rejected', () {
    final badId = registrationJson()..['registration_id'] = 'legacy-local-id';
    expect(
      () => ServerAccountRegistration.fromJson(badId),
      throwsFormatException,
    );
    final incomplete = settingsJson()..['selection_complete'] = false;
    expect(
      () => ServerCharacterSettings.fromJson(incomplete),
      throwsFormatException,
    );
    final wrong = characterJson()..['item_level'] = 1700;
    expect(() => ServerAccountCharacter.fromJson(wrong), throwsFormatException);
  });
  test('logout hides private results and ignores late response', () async {
    final pending = Completer<ServerRegistrationPage>();
    api.onRegistrations = (_) => pending.future;
    final vm = ServerAccountReadViewModel(repository, session);
    session.change(authenticated: false);
    pending.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
    await Future<void>.delayed(Duration.zero);
    expect(vm.registrations, isEmpty);
    expect(vm.loaded, isFalse);
    expect(vm.loading, isFalse);
    expect(vm.failure, isNull);
    vm.dispose();
  });
  test('same-user new session ignores old response and reloads', () async {
    final old = Completer<ServerRegistrationPage>();
    final current = Completer<ServerRegistrationPage>();
    api.onRegistrations = (_) =>
        api.registrationCalls == 1 ? old.future : current.future;
    final vm = ServerAccountReadViewModel(repository, session);
    session.change(authenticated: true);
    old.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
    await Future<void>.delayed(Duration.zero);
    expect(vm.registrations, isEmpty);
    expect(vm.loading, isTrue);
    current.complete(
      ServerRegistrationPage.fromJson(registrationPageJson(empty: true)),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.loaded, isTrue);
    expect(vm.registrations, isEmpty);
    vm.dispose();
  });
  test('changing member blocks previous repository result', () async {
    final pending = Completer<ServerRegistrationPage>();
    api.onRegistrations = (_) => pending.future;
    final result = repository.loadRegistrations();
    final expectation = expectLater(result, throwsA(code('SESSION_CHANGED')));
    session.change(authenticated: true, user: 'other-user');
    pending.complete(ServerRegistrationPage.fromJson(registrationPageJson()));
    await expectation;
  });
}
