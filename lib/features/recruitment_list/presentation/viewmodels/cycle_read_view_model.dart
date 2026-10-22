import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/cycle_read_repository.dart';

/// Page-local cursor state; account/session/ownership changes fence every read.
class CycleReadViewModel extends ChangeNotifier {
  CycleReadViewModel({
    required this.repository,
    required this.changes,
    required this.scopeKey,
    this.roomId,
  }) {
    _binding = scopeKey();
    changes.addListener(_changed);
    repository.api.session.addListener(_changed);
  }
  final CycleReadRepository repository;
  final Listenable changes;
  final String Function() scopeKey;
  final String? roomId;
  late String _binding;
  bool _disposed = false, loading = false;
  int _epoch = 0;
  String? target, failure;
  int tab = 0;
  List<CycleOwnRow> rows = const [];
  CycleRoomCard? card;
  String? cursor;
  final _pages = <(String, int), (List<CycleOwnRow>, String?)>{};
  final _cursors = <String>{};
  bool get signedIn => repository.api.session.isAuthenticated;
  bool _valid(int e) =>
      !_disposed && e == _epoch && signedIn && _binding == scopeKey();
  void _changed() {
    final next = scopeKey();
    if (next == _binding && signedIn) return;
    _binding = next;
    _epoch++;
    _pages.clear();
    _cursors.clear();
    rows = const [];
    card = null;
    cursor = null;
    failure = null;
    loading = false;
    notifyListeners();
    if (signedIn && target != null) unawaited(load());
  }

  void invalidateTarget(String t) {
    _pages.removeWhere((k, _) => k.$1 == t);
    if (target == t) {
      _epoch++;
      loading = false;
      _cursors.clear();
      unawaited(load());
    }
  }

  void select(String t, {int section = 0}) {
    if (target == t && tab == section) return;
    _epoch++;
    target = t;
    tab = section;
    loading = false;
    failure = null;
    card = null;
    _cursors.clear();
    final cached = _pages[(t, section)];
    rows = cached?.$1 ?? const [];
    cursor = cached?.$2;
    notifyListeners();
    if (cached == null || roomId != null) unawaited(load());
  }

  Future<void> load({bool more = false}) async {
    if (_disposed ||
        loading ||
        !signedIn ||
        target == null ||
        (more && cursor == null)) {
      return;
    }
    final e = ++_epoch, t = target!, section = tab, next = more ? cursor : null;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      if (roomId != null) {
        final value = await repository.room(roomId!, t);
        if (!_valid(e)) return;
        card = value;
      } else {
        final value = await repository.own(
          t,
          applications: section == 1,
          history: section == 2,
          cursor: next,
        );
        if (!_valid(e)) return;
        if (more &&
            value.cursor != null &&
            (value.cursor == next || _cursors.contains(value.cursor))) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        final items = more ? [...rows, ...value.rows] : value.rows;
        if (items.map((r) => r.id).toSet().length != items.length) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        if (!more) _cursors.clear();
        if (value.cursor != null) _cursors.add(value.cursor!);
        rows = List.unmodifiable(items);
        cursor = value.cursor;
        _pages[(t, section)] = (rows, cursor);
      }
    } on AccountReadException catch (e2) {
      if (_valid(e)) {
        failure = e2.code;
        if ({
          'CURSOR_STALE',
          'FILTER_CONTEXT_STALE',
          'CYCLE_CHANGED',
        }.contains(failure)) {
          _pages.remove((t, section));
          rows = const [];
          cursor = null;
          _cursors.clear();
        }
      }
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    changes.removeListener(_changed);
    repository.api.session.removeListener(_changed);
    super.dispose();
  }
}
