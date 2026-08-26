import 'package:flutter/foundation.dart';

import '../../../account/data/local/account_database.dart';
import '../../domain/services/party_event_sync_service.dart';
import '../party_notification_message.dart';

class PartyNotificationItem {
  const PartyNotificationItem({
    required this.eventId,
    required this.type,
    required this.recruitmentId,
    required this.message,
    required this.occurredAt,
    required this.isRead,
    required this.route,
  });

  final String eventId;
  final String type;
  final String recruitmentId;
  final String message;
  final DateTime occurredAt;
  final bool isRead;
  final String route;
}

class PartyNotificationViewState {
  const PartyNotificationViewState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = true,
    this.isSyncing = false,
    this.hasLoadFailure = false,
    this.syncFailure,
  });

  final List<PartyNotificationItem> items;
  final int unreadCount;
  final bool isLoading;
  final bool isSyncing;
  final bool hasLoadFailure;
  final PartyEventSyncFailure? syncFailure;

  bool get isEmpty => !isLoading && !hasLoadFailure && items.isEmpty;

  PartyNotificationViewState copyWith({
    List<PartyNotificationItem>? items,
    int? unreadCount,
    bool? isLoading,
    bool? isSyncing,
    bool? hasLoadFailure,
    PartyEventSyncFailure? syncFailure,
    bool clearSyncFailure = false,
  }) {
    return PartyNotificationViewState(
      items: items ?? this.items,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      hasLoadFailure: hasLoadFailure ?? this.hasLoadFailure,
      syncFailure: clearSyncFailure ? null : (syncFailure ?? this.syncFailure),
    );
  }
}

class PartyNotificationViewModel extends ChangeNotifier {
  PartyNotificationViewModel({
    required AccountDatabase database,
    required String playerId,
    required PartyEventSyncService syncService,
  }) : _database = database,
       _playerId = playerId,
       _syncService = syncService;

  final AccountDatabase _database;
  final String _playerId;
  final PartyEventSyncService _syncService;

  PartyNotificationViewState _state = const PartyNotificationViewState();
  var _disposed = false;

  PartyNotificationViewState get state => _state;

  Future<void> initialize() async {
    await load();
    if (_state.hasLoadFailure) return;
    await syncNow();
  }

  Future<void> load() async {
    await _readLocal(isSyncing: _state.isSyncing);
  }

  Future<void> syncNow() async {
    if (_state.isSyncing) return;
    _emit(_state.copyWith(isSyncing: true, clearSyncFailure: true));
    final result = await _syncService.sync();
    if (_disposed) return;
    await _readLocal(isSyncing: false, syncFailure: result.failure);
  }

  Future<void> openItem(PartyNotificationItem item) async {
    if (!item.isRead) {
      await _database.markPartyNotificationRead(item.eventId);
    }
    if (_disposed) return;
    await _readLocal(isSyncing: _state.isSyncing);
  }

  Future<void> _readLocal({
    required bool isSyncing,
    PartyEventSyncFailure? syncFailure,
  }) async {
    try {
      final rows = await _database.loadRecentPartyNotifications(_playerId);
      final unread = await _database.countUnreadPartyNotifications(_playerId);
      if (_disposed) return;
      _emit(
        PartyNotificationViewState(
          items: [
            for (final row in rows)
              PartyNotificationItem(
                eventId: row.eventId,
                type: row.type,
                recruitmentId: row.recruitmentId,
                message: PartyNotificationMessage.format(
                  type: row.type,
                  characterNameSnapshot: row.characterNameSnapshot,
                ),
                occurredAt: row.occurredAt,
                isRead: row.readAt != null,
                route: PartyNotificationMessage.routeFor(
                  type: row.type,
                  recruitmentId: row.recruitmentId,
                ),
              ),
          ],
          unreadCount: unread,
          isLoading: false,
          isSyncing: isSyncing,
          syncFailure: syncFailure,
        ),
      );
    } catch (_) {
      if (_disposed) return;
      _emit(
        PartyNotificationViewState(
          isLoading: false,
          isSyncing: isSyncing,
          hasLoadFailure: true,
          syncFailure: syncFailure,
        ),
      );
    }
  }

  void _emit(PartyNotificationViewState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
