import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../shared/backend/server_analysis_wire.dart';
import '../domain/account_read_session.dart';
import '../domain/entities/character_build_role.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import 'backend_account_read_api.dart';
import 'local/scoped_command_key.dart';
import 'repositories/scoped_role_repository.dart';

abstract interface class AnalysisJournal {
  Future<String?> read(StorageScope scope);
  Future<void> write(StorageScope scope, String value);
}

class SecureAnalysisJournal implements AnalysisJournal {
  const SecureAnalysisJournal();
  static const storage = FlutterSecureStorage();
  String key(StorageScope scope) =>
      'character_analysis_v1_${base64Url.encode(utf8.encode(jsonEncode([scope.environment, scope.userId])))}';
  @override
  Future<String?> read(StorageScope scope) => storage.read(key: key(scope));
  @override
  Future<void> write(StorageScope scope, String value) =>
      storage.write(key: key(scope), value: value);
}

class CharacterAnalysisResult {
  CharacterAnalysisResult(this.state, {this.role, this.head, this.failure});
  final String state;
  final CharacterBuildRole? role;
  final StoredRoleSummary? head;
  final AccountReadException? failure;
}

/// Persists immutable command inputs before sending. No raw data, API key or
/// client-generated summary is accepted. Retries recover the original command.
class CharacterAnalysisClient {
  CharacterAnalysisClient(
    this.api, {
    this.journal = const SecureAnalysisJournal(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final DioBackendAccountReadApi api;
  final AnalysisJournal journal;
  final DateTime Function() now;
  bool _busy = false;
  Future<List<CharacterAnalysisResult>> execute(
    List<ScopedRolePlan> plans,
    String trigger,
    void Function() guard, {
    Map<String, Map<String, dynamic>> candidateContexts = const {},
    Map<String, Map<String, dynamic>> originalCommands = const {},
  }) async {
    roleCheck(
      plans.isNotEmpty &&
          plans.length <= 50 &&
          {'automatic', 'manual'}.contains(trigger),
    );
    if (_busy) throw const AccountReadException('REQUEST_IN_PROGRESS');
    _busy = true;
    try {
      guard();
      final scope = plans.first.ref.scope;
      roleCheck(plans.every((p) => p.ref.scope == scope));
      final captured = accountReadScope(api.session);
      void current() {
        requireAccountReadScope(api.session, captured);
        guard();
      }

      Map<String, dynamic> pending;
      try {
        final raw = await journal.read(scope);
        current();
        pending = raw == null ? {} : roleMap(jsonDecode(raw));
      } on AccountReadException {
        rethrow;
      } catch (_) {
        throw const AccountReadException('LOCAL_STORAGE_UNAVAILABLE');
      }
      Future<void> persist() async {
        current();
        try {
          await journal.write(scope, jsonEncode(pending));
        } catch (_) {
          throw const AccountReadException('LOCAL_STORAGE_UNAVAILABLE');
        }
        current();
      }

      final commands = <Map<String, dynamic>>[];
      for (final p in plans) {
        final id = p.ref.characterId;
        final supplied = originalCommands[id];
        final old =
            pending[id] ??
            (supplied == null
                ? null
                : {
                    'body': supplied,
                    'sent_at': now().toUtc().toIso8601String(),
                    'retry_at': null,
                  });
        if (pending[id] == null && old != null) pending[id] = old;
        Map<String, dynamic> body;
        if (old != null) {
          final record = roleMap(old);
          body = roleMap(record['body']);
          ServerAnalysisWire.definition('AnalysisCommand', body);
          roleCheck(body['character_id'] == id);
          if (body['expected_ownership_revision'] !=
                  p.profile.ownershipRevision ||
              (supplied == null &&
                  !body.containsKey('candidate_context') &&
                  body['expected_lifecycle_revision'] !=
                      p.profile.lifecycleRevision)) {
            throw const AccountReadException('REVISION_CONFLICT');
          }
          final sent = roleUtc(record['sent_at']);
          if (supplied == null &&
              !body.containsKey('candidate_context') &&
              now().toUtc().difference(sent) >= const Duration(hours: 24)) {
            pending.remove(id);
            await persist();
            throw const AccountReadException('IDEMPOTENCY_EXPIRED');
          }
          final retry = record['retry_at'];
          if (retry != null && now().toUtc().isBefore(roleUtc(retry))) {
            throw AccountReadException(
              'REQUEST_IN_PROGRESS',
              retryAt: roleUtc(retry),
            );
          }
        } else {
          if (api.cooldown?.active == true) {
            throw AccountReadException(
              'UPSTREAM_RATE_LIMITED',
              retryAt: api.cooldown!.until,
            );
          }
          body = {
            'command_id': newScopedCommandKey(),
            'character_id': id,
            'expected_ownership_revision': p.profile.ownershipRevision,
            'expected_lifecycle_revision': p.profile.lifecycleRevision,
            'expected_summary_versions': {
              'dealer': p.profile.dealer.version,
              'support': p.profile.support.version,
            },
            'trigger': switch (candidateContexts[id]?['purpose']) {
              'manual_retry' => 'manual',
              'automatic_candidate' => 'automatic',
              _ => trigger,
            },
            if (candidateContexts[id] != null)
              'candidate_context': candidateContexts[id],
          };
          pending[id] = {
            'body': body,
            'sent_at': now().toUtc().toIso8601String(),
            'retry_at': null,
          };
        }
        commands.add(body);
      }
      final body = {'items': commands};
      ServerAnalysisWire.definition('AnalysisRequest', body);
      roleCheck(
        commands.map((c) => c['character_id']).toSet().length ==
            commands.length,
      );
      if (utf8.encode(jsonEncode(body)).length > 524288) {
        throw const AccountReadException('REQUEST_TOO_LARGE');
      }
      await persist();
      final Map<String, dynamic> raw;
      try {
        raw = (await api.request(
          '/v2/me/character-analysis/refresh',
          method: 'POST',
          body: body,
        ))!;
      } on AccountReadException catch (e) {
        current();
        // A received envelope refusal precedes writes; a lost HTTP response does
        // not prove failure. Keep the original input until the outcome is known.
        if ({400, 401, 403, 413}.contains(e.status)) {
          for (final p in plans) {
            pending.remove(p.ref.characterId);
          }
          await persist();
          rethrow;
        }
        throw AccountReadException(
          'ANALYSIS_RESULT_UNKNOWN',
          status: e.status,
          requestId: e.requestId,
          retryAfter: e.retryAfter,
          retryAt: e.retryAt,
        );
      }
      current();
      final List<CharacterAnalysisResult> results;
      try {
        ServerAnalysisWire.definition('AnalysisResponse', raw);
        roleUtc(raw['evaluated_at']);
        final items = raw['items'] as List;
        roleCheck(items.length == plans.length);
        results = [
          for (var i = 0; i < plans.length; i++)
            _parse(roleMap(items[i]), commands[i], plans[i]),
        ];
      } on FormatException {
        throw const AccountReadException('ANALYSIS_RESULT_UNKNOWN');
      }
      for (var i = 0; i < plans.length; i++) {
        final id = plans[i].ref.characterId, result = results[i];
        if ({'saved', 'skipped', 'failed'}.contains(result.state)) {
          pending.remove(id);
        } else {
          pending[id]['retry_at'] =
              result.failure?.retryAt?.toIso8601String() ??
              (result.failure?.retryAfter == null
                  ? null
                  : now()
                        .toUtc()
                        .add(result.failure!.retryAfter!)
                        .toIso8601String());
        }
      }
      try {
        await persist();
      } on AccountReadException catch (e) {
        current();
        if (e.code != 'LOCAL_STORAGE_UNAVAILABLE') rethrow;
        return [
          for (final r in results)
            CharacterAnalysisResult(
              r.state,
              role: r.role,
              head: r.head,
              failure: r.failure ?? e,
            ),
        ];
      }
      return results;
    } finally {
      _busy = false;
    }
  }

  CharacterAnalysisResult _parse(
    Map<String, dynamic> item,
    Map<String, dynamic> command,
    ScopedRolePlan plan,
  ) {
    roleCheck(
      item['command_id'] == command['command_id'] &&
          item['character_id'] == command['character_id'],
    );
    final state = item['state'] as String,
        status = item['status'] as int,
        retry = item['retry'];
    if (state == 'saved') {
      roleCheck(status == 200 && retry == 'none' && item['error'] == null);
      final result = roleMap(item['result']),
          role = summaryRole(result['role']);
      roleCheck(
        result['character_id'] == plan.ref.characterId &&
            result['game_account_id'] == plan.ref.accountId &&
            result['ownership_revision'] == plan.profile.ownershipRevision &&
            result['lifecycle_revision'] ==
                command['expected_lifecycle_revision'] &&
            item['detected_role'] == role.name,
      );
      final head = StoredRoleSummary.fromJson(roleMap(result['analysis']));
      roleCheck(
        head.summary != null &&
            head.detail != null &&
            head.version ==
                (roleMap(command['expected_summary_versions'])[role.name]
                        as int) +
                    1 &&
            head.summary!.lifecycleRevision ==
                command['expected_lifecycle_revision'],
      );
      final detection = roleMap(head.detail!['detection']);
      roleCheck(
        detection['status'] == 'detected' &&
            detection['detected_role'] == role.name &&
            detection['catalog_version'] == head.summary!.catalogVersion,
      );
      return CharacterAnalysisResult(state, role: role, head: head);
    }
    roleCheck(item['result'] == null);
    final error = roleMap(item['error']);
    final code = error['code'] as String;
    roleCheck(switch (state) {
      'skipped' =>
        status == 200 &&
            retry == 'none' &&
            {
              'AUTOMATIC_TARGET_EXCLUDED',
              'ANALYSIS_CANDIDATE_COMPLETED',
              'ANALYSIS_CANDIDATE_RETRY_REQUIRED',
            }.contains(code),
      'failed' =>
        {400, 401, 403, 404, 409, 429, 503}.contains(status) &&
            {'none', 'new_command'}.contains(retry),
      'not_processed' =>
        status == 503 &&
            retry == 'same_command' &&
            code == 'BATCH_NOT_PROCESSED',
      'in_progress' =>
        status == 409 &&
            retry == 'same_command' &&
            code == 'REQUEST_IN_PROGRESS',
      'unknown' =>
        status == 503 &&
            retry == 'same_command' &&
            code == 'SERVICE_UNAVAILABLE',
      _ => false,
    });
    final failure = AccountReadException(
      code,
      status: status,
      requestId: error['request_id'] as String?,
      retryAfter: error['retry_after_seconds'] == null
          ? null
          : Duration(seconds: error['retry_after_seconds'] as int),
      retryAt: error['retry_at'] == null ? null : roleUtc(error['retry_at']),
    );
    // A definitive failure may carry the provider's shared retry deadline too.
    // Keep stored reads available while preventing a fresh collection loop.
    if (state == 'failed' ||
        code == 'UPSTREAM_RATE_LIMITED' ||
        code == 'RATE_LIMITED') {
      final until =
          failure.retryAt ??
          (failure.retryAfter == null
              ? null
              : now().toUtc().add(failure.retryAfter!));
      if (until != null) api.cooldown?.observe(until);
    }
    return CharacterAnalysisResult(state, failure: failure);
  }
}
