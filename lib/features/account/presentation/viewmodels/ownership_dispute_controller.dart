import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/ownership_command_store.dart';
import '../../data/ownership_dispute_client.dart';
import '../../domain/account_read_session.dart';
import '../../domain/ownership_command.dart';
import '../../domain/ownership_verification_models.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/server_account_verification.dart';
import '../../domain/server_registration_api.dart';
import '../../domain/server_character_lifecycle.dart';

enum OwnershipNotice {
  none,
  defenseRequired,
  processing,
  reviewRequired,
  checkRequired,
}

class OwnershipReadFailure {
  OwnershipReadFailure(Object error, DateTime now) {
    final api = error is AccountReadException ? error : null;
    code = api?.code ?? 'OWNERSHIP_READ_FAILED';
    retryAt =
        api?.retryAt ??
        (api?.retryAfter != null
            ? now.add(api!.retryAfter!)
            : api?.status == 429
            ? now.add(const Duration(seconds: 60))
            : null);
  }
  late final String code;
  late final DateTime? retryAt;
  bool canRetry(DateTime now) => retryAt == null || !now.isBefore(retryAt!);
}

typedef _Read = ({
  int identity,
  int reads,
  AccountReadScope member,
  OwnershipDisputeClient client,
});

/// App-owned V2 state. Automatic work is GET only. Pages choose IDs and perform
/// explicit writes; leaving a page never cancels proof or dispute state.
class OwnershipDisputeController extends ChangeNotifier {
  OwnershipDisputeController({
    required this.api,
    required this.session,
    required this.baseUrl,
    required this.commands,
    this.allowHttp = false,
    this.currentBaseUrl,
    this.onAccountStateChanged,
    DateTime Function()? now,
    Duration Function()? elapsed,
  }) : now = now ?? DateTime.now {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? () => watch.elapsed;
    session.addListener(_sessionChanged);
    _synchronize();
  }
  final BackendRegistrationApi api;
  final AccountReadSession session;
  final String baseUrl;
  final bool allowHttp;
  final String Function()? currentBaseUrl;
  final OwnershipCommandStore commands;
  final Future<void> Function(AccountReadScope)? onAccountStateChanged;
  final DateTime Function() now;
  late final Duration Function() _elapsed;
  StorageScope? _scope;
  StorageScope? get scope => _scope;
  OwnershipDisputeClient? _client;
  (String?, int, bool, String)? _identity;
  int _identityEpoch = 0, _readEpoch = 0, _stateVersion = 0;
  bool _initialized = false, _disposed = false, _busy = false;
  bool get commandBusy => _busy;
  bool proofsCurrent = false, disputesCurrent = false, journalLoaded = false;
  OwnershipReadFailure? proofsFailure,
      disputesFailure,
      journalFailure,
      commandFailure,
      accountSyncFailure;
  final Map<String, OwnershipVerification> _proofs = {};
  final Map<String, OwnershipDispute> _disputes = {};
  Set<String> _activeProofIds = {}, _activeDisputeIds = {};
  final Set<String> _currentProofIds = {}, _currentDisputeIds = {};
  final Map<String, OwnershipReadFailure> _proofFailures = {},
      _disputeFailures = {};
  final Map<String, (DateTime, Duration)> _observedAt = {};
  List<OwnershipJournalEntry> _journal = const [];
  List<OwnershipJournalEntry> get pendingCommands => List.unmodifiable(
    _journal.where((e) => e.phase != OwnershipCommandPhase.reconciled),
  );
  String? _selectedProof, _selectedDispute;
  String? get selectedProofId => _selectedProof;
  String? get selectedDisputeId => _selectedDispute;
  OwnershipVerification? get selectedProof => _proofs[_selectedProof];
  OwnershipDispute? get selectedDispute => _disputes[_selectedDispute];
  List<OwnershipVerification> get activeProofs => List.unmodifiable(
    _activeProofIds
        .map((id) => _proofs[id]!)
        .whereType<OwnershipVerification>(),
  );
  List<OwnershipDispute> get activeDisputes => List.unmodifiable(
    _activeDisputeIds.map((id) => _disputes[id]!).whereType<OwnershipDispute>(),
  );
  OwnershipReadFailure? proofFailure(String id) => _proofFailures[id];
  OwnershipReadFailure? disputeFailure(String id) => _disputeFailures[id];
  bool proofIsCurrent(String id) =>
      !_busy &&
      _currentProofIds.contains(id) &&
      !_proofFailures.containsKey(id);
  bool disputeIsCurrent(String id) =>
      !_busy &&
      _currentDisputeIds.contains(id) &&
      !_disputeFailures.containsKey(id);
  Future<void>? _proofFlight, _disputeFlight, _journalFlight, _syncFlight;
  final Map<String, Future<void>> _proofDetails = {}, _disputeDetails = {};
  bool get loading =>
      _proofFlight != null || _disputeFlight != null || _journalFlight != null;
  Timer? _timer;
  final Set<String> _checkedDeadlines = {},
      _appliedEffects = {},
      _pendingEffects = {};
  final Map<String, int> _reviewed = {};

