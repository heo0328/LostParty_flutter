import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/scoped_cache_models.dart';

abstract interface class MemberWeeklyStore {
  Future<String?> read(StorageScope scope);
  Future<void> write(StorageScope scope, String json);
}

class SecureMemberWeeklyStore implements MemberWeeklyStore {
  const SecureMemberWeeklyStore({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  String _key(StorageScope s) =>
      'weekly_v1_${base64Url.encode(utf8.encode('${s.environment}/${s.userId}'))}';
  @override
  Future<String?> read(StorageScope scope) => storage.read(key: _key(scope));
  @override
  Future<void> write(StorageScope scope, String json) =>
      storage.write(key: _key(scope), value: json);
}
