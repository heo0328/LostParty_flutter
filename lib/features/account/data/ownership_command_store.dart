import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/account_read_session.dart';
import '../domain/ownership_command.dart';
import '../domain/ownership_wire.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_verification.dart';

abstract interface class OwnershipJournalStorage {
  Future<String?> read(StorageScope scope);
  Future<void> write(StorageScope scope, String value);
}

class SecureOwnershipJournalStorage implements OwnershipJournalStorage {
  const SecureOwnershipJournalStorage({
    this.storage = const FlutterSecureStorage(),
  });
  final FlutterSecureStorage storage;
  String _key(StorageScope s) =>
      'ownership_commands_v1_${base64Url.encode(utf8.encode(jsonEncode([s.environment, s.userId])))}';
  @override
  Future<String?> read(StorageScope scope) => storage.read(key: _key(scope));
  @override
  Future<void> write(StorageScope scope, String value) =>
      storage.write(key: _key(scope), value: value);
}

enum OwnershipCommandPhase {
  awaitingAck,
  awaitingCurrent,
  reconciliationRequired,
  reconciled,
}

class OwnershipJournalEntry {
  const OwnershipJournalEntry(
    this.command, {
    this.phase = OwnershipCommandPhase.awaitingAck,
    this.responseId,
  });
  final OwnershipCommand command;
  final OwnershipCommandPhase phase;
  final String? responseId;
  Map<String, dynamic> toJson() => {
    'command': command.toJson(),
    'phase': phase.name,
    'response_id': responseId,
  };
}

/// App-owned single writer, independent namespace/schema from weekly data.
/// Failed/corrupt reads never become an empty journal or overwrite old commands.
class OwnershipCommandStore {
  OwnershipCommandStore(this.storage);
  final OwnershipJournalStorage storage;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<OwnershipJournalEntry>> load(
    AccountReadSession session,
    StorageScope scope,
  ) => _serial(() => _read(session, scope));

  Future<List<OwnershipJournalEntry>> _read(
    AccountReadSession session,
    StorageScope scope,
  ) async {
    final binding = accountReadScope(session);
    ownershipRequire(binding.userId == scope.userId);
    final String? raw;
    try {
      raw = await storage.read(scope);
    } on Object {
      throw const AccountReadException('JOURNAL_UNAVAILABLE');
    }
    requireAccountReadScope(session, binding);
    if (raw == null) return [];
    try {
      final j = ownershipObject(jsonDecode(raw), {
        'schema',
        'environment',
        'user_id',
        'entries',
      });
      ownershipRequire(
        j['schema'] is int &&
            j['schema'] == 1 &&
            j['environment'] == scope.environment &&
            j['user_id'] == scope.userId &&
            j['entries'] is List,
      );
      final entries = (j['entries'] as List).map((value) {
        final e = ownershipObject(value, {'command', 'phase', 'response_id'});
        final phase = OwnershipCommandPhase.values.firstWhere(
          (p) => p.name == e['phase'],
          orElse: () => throw const FormatException('Invalid journal phase.'),
        );
        final id = ownershipNullableId(e['response_id']);
        ownershipRequire(
          (phase == OwnershipCommandPhase.awaitingCurrent) == (id != null),
        );
        return OwnershipJournalEntry(
          OwnershipCommand.restore(e['command'], session, scope),
          phase: phase,
          responseId: id,
        );
      }).toList();
      ownershipRequire(
        entries.map((e) => e.command.idempotencyKey).toSet().length ==
                entries.length &&
            entries
                    .where((e) => e.phase != OwnershipCommandPhase.reconciled)
                    .map((e) => e.command.targetKey)
                    .toSet()
                    .length ==
                entries
                    .where((e) => e.phase != OwnershipCommandPhase.reconciled)
                    .length,
      );
      return List.unmodifiable(entries);
    } on FormatException {
      throw const AccountReadException('JOURNAL_INVALID');
    } on TypeError {
      throw const AccountReadException('JOURNAL_INVALID');
    }
  }

  Future<void> _write(
    StorageScope scope,
    List<OwnershipJournalEntry> entries,
  ) async {
    try {
      await storage.write(
        scope,
        jsonEncode({
          'schema': 1,
          'environment': scope.environment,
          'user_id': scope.userId,
          'entries': entries.map((e) => e.toJson()).toList(),
        }),
      );
    } on Object {
      throw const AccountReadException('JOURNAL_UNAVAILABLE');
    }
  }

