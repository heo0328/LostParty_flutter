import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/auth/domain/auth_repository.dart';
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import 'package:lost_party/features/auth/domain/backend_auth_models.dart';
import 'package:lost_party/features/auth/domain/google_authentication_gateway.dart';

final initialTime = DateTime.utc(2026, 10, 14);
Map<String, dynamic> tokenJson(
  DateTime now, {
  bool remember = true,
  String access = 'access-first',
  String? refresh,
}) => {
  'token_type': 'Bearer',
  'access_token': access,
  'refresh_token': refresh ?? newAuthSecret(),
  'access_expires_at': now.add(const Duration(minutes: 10)).toIso8601String(),
  'refresh_expires_at': now.add(const Duration(days: 7)).toIso8601String(),
  'session': {
    'id': 'session-1',
    'remember_me': remember,
    'created_at': initialTime.toIso8601String(),
    'absolute_expires_at': initialTime
        .add(const Duration(days: 30))
        .toIso8601String(),
    'idle_expires_at': now.add(const Duration(days: 7)).toIso8601String(),
    'expires_at': now.add(const Duration(days: 7)).toIso8601String(),
  },
};
Map<String, dynamic> userJson() => {
  'id': 'user-1',
  'status': 'active',
  'created_at': initialTime.toIso8601String(),
};

class MemoryStore implements AuthSessionStore {
  String? value;
  bool failWrite = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('storage');
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class FakeGoogle implements GoogleAuthenticationGateway {
  String? nonce;
  bool cancel = false;
  int clears = 0;
  @override
  Future<GoogleAuthenticationProof> authenticate({
    required String serverClientId,
    required String nonce,
  }) async {
    this.nonce = nonce;
    if (cancel) {
      throw const GoogleAuthenticationException(
        GoogleAuthenticationFailure.cancelled,
      );
    }
    return GoogleAuthenticationProof('test-only-google-proof');
  }

  @override
  Future<void> clearCredentialState() async {
    clears++;
  }
}

class FakeApi implements BackendAuthApi {
  DateTime now = initialTime;
  int challenges = 0, logins = 0, meCalls = 0, refreshCalls = 0;
  String? challengeHash, loginSecret;
  final refreshRequests = <(String, String)>[];
  final revoked = <String>[];
  Future<AuthLogin>? loginResult;
  Future<AuthTokens> Function(String, String)? refreshing;
  AuthApiException? meError;
  Future<void>? logoutResult;
  @override
  Future<AuthChallenge> challenge(String secretHash) async {
    challenges++;
    challengeHash = secretHash;
    return AuthChallenge.fromJson({
      'transaction_id': 'transaction-1',
      'nonce': 'server-nonce',
      'expires_at': now.add(const Duration(minutes: 5)).toIso8601String(),
    });
  }

  @override
  Future<AuthLogin> login({
    required String transactionId,
    required String secret,
    required String proof,
    required bool remember,
  }) async {
    logins++;
    loginSecret = secret;
    return loginResult ??
        AuthLogin.fromJson({
          ...tokenJson(now, remember: remember),
          'user': userJson(),
          'is_new_user': true,
        });
  }

  @override
  Future<AuthTokens> refresh(String token, String requestId) async {
    refreshCalls++;
    refreshRequests.add((token, requestId));
    return refreshing == null
        ? AuthTokens.fromJson(tokenJson(now, access: 'access-next'))
        : refreshing!(token, requestId);
  }

  @override
  Future<AuthUser> me(String access) async {
    meCalls++;
    if (meError != null) throw meError!;
    return AuthUser.fromJson(userJson());
  }

  @override
  Future<AuthSession> session(String access) async =>
      AuthSession.fromJson(tokenJson(now)['session'] as Map<String, dynamic>);
  @override
  Future<void> logout(String refresh) async {
    revoked.add(refresh);
    if (logoutResult != null) await logoutResult;
  }
}

void main() {
  late FakeApi api;
  late FakeGoogle google;
  late MemoryStore store;
  late AuthSessionController controller;
  AuthSessionController create() => AuthSessionController(
    api: api,
    google: google,
    store: store,
    serverClientId: 'web-client',
    clock: () => api.now,
    delay: (wait) async {
      api.now = api.now.add(wait);
    },
  );
  setUp(() {
    api = FakeApi();
    google = FakeGoogle();
    store = MemoryStore();
    controller = create();
  });
  tearDown(() => controller.dispose());

  test(
    'a delayed logout must not clear the next login provider state or cache',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      final revoke = Completer<void>();
      api.logoutResult = revoke.future;
      final logout = controller.logout();
      await Future<void>.delayed(Duration.zero);
      expect(await controller.login(remember: true), isTrue);
      revoke.complete();
      await logout;
      expect(controller.isAuthenticated, isTrue);
      expect(store.value, isNotNull);
      expect(google.clears, 0);
    },
  );

