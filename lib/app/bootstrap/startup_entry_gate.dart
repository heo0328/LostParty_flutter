import 'dart:async';

import 'package:flutter/foundation.dart';

/// Presentation only. Closing this gate never cancels app-owned API work.
class StartupEntryGate extends ChangeNotifier {
  StartupEntryGate({this.waitDuration = const Duration(seconds: 4)});

  final Duration waitDuration;
  Timer? _deadline;
  bool _started = false, _disposed = false;
  bool _canEnter = false;
  bool get canEnter => _canEnter;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _deadline = Timer(waitDuration, () {
      if (_disposed) return;
      _canEnter = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _deadline?.cancel();
    super.dispose();
  }
}
