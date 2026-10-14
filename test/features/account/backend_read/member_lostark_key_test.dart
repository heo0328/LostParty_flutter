import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/account/presentation/viewmodels/member_lostark_key.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/client/api_cooldown.dart';
import '../../../support/server_account_read_fakes.dart';

// Deliberately synthetic; never provider credentials.
const jwt = 'fixture.header.signature';

class GuestStore implements ApiTokenStore {
  ApiToken? token;
  @override
  Future<ApiToken?> read() async => token;
  @override
  Future<void> write(ApiToken value) async {
    token = value;
  }

  @override
  Future<void> delete() async {
    token = null;
  }
}

class DeviceStore implements MemberKeyStorage {
  final tokens = <String, String>{};
  bool fail = false;
  Future<void> Function()? beforeWrite;
  @override
  Future<void> write(String owner, String token, int version) async {
    await beforeWrite?.call();
    if (fail) throw StateError('device failure');
    tokens[owner] = token;
  }

  @override
  Future<void> delete(String owner) async {
    tokens.remove(owner);
  }
}

class KeyApi implements BackendRegistrationApi {
  String? token;
  int version = 1;
  final calls =
      <
        ({
          String path,
          String method,
          Map<String, dynamic>? body,
          Map<String, dynamic>? query,
          String? key,
        })
      >[];
  Future<Map<String, dynamic>?> Function()? restore;
  Future<Map<String, dynamic>?> Function()? put;
  Future<Map<String, dynamic>?> Function()? onGet;
  Map<String, dynamic> metadata() => {
    'configured': token != null,
    'version': version,
    'updated_at': version == 1 ? null : '2026-10-15T00:00:00Z',
  };
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    calls.add((
      path: path,
      method: method,
      body: body,
      query: query,
      key: idempotencyKey,
    ));
    if (path.endsWith('/restore')) {
      return restore != null
          ? restore!()
          : {'token': token, 'version': version};
    }
    if (method == 'GET' && onGet != null) return onGet!();
    if (method == 'PUT') {
      if (put != null) return put!();
      token = body!['token'] as String;
      version++;
    } else if (method == 'DELETE') {
      if (token != null) version++;
      token = null;
    }
    return metadata();
  }
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late ReadSessionFake session;
  late KeyApi api;
  late DeviceStore device;
  late GuestStore guest;
  late ApiCooldown cooldown;
  MemberLostArkKey? model;
  setUp(() {
    session = ReadSessionFake();
    api = KeyApi();
    device = DeviceStore();
    guest = GuestStore();
    cooldown = ApiCooldown();
  });
  tearDown(() {
    model?.dispose();
    model = null;
    cooldown.dispose();
    session.dispose();
  });
  MemberLostArkKey create() =>
      model = MemberLostArkKey(api, session, device, guest, cooldown);
  test('strict metadata and compact JWT, no trimming/coercion', () {
    for (final value in [
      null,
      {},
      {'configured': true, 'version': true, 'updated_at': null},
      {'configured': false, 'version': 0, 'updated_at': null},
    ]) {
      expect(
        () => MemberKeyStatus.fromJson(value?.cast<String, dynamic>()),
        throwsFormatException,
      );
    }
    for (final token in [' $jwt', '$jwt\n', 'Bearer $jwt', 'a..b', 'a.b.한']) {
      expect(MemberLostArkKey.validToken(token), isFalse);
    }
  });
  test(
    'initial missing remains missing, no auto PUT from guest token',
    () async {
      guest.token = ApiToken(jwt);
      final m = create();
      await settle();
      expect(m.value!.configured, isFalse);
      expect(await m.read(), isNull);
      expect(api.calls.every((c) => c.method == 'GET'), isTrue);
    },
  );
  test(
    'register stores server then restores to device, never PUT validates upstream',
    () async {
      final m = create();
      await settle();
      await m.save(jwt);
      expect(m.localReady, isTrue);
      expect((await m.read())!.value, jwt);
      expect(device.tokens[session.userId], jwt);
      expect(api.calls.map((c) => c.method), ['GET', 'PUT', 'GET', 'POST']);
      final put = api.calls[1];
      expect(put.body, {'token': jwt, 'expected_version': 1});
      expect(put.key, matches(RegExp(r'^[0-9a-f-]{14}4[0-9a-f-]{3}-[89ab]')));
      expect(api.calls.last.key, isNull);
      expect(m.notice, contains('키를 등록했습니다'));
    },
  );
  test(
    'same account new session restores server key; logout clears device only',
    () async {
      api.token = jwt;
      api.version = 2;
      final m = create();
      await settle();
      expect(m.localReady, isTrue);
      session.change(authenticated: false);
      await settle();
      expect(device.tokens, isEmpty);
      expect(api.token, jwt);
      expect(await m.read(), isNull);
      session.change(authenticated: true);
      await settle();
      expect(m.localReady, isTrue);
    },
  );
  test(
    'late restore after logout cannot expose or save member token',
    () async {
      api.token = jwt;
      api.version = 2;
      final pending = Completer<Map<String, dynamic>?>();
      api.restore = () => pending.future;
      final m = create();
      await settle();
      session.change(authenticated: false);
      pending.complete({'token': jwt, 'version': 2});
      await settle();
      expect(m.localReady, isFalse);
      expect(device.tokens, isEmpty);
      expect(await m.read(), isNull);
    },
  );
  test(
    'logout during secure write serializes cleanup after old write',
    () async {
      api.token = jwt;
      api.version = 2;
      final gate = Completer<void>();
      device.beforeWrite = () => gate.future;
      final m = create();
      await settle();
      session.change(authenticated: false);
      gate.complete();
      await settle();
      expect(device.tokens, isEmpty);
      expect(m.localReady, isFalse);
    },
  );
  test(
    'device failure is partial server success, restore retry never repeats PUT',
    () async {
      final m = create();
      await settle();
      device.fail = true;
      await m.save(jwt);
      expect(api.token, jwt);
      expect(m.value!.configured, isTrue);
      expect(m.localReady, isFalse);
      expect(m.failure!.code, 'KEY_DEVICE_STORAGE_FAILED');
      expect(m.hasPending, isFalse);
      device.fail = false;
      await m.reload();
      expect(m.localReady, isTrue);
      expect(api.calls.where((c) => c.method == 'PUT').length, 1);
    },
  );
  test(
    'lost response retains immutable key and body for explicit replay',
    () async {
      final m = create();
      await settle();
      api.put = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await m.save(jwt);
      final first = api.calls.last;
      expect(m.hasPending, isTrue);
      await m.save('other.header.signature');
      expect(api.calls.last, first);
      api.put = () async {
        api.token = jwt;
        api.version = 2;
        return api.metadata();
      };
      await m.retry();
      final attempts = api.calls.where((c) => c.method == 'PUT').toList();
      expect(attempts[1].key, first.key);
      expect(attempts[1].body, first.body);
      expect(m.localReady, isTrue);
    },
  );
  test(
    'revision conflict clears command and reads current server state',
    () async {
      final m = create();
      await settle();
      api.token = jwt;
      api.version = 4;
      api.put = () async =>
          throw const AccountReadException('REVISION_CONFLICT', status: 409);
      await m.save(jwt);
      expect(m.hasPending, isFalse);
      expect(m.value!.version, 4);
      expect(m.localReady, isTrue);
    },
  );
  test(
    'delete uses query version, clears local, never deletes character resources',
    () async {
      api.token = jwt;
      api.version = 2;
      final m = create();
      await settle();
      await m.delete();
      final deletion = api.calls.firstWhere((c) => c.method == 'DELETE');
      expect(deletion.body, isNull);
      expect(deletion.query, {'expected_version': 2});
      expect(m.localReady, isFalse);
      expect(device.tokens, isEmpty);
      expect(m.value!.configured, isFalse);
      expect(
        api.calls.every((c) => c.path.startsWith(MemberLostArkKey.path)),
        isTrue,
      );
    },
  );
  test('wrong restored version rejected and token never persisted', () async {
    api.token = jwt;
    api.version = 2;
    api.restore = () async => {'token': jwt, 'version': 3};
    final m = create();
    await settle();
    expect(m.failure!.code, 'INVALID_RESPONSE');
    expect(device.tokens, isEmpty);
  });
  test(
    'failed metadata reload is unknown, cannot overwrite using old version',
    () async {
      api.token = jwt;
      api.version = 2;
      final m = create();
      await settle();
      api.onGet = () async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await m.reload();
      expect(m.value, isNull);
      expect(m.canChange, isFalse);
      final count = api.calls.length;
      await m.save(jwt);
      expect(api.calls.length, count);
    },
  );
}
