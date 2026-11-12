import '../../account/domain/role_summary.dart';
import 'beta/beta_contract.dart';
import 'cycle_read_repository.dart';

/// Minimal search projection. Never parsed as a rich room/detail response.
class DiscoveryCard implements RecruitmentSearchCard {
  DiscoveryCard(
    Map<String, dynamic> json,
    String target,
    Map<String, dynamic>? group,
  ) : wire = betaFreeze(json) as Map<String, dynamic> {
    BetaContract.definition('DiscoveryCard', json);
    roleCheck(json['target_cycle_key'] == target);
    betaData = group;
  }
  @override
  final Map<String, dynamic> wire;
  @override
  late final Map<String, dynamic>? betaData;
  Map<String, dynamic>? get schedule =>
      wire['schedule'] == null ? null : roleMap(wire['schedule']);
  @override
  String get id => wire['room_id'] as String;
  @override
  String get title => wire['title'] as String;
  @override
  int get capacity => wire['app_capacity'] as int;
  @override
  int get count => wire['app_member_count'] as int;
  @override
  bool get canView =>
      roleMap(wire['view_detail_permission'])['allowed'] == true;
  @override
  List<Map<String, dynamic>> get items =>
      (wire['items'] as List).map((v) => roleMap(v)).toList(growable: false);
  @override
  List<DateTime> get starts => schedule != null
      ? [roleUtc(schedule!['effective_starts_at'])]
      : (roleMap(wire['schedule_summary'])['confirmed_starts_at'] as List)
            .map(roleUtc)
            .toList(growable: false);
}
