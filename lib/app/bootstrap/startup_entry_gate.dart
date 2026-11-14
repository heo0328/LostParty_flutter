import '../../shared/diagnostics/startup_timing.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Presentation only. Closing this gate never cancels app-owned API work.
class StartupEntryGate extends ChangeNotifier {
  StartupEntryGate({
    this.waitDuration = const Duration(seconds: 4),
    bool Function()? shouldShowEntry,
  }) : _showEntry = shouldShowEntry?.call() ?? !kIsWeb;

  final bool _showEntry;
  final Duration waitDuration;
  Timer? _deadline;
  StartupSpan? _diagnosticWait;
  bool _started = false, _disposed = false;
  bool _canEnter = false;
  bool get canEnter => _canEnter || !_showEntry;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    if (!_showEntry) {
      notifyListeners();
      return;
    }
    _diagnosticWait = StartupTiming.active?.begin(StartupWork.splashWait);
    _deadline = Timer(waitDuration, () {
      if (_disposed) return;
      _diagnosticWait?.end();
      _canEnter = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _diagnosticWait?.result = StartupResult.interrupted;
    _diagnosticWait?.end();
    _deadline?.cancel();
    super.dispose();
  }
}
