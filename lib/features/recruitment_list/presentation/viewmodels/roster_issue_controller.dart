import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/server_registration_api.dart';
import '../../data/roster_participation.dart';
import '../../domain/policies/party_cycle_policy.dart';

/// App-owned summary. Screens retain their independently authorized room data.
class RosterIssueController extends ChangeNotifier {
  RosterIssueController({
    required this.api,
    required this.session,
    required this.scopeKey,
    required this.changes,
  }) {
    _binding = scopeKey();
    session.addListener(_access);
    changes.addListener(_access);
    unawaited(refresh());
  }
  final BackendRegistrationApi api;
  final AccountReadSession session;
  final String Function() scopeKey;
  final Listenable changes;
  late String _binding;
  int _epoch = 0, mutationVersion = 0;
  bool _disposed = false, _dirty = false;
  Future<void>? _flight;
  Timer? _boundary;
  RosterIssueSummary? value;
  String? failure;
  bool get hasIssues => value?.hasIssues == true;
  Set<String> get affectedCycles => value?.affectedCycles ?? const {};
  bool _valid(int e) =>
      !_disposed &&
      session.isAuthenticated &&
      e == _epoch &&
      _binding == scopeKey();
  void _access() {
    if (_disposed || _binding == scopeKey()) return;
    _binding = scopeKey();
    _epoch++;
    _flight = null;
    _dirty = false;
    value = null;
    failure = null;
    _boundary?.cancel();
    notifyListeners();
    unawaited(refresh());
  }

  void invalidate({bool notifyRooms = true}) {
    if (_disposed) return;
    if (notifyRooms) mutationVersion++;
    if (_flight != null) _dirty = true;
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (_disposed || !session.isAuthenticated) return Future.value();
    if (_binding != scopeKey()) _access();
    return _flight ??= _read(_epoch);
  }

  Future<void> _read(int e) async {
    do {
      _dirty = false;
      try {
        final raw = await api.request('/v2/me/raid-room-character-issues');
        final next = RosterIssueSummary(raw!);
        if (!_valid(e)) return;
        if (!_dirty) {
          value = next;
          failure = null;
          _boundary?.cancel();
          final end = const PartyCyclePolicy()
              .fromKey(next.wire['current_cycle_key'])!
              .endsAt;
          final evaluated = DateTime.parse(next.wire['evaluated_at']);
          _boundary = Timer(end.difference(evaluated), () {
            if (!_valid(e)) return;
            value = null;
            notifyListeners();
            unawaited(refresh());
          });
        }
      } catch (error) {
        if (!_valid(e)) return;
        // Keep the last observation in this scope, never turn failure into zero.
        failure = error is AccountReadException
            ? error.code
            : 'INVALID_RESPONSE';
      }
    } while (_valid(e) && _dirty);
    if (!_valid(e)) return;
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