  String _environment() => currentBaseUrl?.call() ?? baseUrl;
  bool get signedIn =>
      !_disposed && session.isAuthenticated && _scope?.userId == session.userId;
  void initialize() {
    if (_initialized || _disposed) return;
    _initialized = true;
    unawaited(refresh());
  }

  void _sessionChanged() {
    if (_synchronize() && _initialized && signedIn) unawaited(refresh());
  }

  bool _synchronize() {
    if (_disposed) return false;
    final identity = (
      session.userId,
      session.generation,
      session.isAuthenticated,
      _environment(),
    );
    if (identity == _identity) return false;
    _identity = identity;
    _identityEpoch++;
    _invalidateReads();
    _scope = null;
    _client = null;
    _proofs.clear();
    _disputes.clear();
    _activeProofIds = {};
    _activeDisputeIds = {};
    _proofFailures.clear();
    _disputeFailures.clear();
    _observedAt.clear();
    _journal = const [];
    _selectedProof = null;
    _selectedDispute = null;
    proofsCurrent = false;
    disputesCurrent = false;
    journalLoaded = false;
    proofsFailure = null;
    disputesFailure = null;
    journalFailure = null;
    commandFailure = null;
    accountSyncFailure = null;
    _busy = false;
    _syncFlight = null;
    _checkedDeadlines.clear();
    _appliedEffects.clear();
    _pendingEffects.clear();
    _reviewed.clear();
    if (session.isAuthenticated && session.userId != null) {
      try {
        final storage = _scope = StorageScope(
          baseUrl: _environment(),
          userId: session.userId!,
          allowHttp: allowHttp,
        );
        final generation = _identityEpoch;
        _client = OwnershipDisputeClient(
          api,
          session,
          storage,
          commands,
          now: now,
          environmentIsCurrent: () =>
              !_disposed &&
              generation == _identityEpoch &&
              _environment() == identity.$4,
        );
      } on ScopedCacheException catch (e) {
        journalFailure = OwnershipReadFailure(
          AccountReadException(e.code),
          now(),
        );
      }
    }
    _emit();
    return true;
  }

  void _invalidateReads() {
    _readEpoch++;
    _stateVersion++;
    proofsCurrent = false;
    disputesCurrent = false;
    _timer?.cancel();
    _timer = null;
    _currentProofIds.clear();
    _currentDisputeIds.clear();
    _proofFlight = null;
    _disputeFlight = null;
    _journalFlight = null;
    _proofDetails.clear();
    _disputeDetails.clear();
    _reviewed.clear();
  }

  _Read _read() {
    _synchronize();
    if (!signedIn || _client == null) {
      throw const AccountReadException('LOGIN_REQUIRED');
    }
    return (
      identity: _identityEpoch,
      reads: _readEpoch,
      member: accountReadScope(session),
      client: _client!,
    );
  }

