import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/auth/data/auth_session_store.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/secure_api_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('server origins keep separate sessions and scoped deletion', () async {
    final local = SecureAuthSessionStore(environment: 'http://10.0.2.2:8000');
    final other = SecureAuthSessionStore(environment: 'http://10.0.2.2:9000');
    final https = SecureAuthSessionStore(environment: 'https://10.0.2.2:8000');
    await local.write('local-session');
    expect(await other.read(), isNull);
    expect(await https.read(), isNull);
    await other.write('other-session');
    await local.delete();
    expect(await local.read(), isNull);
    expect(await other.read(), 'other-session');
  });

  test('new instance of the same origin reads the saved session', () async {
    final first = SecureAuthSessionStore(environment: 'http://10.0.2.2:8000');
    final next = SecureAuthSessionStore(environment: 'http://10.0.2.2:8000');
    await first.write('saved-session');
    expect(await next.read(), 'saved-session');
  });

  test('backend session replacement leaves the Lost Ark key intact', () async {
    final gameCredential = SecureApiTokenStore();
    await gameCredential.write(ApiToken('separate-credential'));
    final store = SecureAuthSessionStore(environment: 'http://10.0.2.2:8000');
    await store.write('first-session');
    await store.write('replacement-session');
    expect(await store.read(), 'replacement-session');
    await store.delete();
    expect((await gameCredential.read())?.value, 'separate-credential');
  });
}
