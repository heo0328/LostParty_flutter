import 'package:drift/native.dart';
import 'package:lost_party/features/account/data/local/account_database.dart';

/// Uses the real in-memory SQL queries, with a stable notification cutoff.
class FixedClockAccountDatabase extends AccountDatabase {
  FixedClockAccountDatabase({DateTime? now})
    : _now = now ?? DateTime.utc(2026, 9, 10),
      super(NativeDatabase.memory());

  final DateTime _now;

  @override
  Future<List<PartyNotificationReceipt>> loadRecentPartyNotifications(
    String playerId, {
    int? limit = 20,
    DateTime? now,
  }) => super.loadRecentPartyNotifications(
    playerId,
    limit: limit,
    now: now ?? _now,
  );

  @override
  Future<int> countUnreadPartyNotifications(String playerId, {DateTime? now}) =>
      super.countUnreadPartyNotifications(playerId, now: now ?? _now);
}
