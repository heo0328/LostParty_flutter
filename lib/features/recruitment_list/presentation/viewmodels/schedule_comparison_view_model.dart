import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/cycle_schedule.dart';
import '../../data/schedule_comparison_projection.dart';
import '../../data/membership_readers.dart';
import '../../domain/schedule_comparison.dart';
import 'cycle_participation_controller.dart';

/// Owns only this room/week's display snapshot; commands remain app-owned.
class ScheduleComparisonViewModel extends ChangeNotifier {
  ScheduleComparisonViewModel({
    required this.controller,
    required this.room,
    required this.target,
    this.reader,
    this.anchor,
    this.forceReadOnly = false,
  }) : binding = controller.scopeKey() {
    controller.addListener(_access);
    controller.session.addListener(_access);
  }
  final CycleParticipationController controller;
  final String room, target, binding;
  final MembershipReadGateway? reader;
  final MembershipRecordAnchor? anchor;
  final bool forceReadOnly;
  bool loading = false, disposed = false, readOnly = false;
  int epoch = 0, weekday = 3;
  String? failure;
  CycleScheduleView? plan, contextView;
  MembershipReadView? profile;
  ScheduleComparison? comparison;
  final selected = <String>{};
  bool get valid =>
      !disposed &&
      controller.session.isAuthenticated &&
      binding == controller.scopeKey();
  void _access() {
    if (valid || disposed) return;
    epoch++;
    plan = null;
    contextView = null;
    comparison = null;
    profile = null;
    selected.clear();
    loading = false;
    failure = 'SESSION_CHANGED';
    notifyListeners();
  }

  Future<void> load() async {
    if (!valid || loading || !controller.canAct) return;
    final e = ++epoch;
    loading = true;
    failure = null;
    notifyListeners();
    try {
      CycleScheduleView? p;
      MembershipReadView? nextProfile;
      if (reader != null) {
        nextProfile = await reader!.plan(
          room,
          target,
          anchor: anchor,
          includeCoordinationWait: anchor == null && !forceReadOnly,
        );
        if (!valid || e != epoch) return;
        final content = nextProfile.projection.content;
        if (content != null) {
          p = CycleScheduleView(
            room,
            target,
            'plan',
            content,
            betaData: nextProfile.betaData,
          );
        }
      } else {
        p = await controller.scheduleRead(room, target, 'plan');
      }
      if (!valid || e != epoch) return;
      final ro =
          forceReadOnly ||
          anchor != null ||
          nextProfile?.projection.readOnly == true ||
          p?.data['target_state'] == 'ended';
      CycleScheduleView? context;
      if (p != null && !ro) {
        context = await controller.scheduleRead(room, target, 'context');
        if (!valid || e != epoch) return;
        if (context == null) {
          throw StateError(controller.failure ?? 'INVALID_RESPONSE');
        }
        final permission = context.data['permissions']['view_schedule_context'];
        if (permission['allowed'] != true) {
          throw StateError(permission['reason'] ?? 'FORBIDDEN');
        }
        if (context.scope['room_cycle_id'] != p.scope['room_cycle_id'] ||
            context.scope['target_generation'] !=
                p.scope['target_generation'] ||
            context.scope['target_revision'] != p.scope['target_revision'] ||
            context.data['plan_revision'] != p.data['revision'] ||
            context.data['members_revision'] != p.data['members_revision'] ||
            scheduleStable(context.betaData?['beta_schedule']) !=
                scheduleStable(p.betaData?['beta_schedule'])) {
          throw StateError('REVISION_CONFLICT');
        }
      }
      final rows = context == null ? null : scheduleComparisonFromView(context);
      final oldIds = comparison?.members.map((m) => m.id).toSet() ?? <String>{};
      final ids = rows?.members.map((m) => m.id).toSet() ?? <String>{};
      selected.removeWhere((id) => !ids.contains(id));
      selected.addAll(ids.difference(oldIds));
      profile = nextProfile;
      plan = p;
      contextView = context;
      comparison = rows;
      readOnly = ro;
      if (p == null && nextProfile == null) {
        throw StateError(controller.failure ?? 'INVALID_RESPONSE');
      }
    } catch (error) {
      if (valid && e == epoch) {
        failure = error is StateError
            ? error.message.toString()
            : error is AccountReadException
            ? error.code
            : 'INVALID_RESPONSE';
      }
    } finally {
      if (valid && e == epoch) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void selectDay(int value) {
    if (!valid) return;
    weekday = value;
    notifyListeners();
  }

  void toggle(String id, bool value) {
    if (!valid || comparison?.members.any((m) => m.id == id) != true) return;
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  List<TimeSpan>? get common => comparison?.common(weekday, selected);
  @override
  void dispose() {
    disposed = true;
    epoch++;
    controller.removeListener(_access);
    controller.session.removeListener(_access);
    plan = null;
    contextView = null;
    comparison = null;
    profile = null;
    selected.clear();
    super.dispose();
  }
}