  Future<OwnershipJournalEntry> prepare(
    AccountReadSession session,
    OwnershipCommand command,
  ) => _serial(() async {
    requireAccountReadScope(session, command.sessionScope);
    final entries = await _read(session, command.storageScope);
    requireAccountReadScope(session, command.sessionScope);
    for (final entry in entries) {
      if (entry.command.idempotencyKey == command.idempotencyKey) {
        if (jsonEncode(entry.command.toJson()) !=
            jsonEncode(command.toJson())) {
          throw const AccountReadException('IDEMPOTENCY_CONFLICT');
        }
        return entry;
      }
      if (entry.phase != OwnershipCommandPhase.reconciled &&
          entry.command.targetKey == command.targetKey) {
        throw const AccountReadException('COMMAND_PENDING');
      }
    }
    final entry = OwnershipJournalEntry(command);
    await _write(command.storageScope, [...entries, entry]);
    requireAccountReadScope(session, command.sessionScope);
    return entry;
  });

  Future<void> acknowledge(
    AccountReadSession session,
    OwnershipCommand command,
    String responseId,
  ) => _replace(
    session,
    command,
    OwnershipJournalEntry(
      command,
      phase: OwnershipCommandPhase.awaitingCurrent,
      responseId: verificationUuid(responseId),
    ),
  );

  Future<void> requireReconciliation(
    AccountReadSession session,
    OwnershipCommand command,
  ) => _replace(
    session,
    command,
    OwnershipJournalEntry(
      command,
      phase: OwnershipCommandPhase.reconciliationRequired,
    ),
  );

  /// Explicit reconciliation acknowledgement retains the original payload and
  /// never records a successful ACK or permits this key to be replayed again.
  Future<void> acknowledgeReconciliation(
    AccountReadSession session,
    OwnershipCommand command,
  ) => _serial(() async {
    requireAccountReadScope(session, command.sessionScope);
    final entries = await _read(session, command.storageScope);
    final index = entries.indexWhere(
      (e) => e.command.idempotencyKey == command.idempotencyKey,
    );
    if (index < 0 ||
        entries[index].phase != OwnershipCommandPhase.reconciliationRequired ||
        jsonEncode(entries[index].command.toJson()) !=
            jsonEncode(command.toJson())) {
      throw const AccountReadException('COMMAND_CHANGED');
    }
    requireAccountReadScope(session, command.sessionScope);
    await _write(command.storageScope, [
      ...entries.take(index),
      OwnershipJournalEntry(command, phase: OwnershipCommandPhase.reconciled),
      ...entries.skip(index + 1),
    ]);
    requireAccountReadScope(session, command.sessionScope);
  });

  Future<void> _replace(
    AccountReadSession session,
    OwnershipCommand command,
    OwnershipJournalEntry replacement,
  ) => _serial(() async {
    requireAccountReadScope(session, command.sessionScope);
    final entries = await _read(session, command.storageScope);
    requireAccountReadScope(session, command.sessionScope);
    final index = entries.indexWhere(
      (e) => e.command.idempotencyKey == command.idempotencyKey,
    );
    if (index < 0 ||
        jsonEncode(entries[index].command.toJson()) !=
            jsonEncode(command.toJson())) {
      throw const AccountReadException('COMMAND_CHANGED');
    }
    await _write(command.storageScope, [
      ...entries.take(index),
      replacement,
      ...entries.skip(index + 1),
    ]);
    requireAccountReadScope(session, command.sessionScope);
  });

  /// Only called after this entry's ACK and a successful current GET. Other GETs
  /// and empty lists cannot discharge an unknown original command.
  Future<void> completeCurrent(
    AccountReadSession session,
    OwnershipJournalEntry entry,
  ) => _serial(() async {
    final command = entry.command;
    requireAccountReadScope(session, command.sessionScope);
    final entries = await _read(session, command.storageScope);
    requireAccountReadScope(session, command.sessionScope);
    final current = entries
        .where((e) => e.command.idempotencyKey == command.idempotencyKey)
        .toList();
    if (current.length != 1 ||
        current.single.phase != OwnershipCommandPhase.awaitingCurrent ||
        entry.phase != OwnershipCommandPhase.awaitingCurrent ||
        current.single.responseId != entry.responseId ||
        jsonEncode(current.single.command.toJson()) !=
            jsonEncode(command.toJson())) {
      throw const AccountReadException('COMMAND_CHANGED');
    }
    await _write(
      command.storageScope,
      entries
          .where((e) => e.command.idempotencyKey != command.idempotencyKey)
          .toList(),
    );
    requireAccountReadScope(session, command.sessionScope);
  });
}
