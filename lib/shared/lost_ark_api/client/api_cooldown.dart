import 'dart:async';
import 'package:flutter/foundation.dart';

/// A last observed provider deadline, not an estimate of all device traffic.
class ApiCooldown extends ChangeNotifier {
  ApiCooldown({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  DateTime? until;
  Timer? _timer;
  int get seconds => until == null
      ? 0
      : (until!.difference(now()).inMilliseconds / 1000).ceil().clamp(0, 86400);
  bool get active => seconds > 0;
  void observe(DateTime deadline) {
    if (until == null || deadline.isAfter(until!)) until = deadline;
    _timer?.cancel();
    if (active) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!active) timer.cancel();
        notifyListeners();
      });
    }
    notifyListeners();
  }

  void clear() {
    until = null;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
