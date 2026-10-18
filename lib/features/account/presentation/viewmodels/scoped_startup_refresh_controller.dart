import '../../../../shared/diagnostics/load_timing.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/scoped_startup_refresh.dart';

class _MemberRun {
  _MemberRun(this.batch, this.items);
  final ScopedRefreshBatch batch;
  final Map<String, ScopedRefreshItem> items;
}

/// App-owned lifetime. Pages observe this controller and never dispose it.
/// Construct/initialize once; reconnecting the same member never resets _runs.
class ScopedStartupRefreshController extends ChangeNotifier {
  ScopedStartupRefreshController(this.source);
  final ScopedStartupRefreshSource source;
  final Map<StorageScope, _MemberRun> _runs = {};
  Future<void>? _flight;
  Object? _identity;
  int _epoch = 0;
  bool _initialized = false, _disposed = false, _recheck = false;
  bool _uploadOnly = false;
  ScopedRefreshPhase _phase = ScopedRefreshPhase.idle;
  String? _failure;
  StorageScope? get _scope => source.scope;
  _MemberRun? get _run => _scope == null ? null : _runs[_scope];
  ScopedRefreshPhase get phase => _phase;
  List<RosterRefreshProgress> get rosterProgress =>
      source is RosterRefreshingSource
      ? (source as RosterRefreshingSource).rosterProgress
      : const [];
  void _rosterChanged() {
    if (!_disposed) notifyListeners();
  }

  String? get failure => _failure;
  List<ScopedRefreshItem> get items =>
      List.unmodifiable(_run?.items.values ?? <ScopedRefreshItem>[]);
  int get totalCount => items.length;
  int get processedCount => items
      .where(
        (i) => {
          ScopedRefreshStatus.saved,
          ScopedRefreshStatus.failed,
          ScopedRefreshStatus.excluded,
        }.contains(i.status),
      )
      .length;
  int get savedCount =>
      items.where((i) => i.status == ScopedRefreshStatus.saved).length;
  int get warningCount => items
      .where((i) => i.status == ScopedRefreshStatus.saved && i.warning)
      .length;
  int get pendingServerCount => items.where((i) => i.serverPending).length;
  int get incompleteCount => items.where((i) => i.incomplete).length;
  int get excludedCount =>
      items.where((i) => i.status == ScopedRefreshStatus.excluded).length;
  bool get consumed => _run != null;
  bool get isBusy =>
      _phase == ScopedRefreshPhase.preparing ||
      _phase == ScopedRefreshPhase.running;
  bool get settingsChanged =>
      _run != null &&
      source.settingsVersion != null &&
      _run!.batch.settingsVersion != source.settingsVersion;
  bool get canRetry =>
      !isBusy && !source.cooldown.active && incompleteCount > 0;
  bool get canRetryServer =>
      !isBusy && !source.cooldown.active && pendingServerCount > 0;

  /// An explicit per-character resolution used the same authenticated store.
  /// Do not rerun Armory or leave the batch's upload counter stale afterward.
  void serverResolved(ScopedCharacterRef ref, CharacterBuildRole role) {
    if (_disposed || isBusy || ref.scope != _scope) return;
    final run = _run;
    if (run == null) return;
    for (final entry in run.items.entries.toList()) {
      final item = entry.value;
      if (item.target.ref.accountId == ref.accountId &&
          item.target.ref.characterId == ref.characterId &&
          item.role == role &&
          item.serverPending) {
        run.items[entry.key] = ScopedRefreshItem(
          item.target,
          item.status,
          code: item.code,
          role: role,
          warning: item.warning,
        );
        notifyListeners();
      }
    }
  }

  Object _currentIdentity() => (
    source.scope,
    source.session.userId,
    source.session.generation,
    source.session.isAuthenticated,
    source.keyVersion,
  );
  void initialize() {
    if (_initialized || _disposed) return;
    _initialized = true;
    source.session.addListener(_changed);
    source.changes.addListener(_changed);
    source.cooldown.addListener(_cooldownChanged);
    if (source is RosterRefreshingSource) {
      (source as RosterRefreshingSource).rosterChanges.addListener(
        _rosterChanged,
      );
    }
    _identity = _currentIdentity();
    unawaited(startIfReady());
  }

  void _cooldownChanged() {
    if (!_disposed) notifyListeners();
  }

  void _changed() {
    if (_disposed || !_initialized) return;
    final identity = _currentIdentity();
    if (identity != _identity) {
      _identity = identity;
      _interrupt();
      _phase = _run == null
          ? ScopedRefreshPhase.idle
          : ScopedRefreshPhase.completed;
      _failure = null;
    } else if (_phase == ScopedRefreshPhase.preparing) {
      _recheck = true;
    }
    if (isBusy && _run != null && !_uploadOnly) {
      try {
        source.requireCurrent(_run!.batch);
      } on AccountReadException catch (error) {
        _interrupt();
        _phase = ScopedRefreshPhase.completed;
        _failure = error.code;
      }
    }
    notifyListeners();
    if (!consumed && !isBusy) unawaited(startIfReady());
  }