  test(
    'guest bootstrap performs no member creation or server request',
    () async {
      await controller.restore();
      expect(controller.status, AuthStatus.guest);
      expect(api.challenges + api.logins + api.meCalls + api.refreshCalls, 0);
    },
  );
  test(
    'login binds exact server nonce and hashes ASCII encoded secret',
    () async {
      await controller.restore();
      expect(await controller.login(remember: true), isTrue);
      expect(google.nonce, 'server-nonce');
      expect(api.loginSecret!.length, 43);
      expect(base64Url.decode('${api.loginSecret}=').length, 32);
      expect(api.challengeHash, authSecretDigest(api.loginSecret!));
      expect(controller.userId, 'user-1');
      expect(store.value, isNotNull);
    },
  );
  test('memory-only login is not restored by another app instance', () async {
    await controller.restore();
    await controller.login(remember: false);
    expect(controller.isAuthenticated, isTrue);
    expect(store.value, isNull);
    final another = create();
    await another.restore();
    expect(another.status, AuthStatus.guest);
    another.dispose();
  });
  test(
    'Google UI cancel never exchanges proof or creates app member',
    () async {
      await controller.restore();
      google.cancel = true;
      expect(await controller.login(remember: true), isFalse);
      expect(api.logins, 0);
      expect(controller.errorCode, isNull);
      expect(store.value, isNull);
    },
  );
  test(
    'remembered sessions are checked with Backend before restoration succeeds',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      final another = create();
      await another.restore();
      expect(another.isAuthenticated, isTrue);
      expect(api.meCalls, 1);
      another.dispose();
    },
  );
  test(
    'parallel expiry refreshes share one request and atomic credential replacement',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      api.now = api.now.add(const Duration(minutes: 11));
      final reply = Completer<AuthTokens>();
      api.refreshing = (_, _) => reply.future;
      final first = controller.accessToken();
      final second = controller.accessToken();
      await Future<void>.delayed(Duration.zero);
      expect(api.refreshCalls, 1);
      final pending = jsonDecode(store.value!) as Map<String, dynamic>;
      expect((pending['pending'] as Map)['attempts'], 1);
      reply.complete(
        AuthTokens.fromJson(tokenJson(api.now, access: 'access-new')),
      );
      expect(await first, 'access-new');
      expect(await second, 'access-new');
      final saved = jsonDecode(store.value!) as Map;
      expect(saved['pending'], isNull);
      expect((saved['tokens'] as Map)['access_token'], 'access-new');
    },
  );
  test(
    'response loss retries same token/id, maximum three transmissions',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      api.now = api.now.add(const Duration(minutes: 11));
      api.refreshing = (_, _) async {
        if (api.refreshCalls < 3) {
          throw const AuthApiException('SERVICE_UNAVAILABLE', status: 503);
        }
        return AuthTokens.fromJson(tokenJson(api.now));
      };
      await controller.refresh();
      expect(api.refreshCalls, 3);
      expect(api.refreshRequests.toSet().length, 1);
      expect(controller.isAuthenticated, isTrue);
    },
  );
  test(
    'network retry exhaustion retains pending and does not reset attempts on restart',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      api.refreshing = (_, _) async =>
          throw const AuthApiException('NETWORK_UNAVAILABLE');
      await expectLater(controller.refresh(), throwsA(isA<AuthApiException>()));
      expect(controller.status, AuthStatus.unavailable);
      expect(store.value, isNotNull);
      final count = api.refreshCalls;
      final another = create();
      await another.restore();
      expect(api.refreshCalls, count);
      expect(another.status, AuthStatus.reauthenticationRequired);
      another.dispose();
    },
  );
  test(
    'pending operation resumes same id after process interruption',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      final reply = Completer<AuthTokens>();
      api.refreshing = (_, _) => reply.future;
      final first = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      final oldRequest = api.refreshRequests.single;
      controller.dispose();
      controller = create();
      api.refreshing = (_, _) async => AuthTokens.fromJson(tokenJson(api.now));
      await controller.restore();
      expect(api.refreshRequests.last, oldRequest);
      expect(controller.isAuthenticated, isTrue);
      reply.complete(AuthTokens.fromJson(tokenJson(api.now)));
      await first;
    },
  );
  test(
    'backend recovery409 requires explicit login without deleting remember choice',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      api.refreshing = (_, _) async =>
          throw const AuthApiException('REFRESH_RECOVERY_LIMITED', status: 409);
      await expectLater(controller.refresh(), throwsA(isA<AuthApiException>()));
      expect(controller.status, AuthStatus.reauthenticationRequired);
      expect(controller.remember, isTrue);
      expect(store.value, isNotNull);
      expect(api.refreshCalls, 1);
    },
  );
  test('revoked session cannot silently reauthenticate with Google', () async {
    await controller.restore();
    await controller.login(remember: true);
    final calls = api.challenges;
    api.meError = const AuthApiException('SESSION_REVOKED', status: 401);
    final another = create();
    await another.restore();
    expect(another.status, AuthStatus.guest);
    expect(store.value, isNull);
    expect(api.challenges, calls);
    another.dispose();
  });
  test(
    'logout fences a late refresh success and clears disk before remote revoke',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      final reply = Completer<AuthTokens>();
      api.refreshing = (_, _) => reply.future;
      final refreshing = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await controller.logout();
      reply.complete(AuthTokens.fromJson(tokenJson(api.now)));
      await refreshing;
      expect(controller.status, AuthStatus.guest);
      expect(controller.userId, isNull);
      expect(store.value, isNull);
      expect(api.revoked.length, 1);
    },
  );
  test(
    'storage failure prevents sending an unrecorded remembered refresh',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      store.failWrite = true;
      await expectLater(controller.refresh(), throwsA(isA<AuthApiException>()));
      expect(api.refreshCalls, 0);
      expect(controller.status, AuthStatus.unavailable);
    },
  );
  test(
    'Retry-After outside recovery budget does not trigger unsafe retransmission',
    () async {
      await controller.restore();
      await controller.login(remember: true);
      api.refreshing = (_, _) async => throw const AuthApiException(
        'RATE_LIMITED',
        status: 429,
        retryAfter: Duration(seconds: 60),
      );
      await expectLater(controller.refresh(), throwsA(isA<AuthApiException>()));
      expect(api.refreshCalls, 1);
    },
  );
}
