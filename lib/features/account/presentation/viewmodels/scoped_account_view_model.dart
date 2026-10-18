import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/scoped_character_cache_repository.dart';
import '../../data/scoped_account_runtime.dart';
import '../../data/server_character_lifecycle_client.dart';
import '../../domain/account_read_session.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_character_lifecycle.dart';

enum ScopedReadFailureKind { network, storage, configuration, conflict }

enum ScopedRosterCoverage { metadataOnly, canonical, preview }

class ScopedReadFailure {
  ScopedReadFailure(Object error, DateTime receivedAt) {
    final api = error is AccountReadException ? error : null;
    if (kDebugMode) {
      debugPrint(
        'Roster read failed: code=${api?.code ?? error.runtimeType}, status=${api?.status}',
      );
    }
    code =
        api?.code ??
        (error is ScopedCacheException ? error.code : 'CACHE_UNAVAILABLE');
    status = api?.status;
    requestId = api?.requestId;
    deadline =
        api?.retryAt ??
        (api?.retryAfter == null ? null : receivedAt.add(api!.retryAfter!));
    kind = switch (code) {
      'CACHE_UNAVAILABLE' => ScopedReadFailureKind.storage,
      'INVALID_ENVIRONMENT' ||
      'ENVIRONMENT_CHANGED' ||
      'SCOPE_MISMATCH' ||
      'CONTRACT_MISMATCH' => ScopedReadFailureKind.configuration,
      'CURSOR_STALE' ||
      'REVISION_CONFLICT' ||
      'CACHE_CONFLICT' ||
      'STALE_READ' ||
      'SNAPSHOT_MISMATCH' ||
      'REVISION_REGRESSION' ||
      'REGISTRATION_NOT_CURRENT' ||
      'REGISTRATION_NOT_FOUND' ||
      'IDENTITY_CONFLICT' => ScopedReadFailureKind.conflict,
      _ => ScopedReadFailureKind.network,
    };
  }
  late final String code;
  late final int? status;
  late final String? requestId;
  late final DateTime? deadline;
  late final ScopedReadFailureKind kind;
  int secondsLeft(DateTime now) => deadline == null
      ? 0
      : ((deadline!.difference(now).inMilliseconds / 1000).ceil()).clamp(
          0,
          86400,
        );
}

class ScopedRosterReadState {
  const ScopedRosterReadState({
    this.observation,
    this.loading = false,
    this.current = false,
    this.failure,
  });
  final CachedRosterView? observation;
  final bool loading;

  /// Current read observation only, never permission to submit a command.
  final bool current;
  final ScopedReadFailure? failure;
  ScopedRosterCoverage get coverage {
    final view = observation;
    if (view == null) return ScopedRosterCoverage.metadataOnly;
    final display =
        view.registration.toStorage()['display'] as Map<String, dynamic>;
    if (view.registration.ownershipStatus != 'owned' &&
        (current || display['preview'] is List)) {
      return ScopedRosterCoverage.preview;
    }
    return view.complete
        ? ScopedRosterCoverage.canonical
        : ScopedRosterCoverage.metadataOnly;
  }
}

class ScopedHistoryReadState {
  ScopedHistoryReadState({
    Iterable<CharacterRetirement> items = const [],
    this.open = false,
    this.loading = false,
    this.loaded = false,
    this.current = false,
    this.hasMore = false,
    this.needsRestart = false,
    this.revision,
    this.failure,
  }) : items = List.unmodifiable(items);
  final List<CharacterRetirement> items;
  final bool open, loading, loaded, current, hasMore, needsRestart;
  final int? revision;
  final ScopedReadFailure? failure;
}