  void _interrupt() {
    _epoch++;
    _uploadOnly = false;
    _flight = null;
    // _scope may already be the new member. Interrupt every unfinished batch
    // without exposing other members' private results through items.
    for (final run in _runs.values) {
      for (final entry in run.items.entries.toList()) {
        if (entry.value.status == ScopedRefreshStatus.queued) {
          run.items[entry.key] = ScopedRefreshItem(
            entry.value.target,
            ScopedRefreshStatus.interrupted,
            code: 'RUN_CANCELLED',
          );
        }
      }
    }
  }

  Future<void> startIfReady() {
    if (_disposed || !_initialized || consumed) return Future.value();
    return _start(retry: false);
  }

  Future<void> retryIncomplete() {
    if (_disposed || !_initialized || !canRetry) {
      return _flight ?? Future.value();
    }
    return _start(retry: true);
  }

  Future<void> _start({required bool retry}) {
    if (_flight case final pending?) return pending;
    if (source.cooldown.active) {
      _phase = ScopedRefreshPhase.blocked;
      _failure = 'RATE_LIMITED';
      notifyListeners();
      return Future.value();
    }
    final epoch = _epoch, identity = _currentIdentity();
    _uploadOnly = false;
    _phase = ScopedRefreshPhase.preparing;
    _failure = null;
    _recheck = false;
    // Assign before notifications, including reentrant listeners.
    late final Future<void> operation;
    operation =
        Future<void>(
          () => LoadTiming.run(
            LoadStage.automaticRefresh,
            () => _execute(epoch, identity, retry),
            root: true,
          ),
        ).whenComplete(() {
          if (!identical(_flight, operation)) return;
          _flight = null;
          final again = _recheck && !consumed && !_disposed;
          _recheck = false;
          if (again) unawaited(startIfReady());
        });
    _flight = operation;
    notifyListeners();
    return operation;
  }

  void _valid(int epoch, Object identity) {
    if (_disposed || epoch != _epoch || identity != _currentIdentity()) {
      throw const AccountReadException('RUN_CANCELLED');
    }
  }

  void _publish(int epoch, Object identity) {
    if (!_disposed && epoch == _epoch && identity == _currentIdentity()) {
      notifyListeners();
    }
  }

