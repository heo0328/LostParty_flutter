import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/raid_room_usage_repository.dart';
import '../../domain/policies/party_cycle_policy.dart';

/// One app-owned snapshot. Failed reads never change a successful command.
class RaidRoomUsageController extends ChangeNotifier {
  RaidRoomUsageController({
    required this.repository,
    required this.session,
    required this.scopeKey,
    required this.changes,
  }) {
    _binding = scopeKey();
    session.addListener(_access);
    changes.addListener(_access);
    unawaited(refresh());
  }
  final RaidRoomUsageRepository repository;
  final AccountReadSession session;
  final String Function() scopeKey;
  final Listenable changes;
  late String _binding;
  RaidRoomUsage? value;
  String? failure;
  bool _disposed = false, _dirty = false;
  int _epoch = 0;
  Future<void>? _flight;
  Timer? _boundary;
  final _appliedKeys = <String>{};
  bool get authenticated => session.isAuthenticated;
  String get label {
    if (failure != null || value == null) return '—/—';
    // evaluated_at is server time: its boundary timer below also expires this.
    return value!.label;
  }

  bool _valid(int epoch) =>
      !_disposed &&
      session.isAuthenticated &&
      epoch == _epoch &&
      _binding == scopeKey();
  void _access() {
    if (_disposed || _binding == scopeKey()) return;
    _binding = scopeKey();
    _epoch++;
    _flight = null;
    _dirty = false;
    _boundary?.cancel();
    value = null;
    failure = null;
    _appliedKeys.clear();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed || !authenticated) return Future.value();
    if (_binding != scopeKey()) {
      _access();
      return _flight ?? Future.value();
    }
    return _flight ??= _read(_epoch);
  }

  /// Only validated, durably stored ACKs call this, once per original command.
  void commandApplied(String key) {
    if (_disposed || !authenticated) return;
    if (_binding != scopeKey()) _access();
    if (!_appliedKeys.add(key)) return;
    if (_flight != null) {
      _dirty = true;
    } else {
      unawaited(refresh());
    }
  }

  Future<void> _read(int epoch) async {
    do {
      _dirty = false;
      try {
        final next = await repository.read();
        if (!_valid(epoch)) return;
        if (!_dirty) {
          value = next;
          failure = null;
          _boundary?.cancel();
          final end = const PartyCyclePolicy()
              .fromKey(next.currentCycle)!
              .endsAt;
          // Relative server time avoids applying the device's week to the server.
          _boundary = Timer(end.difference(next.evaluatedAt), () {
            if (!_valid(epoch)) return;
            value = null;
            notifyListeners();
            unawaited(refresh());
          });
        }
      } on Object catch (error) {
        if (!_valid(epoch)) return;
        value = null;
        failure = error is AccountReadException
            ? error.code
            : 'INVALID_RESPONSE';
      }
    } while (_valid(epoch) && _dirty);
    if (!_valid(epoch)) return;
    _flight = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _boundary?.cancel();
    session.removeListener(_access);
    changes.removeListener(_access);
    super.dispose();
  }
}
