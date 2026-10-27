import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/application_messages.dart';
import '../../data/beta/beta_contract.dart';
import '../../data/beta/recruitment_command.dart';
import '../../data/beta/recruitment_command_transport.dart';
import '../../domain/application_memo_policy.dart';

/// App-owned account document and unresolved preset write. Editor drafts stay local.
class ApplicationMessagesController extends ChangeNotifier {
  ApplicationMessagesController({
    required this.gateway,
    required this.session,
    required this.scopeKey,
    required this.changes,
    this.transport,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    binding = scopeKey();
    session.addListener(_access);
    changes.addListener(_access);
  }
  final ApplicationMessagesGateway gateway;
  final AccountReadSession session;
  final String Function() scopeKey;
  final Listenable changes;
  final RecruitmentCommandTransport? transport;
  final DateTime Function() now;
  late String binding;
  int epoch = 0;
  bool disposed = false, loading = false, saving = false;
  String? failure;
  ApplicationMessagePresets? document;
  RecruitmentCommand? pending;
  List<Map<String, dynamic>> get items =>
      (document?.wire['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
  bool _valid(int e) =>
      !disposed &&
      e == epoch &&
      session.isAuthenticated &&
      binding == scopeKey();
  void _emit() {
    if (!disposed) notifyListeners();
  }

  void _access() {
    if (binding == scopeKey() && session.isAuthenticated || disposed) return;
    epoch++;
    binding = scopeKey();
    document = null;
    pending = null;
    loading = saving = false;
    failure = 'ACCESS_CHANGED';
    _emit();
  }

  void _ack(RecruitmentCommand command, Map<String, dynamic> raw) {
    final result = ApplicationMessagePresets(raw);
    final body = jsonDecode(command.rawBody) as Map;
    final expectedVersion = body['expected_version'] as int;
    final actual = result.wire['items'] as List,
        expected = body['items'] as List;
    if (!{
          expectedVersion,
          expectedVersion + 1,
        }.contains(result.wire['version']) ||
        actual.length != expected.length ||
        List.generate(actual.length, (i) => i).any(
          (i) =>
              actual[i]['id'] != expected[i]['id'] ||
              actual[i]['text'] != expected[i]['text'],
        ) ||
        (result.wire['version'] == expectedVersion + 1 &&
            result.wire['saved_at'] == null)) {
      throw const FormatException('Preset ACK does not match original write');
    }
  }

  Future<void> load() async {
    if (disposed || loading || saving || !session.isAuthenticated) return;
    final e = epoch;
    loading = true;
    failure = null;
    _emit();
    try {
      final saved = await transport?.restore(RecruitmentCommandOwner.presets);
      if (!_valid(e)) return;
      pending = saved;
      if (saved?.state == RecruitmentCommandState.acknowledged) {
        _ack(saved!, jsonDecode(saved.rawAck!) as Map<String, dynamic>);
        document = ApplicationMessagePresets(
          jsonDecode(saved.rawAck!) as Map<String, dynamic>,
        );
        await transport!.releaseResolved(saved.owner, saved.key);
        if (!_valid(e)) return;
        pending = null;
      } else if (saved?.state == RecruitmentCommandState.rejected) {
        await transport!.releaseResolved(saved!.owner, saved.key);
        if (!_valid(e)) return;
        pending = null;
      }
      final result = await gateway.applicationMessagePresets();
      if (_valid(e)) document = result;
    } catch (err) {
      if (_valid(e)) {
        failure = err is AccountReadException ? err.code : 'INVALID_RESPONSE';
      }
    } finally {
      if (_valid(e)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<bool> save(
    List<Map<String, dynamic>> rows,
    int expectedVersion,
  ) async {
    if (disposed ||
        saving ||
        loading ||
        pending != null ||
        !session.isAuthenticated) {
      return false;
    }
    final normalized = <Map<String, dynamic>>[];
    for (final row in rows) {
      final result = ApplicationMemoPolicy.check(
        row['text'] as String,
        required: true,
      );
      if (!result.valid) {
        failure = result.error;
        _emit();
        return false;
      }
      normalized.add({'id': row['id'], 'text': result.text});
    }
    if (rows.length > 5 ||
        rows.map((r) => r['id']).toSet().length != rows.length) {
      return false;
    }
    pending = RecruitmentCommand(
      owner: RecruitmentCommandOwner.presets,
      operation: 'beta_application_message_presets_put',
      method: 'PUT',
      path: '/v2/me/application-message-presets',
      query: const {},
      targetCycles: const [],
      rawBody: jsonEncode({
        'expected_version': expectedVersion,
        'items': normalized,
      }),
      key: newScopedCommandKey(),
      createdAt: now().toUtc(),
      version: 2,
    );
    return retry();
  }

  Future<bool> retry() async {
    final command = pending, e = epoch;
    if (disposed || saving || command == null || !session.isAuthenticated) {
      return false;
    }
    saving = true;
    failure = null;
    _emit();
    try {
      if (transport == null) {
        throw const AccountReadException('COMMAND_STORE_UNAVAILABLE');
      }
      final ack = await transport!.submit(
        command,
        validateAck: (raw) => _ack(command, raw),
      );
      if (!_valid(e)) return false;
      document = ApplicationMessagePresets(ack);
      await transport!.releaseResolved(command.owner, command.key);
      if (!_valid(e)) return false;
      pending = null;
      return true;
    } catch (err) {
      if (_valid(e)) {
        failure = err is AccountReadException ? err.code : 'INVALID_RESPONSE';
        try {
          final saved = await transport?.restore(
            RecruitmentCommandOwner.presets,
          );
          if (!_valid(e)) return false;
          pending = saved ?? pending;
          if (saved?.state == RecruitmentCommandState.rejected) {
            await transport!.releaseResolved(saved!.owner, saved.key);
            if (_valid(e)) pending = null;
          }
        } catch (_) {
          /* Keep the original request if local recovery is unavailable. */
        }
      }
      return false;
    } finally {
      if (_valid(e)) {
        saving = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    epoch++;
    session.removeListener(_access);
    changes.removeListener(_access);
    super.dispose();
  }
}
