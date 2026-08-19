import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token.dart';
import 'package:lost_party/shared/lost_ark_api/auth/api_token_store.dart';
import 'package:lost_party/shared/lost_ark_api/auth/secure_api_token_store.dart';

void main() {
  group('ApiToken', () {
    test('trims surrounding whitespace', () {
      final token = ApiToken('  jwt-value  ');

      expect(token.value, 'jwt-value');
    });

    test('rejects an empty value', () {
      expect(() => ApiToken('   '), throwsFormatException);
    });

    test('creates the Lost Ark authorization header value', () {
      final token = ApiToken('jwt-value');

      expect(token.authorizationHeaderValue, 'bearer jwt-value');
    });

    test('does not expose the token through toString', () {
      final token = ApiToken('secret-jwt-value');

      expect(token.toString(), 'ApiToken(***)');
      expect(token.toString(), isNot(contains('secret-jwt-value')));
    });
  });

  group('SecureApiTokenStore', () {
    late ApiTokenStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = SecureApiTokenStore();
    });

    test('returns null before a token is stored', () async {
      expect(await store.read(), isNull);
    });

    test('stores and reads a token', () async {
      await store.write(ApiToken('jwt-value'));

      final storedToken = await store.read();

      expect(storedToken?.value, 'jwt-value');
    });

    test('deletes a stored token', () async {
      await store.write(ApiToken('jwt-value'));

      await store.delete();

      expect(await store.read(), isNull);
    });

    test('treats a blank stored value as missing', () async {
      FlutterSecureStorage.setMockInitialValues({'lost_ark_api_jwt': '   '});

      expect(await store.read(), isNull);
    });
  });
}
