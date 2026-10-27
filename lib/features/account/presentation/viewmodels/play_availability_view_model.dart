import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/local/scoped_command_key.dart';
import '../../domain/account_read_session.dart';
import '../../domain/play_availability.dart';

class _Save {
  _Save(this.version, List<PlayTimeRow> rows, this.createdAt)
    : rows = List.unmodifiable(rows),
      key = newScopedCommandKey();
  final int version;
  final List<PlayTimeRow> rows;
  final String key;
  final DateTime createdAt;
}

/// App-owned editor; navigation does not recreate a failed command or its key.
class PlayAvailabilityViewModel extends ChangeNotifier {
  PlayAvailabilityViewModel({
    required this.repository,
    required this.session,
    required this.accessChanges,
    required this.hasVerifiedAccount,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final PlayAvailabilityRepository repository;
  final AccountReadSession session;
  final Listenable accessChanges;
  final bool Function() hasVerifiedAccount;
  final DateTime Function() now;
  PlayAvailability? value;
  List<PlayTimeRow> _draft = [];
  List<PlayTimeRow> get draft => List.unmodifiable(_draft);
  bool expanded = false, loading = false, saving = false, needsReview = false;
  String? failure, notice;
  _Save? _pending;
  (String?, int, bool)? _scope;
  bool _visible = false, _disposed = false, _initialized = false;
  int _epoch = 0;
  DateTime? _retryAt;
  Timer? _timer;
  bool get visible => !_disposed && _visible;
  bool get hasPending => _pending != null;
  int get editGeneration => _epoch;
  bool get busy => loading || saving;
  bool get editable =>
      visible && expanded && value != null && !busy && !hasPending;
  bool get validDraft => _draft.every((r) => r.valid);
  bool get canSave => editable && !needsReview && validDraft && _delayPassed;
  bool get _delayPassed => _retryAt == null || !now().isBefore(_retryAt!);
  bool get canRetry =>
      visible &&
      hasPending &&
      !busy &&
      _delayPassed &&
      now().difference(_pending!.createdAt) < const Duration(hours: 24);

  void initialize() {
    if (_initialized || _disposed) return;
    _initialized = true;
    session.addListener(_access);
    accessChanges.addListener(_access);
    _access();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _access() {
    final scope = (session.userId, session.generation, session.isAuthenticated);
    final eligible = session.isAuthenticated && hasVerifiedAccount();
    if (scope == _scope && eligible == _visible) return;
    _scope = scope;
    _visible = eligible;
    _epoch++;
    _timer?.cancel();
    _retryAt = null;
    value = null;
    _draft = [];
    _pending = null;
    expanded = loading = saving = needsReview = false;
    failure = notice = null;
    _emit();
    if (eligible) unawaited(reload());
  }

  bool _current(int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      visible &&
      _scope == (session.userId, session.generation, session.isAuthenticated) &&
      hasVerifiedAccount();

  void toggle() {
    if (!visible || busy) return;
    if (expanded) {
      cancel();
      return;
    }
    expanded = true;
    if (!hasPending) _draft = [...?value?.intervals];
    _emit();
  }

  void cancel() {
    if (busy) return;
    expanded = false;
    if (!hasPending) {
      _draft = [];
      notice = null;
    }
    _emit();
  }

  void selectDay(int day) {
    if (!editable || !playWeekdays.contains(day)) return;
    if (_draft.any((r) => r.weekday == day)) {
      _draft.removeWhere((r) => r.weekday == day);
    } else {
      _draft.add(PlayTimeRow(weekday: day));
    }
    _emit();
  }

  void addRow(int day) {
    if (!editable) return;
    _draft.add(PlayTimeRow(weekday: day));
    _emit();
  }

  void removeRow(PlayTimeRow row) {
    if (!editable) return;
    _draft.remove(row);
    _emit();
  }

  void replaceRow(PlayTimeRow old, PlayTimeRow next) {
    if (!editable) return;
    final i = _draft.indexOf(old);
    if (i < 0 || next.weekday != old.weekday) return;
    _draft[i] = next;
    _emit();
  }

  void useServer() {
    if (!editable || value == null) return;
    _draft = [...value!.intervals];
    needsReview = false;
    failure = notice = null;
    _emit();
  }

  Future<void> reload() async {
    if (!visible || busy || hasPending || !_delayPassed) return;
    final epoch = _epoch;
    loading = true;
    _emit();
    try {
      final result = await repository.load();
      if (!_current(epoch)) return;
      value = result;
      failure = null;
      if (needsReview) {
        needsReview = false;
        notice = '최신 저장값을 확인했습니다. 초안을 확인한 뒤 저장해 주세요.';
      } else if (expanded) {
        _draft = [...result.intervals];
      }
    } on AccountReadException catch (e) {
      if (_current(epoch)) _fail(e);
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> save() async {
    if (!canSave) return;
    _pending = _Save(value!.version, _draft, now());
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  Future<void> reviewPending() async {
    if (!visible || busy) return;
    _pending = null;
    needsReview = true;
    await reload();
  }

  Future<void> _send() async {
    final command = _pending!, epoch = _epoch;
    saving = true;
    failure = notice = null;
    _emit();
    try {
      final result = await repository.save(
        version: command.version,
        rows: command.rows,
        key: command.key,
      );
      if (!_current(epoch)) return;
      value = result;
      _pending = null;
      _draft = [];
      expanded = needsReview = false;
    } on AccountReadException catch (e) {
      if (!_current(epoch)) return;
      _fail(e);
      // Unknown outcomes keep the immutable command. Never resend it with a new key.
      if (e.code == 'REVISION_CONFLICT' ||
          e.code == 'IDEMPOTENCY_CONFLICT' ||
          e.code == 'IDEMPOTENCY_EXPIRED' ||
          e.status == 400 ||
          e.status == 413 ||
          e.status == 403 ||
          e.status == 404) {
        _pending = null;
        needsReview = true;
      }
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        saving = false;
        _emit();
      }
    }
  }

  void _fail(AccountReadException e) {
    failure = e.code;
    final delay = e.retryAfter;
    final until = e.retryAt ?? (delay == null ? null : now().add(delay));
    if (until != null && until.isAfter(now())) {
      _retryAt = until;
      _timer?.cancel();
      _timer = Timer(until.difference(now()), _emit);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    if (_initialized) {
      session.removeListener(_access);
      accessChanges.removeListener(_access);
    }
    super.dispose();
  }
}
