import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../account/domain/role_summary.dart';
import '../../../account/domain/member_raid_models.dart';
import '../cycle_interaction_repository.dart';
import '../cycle_member_actions.dart';
import '../membership_actions.dart';
import 'beta_contract.dart';

/// ACK expectations, not a restored permission/context or a screen snapshot.
class ParticipationCommandEvidence {
  ParticipationCommandEvidence(Map<String, dynamic> json)
    : wire = betaFreeze(json) as Map<String, dynamic> {
    roleShape(
      wire,
      'kind room target scope application_id application_state affected_targets global_ack submission_ack details request_hash checksum',
    );
    roleCheck(wire['checksum'] == _digest({...wire}..remove('checksum')));
    roleId(room);
    raidCycleKey(target);
    roleMap(wire['scope']);
    roleCheck(
      {
        'basic',
        'application',
        'submission',
        'global',
        'membership',
        'removal',
        'departure',
      }.contains(kind),
    );
    for (final t in affected) {
      raidCycleKey(t);
    }
    roleCheck(
      affected.length <= 2 && affected.toSet().length == affected.length,
    );
    roleCheck({'membership', 'global'}.contains(kind) || affected.isNotEmpty);
    if (kind == 'membership') {
      final e = MembershipAckEvidence(details);
      roleCheck(
        e.room == room &&
            e.view == target &&
            cycleStableJson(e.affected) == cycleStableJson(affected),
      );
    }
    if (kind == 'removal') {
      final e = RemovalAckEvidence(details);
      roleCheck(
        e.room == room &&
            e.target == target &&
            cycleStableJson(e.option['impact']['affected_cycle_keys']) ==
                cycleStableJson(affected),
      );
    }
    if (kind == 'departure') {
      final e = DepartureAckEvidence(details);
      roleCheck(
        e.room == room &&
            e.target == target &&
            affected.length == 1 &&
            affected.single == target,
      );
    }
    if (kind == 'application') {
      if (wire['application_id'] != null) roleId(wire['application_id']);
      roleCheck(
        {
          'pending',
          'accepted',
          'rejected',
          'withdrawn',
        }.contains(wire['application_state']),
      );
    }
    roleCheck((kind == 'submission') == (wire['submission_ack'] != null));
    roleCheck((kind == 'global') == (wire['global_ack'] != null));
    roleCheck(
      {'membership', 'removal', 'departure'}.contains(kind) ==
          (wire['details'] != null),
    );
  }
  factory ParticipationCommandEvidence.create({
    required String kind,
    required String room,
    required String target,
    required Map<String, dynamic> scope,
    String? applicationId,
    String? applicationState,
    required List<String> affected,
    String? globalAck,
    Map<String, dynamic>? submissionAck,
    Map<String, dynamic>? details,
    required String method,
    required String path,
    required String rawQuery,
    required String rawBody,
    required String key,
    required int status,
    required List<String> targets,
  }) {
    final j = <String, dynamic>{
      'kind': kind,
      'room': room,
      'target': target,
      'scope': scope,
      'application_id': applicationId,
      'application_state': applicationState,
      'affected_targets': affected,
      'global_ack': globalAck,
      'submission_ack': submissionAck,
      'details': details,
      'request_hash': requestHash(
        method,
        path,
        rawQuery,
        rawBody,
        key,
        status,
        targets,
      ),
    };
    return ParticipationCommandEvidence({...j, 'checksum': _digest(j)});
  }
  static String _digest(Object? value) =>
      sha256.convert(utf8.encode(cycleStableJson(value))).toString();
  static String requestHash(
    String method,
    String path,
    String query,
    String body,
    String key,
    int status,
    List<String> targets,
  ) => _digest([method, path, query, body, key, status, targets]);
  final Map<String, dynamic> wire;
  String get kind => wire['kind'] as String;
  String get room => wire['room'] as String;
  String get target => wire['target'] as String;
  Map<String, dynamic> get scope => roleMap(wire['scope']);
  Map<String, dynamic> get details => roleMap(wire['details']);
  List<String> get affected => List<String>.unmodifiable(
    raidList(wire['affected_targets']).cast<String>(),
  );
  void bind(
    String method,
    String path,
    String query,
    String body,
    String key,
    int status,
    List<String> targets,
  ) {
    roleCheck(
      wire['request_hash'] ==
          requestHash(method, path, query, body, key, status, targets),
    );
    roleCheck(targets.contains(target) && affected.every(targets.contains));
    roleCheck(
      !path.contains('weekly-incomplete-closures') && !path.contains('resume'),
    );
    final b = roleMap(jsonDecode(body));
    roleCheck((kind == 'membership') == path.endsWith('/membership-actions'));
    roleCheck((kind == 'removal') == path.endsWith('/member-removals'));
    roleCheck(
      (kind == 'departure') == path.endsWith('/personal-completion-departures'),
    );
    roleCheck(
      (kind == 'submission') ==
          (path.endsWith('/availability-submission') && method == 'PUT'),
    );
    roleCheck(
      (kind == 'global') ==
          {'common-settings', 'leave', 'end'}.contains(path.split('/').last),
    );
    roleCheck(
      b['expected_cycle_key'] == null ||
          b['expected_cycle_key'] == scope['current_cycle_key'],
    );
    if (kind == 'membership') {
      roleCheck(b['actor_membership_id'] == details['actor']['membership_id']);
    }
    if (kind == 'removal') {
      roleCheck(
        b['target_membership_id'] == details['membership'] &&
            b['target_cycle_member_id'] == details['member'],
      );
    }
    if (kind == 'departure') {
      roleCheck(
        b['actor_cycle_member_id'] == details['subject']['cycle_member_id'] &&
            b['expected_cycle_member_revision'] ==
                details['subject']['cycle_member_revision'],
      );
    }

    roleCheck(b['view_cycle_key'] == null || b['view_cycle_key'] == target);
    roleCheck(b['target_cycle_key'] == null || b['target_cycle_key'] == target);
    if (kind == 'membership') {
      roleCheck(
        path == '/v2/raid-rooms/$room/membership-actions' &&
            b['action'] == details['action'],
      );
    }
    if (kind == 'removal') {
      roleCheck(path == '/v2/raid-rooms/$room/member-removals');
    }
    if (kind == 'departure') {
      roleCheck(path == '/v2/raid-rooms/$room/personal-completion-departures');
    }
  }

