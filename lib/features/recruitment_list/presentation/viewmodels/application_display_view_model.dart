import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/role_summary.dart';
import '../../data/application_display.dart';
import 'cycle_participation_controller.dart';

class ApplicationDisplayViewModel extends ChangeNotifier {
  ApplicationDisplayViewModel({
    required this.controller,
    required this.room,
    required this.target,
  }) {
    _binding = controller.scopeKey();
    _mutation = controller.mutationVersion;
    controller.session.addListener(_access);
    controller.changes.addListener(_access);
    controller.addListener(_changed);
  }
  final CycleParticipationController controller;
  final String room, target;
  late String _binding;
  late int _mutation;
  int _epoch = 0;
  bool _disposed = false, loading = false, opened = false;
  String? failure, cursor, _identity;
  List<ApplicationDisplayItem> rows = const [];
  final _cursors = <String>{};
  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      controller.session.isAuthenticated &&
      controller.scopeKey() == _binding;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _clear() {
    rows = const [];
    cursor = _identity = null;
    _cursors.clear();
  }

  void _access() {
    if (controller.scopeKey() == _binding &&
        controller.session.isAuthenticated) {
      return;
    }
    _binding = controller.scopeKey();
    _epoch++;
    _clear();
    loading = opened = false;
    failure = 'ACCESS_CHANGED';
    _emit();
  }

  void _changed() {
    if (_disposed) return;
    _access();
    final c = controller;
    if (!c.busy && c.mutationVersion != _mutation) {
      _mutation = c.mutationVersion;
      if (opened && c.lastRoom == room && c.lastTarget == target) {
        // A pre-command page must not overwrite the post-ACK refresh.
        if (loading) {
          _epoch++;
          loading = false;
          _clear();
        }
        unawaited(load());
      }
    }
    _emit();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || loading || !controller.canAct || more && cursor == null) {
      return;
    }
    final e = ++_epoch, next = more ? cursor : null;
    if (!more) _clear();
    opened = loading = true;
    failure = null;
    _emit();
    try {
      final gateway = controller.gateway;
      if (gateway is! ApplicationDisplayListGateway) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      final page = await (gateway as ApplicationDisplayListGateway)
          .applicationDisplayPage(room, target, cursor: next);
      if (!_valid(e)) return;
      roleCheck(!more || page.items.isNotEmpty);
      roleCheck(!more || _identity == page.identity);
      roleCheck(
        page.cursor == null ||
            page.cursor != next && !_cursors.contains(page.cursor),
      );
      final combined = more ? [...rows, ...page.items] : page.items;
      roleCheck(
        combined.map((r) => r.row.id).toSet().length == combined.length,
      );
      rows = List.unmodifiable(combined);
      _identity = page.identity;
      cursor = page.cursor;
      if (cursor != null) _cursors.add(cursor!);
    } on AccountReadException catch (error) {
      if (_valid(e)) {
        _clear();
        failure = error.code;
      }
    } catch (_) {
      if (_valid(e)) {
        _clear();
        failure = 'INVALID_RESPONSE';
      }
    } finally {
      if (_valid(e)) {
        loading = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _clear();
    controller.session.removeListener(_access);
    controller.changes.removeListener(_access);
    controller.removeListener(_changed);
    super.dispose();
  }
}