/// Opt-in app-lifetime state. Pages dispose history/selection, the app owns the
/// runtime/DB. No widget, local writer, key lookup, or provider call is involved.
class ScopedAccountViewModel extends ChangeNotifier {
  ScopedAccountViewModel(this.runtime, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    _sessionKey = (
      runtime.session.userId,
      runtime.session.generation,
      runtime.session.isAuthenticated,
    );
    runtime.session.addListener(_onSession);
  }
  final ScopedAccountRuntime runtime;
  final DateTime Function() now;
  bool _disposed = false, _activated = false, _attempted = false;
  int _epoch = 0, _metadataEpoch = 0, _historyEpoch = 0;
  late (String?, int, bool) _sessionKey;
  Future<void> _tail = Future.value();
  Future<void>? _metadataFlight, _historyFlight;
  final Map<String, Future<void>> _rosterFlights = {};
  final Map<String, ScopedRosterReadState> _rosters = {};
  String? _selected;
  Timer? _timer;
  RetirementContinuation? _continuation;
  bool _requiresMetadata = false;
  bool _commandInProgress = false;
  List<CacheRegistrationSnapshot> _registrations = const [];
  List<ServerAccountRegistration> _metadata = const [];
  bool _registrationsCurrent = false, _hydrated = false, _loading = false;
  ScopedReadFailure? _failure;
  ScopedHistoryReadState _history = ScopedHistoryReadState();

  bool get canRead => !_disposed && runtime.canRead;
  bool get loading => _loading || _commandInProgress;
  bool get commandInProgress => _commandInProgress;
  bool get hydrated => _hydrated;
  bool get registrationsCurrent => _registrationsCurrent;
  bool get needsMetadata => _requiresMetadata;
  List<CacheRegistrationSnapshot> get registrations => _registrations;
  List<ServerAccountRegistration> get metadata => _metadata;
  ScopedReadFailure? get failure => _failure;
  ScopedHistoryReadState get history => _history;
  ScopedRosterReadState roster(String id) =>
      _rosters[id] ?? const ScopedRosterReadState();
  int get retrySeconds => _failure?.secondsLeft(now()) ?? 0;
  int get historyRetrySeconds => _history.failure?.secondsLeft(now()) ?? 0;
  int rosterRetrySeconds(String id) =>
      _rosters[id]?.failure?.secondsLeft(now()) ?? 0;

  void _onSession() {
    final s = runtime.session;
    final key = (s.userId, s.generation, s.isAuthenticated);
    if (_sessionKey == key) return;
    _sessionKey = key;
    _epoch++;
    _metadataEpoch++;
    _historyEpoch++;
    runtime.invalidateReads();
    _registrations = const [];
    _metadata = const [];
    _rosters.clear();
    _registrationsCurrent = false;
    _hydrated = false;
    _loading = false;
    _commandInProgress = false;
    _failure = null;
    _selected = null;
    _attempted = false;
    _requiresMetadata = false;
    _metadataFlight = null;
    _historyFlight = null;
    _rosterFlights.clear();
    _continuation = null;
    _history = ScopedHistoryReadState();
    _timer?.cancel();
    _timer = null;
    _tail = Future.value();
    _emit();
    if (_activated && canRead) unawaited(initialize());
  }

  bool _valid(int epoch, [int? metadataEpoch]) =>
      canRead &&
      _epoch == epoch &&
      (metadataEpoch == null || _metadataEpoch == metadataEpoch);
  void _guard(int epoch, [int? metadataEpoch]) {
    if (!_valid(epoch, metadataEpoch)) {
      throw const AccountReadException('STALE_READ');
    }
  }

