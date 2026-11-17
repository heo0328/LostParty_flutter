import '../../../shared/backend/server_analysis_wire.dart';
import 'role_summary.dart';

/// A current server observation; never derives eligibility from local levels.
class AnalysisCandidates {
  AnalysisCandidates(Map<String, dynamic> json) {
    ServerAnalysisWire.definition('CandidateProjection', json);
    registrationId = roleId(json['registration_id']);
    accountId = roleId(json['game_account_id']);
    ownershipRevision = rolePositive(json['ownership_revision']);
    settingsVersion = rolePositive(json['settings_version']);
    policyRevision = rolePositive(json['policy_revision']);
    items = List.unmodifiable([
      for (final raw in json['candidates'] as List)
        AnalysisCandidate(roleMap(raw), this),
    ]);
    roleCheck(items.map((c) => c.id).toSet().length == items.length);
    roleCheck(items.map((c) => c.characterId).toSet().length == items.length);
  }
  late final String registrationId, accountId;
  late final int ownershipRevision, settingsVersion, policyRevision;
  late final List<AnalysisCandidate> items;
}

class AnalysisCandidate {
  AnalysisCandidate(this.wire, this.projection) {
    id = roleId(wire['candidate_id']);
    characterId = roleId(wire['character_id']);
    if (original != null) {
      roleCheck(
        original!['character_id'] == characterId &&
            original!['expected_ownership_revision'] ==
                projection.ownershipRevision,
      );
      final context = original!['candidate_context'];
      if (context != null) roleCheck(roleMap(context)['candidate_id'] == id);
    }
    for (final k in ['next_attempt_at', 'completed_at']) {
      if (wire[k] != null) roleUtc(wire[k]);
    }
  }
  final Map<String, dynamic> wire;
  final AnalysisCandidates projection;
  late final String id, characterId;
  String get state => wire['state'] as String;
  String get eligibility => wire['eligibility'] as String;
  String? get error => wire['last_error'] == null
      ? null
      : roleMap(wire['last_error'])['code'] as String;
  Map<String, dynamic>? get original => wire['unresolved_command'] == null
      ? null
      : roleMap(roleMap(wire['unresolved_command'])['command']);
  Map<String, dynamic> context({required bool manualRetry}) => {
    'candidate_id': id,
    'expected_generation': wire['generation'],
    'expected_policy_revision': projection.policyRevision,
    'expected_settings_version': projection.settingsVersion,
    'purpose': manualRetry ? 'manual_retry' : 'automatic_candidate',
  };
}
