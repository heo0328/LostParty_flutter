import 'dart:convert';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/member_raid_models.dart';
import '../../../account/domain/role_summary.dart';
import '../../../account/domain/server_registration_api.dart';
import '../../domain/backend_recruitment.dart';
import '../../domain/policies/recruitment_start_policy.dart';
import '../../domain/policies/party_cycle_policy.dart';
import 'beta_contract.dart';
import 'cycle_group_policy.dart';
import 'recruitment_command.dart';

abstract interface class BetaCreationGateway {
  bool get betaContractActive;
  RecruitmentCommand prepareBetaCreation(
    RecruitmentDraft draft,
    RecruitmentCreationContext context,
    String title,
    String key,
    DateTime createdAt,
  );
}

BetaCreationDraft betaScheduleTargets(RecruitmentDraft draft) {
  final target = raidCycleKey(draft.targetCycleKey);
  final next = const PartyCyclePolicy().keyFor(
    const PartyCyclePolicy().fromKey(target)!.endsAt,
  );
  final values = <String, BetaScheduleConfig>{};
  for (final t in [target, if (draft.continueTogether) next]) {
    final input = draft.betaSchedules[t];
    roleCheck(input?.weekday != null && input?.minute != null);
    final date = const RecruitmentStartPolicy().dateForDay(
      DateTime.utc(2000),
      input!.weekday!,
      targetCycleKey: t,
    );
    final start = date
        .add(Duration(minutes: input.minute!))
        .subtract(const Duration(hours: 9));
    values[t] = BetaScheduleConfig({
      'base_starts_at': start.toIso8601String(),
      'early_coordination_enabled': input.enabled,
      'early_additional_members': input.enabled ? input.additional : null,
    });
  }
  return BetaCreationDraft(values);
}

class BetaCreationReader {
  const BetaCreationReader(this.api);
  final BackendRegistrationApi api;
  static const contract = BetaContract(mode: RecruitmentContractMode.betaWire2);
  Future<RecruitmentCreationContext> context(RecruitmentDraft draft) async {
    roleCheck(draft.groupOnly || draft.groupId == null);
    final targets = betaScheduleTargets(draft).targets;
    final current = targets.values.first;
    final next = targets.length == 2 ? targets.values.last : null;
    final query = contract.query('GET', '/v2/me/raid-room-creation-context', {
      'target_cycle_key': draft.targetCycleKey,
      'continuation_enabled': draft.continueTogether,
      'character_id': draft.characterId,
      'selected_role': draft.role,
      'items': jsonEncode(draft.items.map((i) => i.choice).toList()),
      if (draft.groupId != null) 'group_id': draft.groupId,
      'base_starts_at': current.wire['base_starts_at'],
      'early_coordination_enabled': current.enabled,
      if (current.enabled)
        'early_additional_members': current.additionalMembers,
      if (next != null) ...{
        'next_base_starts_at': next.wire['base_starts_at'],
        'next_early_coordination_enabled': next.enabled,
        if (next.enabled)
          'next_early_additional_members': next.additionalMembers,
      },
    });
    contract.validateRequest(
      'GET',
      '/v2/me/raid-room-creation-context',
      query,
      null,
    );
    final raw = (await api.request(
      '/v2/me/raid-room-creation-context',
      query: query,
    ))!;
    final parsed = BetaResponse.parse(
      method: 'GET',
      path: '/v2/me/raid-room-creation-context',
      status: 200,
      json: raw,
      parseLegacy: (j) {
        roleCheck(
          j['scope']['target_cycle_key'] == draft.targetCycleKey &&
              j['scope']['current_cycle_key'] ==
                  j['data']['expected_cycle_key'],
        );
        return RecruitmentCreationContext.fromCycleJson(
          roleMap(j['data']),
          draft,
        );
      },
    );
    final actual = parsed.metadata['data']['beta_schedule_targets'] as List;
    roleCheck(actual.length == targets.length);
    roleCheck(
      actual.map((v) => v['target_cycle_key']).toSet().length == targets.length,
    );
    for (final t in actual) {
      final config = targets[t['target_cycle_key']];
      roleCheck(
        config != null &&
            roleUtc(t['base_starts_at']) == config.startsAt &&
            t['early_coordination_enabled'] == config.enabled &&
            t['early_additional_members'] == config.additionalMembers,
      );
    }
    return parsed.value;
  }

  static RecruitmentCommand prepare(
    RecruitmentDraft draft,
    RecruitmentCreationContext context,
    String title,
    String key,
    DateTime createdAt,
  ) {
    roleCheck(draft.groupOnly || draft.groupId == null);
    final body = draft.body(context, title)..remove('schedule_groups');
    body['beta_schedule_targets'] = betaScheduleTargets(draft).toWire();
    final evidence = {
      'room_id': context.prospectiveRoomId,
      'target_cycle_key': context.targetKey,
      'effect': context.effect,
      'created_cycles': [
        for (final p in context.prospective!)
          {
            'target_cycle_key': p['target_cycle_key'],
            'room_cycle_id': p['room_cycle_id'],
            'generation': p['generation'],
            'target_revision': p['initial_target_revision'],
          },
      ],
    };
    return RecruitmentCommand(
      owner: RecruitmentCommandOwner.creation,
      operation: 'contract3_post__v2_raid-rooms',
      method: 'POST',
      path: '/v2/raid-rooms',
      query: contract.query('POST', '/v2/raid-rooms'),
      targetCycles: betaScheduleTargets(draft).targets.keys.toList(),
      rawBody: jsonEncode(body),
      key: key,
      createdAt: createdAt.toUtc(),
      expectedStatus: 201,
      version: 2,
      validationSnapshot: evidence,
    );
  }
}

RecruitmentCreationAck validateBetaCreationAck(
  RecruitmentCommand command,
  Map<String, dynamic> raw,
) {
  final evidence = command.validationSnapshot;
  if (evidence == null) {
    throw const AccountReadException('REQUEST_REVIEW_REQUIRED');
  }
  roleShape(evidence, 'room_id target_cycle_key effect created_cycles');
  raw = withoutCycleGroupFields(raw);
  roleShape(raw, 'scope data');
  final ack = RecruitmentCreationAck.fromCycleJson(
    roleMap(raw['data']),
    command.key,
    roleMap(jsonDecode(command.rawBody)),
  );
  roleCheck(
    ack.roomId == evidence['room_id'] &&
        ack.targetKey == evidence['target_cycle_key'] &&
        ack.effect == evidence['effect'],
  );
  final expected = evidence['created_cycles'] as List;
  roleCheck(ack.created!.length == expected.length);
  for (final p in expected) {
    final actual = ack.created!
        .where((a) => a['target_cycle_key'] == p['target_cycle_key'])
        .single;
    for (final k in ['room_cycle_id', 'generation', 'target_revision']) {
      roleCheck(actual[k] == p[k]);
    }
    if (p['target_cycle_key'] == ack.targetKey) {
      roleCheck(
        raw['scope']['room_cycle_id'] == p['room_cycle_id'] &&
            raw['scope']['target_generation'] == p['generation'] &&
            raw['scope']['target_revision'] == p['target_revision'],
      );
    }
  }
  return ack;
}
