import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/auth/domain/auth_session_controller.dart';
import 'package:lost_party/features/auth/domain/backend_auth_models.dart';
import '../../auth/auth_session_controller_test.dart' as auth_fakes;

void main() {
  late AuthSessionController auth;
  late AuthAccountReadSession session;
  late auth_fakes.MemoryStore store;
  setUp(() async {
    final api = auth_fakes.FakeApi();
    store = auth_fakes.MemoryStore();
    auth = AuthSessionController(
      api: api,
      google: auth_fakes.FakeGoogle(),
      store: store,
      serverClientId: 'test-web-client',
      clock: () => api.now,
    );
    session = AuthAccountReadSession(auth);
    await auth.restore();
    expect(await auth.login(remember: true), isTrue);
  });
  tearDown(() => auth.dispose());

  test(
    'a previous same-user session cannot invalidate the new login',
    () async {
      final generation = session.generation;
      final user = session.userId;
      expect(await auth.login(remember: true), isTrue);
      expect(session.userId, user);
      expect(session.generation, isNot(generation));
      await session.reject(
        generation,
        const AuthApiException('SESSION_REVOKED', status: 401),
      );
      expect(session.isAuthenticated, isTrue);
      expect(store.value, isNotNull);
    },
  );
  test(
    'business ownership rejection preserves the actual authentication cache',
    () async {
      await session.reject(
        session.generation,
        const AuthApiException('OWNERSHIP_REQUIRED', status: 403),
      );
      expect(session.isAuthenticated, isTrue);
      expect(store.value, isNotNull);
    },
  );
  test(
    'current session revocation clears credentials and notifies read owners',
    () async {
      var notifications = 0;
      session.addListener(() => notifications++);
      await session.reject(
        session.generation,
        const AuthApiException('SESSION_REVOKED', status: 401),
      );
      expect(session.isAuthenticated, isFalse);
      expect(store.value, isNull);
      expect(notifications, greaterThan(0));
    },
  );
}
