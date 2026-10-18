import 'dart:async';

import 'package:flutter/foundation.dart';

/// Presentation only. Closing this gate never cancels app-owned API work.
class StartupEntryGate extends ChangeNotifier {
  StartupEntryGate({this.maximumWait = const Duration(seconds: 6)});

  final Duration maximumWait;
  Timer? _deadline;
  bool _started = false, _animationReady = false, _expired = false;
  bool _sessionResolved = false, _displayReady = false, _disposed = false;
  bool _canEnter = false;
  bool get canEnter => _canEnter;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _deadline = Timer(maximumWait, () {
      if (_disposed) return;
      _expired = true;
      _evaluate();
    });
    _evaluate();
  }

  void animationCompleted() {
    if (_disposed) return;
    _animationReady = true;
    _evaluate();
  }

  void update({required bool sessionResolved, required bool displayReady}) {
    if (_disposed || _canEnter) return;
    _sessionResolved = sessionResolved;
    _displayReady = displayReady;
    _evaluate();
  }

  void _evaluate() {
    if (!_started || _disposed || _canEnter || !_animationReady) return;
    if (!_expired && !(_sessionResolved && _displayReady)) return;
    _canEnter = true;
    _deadline?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    super.dispose();
  }
}