  /// Returns only the membership result needed for existing exit/navigation rules.
  MembershipActionResult? validate(
    Map<String, dynamic> raw, {
    required String method,
    required String path,
    required String key,
    required int status,
    required RecruitmentContractMode mode,
  }) {
    final j = mode == RecruitmentContractMode.betaWire2
        ? BetaResponse.parse(
            method: method,
            path: path,
            status: status,
            json: raw,
            parseLegacy: (v) => v,
          ).value
        : raw;
    if (kind == 'membership') {
      return MembershipActionResult.fromEvidence(
        j,
        MembershipAckEvidence(details),
        key,
      );
    }
    if (kind == 'removal') {
      validateRemovalEvidenceResult(j, RemovalAckEvidence(details), key);
      return null;
    }
    if (kind == 'departure') {
      validateDepartureEvidenceResult(j, DepartureAckEvidence(details), key);
      return null;
    }
    validateCycleWriteResult(
      j,
      path: path,
      key: key,
      room: room,
      target: target,
      applicationAck: kind == 'application',
      applicationId: wire['application_id'] as String?,
      applicationState: wire['application_state'] as String?,
      expectedScope: scope,
      globalAck: wire['global_ack'] as String?,
      affectedTargets: affected,
      submissionAck: wire['submission_ack'] == null
          ? null
          : roleMap(wire['submission_ack']),
    );
    return null;
  }
}
