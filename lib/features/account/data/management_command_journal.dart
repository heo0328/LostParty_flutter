import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/scoped_cache_models.dart';

abstract interface class ManagementJournalStorage {
  Future<String?> read(StorageScope scope, String registrationId);
  Future<void> write(StorageScope scope, String registrationId, String? value);
}

/// Independent namespace: never converts v1/preferences/ownership pending writes.
class SecureManagementJournalStorage implements ManagementJournalStorage {
  const SecureManagementJournalStorage({
    this.storage = const FlutterSecureStorage(),
  });
  final FlutterSecureStorage storage;
  String _key(StorageScope scope, String id) =>
      'character_management_v1_${base64Url.encode(utf8.encode(jsonEncode([scope.environment, scope.userId, id])))}';
  @override
  Future<String?> read(StorageScope scope, String registrationId) =>
      storage.read(key: _key(scope, registrationId));
  @override
  Future<void> write(
    StorageScope scope,
    String registrationId,
    String? value,
  ) async {
    final key = _key(scope, registrationId);
    if (value == null) {
      await storage.delete(key: key);
    } else {
      await storage.write(key: key, value: value);
    }
  }
}
