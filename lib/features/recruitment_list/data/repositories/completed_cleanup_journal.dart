import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/entities/completed_ownership_cleanup.dart';

/// Confirmed requests only. Each event has its own key, avoiding list overwrites.
class CompletedCleanupJournal {
  const CompletedCleanupJournal({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;
  static const _prefix = 'completed_cleanup_v1/';
  String _key(CompletedOwnershipCleanup request) =>
      '$_prefix${Uri.encodeComponent(request.actorId)}/${request.eventId}';

  Future<void> save(CompletedOwnershipCleanup request) =>
      _storage.write(key: _key(request), value: encode(request));

  Future<void> remove(CompletedOwnershipCleanup request) =>
      _storage.delete(key: _key(request));

  Future<void> run(
    CompletedOwnershipCleanup request,
    Future<void> Function() send,
  ) async {
    await save(request);
    await send();
    await remove(request);
  }

  Future<List<CompletedOwnershipCleanup>> pending(String actorId) async {
    final values = await _storage.readAll();
    final prefix = '$_prefix${Uri.encodeComponent(actorId)}/';
    final requests = <CompletedOwnershipCleanup>[];
    for (final entry in values.entries.where((e) => e.key.startsWith(prefix))) {
      final request = decode(entry.value);
      if (request.actorId != actorId || _key(request) != entry.key) {
        throw const FormatException('저장된 요청의 사용자 정보를 확인할 수 없습니다.');
      }
      requests.add(request);
    }
    return requests;
  }

  static Object? _time(Object? value) {
    if (value == null) return null;
    if (value is! Timestamp) {
      throw const FormatException('지원하지 않는 참가 기록 시각입니다.');
    }
    return [value.seconds, value.nanoseconds];
  }

  static Timestamp? _restoreTime(dynamic value) => value == null
      ? null
      : Timestamp((value as List)[0] as int, value[1] as int);

  static String encode(CompletedOwnershipCleanup r) => jsonEncode({
    'version': 1,
    'targetName': r.targetName,
    'roomId': r.roomId,
    'actorId': r.actorId,
    'targetId': r.targetId,
    'characterId': r.characterId,
    'eventId': r.eventId,
    'revision': r.revision,
    'targetIndex': r.targetIndex,
    'actorIndex': r.actorIndex,
    'observedRevision': r.observedRevision,
    'memberUpdatedAt': _time(r.memberUpdatedAt),
    'kind': r.kind.name,
    'leaderIndex': r.leaderIndex,
    'observedLeaderRevision': r.observedLeaderRevision,
    'successorIndex': r.successorIndex,
    'successorId': r.successorId,
    'successorName': r.successorName,
    'successorClass': r.successorClass,
    'successorUpdatedAt': _time(r.successorUpdatedAt),
  });

  static CompletedOwnershipCleanup decode(String value) {
    final d = jsonDecode(value) as Map<String, dynamic>;
    if (d['version'] != 1) throw const FormatException('지원하지 않는 요청 버전입니다.');
    return CompletedOwnershipCleanup(
      targetName: d['targetName'] as String?,
      roomId: d['roomId'] as String,
      actorId: d['actorId'] as String,
      targetId: d['targetId'] as String,
      characterId: d['characterId'] as String,
      eventId: d['eventId'] as String,
      revision: d['revision'] as int,
      targetIndex: d['targetIndex'] as int,
      actorIndex: d['actorIndex'] as int,
      observedRevision: d['observedRevision'] as int,
      memberUpdatedAt: _restoreTime(d['memberUpdatedAt']),
      kind: CompletedCleanupKind.values.byName(d['kind'] as String),
      leaderIndex: d['leaderIndex'] as int?,
      observedLeaderRevision: d['observedLeaderRevision'] as int?,
      successorIndex: d['successorIndex'] as int?,
      successorId: d['successorId'] as String?,
      successorName: d['successorName'] as String?,
      successorClass: d['successorClass'] as String?,
      successorUpdatedAt: _restoreTime(d['successorUpdatedAt']),
    );
  }
}