  bool _current(_Read r) =>
      !_disposed &&
      r.identity == _identityEpoch &&
      r.reads == _readEpoch &&
      session.isAuthenticated &&
      session.userId == r.member.userId &&
      session.generation == r.member.generation &&
      _environment() == _identity?.$4;
  void _guard(_Read r) {
    if (!_current(r)) throw const AccountReadException('STALE_READ');
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _retry(OwnershipReadFailure? failure) =>
      failure?.canRetry(now()) != false;

  Future<void> resume() => refresh();
  Future<LifecycleCharacterPage> defenseCharacters(
    String registrationId,
    String? cursor,
  ) async {
    final r = _read();
    final json = await api.request(
      '/v2/me/game-accounts/$registrationId/characters',
      query: {'limit': 50, 'cursor': ?cursor},
    );
    _guard(r);
    try {
      return LifecycleCharacterPage.fromJson(json!);
    } on Object {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<OwnershipPreview> preview(String name) async {
    final r = _read();
    final value = await r.client.preview(name);
    _guard(r);
    return value;
  }

  Duration defenseRemaining(String id) {
    final value = _disputes[id];
    if (value?.defenseAvailableUntil == null) return Duration.zero;
    final left = value!.defenseAvailableUntil!.difference(
      _serverNow('d:$id', value.serverNow),
    );
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> refresh() => _refresh();
  Future<void> _refresh({bool synchronizeAccount = true}) async {
    _synchronize();
    if (!signedIn || _client == null || _busy) return;
    await Future.wait([
      _refreshProofs(),
      _refreshDisputes(),
      _refreshJournal(),
    ]);
    if (!signedIn || _disposed) return;
    if (synchronizeAccount) await retryAccountSync();
    _armDeadline();
  }

  Future<List<T>> _pages<T>(
    _Read r,
    Future<OwnershipPage<T>> Function(String?) fetch,
    String Function(T) id,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final items = <T>[], ids = <String>{}, cursors = <String>{};
      String? cursor;
      int? revision;
      try {
        do {
          final page = await fetch(cursor);
          _guard(r);
          if (revision != null && revision != page.feedRevision) {
            throw const AccountReadException('CURSOR_STALE');
          }
          revision = page.feedRevision;
          for (final item in page.items) {
            if (!ids.add(id(item))) {
              throw const AccountReadException('INVALID_RESPONSE');
            }
            items.add(item);
          }
          cursor = page.nextCursor;
          if (cursor != null && !cursors.add(cursor)) {
            throw const AccountReadException('INVALID_RESPONSE');
          }
        } while (cursor != null);
        return items;
      } on AccountReadException catch (e) {
        _guard(r);
        if (e.code != 'CURSOR_STALE' || attempt == 1) rethrow;
      }
    }
    throw const AccountReadException('CURSOR_STALE');
  }

  Future<void> _refreshProofs() {
    if (_proofFlight case final flight?) return flight;
    if (!_retry(proofsFailure)) return Future.value();
    final r = _read();
    final previous = {..._activeProofIds};
    proofsCurrent = false;
    _currentProofIds.clear();
    late final Future<void> flight;
    flight = Future<void>(() async {
      try {
        final items = await _pages(
          r,
          (c) => r.client.proofs(limit: 100, cursor: c),
          (v) => v.id,
        );
        _guard(r);
        final nextIds = items.map((v) => v.id).toSet();
        _activeProofIds = previous.union(nextIds);
        for (final item in items) {
          _acceptProof(item, current: false);
        }
        proofsCurrent = true;
        proofsFailure = null;
        _stateVersion++;
        if (_selectedProof == null && items.length == 1) {
          _selectedProof = items.single.id;
        }
        _emit();
        final ids = {...previous.difference(nextIds), ?_selectedProof};
        for (final id in ids) {
          _guard(r);
          await _loadProof(id, r);
        }
      } on Object catch (e) {
        if (_current(r)) {
          proofsFailure = OwnershipReadFailure(e, now());
          proofsCurrent = false;
        }
      } finally {
        if (identical(_proofFlight, flight)) _proofFlight = null;
        if (_current(r)) {
          _emit();
          _armDeadline();
        }
      }
    });
    _proofFlight = flight;
    _emit();
    return flight;
  }

  Future<void> _refreshDisputes() {
    if (_disputeFlight case final flight?) return flight;
    if (!_retry(disputesFailure)) return Future.value();
    final r = _read();
    final previous = {..._activeDisputeIds};
    disputesCurrent = false;
    _currentDisputeIds.clear();
    late final Future<void> flight;
    flight = Future<void>(() async {
      try {
        final items = await _pages(
          r,
          (c) => r.client.disputes(limit: 100, cursor: c),
          (v) => v.id,
        );
        _guard(r);
        final nextIds = items.map((v) => v.id).toSet();
        _activeDisputeIds = previous.union(nextIds);
        for (final item in items) {
          _acceptDispute(item, current: false);
        }
        disputesCurrent = true;
        disputesFailure = null;
        _stateVersion++;
        if (_selectedDispute == null && items.length == 1) {
          _selectedDispute = items.single.id;
        }
        _emit();
        final ids = {...previous.difference(nextIds), ?_selectedDispute};
        for (final id in ids) {
          _guard(r);
          await _loadDispute(id, r);
        }
      } on Object catch (e) {
        if (_current(r)) {
          disputesFailure = OwnershipReadFailure(e, now());
          disputesCurrent = false;
        }
      } finally {
        if (identical(_disputeFlight, flight)) _disputeFlight = null;
        if (_current(r)) {
          _emit();
          _armDeadline();
        }
      }
    });
    _disputeFlight = flight;
    _emit();
    return flight;
  }

  Future<void> _refreshJournal() {
    if (_journalFlight case final flight?) return flight;
    if (!_retry(journalFailure)) return Future.value();
    final r = _read();
    late final Future<void> flight;
    flight = Future<void>(() async {
      try {
        final initial = await commands.load(session, r.client.scope);
        _guard(r);
        _journal = initial;
        journalLoaded = true;
        journalFailure = null;
        for (final entry in _journal) {
          if (entry.phase != OwnershipCommandPhase.awaitingCurrent ||
              !_retry(commandFailure)) {
            continue;
          }
          try {
            final current = await r.client.loadCurrentFor(entry);
            _guard(r);
            _acceptCurrent(current);
          } on Object catch (e) {
            _guard(r);
            commandFailure = OwnershipReadFailure(e, now());
          }
        }
        final entries = await commands.load(session, r.client.scope);
        _guard(r);
        _journal = entries;
      } on Object catch (e) {
        if (_current(r)) {
          journalFailure = OwnershipReadFailure(e, now());
          journalLoaded = false;
        }
      } finally {
        if (identical(_journalFlight, flight)) _journalFlight = null;
        if (_current(r)) _emit();
      }
    });
    _journalFlight = flight;
    _emit();
    return flight;
  }

  Future<void> selectProof(String id) async {
    final r = _read();
    _selectedProof = verificationUuid(id);
    _emit();
    await _loadProof(_selectedProof!, r);
    if (_current(r)) await retryAccountSync();
  }

  Future<void> selectDispute(String id) async {
    final r = _read();
    _selectedDispute = verificationUuid(id);
    _emit();
    await _loadDispute(_selectedDispute!, r);
    if (_current(r)) await retryAccountSync();
  }

  Future<void> _loadProof(String id, _Read r) {
    if (_proofDetails[id] case final pending?) return pending;
    if (!_retry(_proofFailures[id])) return Future.value();
    late final Future<void> flight;
    flight = Future<void>(() async {
      _currentProofIds.remove(id);
      try {
        final value = await r.client.proof(id);
        _guard(r);
        _proofFailures.remove(id);
        _acceptProof(value, current: true);
      } on Object catch (e) {
        if (_current(r)) _proofFailures[id] = OwnershipReadFailure(e, now());
      } finally {
        if (identical(_proofDetails[id], flight)) _proofDetails.remove(id);
        if (_current(r)) {
          _emit();
          _armDeadline();
        }
      }
    });
    _proofDetails[id] = flight;
    return flight;
  }

  Future<void> _loadDispute(String id, _Read r) {
    if (_disputeDetails[id] case final pending?) return pending;
    if (!_retry(_disputeFailures[id])) return Future.value();
    late final Future<void> flight;
    flight = Future<void>(() async {
      _currentDisputeIds.remove(id);
      try {
        final value = await r.client.dispute(id);
        _guard(r);
        _disputeFailures.remove(id);
        _acceptDispute(value, current: true);
        for (final proofId in value.myActiveVerificationIds) {
          _guard(r);
          await _loadProof(proofId, r);
        }
      } on Object catch (e) {
        if (_current(r)) _disputeFailures[id] = OwnershipReadFailure(e, now());
      } finally {
        if (identical(_disputeDetails[id], flight)) _disputeDetails.remove(id);
        if (_current(r)) {
          _emit();
          _armDeadline();
        }
      }
    });
    _disputeDetails[id] = flight;
    return flight;
  }

  bool _newer(int version, DateTime time, int? oldVersion, DateTime? oldTime) =>
      oldVersion == null ||
      version > oldVersion ||
      (version == oldVersion && !time.isBefore(oldTime!));
  void _acceptProof(OwnershipVerification v, {required bool current}) {
    final old = _proofs[v.id];
    if (!_newer(v.version, v.serverNow, old?.version, old?.serverNow)) return;
    _proofs[v.id] = v;
    _observedAt['p:${v.id}'] = (v.serverNow, _elapsed());
    _stateVersion++;
    if (current) {
      _currentProofIds.add(v.id);
      if (v.equipmentStatus != 'pending') {
        _activeProofIds.remove(v.id);
      } else {
        _activeProofIds.add(v.id);
      }
      if ({'verified', 'defended'}.contains(v.outcome)) {
        _pendingEffects.add('p:${v.id}:${v.version}:${v.outcome}');
      }
    }
  }

  void _acceptDispute(OwnershipDispute v, {required bool current}) {
    final old = _disputes[v.id];
    if (!_newer(v.version, v.serverNow, old?.version, old?.serverNow)) return;
    _disputes[v.id] = v;
    _observedAt['d:${v.id}'] = (v.serverNow, _elapsed());
    _stateVersion++;
    if (current) {
      _currentDisputeIds.add(v.id);
      if (!{'defending', 'review_required'}.contains(v.state)) {
        _activeDisputeIds.remove(v.id);
      }
      if ({'transferred', 'defended'}.contains(v.state) ||
          v.reasonCode == 'OWNER_CHANGED') {
        _pendingEffects.add(
          'd:${v.id}:${v.version}:${v.state}:${v.reasonCode}',
        );
      }
    }
  }

  void _acceptCurrent(OwnershipAcknowledgement value) {
    if (value.proof case final proof?) {
      _acceptProof(proof, current: true);
      // This result follows an explicit page command, including recovery.
      _selectedProof = proof.id;
    }
    if (value.dispute case final dispute?) {
      _acceptDispute(dispute, current: true);
      _selectedDispute = dispute.id;
    }
    _emit();
  }

  Future<void> retryAccountSync() {
    if (_syncFlight case final flight?) return flight;
    final pending = _pendingEffects.difference(_appliedEffects);
    if (pending.isEmpty || !signedIn || !_retry(accountSyncFailure)) {
      return Future.value();
    }
    final r = _read();
    late final Future<void> flight;
    flight = Future<void>(() async {
      try {
        await onAccountStateChanged?.call(r.member);
        _guard(r);
        _appliedEffects.addAll(pending);
        _pendingEffects.removeAll(pending);
        accountSyncFailure = null;
      } on Object catch (e) {
        if (_current(r)) accountSyncFailure = OwnershipReadFailure(e, now());
      } finally {
        if (identical(_syncFlight, flight)) _syncFlight = null;
        if (_current(r)) _emit();
      }
    });
    _syncFlight = flight;
    return flight;
  }

  Future<void> execute(OwnershipCommand command) async {
    final r = _read();
    if (_busy || _syncFlight != null) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    if (!journalLoaded || journalFailure != null) {
      throw const AccountReadException('JOURNAL_NOT_READY');
    }
    if (!_retry(commandFailure)) {
      throw const AccountReadException('RETRY_LATER');
    }
    if (command.operation == OwnershipOperation.startClaim) {
      if (!proofsCurrent ||
          !disputesCurrent ||
          pendingCommands.any(
            (e) =>
                e.command.operation == OwnershipOperation.startClaim ||
                e.command.operation == OwnershipOperation.startDefense,
          )) {
        throw const AccountReadException('CURRENT_READ_REQUIRED');
      }
    } else {
      final proof = _proofs[command.targetId],
          dispute = _disputes[command.targetId];
      final action = switch (command.operation) {
        OwnershipOperation.confirm => 'confirm',
        OwnershipOperation.cancelProof => 'cancel',
        OwnershipOperation.startDefense => 'start_defense',
        OwnershipOperation.cancelDispute => 'cancel_dispute',
        OwnershipOperation.settle => 'request_settlement',
        _ => '',
      };
      final proofCommand =
          command.operation == OwnershipOperation.confirm ||
          command.operation == OwnershipOperation.cancelProof;
      if (proofCommand
          ? proof == null ||
                !proofIsCurrent(proof.id) ||
                proofRemaining(proof.id) == Duration.zero ||
                !proof.allowedActions.contains(action) ||
                command.body['expected_version'] != proof.version
          : dispute == null ||
                !disputeIsCurrent(dispute.id) ||
                !dispute.allowedActions.contains(action) ||
                (command.body['expected_version'] ??
                        command.body['expected_dispute_version']) !=
                    dispute.version) {
        throw const AccountReadException('CURRENT_READ_REQUIRED');
      }
      if (!proofCommand && dispute != null) {
        final time = _serverNow('d:${dispute.id}', dispute.serverNow);
        if ((action == 'start_defense' &&
                (dispute.defenseAvailableUntil == null ||
                    !dispute.defenseAvailableUntil!.isAfter(time))) ||
            (action == 'cancel_dispute' &&
                dispute.state != 'review_required' &&
                !time.isBefore(dispute.defenseDeadline))) {
          throw const AccountReadException('CURRENT_READ_REQUIRED');
        }
      }
    }
    _guard(r);
    await _perform(command);
  }

  Future<void> recoverCommand(String key) async {
    _read();
    final entry = pendingCommands
        .where((e) => e.command.idempotencyKey == key)
        .firstOrNull;
    if (entry == null) throw const AccountReadException('COMMAND_NOT_FOUND');
    if (_busy || _syncFlight != null) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    if (!_retry(commandFailure)) {
      throw const AccountReadException('RETRY_LATER');
    }
    await _perform(entry.command, entry: entry);
  }

  Future<void> _perform(
    OwnershipCommand command, {
    OwnershipJournalEntry? entry,
  }) async {
    _invalidateReads();
    _busy = true;
    commandFailure = null;
    final r = _read();
    var succeeded = false;
    _emit();
    try {
      if (entry?.phase != OwnershipCommandPhase.awaitingCurrent) {
        await r.client.execute(command);
        _guard(r);
      }
      final entries = await commands.load(session, r.client.scope);
      _guard(r);
      _journal = entries;
      final saved = entries.singleWhere(
        (e) => e.command.idempotencyKey == command.idempotencyKey,
      );
      final current = await r.client.loadCurrentFor(saved);
      _guard(r);
      _acceptCurrent(current);
      final remaining = await commands.load(session, r.client.scope);
      _guard(r);
      _journal = remaining;
      await retryAccountSync();
      succeeded = true;
    } on Object catch (e) {
      if (_current(r)) {
        commandFailure = OwnershipReadFailure(e, now());
        try {
          final entries = await commands.load(session, r.client.scope);
          _guard(r);
          _journal = entries;
        } on Object {
          if (_current(r)) journalLoaded = false;
        }
      }
      rethrow;
    } finally {
      if (_current(r)) {
        _busy = false;
        _emit();
        if (succeeded) unawaited(_refresh(synchronizeAccount: false));
      }
    }
  }

  Future<
    ({List<OwnershipVerification> proofs, List<OwnershipDispute> disputes})
  >
  history() async {
    final r = _read();
    final proofs = await _pages<OwnershipVerification>(
      r,
      (c) => r.client.proofs(view: 'all', limit: 100, cursor: c),
      (v) => v.id,
    );
    final disputes = await _pages<OwnershipDispute>(
      r,
      (c) => r.client.disputes(view: 'all', limit: 100, cursor: c),
      (v) => v.id,
    );
    _guard(r);
    return (
      proofs: List<OwnershipVerification>.unmodifiable(proofs),
      disputes: List<OwnershipDispute>.unmodifiable(disputes),
    );
  }

  Future<
    ({List<OwnershipVerification> proofs, List<OwnershipDispute> disputes})
  >
  reviewReconciliation(String key) async {
    final r = _read();
    final entry = pendingCommands
        .where((e) => e.command.idempotencyKey == key)
        .firstOrNull;
    if (entry == null) throw const AccountReadException('COMMAND_NOT_FOUND');
    if (_busy ||
        entry.phase == OwnershipCommandPhase.awaitingCurrent ||
        (entry.phase != OwnershipCommandPhase.reconciliationRequired &&
            entry.command.replayableAt(now()))) {
      throw const AccountReadException('ACK_REQUIRED');
    }
    final currentHistory = await history();
    _guard(r);
    if (entry.command.targetId case final id?) {
      if (entry.command.operation == OwnershipOperation.confirm ||
          entry.command.operation == OwnershipOperation.cancelProof) {
        final current = await r.client.proof(id);
        _guard(r);
        _acceptProof(current, current: true);
      } else {
        final current = await r.client.dispute(id);
        _guard(r);
        _acceptDispute(current, current: true);
      }
    }
    await commands.requireReconciliation(session, entry.command);
    _guard(r);
    final entries = await commands.load(session, r.client.scope);
    _guard(r);
    _journal = entries;
    _reviewed[key] = _stateVersion;
    _emit();
    return currentHistory;
  }

  Future<void> acknowledgeReconciliation(String key) async {
    final before = _read();
    final entry = pendingCommands
        .where((e) => e.command.idempotencyKey == key)
        .firstOrNull;
    if (_busy || entry == null || _reviewed[key] != _stateVersion) {
      throw const AccountReadException('RECONCILIATION_REVIEW_REQUIRED');
    }
    _guard(before);
    _invalidateReads();
    _busy = true;
    final r = _read();
    try {
      await commands.acknowledgeReconciliation(session, entry.command);
      _guard(r);
      final entries = await commands.load(session, r.client.scope);
      _guard(r);
      _journal = entries;
    } finally {
      if (_current(r)) {
        _busy = false;
        _emit();
      }
    }
  }

  DateTime _serverNow(String key, DateTime fallback) {
    final observed = _observedAt[key];
    return observed == null
        ? fallback
        : observed.$1.add(_elapsed() - observed.$2);
  }

  Duration proofRemaining(String id) {
    final v = _proofs[id];
    if (v == null) return Duration.zero;
    final left = v.equipmentExpiresAt.difference(
      _serverNow('p:$id', v.serverNow),
    );
    return left.isNegative ? Duration.zero : left;
  }

  OwnershipNotice get notice {
    final owners = activeDisputes
        .where((v) => v.viewerRole == 'owner')
        .toList();
    if (owners.isEmpty) return OwnershipNotice.none;
    if (!disputesCurrent ||
        disputesFailure != null ||
        owners.any(
          (v) =>
              _disputeFailures.containsKey(v.id) ||
              v.myActiveVerificationIds.any(_proofFailures.containsKey),
        )) {
      return OwnershipNotice.checkRequired;
    }
    if (owners.any(
      (v) =>
          (v.allowedActions.contains('start_defense') &&
              v.defenseAvailableUntil != null &&
              v.defenseAvailableUntil!.isAfter(
                _serverNow('d:${v.id}', v.serverNow),
              )) ||
          v.myActiveVerificationIds.any(
            (id) =>
                proofIsCurrent(id) &&
                _proofs[id]?.purpose == 'defense' &&
                _proofs[id]?.equipmentStatus == 'pending' &&
                proofRemaining(id) > Duration.zero,
          ),
    )) {
      return OwnershipNotice.defenseRequired;
    }
    if (owners.any((v) => v.state == 'review_required')) {
      return OwnershipNotice.reviewRequired;
    }
    return OwnershipNotice.processing;
  }

  void _armDeadline() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !signedIn || _busy) return;
    final candidates = <(String, Duration)>[];
    void add(String key, DateTime? deadline, DateTime serverNow) {
      if (deadline == null || _checkedDeadlines.contains(key)) return;
      final remaining = deadline.difference(serverNow);
      // A past deadline already represented in the current GET isn't a new
      // trigger. The worker may still be due; never turn this into polling.
      if (remaining > Duration.zero) candidates.add((key, remaining));
    }

    for (final id in _activeProofIds) {
      final v = _proofs[id]!;
      add(
        'p:$id:${v.version}:${v.equipmentExpiresAt}',
        v.equipmentExpiresAt,
        _serverNow('p:$id', v.serverNow),
      );
    }
    for (final id in _activeDisputeIds) {
      final v = _disputes[id]!,
          time = _serverNow('d:$id', _disputes[id]!.serverNow);
      for (final end in [
        v.defenseDeadline,
        v.defenseAvailableUntil,
        v.nextRetryAt,
      ]) {
        add('d:$id:${v.version}:$end', end, time);
      }
    }
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final r = _read(), first = candidates.first;
    _timer = Timer(first.$2, () {
      if (!_current(r)) return;
      _checkedDeadlines.add(first.$1);
      unawaited(refresh());
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _identityEpoch++;
    _timer?.cancel();
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
