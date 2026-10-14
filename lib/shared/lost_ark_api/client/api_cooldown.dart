import 'dart:async';
import 'package:flutter/foundation.dart';

/// A last observed provider deadline, not an estimate of all device traffic.
class ApiCooldown extends ChangeNotifier {
  ApiCooldown({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  DateTime? until;
  Timer? _timer;
  String? _tokenIdentity;
  void bindToken(String token) {
    if (_tokenIdentity != null && _tokenIdentity != token) clear();
    _tokenIdentity = token;
  }

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
    _tokenIdentity = null;
    _timer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

DateTime providerRetryAt(String? reset, DateTime observed) {
  final seconds = int.tryParse(reset ?? '');
  if (seconds != null && seconds > 0 && seconds < 100000000000) {
    final deadline = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    );
    if (deadline.isAfter(observed) &&
        deadline.difference(observed) <= const Duration(seconds: 300)) {
      return deadline;
    }
  }
  return observed.add(const Duration(seconds: 60));
}
