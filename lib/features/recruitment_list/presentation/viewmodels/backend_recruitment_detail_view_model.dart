import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/domain/account_read_session.dart';
import '../../domain/backend_recruitment.dart';

class BackendRecruitmentDetailViewModel extends ChangeNotifier {
  BackendRecruitmentDetailViewModel({
    required this.gateway,
    required this.session,
    required this.roomId,
  }) {
    session.addListener(_sessionChanged);
    _binding = (session.userId, session.generation);
  }
  final RecruitmentGateway gateway;
  final AccountReadSession session;
  final String roomId;
  late (String?, int) _binding;
  bool _disposed = false, loading = false;
  int _epoch = 0;
  BackendRecruitmentDetail? value;
  RaidCatalog? catalog;
  String? failure;
  String? groupName;
  void _sessionChanged() {
    final binding = (session.userId, session.generation);
    if (binding == _binding && session.isAuthenticated) return;
    _binding = binding;
    _epoch++;
    value = null;
    catalog = null;
    groupName = null;
    loading = false;
    failure = null;
    notifyListeners();
    if (session.isAuthenticated) unawaited(load());
  }

  bool _current(int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      session.isAuthenticated &&
      _binding == (session.userId, session.generation);
  Future<void> load() async {
    if (_disposed || loading || !session.isAuthenticated) return;
    final epoch = ++_epoch;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      final detail = await gateway.detail(roomId);
      if (!_current(epoch)) return;
      value = detail;
      if (detail.room['group_id'] != null) {
        try {
          final groups = await gateway.groups();
          if (_current(epoch)) {
            groupName = groups
                .where((g) => g.id == detail.room['group_id'])
                .firstOrNull
                ?.name;
          }
        } catch (_) {
          /* A lost group membership must not hide the existing room. */
        }
      }
      // Failure of display labels cannot erase an acknowledged room/detail.
      try {
        final labels = await gateway.catalog();
        if (_current(epoch)) catalog = labels;
      } catch (_) {
        /* Keep server identifiers if the public catalog is unavailable. */
      }
    } on AccountReadException catch (e) {
      if (_current(epoch)) {
        failure = e.code;
        value = null;
      }
    } catch (_) {
      if (_current(epoch)) {
        failure = 'INVALID_RESPONSE';
        value = null;
      }
    } finally {
      if (_current(epoch)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
