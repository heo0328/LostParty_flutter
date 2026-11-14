import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/personal_reservations_repository.dart';
import '../../domain/account_read_session.dart';
import '../../domain/personal_reservations.dart';

/// Member-owned read state; independent from availability editing and game weeks.
class PersonalScheduleViewModel extends ChangeNotifier {
  PersonalScheduleViewModel({
    required this.repository,
    required this.session,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    session.addListener(_sessionChanged);
    _sessionChanged();
  }
  final PersonalReservationsRepository repository;
  final AccountReadSession session;
  final DateTime Function() now;
  bool expanded = false, loading = false, nextWeek = false;
  String? key, failure;
  DateTime? checkedAt, retryAt, _server, _received;
  List<PersonalReservation> items = const [];
  int _epoch = 0;
  bool _disposed = false, _dirty = true;
  Timer? _retryTimer;
  (String?, int, bool)? _scope;
  bool get visible => session.isAuthenticated && !_disposed;
  bool get canReload =>
      visible && !loading && (retryAt == null || !now().isBefore(retryAt!));

  void _sessionChanged() {
    final scope = (session.userId, session.generation, session.isAuthenticated);
    if (scope == _scope) return;
    _scope = scope;
    _retryTimer?.cancel();
    _epoch++;
    items = const [];
    key = failure = null;
    checkedAt = retryAt = _server = _received = null;
    expanded = loading = nextWeek = false;
    _dirty = true;
    notifyListeners();
  }

  void toggle() {
    expanded = !expanded;
    notifyListeners();
    if (expanded && (_dirty || _targetKey() != key)) unawaited(reload());
  }

  void invalidate() {
    _dirty = true;
    if (expanded) unawaited(reload());
  }

  void selectWeek(bool next) {
    if (next == nextWeek) return;
    nextWeek = next;
    _epoch++;
    loading = false;
    items = const [];
    checkedAt = null;
    key = _targetKey();
    failure = null;
    notifyListeners();
    unawaited(reload());
  }

  String? _targetKey() {
    if (_server == null) return null;
    final current = calendarKey(_server!.add(now().difference(_received!)));
    return nextWeek
        ? calendarKey(calendarStart(current).add(const Duration(days: 7)))
        : current;
  }

  Future<void> reload() async {
    if (!canReload) return;
    final epoch = ++_epoch;
    bool current() => !_disposed && epoch == _epoch && visible;
    loading = true;
    failure = null;
    _dirty = false;
    notifyListeners();
    var staleRetries = 0, clockRetries = 0;
    try {
      if (_server == null) {
        final time = await repository.serverTime();
        if (!current()) return;
        _server = time;
        _received = now();
      }
      while (current()) {
        final target = _targetKey()!;
        if (target != key) {
          key = target;
          items = const [];
          checkedAt = null;
          notifyListeners();
        }
        try {
          final all = <PersonalReservation>[];
          final ids = <String>{}, cursors = <String>{};
          String? cursor, revision, calendar;
          DateTime? evaluated;
          do {
            final page = await repository.page(target, cursor: cursor);
            if (!current()) return;
            checkReservation(revision == null || revision == page.revision);
            checkReservation(calendar == null || calendar == page.currentKey);
            revision = page.revision;
            calendar = page.currentKey;
            evaluated = page.serverNow;
            for (final item in page.items) {
              checkReservation(ids.add(item.id));
              if (all.isNotEmpty) {
                final previous = all.last;
                checkReservation(
                  previous.start.isBefore(item.start) ||
                      previous.start == item.start &&
                          previous.id.compareTo(item.id) < 0,
                );
              }
              all.add(item);
              checkReservation(all.length <= 10000);
            }
            cursor = page.cursor;
            if (cursor != null) {
              checkReservation(page.items.isNotEmpty && cursors.add(cursor));
            }
          } while (cursor != null);
          items = List.unmodifiable(all);
          checkedAt = evaluated;
          _server = evaluated;
          _received = now();
          break;
        } on AccountReadException catch (e) {
          if (e.code == 'CURSOR_STALE' && staleRetries++ == 0) continue;
          if (e.code == 'CALENDAR_WEEK_UNAVAILABLE' && clockRetries++ == 0) {
            final time = await repository.serverTime();
            if (!current()) return;
            _server = time;
            _received = now();
            continue;
          }
          rethrow;
        }
      }
    } on AccountReadException catch (e) {
      if (current()) {
        failure = e.code;
        retryAt =
            e.retryAt ??
            (e.retryAfter == null ? null : now().add(e.retryAfter!));
        if (retryAt != null) {
          _retryTimer?.cancel();
          final delay = retryAt!.difference(now());
          _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
            if (!_disposed) notifyListeners();
          });
        }
      }
    } catch (_) {
      if (current()) failure = 'INVALID_RESPONSE';
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
        if (_dirty && failure == null) unawaited(reload());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _epoch++;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
