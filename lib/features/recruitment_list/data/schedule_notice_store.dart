import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A local display preference, never a server request or timetable mutation.
class ScheduleNoticeStore {
  ScheduleNoticeStore({this.storage = const FlutterSecureStorage()});
  final FlutterSecureStorage storage;
  static final _acknowledged = <String>{};
  static String day(DateTime now) => now
      .toUtc()
      .add(const Duration(hours: 9))
      .toIso8601String()
      .substring(0, 10);
  String key(String scope) =>
      'schedule-unset-v1/${sha256.convert(utf8.encode(scope))}';
  Future<bool> shouldShow(String scope, DateTime now) async {
    final current = day(now);
    if (_acknowledged.contains('${key(scope)}/$current')) return false;
    try {
      if (await storage.read(key: key(scope)) == current) return false;
    } catch (_) {
      /* Display still works if local preferences cannot be read. */
    }
    return true;
  }

  Future<void> hideToday(String scope, DateTime now) =>
      storage.write(key: key(scope), value: day(now));

  Future<void> acknowledge(
    String scope,
    DateTime now, {
    required bool hide,
  }) async {
    final current = day(now);
    _acknowledged.removeWhere((value) => !value.endsWith('/$current'));
    _acknowledged.add('${key(scope)}/$current');
    if (hide) await hideToday(scope, now);
  }
}
