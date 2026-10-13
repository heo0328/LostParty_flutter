import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/auth_repository.dart';

/// One JSON value contains tokens and pending refresh. No separate partially
/// updated token/request-ID keys, and no overlap with the Lost Ark API key.
class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({
    required String environment,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _key = 'lostparty_backend_auth_v1:$environment',
       _storage = storage;
  final String _key;
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}