  Future<void> _queue(int epoch, Future<void> Function() action) {
    final future = _tail.then((_) async {
      if (_valid(epoch)) await action();
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  CachedRosterView? _stale(CachedRosterView? view) => view == null
      ? null
      : CachedRosterView(
          view.registration,
          view.characters,
          validated: false,
          complete: view.complete,
        );

  void _emit({bool notify = true}) {
    if (_disposed) return;
    if (notify) notifyListeners();
    if (_disposed) return;
    final waiting = [
      ?_failure,
      ?_history.failure,
      ..._rosters.values.map((s) => s.failure).whereType<ScopedReadFailure>(),
    ].any((f) => f.secondsLeft(now()) > 0);
    if (waiting && _timer == null && canRead) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    } else if (!waiting || !canRead) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> initialize() {
    _activated = true;
    if (!canRead || _commandInProgress) return Future.value();
    if (_metadataFlight case final running?) return running;
    if (_attempted) return Future.value();
    _attempted = true;
    return refreshRegistrations(initial: true);
  }

  /// Call synchronously on command start. Disk rows survive, receipts do not.
  /// After command success/uncertain completion, explicitly refresh metadata.
  void invalidate({bool notify = true}) {
    if (_disposed) return;
    _metadataEpoch++;
    runtime.invalidateReads();
    _registrationsCurrent = false;
    _requiresMetadata = true;
    _loading = false;
    _metadataFlight = null;
    _rosterFlights.clear();
    for (final entry in _rosters.entries.toList()) {
      _rosters[entry.key] = ScopedRosterReadState(
        observation: _stale(entry.value.observation),
      );
    }
    if (notify) _emit();
  }

  void beginCommand() {
    if (!canRead) return;
    _commandInProgress = true;
    invalidate();
  }

  Future<void> finishCommand() {
    if (!canRead) return Future.value();
    _commandInProgress = false;
    return refreshRegistrations();
  }

  Future<void> refreshRegistrations({bool initial = false}) {
    _activated = true;
    if (!canRead || _commandInProgress || retrySeconds > 0) {
      return Future.value();
    }
    if (_metadataFlight case final running?) return running;
    invalidate(notify: false);
    final epoch = _epoch, metadataEpoch = _metadataEpoch;
    _attempted = true;
    _loading = true;
    _failure = null;
    late final Future<void> flight;
    flight =
        _queue(epoch, () async {
          if (!_valid(epoch, metadataEpoch)) return;
          try {
            if (!_hydrated) {
              final rows = await runtime.readRegistrations(
                guard: () => _guard(epoch, metadataEpoch),
              );
              _guard(epoch, metadataEpoch);
              _registrations = rows;
              _hydrated = true;
              _emit();
            }
            final result = await runtime.refreshRegistrations(
              shareInFlight: initial,
              guard: () => _guard(epoch, metadataEpoch),
            );
            _guard(epoch, metadataEpoch);
            _registrations = result.cached;
            _metadata = result.metadata;
            _registrationsCurrent = true;
            _requiresMetadata = false;
            // Old registration observations are retained only on disk.
            final present = _registrations.map((r) => r.registrationId).toSet();
            for (final id in _rosters.keys.toList()) {
              if (!present.contains(id)) {
                _rosters[id] = ScopedRosterReadState(
                  failure: ScopedReadFailure(
                    const AccountReadException('REGISTRATION_NOT_FOUND'),
                    now(),
                  ),
                );
              }
            }
          } catch (error) {
            if (_valid(epoch, metadataEpoch)) {
              _failure = ScopedReadFailure(error, now());
            }
          } finally {
            if (_valid(epoch, metadataEpoch)) {
              _loading = false;
              _emit();
            }
          }
        }).whenComplete(() {
          if (identical(_metadataFlight, flight)) _metadataFlight = null;
          final selected = _selected;
          if (_valid(epoch, metadataEpoch) &&
              _registrationsCurrent &&
              selected != null) {
            unawaited(_startRoster(runtime.reference(selected)));
          }
        });
    _metadataFlight = flight;
    _emit();
    return flight;
  }

  Future<void> openRoster(
    ScopedRegistrationRef ref, {
    bool refresh = false,
  }) async {
    if (!canRead || _commandInProgress) return;
    if (ref.scope != runtime.scope) {
      throw const AccountReadException('SCOPE_MISMATCH');
    }
    _selected = ref.registrationId;
    final epoch = _epoch;
    if (_requiresMetadata) {
      await refreshRegistrations();
    } else {
      await initialize();
    }
    if (!_valid(epoch) || _selected != ref.registrationId) return;
    if (!refresh && roster(ref.registrationId).current) return;
    await _startRoster(ref);
  }

  void closeRoster() {
    _selected = null;
  }

  Future<void> _startRoster(ScopedRegistrationRef ref) {
    final id = ref.registrationId;
    if (!canRead || rosterRetrySeconds(id) > 0) return Future.value();
    if (_rosterFlights[id] case final running?) return running;
    final epoch = _epoch, metadataEpoch = _metadataEpoch;
    _rosters[id] = ScopedRosterReadState(
      observation: _stale(roster(id).observation),
      loading: true,
    );
    _emit();
    late final Future<void> flight;
    flight =
        _queue(epoch, () async {
          if (!_valid(epoch, metadataEpoch)) return;
          CachedRosterView? observed = _rosters[id]?.observation;
          try {
            observed = await runtime.readRoster(
              ref,
              guard: () => _guard(epoch, metadataEpoch),
            );
            _guard(epoch, metadataEpoch);
            _rosters[id] = ScopedRosterReadState(
              observation: _stale(observed),
              loading: true,
            );
            _emit();
            if (!_registrationsCurrent) {
              _rosters[id] = ScopedRosterReadState(
                observation: _stale(observed),
                failure: _failure,
              );
              return;
            }
            if (!_registrations.any((r) => r.registrationId == id)) {
              throw const AccountReadException('REGISTRATION_NOT_FOUND');
            }
            final view = await runtime.refreshRoster(
              ref,
              guard: () => _guard(epoch, metadataEpoch),
            );
            _guard(epoch, metadataEpoch);
            _rosters[id] = ScopedRosterReadState(
              observation: view,
              current: true,
            );
          } catch (error) {
            if (_valid(epoch, metadataEpoch)) {
              final failure = ScopedReadFailure(error, now());
              if (failure.kind == ScopedReadFailureKind.conflict) {
                _requiresMetadata = true;
              }
              _rosters[id] = ScopedRosterReadState(
                observation: _stale(observed),
                failure: failure,
              );
            }
          } finally {
            if (_valid(epoch, metadataEpoch)) _emit();
          }
        }).whenComplete(() {
          if (identical(_rosterFlights[id], flight)) _rosterFlights.remove(id);
        });
    _rosterFlights[id] = flight;
    return flight;
  }

  Future<void> openHistory() {
    if (!canRead) return Future.value();
    if (_history.open) return _historyFlight ?? Future.value();
    return restartHistory();
  }

  Future<void> restartHistory() => _readHistory(restart: true);
  Future<void> loadMoreHistory() => _readHistory(restart: false);

  Future<void> _readHistory({required bool restart}) {
    if (!canRead || historyRetrySeconds > 0) return Future.value();
    if (_historyFlight case final running?) return running;
    if (!restart &&
        (!_history.open || _continuation == null || _history.needsRestart)) {
      return Future.value();
    }
    final epoch = _epoch, historyEpoch = _historyEpoch;
    final previous = _history;
    final next = restart ? null : _continuation;
    // A continuation is single use even when the next request fails.
    _continuation = null;
    _history = ScopedHistoryReadState(
      items: previous.items,
      open: true,
      loading: true,
      loaded: previous.loaded,
      revision: previous.revision,
    );
    void guard() {
      _guard(epoch);
      if (historyEpoch != _historyEpoch) {
        throw const AccountReadException('STALE_READ');
      }
    }

    late final Future<void> flight;
    flight =
        Future<void>.sync(() async {
          try {
            final result = await runtime.readRetirements(
              next: next,
              guard: guard,
            );
            guard();
            _continuation = result.next;
            _history = ScopedHistoryReadState(
              items: [
                ...(restart ? <CharacterRetirement>[] : previous.items),
                ...result.page.items,
              ],
              open: true,
              loaded: true,
              current: true,
              revision: result.page.revision,
              hasMore: result.next != null,
            );
          } catch (error) {
            if (_valid(epoch) && historyEpoch == _historyEpoch) {
              _history = ScopedHistoryReadState(
                items: previous.items,
                open: true,
                loaded: previous.loaded,
                revision: previous.revision,
                needsRestart: true,
                failure: ScopedReadFailure(error, now()),
              );
            }
          } finally {
            if (_valid(epoch) && historyEpoch == _historyEpoch) _emit();
          }
        }).whenComplete(() {
          if (identical(_historyFlight, flight)) _historyFlight = null;
        });
    _historyFlight = flight;
    _emit();
    return flight;
  }

  void closeHistory({bool notify = true}) {
    _historyEpoch++;
    _historyFlight = null;
    _continuation = null;
    _history = ScopedHistoryReadState();
    _emit(notify: notify);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _metadataEpoch++;
    _historyEpoch++;
    runtime.session.removeListener(_onSession);
    runtime.invalidateReads();
    _timer?.cancel();
    _timer = null;
    _registrations = const [];
    _metadata = const [];
    _rosters.clear();
    _registrationsCurrent = false;
    _loading = false;
    _failure = null;
    _selected = null;
    _metadataFlight = null;
    _rosterFlights.clear();
    _historyFlight = null;
    _continuation = null;
    _history = ScopedHistoryReadState();
    super.dispose();
  }
}
