import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/domain/account_read_session.dart';
import '../../domain/backend_recruitment.dart';
import '../../../account/domain/member_cycle_models.dart';

class BackendRecruitmentDetailViewModel extends ChangeNotifier {
  BackendRecruitmentDetailViewModel({
    required this.gateway,
    required this.session,
    required this.roomId,
    this.target,
    this.accessChanges,
    this.scopeKey,
  }) {
    session.addListener(_sessionChanged);
    accessChanges?.addListener(_sessionChanged);
    _scopeBinding = scopeKey?.call();
    _binding = (session.userId, session.generation);
  }
  final RecruitmentGateway gateway;
  final AccountReadSession session;
  final String roomId;
  final Listenable? accessChanges;
  final String Function()? scopeKey;
  String? _scopeBinding;
  String? target;
  MemberCycles? cycles;
  Timer? _cycleTimer;
  final notOpen = <String>{};
  CycleRecruitmentGateway? get cycleGateway =>
      gateway is CycleRecruitmentGateway &&
          (gateway as CycleRecruitmentGateway).twoCycleEnabled
      ? gateway as CycleRecruitmentGateway
      : null;
  void selectCycle(String t) {
    if (cycles?.find(t) == null || target == t) return;
    _epoch++;
    loading = false;
    target = t;
    value = null;
    groupName = null;
    unawaited(load());
  }

  late (String?, int) _binding;
  bool _disposed = false, loading = false;
  int _epoch = 0;
  BackendRecruitmentDetail? value;
  bool nextParticipationAvailable = false;
  RaidCatalog? catalog;
  String? failure;
  String? groupName;
  void _sessionChanged() {
    final binding = (session.userId, session.generation);
    if (binding == _binding &&
        session.isAuthenticated &&
        _scopeBinding == scopeKey?.call()) {
      return;
    }
    _scopeBinding = scopeKey?.call();
    _binding = binding;
    _epoch++;
    value = null;
    nextParticipationAvailable = false;
    cycles = null;
    notOpen.clear();
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
      _binding == (session.userId, session.generation) &&
      _scopeBinding == scopeKey?.call();
  Future<void> load() async {
    if (_disposed || loading || !session.isAuthenticated) return;
    final epoch = ++_epoch;
    nextParticipationAvailable = false;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      if (cycleGateway != null) {
        final meta = await cycleGateway!.cycles();
        if (!_current(epoch)) return;
        cycles = meta;
        _cycleTimer?.cancel();
        _cycleTimer = Timer(
          meta.current.endsAt.difference(meta.serverNow),
          () => unawaited(load()),
        );
        target ??= meta.current.key;
        if (meta.find(target!) == null) {
          throw const AccountReadException('TARGET_CYCLE_OUT_OF_RANGE');
        }
      }
      final detail = cycleGateway == null
          ? await gateway.detail(roomId)
          : await cycleGateway!.cycleDetail(roomId, target!);
      if (!_current(epoch)) return;
      value = detail;
      notOpen.remove(target);
      if (cycleGateway != null &&
          target == cycles!.current.key &&
          detail.room['continuation_enabled'] == true &&
          {'leader', 'member'}.contains(detail.room['my_target_role'])) {
        try {
          final next = await cycleGateway!.cycleDetail(
            roomId,
            cycles!.next.key,
          );
          if (!_current(epoch)) return;
          nextParticipationAvailable =
              next.room['target_state'] == 'open' &&
              next.room['my_target_role'] == 'none';
        } catch (_) {
          // Unknown or unopened next-cycle state never exposes a join shortcut.
        }
      }
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
        if (e.code == 'TARGET_NOT_OPEN' && target != null) notOpen.add(target!);
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
    _cycleTimer?.cancel();
    session.removeListener(_sessionChanged);
    accessChanges?.removeListener(_sessionChanged);
    super.dispose();
  }
}
