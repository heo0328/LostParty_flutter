import 'dart:async';

import 'package:flutter/widgets.dart';

import '../policies/party_cycle_policy.dart';

typedef PartyCycleNow = DateTime Function();

/// Keeps the app-wide current raid cycle aligned while the process remains
/// alive. Stored recruitment cycle windows are never recalculated by this
/// service; it only supplies the current cycle for new queries and commands.
class PartyCycleRuntime extends ChangeNotifier with WidgetsBindingObserver {
  PartyCycleRuntime({
    PartyCyclePolicy policy = const PartyCyclePolicy(),
    PartyCycleNow now = DateTime.now,
    bool observeLifecycle = true,
    bool scheduleBoundaryRefresh = true,
  }) : _policy = policy,
       _now = now,
       _observeLifecycle = observeLifecycle,
       _scheduleBoundaryRefresh = scheduleBoundaryRefresh,
       _current = _resolve(policy, now()) {
    if (_observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    _scheduleNextBoundary();
  }

  final PartyCyclePolicy _policy;
  final PartyCycleNow _now;
  final bool _observeLifecycle;
  final bool _scheduleBoundaryRefresh;
  PartyCycleWindow _current;
  Timer? _boundaryTimer;

  PartyCycleWindow get current => _current;

  String refreshAndGetKey() {
    refresh();
    return _current.key;
  }

  /// Re-evaluates the current cycle. Listeners are notified only when the
  /// cycle key changes, so cycle-dependent streams resubscribe once.
  void refresh() {
    final next = _resolve(_policy, _now());
    final changed = next.key != _current.key;
    _current = next;
    _scheduleNextBoundary();
    if (changed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  void _scheduleNextBoundary() {
    _boundaryTimer?.cancel();
    if (!_scheduleBoundaryRefresh) return;
    final delay = _current.endsAt.difference(_now());
    _boundaryTimer = Timer(delay.isNegative ? Duration.zero : delay, refresh);
  }

  @override
  void dispose() {
    _boundaryTimer?.cancel();
    if (_observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  static PartyCycleWindow _resolve(PartyCyclePolicy policy, DateTime now) {
    final key = policy.keyFor(now);
    return policy.fromKey(key)!;
  }
}
