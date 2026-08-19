import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_token.dart';
import 'api_token_store.dart';

class SecureApiTokenStore implements ApiTokenStore {
  SecureApiTokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _storageKey = 'lost_ark_api_jwt';

  final FlutterSecureStorage _storage;

  @override
  Future<ApiToken?> read() async {
    final storedValue = await _storage.read(key: _storageKey);
    if (storedValue == null || storedValue.trim().isEmpty) {
      return null;
    }

    return ApiToken(storedValue);
  }

  @override
  Future<void> write(ApiToken token) {
    return _storage.write(key: _storageKey, value: token.value);
  }

  @override
  Future<void> delete() {
    return _storage.delete(key: _storageKey);
  }
}
