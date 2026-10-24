import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/domain/account_read_session.dart';
import '../../domain/backend_recruitment.dart';
import '../../../account/domain/member_cycle_models.dart';
import '../../data/membership_actions.dart';
import '../../data/membership_readers.dart';
import '../../data/backend_recruitment_repository.dart';
import '../../data/application_display.dart';

class BackendRecruitmentDetailViewModel extends ChangeNotifier {
  BackendRecruitmentDetailViewModel({
    required this.gateway,
    required this.session,
    required this.roomId,
    this.target,
    this.accessChanges,
    this.scopeKey,
    this.loadEndPermission,
    this.membershipGateway,
    this.reader,
    this.recordAnchor,
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
  final Future<bool> Function(String room, String target)? loadEndPermission;
  final MembershipActionGateway? membershipGateway;
  final MembershipReadGateway? reader;
  final MembershipRecordAnchor? recordAnchor;
  MembershipRecordAnchor? _resolvedRecordAnchor;
  MembershipRecordAnchor? get recordIdentity =>
      recordAnchor ?? _resolvedRecordAnchor;
  MembershipReadView? profile;
  bool get readOnly =>
      recordIdentity != null || profile?.projection.isRecord == true;
  MembershipActionContext? membershipMenu;
  String? membershipFailure;
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
    if (readOnly) return;
    if (cycles?.find(t) == null || target == t) return;
    _epoch++;
    loading = false;
    target = t;
    value = null;
    application = null;
    applicationKnown = false;
    profile = null;
    membershipMenu = null;
    membershipFailure = null;
    groupName = null;
    unawaited(load());
  }

  late (String?, int) _binding;
  bool _disposed = false, loading = false;
  int _epoch = 0;
  BackendRecruitmentDetail? value;
  OwnApplicationStatus? application;
  bool applicationKnown = false;
  bool get waitingForApproval =>
      value?.room['my_target_role'] == 'none' && application?.pending == true;
  bool get canStartAdmission =>
      !loading &&
      value?.room['my_target_role'] == 'none' &&
      failure == null &&
      !waitingForApproval &&
      (reader != null || cycleGateway == null || applicationKnown);
  bool nextParticipationAvailable = false, endAvailable = false;
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
    _resolvedRecordAnchor = null;
    application = null;
    applicationKnown = false;
    _epoch++;
    value = null;
    profile = null;
    membershipMenu = null;
    membershipFailure = null;
    nextParticipationAvailable = false;
    endAvailable = false;
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
    application = null;
    applicationKnown = false;
    if (reader != null) {
      value = null;
      profile = null;
    }
    nextParticipationAvailable = false;
    endAvailable = false;
    membershipMenu = null;
    membershipFailure = null;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      if (recordIdentity != null && (target == null || reader == null)) {
        throw const AccountReadException('INVALID_REQUEST');
      }
      if (cycleGateway != null && recordIdentity == null) {
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
      if (reader != null) {
        final result = await reader!.detail(
          roomId,
          target!,
          anchor: recordIdentity,
        );
        if (!_current(epoch)) return;
        profile = result;
        if (result.projection.isRecord) {
          _resolvedRecordAnchor = result.projection.locator!.anchor;
        }
        final content = result.projection.content;
        value = content == null
            ? null
            : BackendRecruitmentRepository.parseCycleDetail(
                content,
                roomId,
                target!,
              );
      }
      // An explicit historical profile never enters the current-member menu.
      if (membershipGateway != null &&
          cycleGateway != null &&
          !readOnly &&
          (reader == null || profile!.projection.canReadMenu)) {
        try {
          final menu = await membershipGateway!.membershipContext(
            roomId,
            target!,
          );
          if (!_current(epoch)) return;
          membershipMenu = menu;
        } on AccountReadException catch (e) {
          if (!_current(epoch)) return;
          membershipFailure = e.code;
        } catch (_) {
          if (!_current(epoch)) return;
          membershipFailure = 'INVALID_RESPONSE';
        }
      }
      ApplicationDisplayDetail? display;
      if (reader == null && cycleGateway != null) {
        final source = gateway;
        if (source is! ApplicationDisplayGateway) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        display = await (source as ApplicationDisplayGateway)
            .applicationDisplayDetail(roomId, target!);
        if (!_current(epoch)) return;
        application = display.application;
        applicationKnown = true;
      }
      final detail = reader != null
          ? value
          : cycleGateway == null
          ? await gateway.detail(roomId)
          : display!.detail;
      if (!_current(epoch)) return;
      value = detail;
      if (detail == null) {
        if (profile?.projection.record != null) {
          try {
            final labels = await gateway.catalog();
            if (_current(epoch)) catalog = labels;
          } catch (_) {
            /* Keep original identifiers when catalog is unavailable. */
          }
        }
        return;
      }
      notOpen.remove(target);
      if (loadEndPermission != null &&
          detail.room['state'] == 'active' &&
          cycleGateway != null &&
          detail.room['my_target_role'] == 'leader' &&
          detail.memberCount == 1) {
        try {
          final allowed = await loadEndPermission!(roomId, target!);
          if (!_current(epoch)) return;
          endAvailable = allowed;
        } catch (_) {
          // A missing global permission never implies a one-person room.
        }
      }
      if (!readOnly &&
          cycleGateway != null &&
          detail.room['state'] == 'active' &&
          target == cycles!.current.key &&
          detail.room['continuation_enabled'] == true &&
          {'leader', 'member'}.contains(detail.room['my_target_role'])) {
        try {
          if (reader != null) {
            final next = await reader!.detail(roomId, cycles!.next.key);
            if (!_current(epoch)) return;
            nextParticipationAvailable =
                !next.projection.isRecord &&
                next.projection.target['target_state'] == 'open' &&
                next.projection.viewer['cycle_member_state'] == 'not_selected';
          } else {
            final next = await cycleGateway!.cycleDetail(
              roomId,
              cycles!.next.key,
            );
            if (!_current(epoch)) return;
            nextParticipationAvailable =
                next.room['target_state'] == 'open' &&
                next.room['my_target_role'] == 'none';
          }
          if (!_current(epoch)) return;
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
        profile = null;
        if (e.code == 'TARGET_NOT_OPEN' && target != null) notOpen.add(target!);
        value = null;
      }
    } catch (_) {
      if (_current(epoch)) {
        failure = 'INVALID_RESPONSE';
        profile = null;
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