  Future<void> _execute(int epoch, Object identity, bool retry) async {
    ScopedRefreshBatch? activeBatch;
    void guard() {
      _valid(epoch, identity);
      if (activeBatch != null) source.requireCurrent(activeBatch);
    }

    _MemberRun? run;
    try {
      guard();
      final prepared = await LoadTiming.run(
        LoadStage.prepareRefresh,
        source.prepare,
      );
      activeBatch = prepared;
      guard();
      final previous = _runs[prepared.scope];
      if (!retry && previous != null) {
        _phase = ScopedRefreshPhase.completed;
        return;
      }
      final selected = retry
          ? previous!.items.entries
                .where((e) => e.value.incomplete)
                .map((e) => e.key)
                .toSet()
          : prepared.targets.map((t) => t.ref.characterId).toSet();
      final result = retry
          ? Map<String, ScopedRefreshItem>.of(previous!.items)
          : <String, ScopedRefreshItem>{};
      final fresh = {for (final t in prepared.targets) t.ref.characterId: t};
      for (final id in selected) {
        final target = fresh[id];
        if (target == null) {
          result[id] = ScopedRefreshItem(
            previous!.items[id]!.target,
            ScopedRefreshStatus.excluded,
            code: 'NO_LONGER_ACTIVE',
          );
          continue;
        }
        result[id] = ScopedRefreshItem(
          target,
          target.exclusion == null
              ? ScopedRefreshStatus.queued
              : ScopedRefreshStatus.excluded,
          code: target.exclusion,
        );
      }
      run = _MemberRun(prepared, result);
      // The per-member once flag is this synchronous insertion after readiness.
      _runs[prepared.scope] = run;
      _phase = ScopedRefreshPhase.running;
      _publish(epoch, identity);
      for (final id in selected) {
        guard();
        final item = run.items[id]!;
        if (item.status != ScopedRefreshStatus.queued) continue;
        if (source.cooldown.active) {
          _failure = 'RATE_LIMITED';
          break;
        }
        try {
          final value = await LoadTiming.run(
            LoadStage.characterRefresh,
            () => source.refresh(prepared, item.target, guard, (saved) {
              if (identical(_runs[prepared.scope], run)) run!.items[id] = saved;
              _publish(epoch, identity);
            }),
          );
          guard();
          run.items[id] = value;
        } on LostArkApiException catch (error) {
          guard();
          run.items[id] = ScopedRefreshItem(
            item.target,
            ScopedRefreshStatus.failed,
            code: 'ARMORY_${error.type.name.toUpperCase()}',
          );
          if (error.type == LostArkApiErrorType.rateLimited) {
            source.cooldown.observe(
              error.retryAt ??
                  source.cooldown.now().add(const Duration(seconds: 60)),
            );
            _failure = 'RATE_LIMITED';
            break;
          }
          if ({
            LostArkApiErrorType.unauthorized,
            LostArkApiErrorType.missingToken,
            LostArkApiErrorType.cancelled,
          }.contains(error.type)) {
            _failure = 'KEY_NOT_READY';
            break;
          }
        } on AccountReadException catch (error) {
          guard();
          if (run.items[id]!.status != ScopedRefreshStatus.saved) {
            run.items[id] = ScopedRefreshItem(
              item.target,
              ScopedRefreshStatus.failed,
              code: error.code,
            );
          }
          if (error.status == 429) {
            source.cooldown.observe(
              error.retryAt ??
                  source.cooldown.now().add(
                    error.retryAfter ?? const Duration(seconds: 60),
                  ),
            );
            _failure = 'RATE_LIMITED';
            break;
          }
        } on ScopedCacheException catch (error) {
          guard();
          if (run.items[id]!.status != ScopedRefreshStatus.saved) {
            run.items[id] = ScopedRefreshItem(
              item.target,
              ScopedRefreshStatus.failed,
              code: error.code,
            );
          }
          if ({
            'STALE_WRITE',
            'REGISTRATION_NOT_CURRENT',
            'SCOPE_CHANGED',
          }.contains(error.code)) {
            _failure = error.code;
            break;
          }
        } catch (_) {
          guard();
          if (run.items[id]!.status != ScopedRefreshStatus.saved) {
            run.items[id] = ScopedRefreshItem(
              item.target,
              ScopedRefreshStatus.failed,
              code: 'ANALYSIS_FAILED',
            );
          }
        }
        _publish(epoch, identity);
      }
      guard();
      _markInterrupted(run);
      _phase = ScopedRefreshPhase.completed;
    } catch (error) {
      LoadTiming.failure();
      if (run != null) _markInterrupted(run);
      if (!_disposed && epoch == _epoch && identity == _currentIdentity()) {
        _phase = run == null
            ? ScopedRefreshPhase.blocked
            : ScopedRefreshPhase.completed;
        _failure = error is AccountReadException
            ? error.code
            : error is ScopedCacheException
            ? error.code
            : 'PREPARATION_FAILED';
      }
    } finally {
      _publish(epoch, identity);
    }
  }

  void _markInterrupted(_MemberRun run) {
    for (final e in run.items.entries.toList()) {
      if (e.value.status == ScopedRefreshStatus.queued) {
        run.items[e.key] = ScopedRefreshItem(
          e.value.target,
          ScopedRefreshStatus.interrupted,
          code: _failure ?? 'RUN_CANCELLED',
        );
      }
    }
  }

  Future<void> retryServerSaved() {
    if (_disposed || !_initialized || !canRetryServer) {
      return _flight ?? Future.value();
    }
    final run = _run!,
        epoch = _epoch,
        member = accountReadScope(source.session),
        scope = _scope!;
    void guard() {
      if (_disposed || epoch != _epoch || source.scope != scope) {
        throw const AccountReadException('RUN_CANCELLED');
      }
      requireAccountReadScope(source.session, member);
    }

    _phase = ScopedRefreshPhase.running;
    _uploadOnly = true;
    late final Future<void> operation;
    operation =
        Future<void>(() async {
          try {
            for (final e in run.items.entries.toList().where(
              (e) => e.value.serverPending,
            )) {
              guard();
              if (source.cooldown.active) break;
              try {
                final saved = await source.retryUpload(e.value, guard);
                guard();
                run.items[e.key] = saved;
              } on AccountReadException catch (error) {
                guard();
                _failure = error.code;
              } on ScopedCacheException catch (error) {
                guard();
                _failure = error.code;
              }
              notifyListeners();
            }
          } catch (_) {
            /* Cancellation preserves durable pending and member data. */
          } finally {
            if (!_disposed && epoch == _epoch) {
              _uploadOnly = false;
              _phase = ScopedRefreshPhase.completed;
              notifyListeners();
            }
          }
        }).whenComplete(() {
          if (identical(_flight, operation)) _flight = null;
        });
    _flight = operation;
    notifyListeners();
    return operation;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _interrupt();
    _disposed = true;
    if (_initialized) {
      source.session.removeListener(_changed);
      source.changes.removeListener(_changed);
      source.cooldown.removeListener(_cooldownChanged);
      if (source is RosterRefreshingSource) {
        (source as RosterRefreshingSource).rosterChanges.removeListener(
          _rosterChanged,
        );
      }
    }
    super.dispose();
  }
}
