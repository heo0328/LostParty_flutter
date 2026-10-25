import 'dart:convert';
import 'beta/beta_contract.dart';
import 'beta/beta_read.dart';
import 'beta/beta_interaction_api.dart';
import 'admission_candidates.dart';
import 'application_display.dart';
import 'application_messages.dart';
import 'cycle_member_actions.dart';
import 'membership_actions.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import '../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../domain/backend_recruitment.dart';
import 'cycle_read_repository.dart';
import 'group_character_candidates.dart';
import 'cycle_management.dart';
import 'cycle_schedule.dart';
import 'cycle_outcome.dart';
import 'cycle_resume.dart';
import 'cycle_session_display.dart';

String cycleStableJson(Object? value) {
  Object? canonical(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: canonical(v[k])};
    }
    if (v is List) return v.map(canonical).toList();
    return v;
  }

  return jsonEncode(canonical(value));
}

class CycleSearchFilter {
  CycleSearchFilter({
    this.category = 'all',
    this.admissionScope,
    String? groupId,
    Set<String> groupIds = const {},
    this.token,
    this.candidateToken,
    Set<String> raids = const {},
    Set<String> difficulties = const {},
    Set<String> experiences = const {},
    Set<int> remaining = const {},
    this.descending = true,
    Map<String, Set<String>> members = const {},
  }) : groupIds = Set.unmodifiable(groupId == null ? groupIds : {groupId}),
       raids = Set.unmodifiable(raids),
       difficulties = Set.unmodifiable(difficulties),
       experiences = Set.unmodifiable(experiences),
       remaining = Set.unmodifiable(remaining),
       members = Map.unmodifiable({
         for (final e in members.entries)
           e.key: Set<String>.unmodifiable(e.value),
       });
  final String category;
  final String? admissionScope, token, candidateToken;
  final Set<String> groupIds;
  String? get groupId => groupIds.length == 1 ? groupIds.single : null;
  final Set<String> raids, difficulties, experiences;
  final Set<int> remaining;
  final bool descending;
  final Map<String, Set<String>> members;
  CycleSearchFilter copy({
    String? category,
    String? admissionScope,
    bool clearScope = false,
    String? groupId,
    Set<String>? groupIds,
    bool clearGroup = false,
    String? token,
    String? candidateToken,
    bool clearCandidateToken = false,
    Set<String>? raids,
    Set<String>? difficulties,
    Set<String>? experiences,
    Set<int>? remaining,
    bool? descending,
    Map<String, Set<String>>? members,
  }) => CycleSearchFilter(
    category: category ?? this.category,
    admissionScope: clearScope ? null : admissionScope ?? this.admissionScope,
    groupIds:
        groupIds ??
        (clearGroup
            ? {}
            : groupId != null
            ? {groupId}
            : this.groupIds),
    token: clearGroup ? null : token ?? this.token,
    candidateToken: clearGroup || clearCandidateToken
        ? null
        : candidateToken ?? this.candidateToken,
    raids: raids ?? this.raids,
    difficulties: difficulties ?? this.difficulties,
    experiences: experiences ?? this.experiences,
    remaining: remaining ?? this.remaining,
    descending: descending ?? this.descending,
    members: clearGroup ? {} : members ?? this.members,
  );
  Map<String, dynamic> body(String target, {String? cursor}) {
    roleCheck({'all', 'general', 'group_linked'}.contains(category));
    roleCheck(
      admissionScope == null || {'public', 'group'}.contains(admissionScope),
    );
    for (final id in groupIds) {
      roleId(id);
    }
    roleCheck(members.isEmpty || (groupId != null && token != null));
    if (candidateToken != null) {
      candidateHex(candidateToken);
      roleCheck(groupId != null && token != null);
    }
    for (final e in members.entries) {
      roleCheck(e.key.length == 64);
      for (final id in e.value) {
        roleId(id);
      }
    }
    roleCheck(remaining.every((n) => n >= 1 && n <= 7));
    roleCheck(
      experiences.every(
        (e) => e == 'unrestricted' || recruitmentExperiences.containsKey(e),
      ),
    );
    final refs = members.keys.toList()..sort();
    return {
      'target_cycle_key': raidCycleKey(target),
      'category': category,
      'admission_scope': admissionScope,
      'group_ids': groupIds.toList()..sort(),
      'filter_context_token': members.isEmpty && candidateToken == null
          ? null
          : token,
      if (candidateToken != null)
        'group_character_candidates_token': candidateToken,
      'member_conditions': [
        for (final ref in refs)
          {'member_ref': ref, 'character_ids': members[ref]!.toList()..sort()},
      ],
      'raid_ids': raids.toList()..sort(),
      'difficulty_ids': difficulties.toList()..sort(),
      'experience_levels': experiences.toList()..sort(),
      'sort': {
        'criterion': 'member_count',
        'direction': descending ? 'descending' : 'ascending',
      },
      'remaining_slot_counts': remaining.toList()..sort(),
      'limit': 20,
      'cursor': cursor,
    };
  }

  String get signature => jsonEncode(body('2026-10-21'));
}

class CycleSearchPage {
  CycleSearchPage(Map<String, dynamic> j, String target) {
    roleShape(j, 'scope data');
    CycleReadScope(roleMap(j['scope']), target);
    final d = roleMap(j['data']);
    roleShape(
      d,
      'items directory_revision filter_scope_digest next_cursor evaluated_at',
    );
    rolePositive(d['directory_revision']);
    roleUtc(d['evaluated_at']);
    rows = raidList(
      d['items'],
    ).map((v) => CycleRoomCard(roleMap(v), target)).toList();
    roleCheck(
      rows.length <= 20 && rows.map((r) => r.id).toSet().length == rows.length,
    );
    digest = d['filter_scope_digest'] as String?;
    cursor = d['next_cursor'] as String?;
    roleCheck(
      cursor == null ||
          (cursor!.isNotEmpty && cursor!.length <= 2048 && rows.isNotEmpty),
    );
  }
  late final List<CycleRoomCard> rows;
  late final String? cursor, digest;
}

class CycleFilterContext {
  CycleFilterContext(Map<String, dynamic> j, String group) {
    roleShape(
      j,
      'filter_context_token scope_digest evaluated_at groups members',
    );
    token = raidText(j['filter_context_token']);
    roleCheck(token.length == 64);
    scopeDigest = raidText(j['scope_digest']);
    roleUtc(j['evaluated_at']);
    final groups = raidList(j['groups']);
    roleCheck(groups.length == 1);
    final g = roleMap(groups.single);
    roleShape(g, 'group_id revision members_revision');
    roleCheck(roleId(g['group_id']) == group);
    rolePositive(g['revision']);
    rolePositive(g['members_revision']);
    members = raidList(j['members']).map((raw) {
      final m = roleMap(raw);
      roleShape(m, 'member_ref aliases display');
      roleCheck(raidText(m['member_ref']).length == 64);
      final aliases = raidList(m['aliases']);
      roleCheck(aliases.isNotEmpty);
      for (final a in aliases) {
        final v = roleMap(a);
        roleShape(v, 'group_id group_membership_id');
        roleCheck(roleId(v['group_id']) == group);
        roleId(v['group_membership_id']);
      }
      if (m['display'] != null) {
        for (final v in roleMap(m['display']).values) {
          roleCheck(v == null || v is String);
        }
      }
      return Map<String, dynamic>.unmodifiable(m);
    }).toList();
    roleCheck(
      members.map((m) => m['member_ref']).toSet().length == members.length,
    );
  }
  late final String token, scopeDigest;
  late final List<Map<String, dynamic>> members;
  Map<String, String> get aliases => {
    for (final m in members)
      m['member_ref'] as String:
          (m['aliases'] as List).single['group_membership_id'] as String,
  };
}

class CycleAdmissionPreview {
  CycleAdmissionPreview(
    Map<String, dynamic> j, {
    required this.room,
    required this.target,
    required this.character,
    required this.role,
    required this.intent,
  }) {
    roleShape(j, 'scope data');
    scope = Map.unmodifiable(roleMap(j['scope']));
    CycleReadScope(scope, target);
    roleId(scope['room_cycle_id']);
    rolePositive(scope['target_generation']);
    data = Map.unmodifiable(roleMap(j['data']));
    roleShape(
      data,
      'room_id room_revision members_revision plan_revision expected_cycle_key server_time catalog_version policy_snapshot context_token selection targets session_choices comparison permissions target_cycle_key expected_target_revision issued_at expires_at leadership session_display',
    );
    roleCheck(
      roleId(data['room_id']) == room &&
          data['target_cycle_key'] == target &&
          data['expected_cycle_key'] == scope['current_cycle_key'] &&
          data['expected_target_revision'] == scope['target_revision'],
    );
    for (final k in [
      'room_revision',
      'members_revision',
      'plan_revision',
      'expected_target_revision',
    ]) {
      rolePositive(data[k]);
    }
    final issued = roleUtc(data['issued_at']),
        expires = roleUtc(data['expires_at']),
        now = roleUtc(data['server_time']);
    roleCheck(!issued.isAfter(now) && expires.isAfter(now));
    raidText(data['catalog_version']);
    raidText(data['policy_snapshot']);
    final token = raidText(data['context_token']);
    roleCheck(token.length <= 4096);
    final selected = roleMap(data['selection']);
    roleShape(
      selected,
      'registration_id character_id selected_role expected_registration_version expected_ownership_revision expected_roster_revision expected_lifecycle_revision expected_role_summary_version expected_limits_revision expected_usage_revision',
    );
    roleId(selected['registration_id']);
    roleCheck(
      roleId(selected['character_id']) == character &&
          selected['selected_role'] == role &&
          {'dealer', 'support'}.contains(role),
    );
    for (final k in selected.keys.where((k) => k.startsWith('expected_'))) {
      rolePositive(selected[k]);
    }
    final targets = raidList(data['targets']);
    roleCheck(targets.isNotEmpty && targets.length <= 5);
    final itemIds = <String>{}, roundIds = <String>{};
    for (final raw in targets) {
      final t = roleMap(raw);
      roleShape(
        t,
        'item_id round_id party_no expected_round_revision expected_weekly_revision',
      );
      roleCheck(
        itemIds.add(roleId(t['item_id'])) &&
            roundIds.add(roleId(t['round_id'])) &&
            {1, 2}.contains(t['party_no']),
      );
      rolePositive(t['expected_round_revision']);
      rolePositive(t['expected_weekly_revision']);
    }
    final choices = raidList(data['session_choices']).map((raw) {
      final s = roleMap(raw);
      roleShape(s, 'session_id required join_deadline permission');
      roleId(s['session_id']);
      raidBool(s['required']);
      if (s['join_deadline'] != null) roleUtc(s['join_deadline']);
      CyclePermission.fromJson(roleMap(s['permission']));
      return Map<String, dynamic>.unmodifiable(s);
    }).toList();
    roleCheck(
      choices.length <= 64 &&
          choices.map((s) => s['session_id']).toSet().length == choices.length,
    );
    display = CycleSessionDisplay(data['session_display']);
    display.bind(scope, kind: 'existing', planRevision: data['plan_revision']);
    display.matchChoices(choices);
    sessions = display.sessions;
    final perms = roleMap(data['permissions']);
    roleCheck(perms.keys.every({'join', 'apply', 'change_character'}.contains));
    for (final v in perms.values) {
      if (v != null) CyclePermission.fromJson(roleMap(v));
    }
    final raw = perms[intent];
    roleCheck(raw != null);
    permission = CyclePermission.fromJson(roleMap(raw));
    final leader = roleMap(data['leadership']);
    roleShape(
      leader,
      'leader_cycle_member_id leadership_revision leader_membership_id',
    );
    rolePositive(leader['leadership_revision']);
  }
  final String room, target, character, role, intent;
  late final Map<String, dynamic> scope, data;
  late final CyclePermission permission;
  late final CycleSessionDisplay display;
  late final List<Map<String, dynamic>> sessions;
  String get confirmationSignature => cycleStableJson({
    for (final k in [
      'room_revision',
      'members_revision',
      'plan_revision',
      'expected_cycle_key',
      'catalog_version',
      'policy_snapshot',
      'selection',
      'targets',
      'session_choices',
      'session_display',
      'target_cycle_key',
      'expected_target_revision',
      'leadership',
    ])
      k: k == 'session_display' ? display.wire : data[k],
  });
  Map<String, dynamic> body(Set<String> chosen) {
    if (!permission.allowed) {
      throw AccountReadException(permission.reason ?? 'PERMISSION_DENIED');
    }
    final allowed = sessions
        .where((s) => (s['permission'] as Map)['allowed'] == true)
        .map((s) => s['session_id'] as String)
        .toSet();
    roleCheck(allowed.containsAll(chosen));
    for (final session in sessions.where(
      (s) => chosen.contains(s['session_id']),
    )) {
      if (session['join_deadline'] != null &&
          !roleUtc(
            session['join_deadline'],
          ).isAfter(roleUtc(data['server_time']))) {
        throw const AccountReadException('RECRUITMENT_CLOSED');
      }
    }
    if (sessions.any(
      (s) => s['required'] == true && !chosen.contains(s['session_id']),
    )) {
      throw const AccountReadException('SESSION_SELECTION_REQUIRED');
    }
    return {
      'expected_cycle_key': data['expected_cycle_key'],
      for (final k in ['room_revision', 'members_revision', 'plan_revision'])
        'expected_$k': data[k],
      'expected_policy_snapshot': data['policy_snapshot'],
      'expected_catalog_version': data['catalog_version'],
      'selection_context': {'context_token': data['context_token']},
      'selection': data['selection'],
      'target_items': data['targets'],
      'target_session_ids': chosen.toList()..sort(),
      'target_cycle_key': target,
      'expected_target_revision': data['expected_target_revision'],
    };
  }
}

class CycleApplicationView {
  final String? applicationMemo;
  CycleApplicationView(
    Map<String, dynamic> j,
    String id, {
    String? expectedTarget,
    this.applicationMemo,
  }) {
    if (applicationMemo != null) ApplicationMemo(applicationMemo!);
    roleShape(j, 'scope data');
    scope = Map.unmodifiable(roleMap(j['scope']));
    final raw = roleMap(j['data']);
    review = raw.containsKey('application') ? Map.unmodifiable(raw) : null;
    data = Map.unmodifiable(roleMap(review?['application'] ?? raw));
    target = raidCycleKey(data['target_cycle_key']);
    CycleReadScope(scope, target);
    roleCheck(expectedTarget == null || target == expectedTarget);
    roleShape(
      data,
      'application_id room_id revision state created_at expires_at ended_at display character_id selected_role admission_origin target_cycle_key target_generation',
    );
    roleCheck(roleId(data['application_id']) == id);
    room = roleId(data['room_id']);
    rolePositive(data['revision']);
    rolePositive(data['target_generation']);
    roleCheck(data['target_generation'] == scope['target_generation']);
    roleCheck(
      {
        'pending',
        'accepted',
        'rejected',
        'withdrawn',
        'expired',
        'cancelled',
      }.contains(data['state']),
    );
    roleId(data['character_id']);
    roleCheck({'dealer', 'support'}.contains(data['selected_role']));
    roleUtc(data['created_at']);
    if (data['expires_at'] != null) roleUtc(data['expires_at']);
    if (data['ended_at'] != null) roleUtc(data['ended_at']);
    roleMap(data['display']);
    roleMap(data['admission_origin']);
    if (review != null) {
      roleShape(
        review!,
        'application room_revision members_revision plan_revision server_time eligibility permissions',
      );
      for (final k in ['room_revision', 'members_revision', 'plan_revision']) {
        rolePositive(review![k]);
      }
      roleUtc(review!['server_time']);
      final p = roleMap(review!['permissions']);
      roleShape(p, 'approve reject');
      for (final v in p.values) {
        CyclePermission.fromJson(roleMap(v));
      }
    }
  }
  late final Map<String, dynamic> scope, data;
  late final Map<String, dynamic>? review;
  late final String room, target;
}

abstract interface class CycleInteractionGateway {
  Future<CycleResumePlan> resumePlan(String room, String target);
  Future<CycleResumePreview> resumePreview(
    String room,
    String target, {
    String? proposalId,
    List<dynamic>? groups,
  });
  Future<CycleOutcomePreview> outcome(
    String room,
    String target,
    String action, {
    String? round,
  });
  Future<CycleScheduleView> scheduleRead(
    String room,
    String target,
    String kind, {
    String? id,
    String? cursor,
  });
  Future<CycleSchedulePreview> schedulePreview(
    String room,
    String target,
    String action, {
    String? id,
  });
  Future<CycleManagementPreview> management(
    String room,
    String target,
    String action, {
    Map<String, dynamic> query,
  });
  Future<MemberCycles> cycles();
  Future<RaidCatalog> catalog();
  Future<List<RecruitmentGroupChoice>> groups();
  Future<List<RecruitmentCharacter>> characters();
  Future<CycleFilterContext> filterContext(String group);
  Future<CandidatePage> candidates(
    String group,
    CycleFilterContext context, {
    String? cursor,
  });
  Future<CycleSearchPage> search(
    String target,
    CycleSearchFilter filter, {
    String? cursor,
  });
  Future<CycleAdmissionPreview> admission(
    String room,
    String target,
    String character,
    String role,
    String intent,
  );
  Future<CycleApplicationView> application(String id, String target);
  Future<Map<String, dynamic>> applicationPage(
    String room,
    String target, {
    String? cursor,
  });
  Future<Map<String, dynamic>> decisionBody(
    CycleApplicationView application,
    String action,
  );
  Future<Map<String, dynamic>> characterBody(
    CycleAdmissionPreview preview,
    Set<String> sessions,
  );
  Future<void> write(
    String path,
    String key,
    Map<String, dynamic> body, {
    required String room,
    required String target,
    required bool applicationAck,
    String? applicationId,
    String? applicationState,
    Map<String, dynamic>? expectedScope,
    int status = 200,
    String method = 'POST',
    Map<String, dynamic> query = const {},
    String? globalAck,
    List<String>? affectedTargets,
    Map<String, dynamic>? submissionAck,
    String? resumeAck,
    void Function(String)? onOutcome,
  });
}

class CycleInteractionRepository
    implements
        CycleInteractionGateway,
        CycleDepartureGateway,
        CycleRemovalGateway,
        MembershipActionGateway,
        AdmissionCandidatesGateway,
        ApplicationDisplayListGateway,
        ApplicationMessagesGateway {
  CycleInteractionRepository({
    required this.api,
    required this.recruitment,
    this.contractMode = RecruitmentContractMode.legacy,
  });
  final RecruitmentContractMode contractMode;
  @override
  bool get applicationMessagesEnabled =>
      contractMode == RecruitmentContractMode.betaWire2;
  @override
  Future<ApplicationMessagePresets> applicationMessagePresets() =>
      ApplicationMessagesReader(api).applicationMessagePresets();
  final BackendRegistrationApi api;
  late final BackendRegistrationApi interactionApi =
      contractMode == RecruitmentContractMode.betaWire2
      ? BetaInteractionApi(api)
      : api;
  @override
  Future<ApplicationDisplayPage> applicationDisplayPage(
    String room,
    String target, {
    String? cursor,
  }) => ApplicationDisplayReader(
    api,
    contractMode: contractMode,
  ).applicationDisplayPage(room, target, cursor: cursor);
  final CycleRecruitmentGateway recruitment;
  @override
  Future<AdmissionCandidatePage> admissionCandidates(
    String room,
    String target,
    String intent, {
    String? cursor,
  }) => _decode(
    () => AdmissionCandidatesReader(
      interactionApi,
    ).admissionCandidates(room, target, intent, cursor: cursor),
  );
  @override
  Future<MembershipActionContext> membershipContext(String room, String view) =>
      _decode(() async {
        roleId(room);
        raidCycleKey(view);
        final raw = await interactionApi.request(
          '/v2/raid-rooms/$room/membership-action-context',
          query: {'target_cycle_key': view},
        );
        return MembershipActionContext(room, view, raw!);
      });

  @override
  Future<MembershipActionResult> writeMembershipAction(
    MembershipActionPreview preview,
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(key);
    roleCheck(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(key),
    );
    roleCheck(cycleStableJson(body) == cycleStableJson(preview.body()));
    final raw = await interactionApi.request(
      preview.path,
      method: 'POST',
      body: body,
      idempotencyKey: key,
    );
    return MembershipActionResult(raw!, preview, key);
  });

  @override
  Future<RemovalPreview> removal(String room, String target, String member) =>
      _decode(() async {
        roleId(room);
        raidCycleKey(target);
        roleId(member);
        final raw = await interactionApi.request(
          '/v2/raid-rooms/$room/member-removal-context',
          query: {'target_cycle_key': target, 'target_cycle_member_id': member},
        );
        return RemovalPreview(room, target, member, raw!);
      });
  @override
  Future<void> writeRemoval(
    RemovalPreview preview,
    String mode,
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(key);
    roleCheck(cycleStableJson(body) == cycleStableJson(preview.body(mode)));
    final raw = await interactionApi.request(
      preview.path,
      method: 'POST',
      body: body,
      idempotencyKey: key,
    );
    validateRemovalResult(raw!, preview, mode, key);
  });
  @override
  Future<DeparturePreview> departure(
    String room,
    String target,
    String round,
  ) => _decode(() async {
    roleId(room);
    raidCycleKey(target);
    roleId(round);
    final raw = await interactionApi.request(
      '/v2/raid-rooms/$room/personal-completion-departure-context',
      query: {'target_cycle_key': target, 'round_id': round},
    );
    return DeparturePreview(room, target, round, raw!);
  });
  @override
  Future<void> writeDeparture(
    DeparturePreview preview,
    String key,
    Map<String, dynamic> body,
  ) => _decode(() async {
    roleId(key);
    roleCheck(cycleStableJson(body) == cycleStableJson(preview.body()));
    final raw = await interactionApi.request(
      preview.path,
      method: 'POST',
      body: body,
      idempotencyKey: key,
    );
    validateDepartureResult(raw!, preview, key);
  });

  @override
  Future<CycleResumePlan> resumePlan(String room, String target) =>
      _decode(() => CycleResumeReader(interactionApi).read(room, target));
  @override
  Future<CycleResumePreview> resumePreview(
    String room,
    String target, {
    String? proposalId,
    List<dynamic>? groups,
  }) => _decode(
    () => CycleResumeReader(
      interactionApi,
    ).preview(room, target, proposalId: proposalId, groups: groups),
  );
  @override
  Future<CycleOutcomePreview> outcome(
    String room,
    String target,
    String action, {
    String? round,
  }) => _decode(
    () => CycleOutcomeReader(
      interactionApi,
    ).preview(room, target, action, round: round),
  );
  @override
  Future<CycleScheduleView> scheduleRead(
    String room,
    String target,
    String kind, {
    String? id,
    String? cursor,
  }) => _decode(
    () => CycleScheduleReader(
      interactionApi,
    ).read(room, target, kind, id: id, cursor: cursor),
  );
  @override
  Future<CycleSchedulePreview> schedulePreview(
    String room,
    String target,
    String action, {
    String? id,
  }) => _decode(
    () => CycleScheduleReader(
      interactionApi,
    ).preview(room, target, action, id: id),
  );
  @override
  Future<CycleManagementPreview> management(
    String room,
    String target,
    String action, {
    Map<String, dynamic> query = const {},
  }) => _decode(
    () => CycleManagementReader(
      interactionApi,
    ).preview(room, target, action, query: query),
  );
  Future<T> _decode<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  @override
  Future<MemberCycles> cycles() => recruitment.cycles();
  @override
  Future<RaidCatalog> catalog() => recruitment.catalog();
  @override
  Future<List<RecruitmentGroupChoice>> groups() => recruitment.groups();
  @override
  Future<List<RecruitmentCharacter>> characters() => recruitment.characters();
  @override
  Future<CycleFilterContext> filterContext(String group) => _decode(() async {
    roleId(group);
    return CycleFilterContext(
      (await interactionApi.request(
        '/v2/me/raid-room-filter-context',
        query: {
          'group_ids': jsonEncode([group]),
        },
      ))!,
      group,
    );
  });
  @override
  Future<CandidatePage> candidates(
    String group,
    CycleFilterContext context, {
    String? cursor,
  }) => _decode(() async {
    roleId(group);
    candidateHex(context.token);
    return CandidatePage(
      (await interactionApi.request(
        '/v2/groups/$group/raid-room-character-candidates',
        query: {
          'filter_context_token': context.token,
          'limit': 50,
          'cursor': ?cursor,
        },
      ))!,
      group: group,
      contextToken: context.token,
      scopeDigest: context.scopeDigest,
      aliases: context.aliases,
    );
  });
  @override
  Future<CycleSearchPage> search(
    String target,
    CycleSearchFilter filter, {
    String? cursor,
  }) => _decode(() async {
    final result = await readRecruitment(
      api: api,
      mode: contractMode,
      path: '/v2/raid-rooms/search',
      method: 'POST',
      body: filter.body(target, cursor: cursor),
      parse: (j) => CycleSearchPage(j, target),
    );
    if (result.metadata != null) {
      final items = result.metadata!['items'] as List;
      for (var i = 0; i < result.value.rows.length; i++) {
        result.value.rows[i].betaData = betaDisplayData(roleMap(items[i]));
      }
    }
    return result.value;
  });
  @override
  Future<CycleAdmissionPreview> admission(
    String room,
    String target,
    String character,
    String role,
    String intent,
  ) => _decode(() async {
    roleId(room);
    roleId(character);
    raidCycleKey(target);
    roleCheck({'apply', 'join', 'change_character'}.contains(intent));
    final j = (await interactionApi.request(
      '/v2/raid-rooms/$room/admission-context',
      query: {
        'target_cycle_key': target,
        'character_id': character,
        'selected_role': role,
        'intent': intent,
        'include_session_display': 'true',
      },
    ))!;
    return CycleAdmissionPreview(
      j,
      room: room,
      target: target,
      character: character,
      role: role,
      intent: intent,
    );
  });
  @override
  Future<CycleApplicationView> application(String id, String target) =>
      _decode(() async {
        roleId(id);
        final path = '/v2/raid-room-applications/$id';
        if (interactionApi is BetaInteractionApi) {
          final decoded = await (interactionApi as BetaInteractionApi)
              .requestDecoded(path);
          final raw = decoded.metadata!['data'] as Map;
          final app = (raw['application'] ?? raw) as Map;
          return CycleApplicationView(
            decoded.value,
            id,
            expectedTarget: target,
            applicationMemo: app['application_memo'] as String?,
          );
        }
        return CycleApplicationView(
          (await interactionApi.request(path))!,
          id,
          expectedTarget: target,
        );
      });
  @override
  Future<Map<String, dynamic>> applicationPage(
    String room,
    String target, {
    String? cursor,
  }) => _decode(() async {
    roleId(room);
    final j = (await interactionApi.request(
      '/v2/raid-rooms/$room/applications',
      query: {
        'target_cycle_key': target,
        'state': 'pending',
        'limit': 20,
        'cursor': ?cursor,
      },
    ))!;
    final page = CycleOwnPage(j, target, true);
    roleCheck(page.rows.every((r) => r.roomId == room));
    return j;
  });
  @override
  Future<Map<String, dynamic>> decisionBody(
    CycleApplicationView a,
    String action,
  ) => _decode(() async {
    if (a.data['state'] != 'pending') {
      throw const AccountReadException('APPLICATION_STATE_CHANGED');
    }
    if (action == 'withdraw') {
      return {
        'expected_application_revision': a.data['revision'],
        'target_cycle_key': a.target,
        'expected_cycle_key': a.scope['current_cycle_key'],
        'expected_target_revision': rolePositive(a.scope['target_revision']),
      };
    }
    final review = a.review;
    if (review == null) throw const AccountReadException('PERMISSION_DENIED');
    final permission = CyclePermission.fromJson(
      roleMap(roleMap(review['permissions'])[action]),
    );
    if (!permission.allowed) {
      throw AccountReadException(permission.reason ?? 'PERMISSION_DENIED');
    }
    final detail = await recruitment.cycleDetail(a.room, a.target);
    if (detail.room['target_generation'] != a.data['target_generation'] ||
        detail.room['target_revision'] != a.scope['target_revision'] ||
        detail.room['revision'] != review['room_revision'] ||
        detail.membersRevision != review['members_revision'] ||
        detail.planRevision != review['plan_revision']) {
      throw const AccountReadException('REVISION_CONFLICT');
    }
    if (detail.room['my_target_role'] != 'leader') {
      throw const AccountReadException('PERMISSION_DENIED');
    }
    return {
      'expected_cycle_key': a.scope['current_cycle_key'],
      'expected_application_revision': a.data['revision'],
      for (final k in ['room_revision', 'members_revision', 'plan_revision'])
        'expected_$k': review[k],
      'target_cycle_key': a.target,
      'expected_target_revision': a.scope['target_revision'],
      'expected_leadership_revision': rolePositive(
        roleMap(detail.room['leadership'])['leadership_revision'],
      ),
    };
  });
  @override
  Future<Map<String, dynamic>> characterBody(
    CycleAdmissionPreview p,
    Set<String> sessions,
  ) => _decode(() async {
    final j = (await interactionApi.request(
      '/v2/me/raid-rooms/${p.room}/plan',
      query: {'target_cycle_key': p.target},
    ))!;
    roleShape(j, 'scope data');
    final scope = roleMap(j['scope']);
    CycleReadScope(scope, p.target);
    final d = roleMap(j['data']), mine = roleMap(d['my_membership']);
    roleCheck(
      roleId(d['room_id']) == p.room && d['target_cycle_key'] == p.target,
    );
    if (scope['room_cycle_id'] != p.scope['room_cycle_id'] ||
        scope['target_generation'] != p.scope['target_generation'] ||
        scope['target_revision'] != p.scope['target_revision'] ||
        d['revision'] != p.data['plan_revision'] ||
        d['members_revision'] != p.data['members_revision']) {
      throw const AccountReadException('REVISION_CONFLICT');
    }
    roleId(mine['cycle_member_id']);
    final revision = rolePositive(mine['cycle_member_revision']);
    final assignments = raidList(d['my_assignments'])
        .where((raw) => roleMap(raw)['ended_at'] == null)
        .map((raw) {
          final a = roleMap(raw);
          roleCheck(
            a['target_cycle_key'] == p.target &&
                a['membership_id'] == mine['membership_id'] &&
                raidList(p.data['targets']).any(
                  (t) =>
                      roleMap(t)['round_id'] == a['round_id'] &&
                      roleMap(t)['item_id'] == a['item_id'],
                ),
          );
          return {
            'assignment_id': roleId(a['assignment_id']),
            'expected_revision': rolePositive(a['revision']),
          };
        })
        .toList();
    roleCheck(
      assignments.length == raidList(p.data['targets']).length &&
          assignments.map((a) => a['assignment_id']).toSet().length ==
              assignments.length,
    );
    return {
      ...p.body(sessions),
      'assignments': assignments,
      'expected_cycle_member_revision': revision,
    };
  });
  @override
  Future<void> write(
    String path,
    String key,
    Map<String, dynamic> body, {
    required String room,
    required String target,
    required bool applicationAck,
    String? applicationId,
    String? applicationState,
    Map<String, dynamic>? expectedScope,
    int status = 200,
    String method = 'POST',
    Map<String, dynamic> query = const {},
    String? globalAck,
    List<String>? affectedTargets,
    Map<String, dynamic>? submissionAck,
    String? resumeAck,
    void Function(String)? onOutcome,
  }) => _decode(() async {
    roleId(key);
    final j = (await interactionApi.request(
      path,
      method: method,
      body: body,
      query: query.isEmpty ? null : query,
      idempotencyKey: key,
      expectedStatus: status,
    ))!;
    roleShape(j, 'scope data');
    final scope = roleMap(j['scope']);
    if (submissionAck != null) {
      validateSubmissionAck(j, room, target, submissionAck, expectedScope!);
      return;
    }
    if (globalAck != null) {
      roleShape(scope, 'server_now current_cycle_key policy_version');
      roleUtc(scope['server_now']);
      raidCycleKey(scope['current_cycle_key']);
      roleCheck(scope['policy_version'] == twoCyclePolicy);
      final d = roleMap(j['data']);
      roleShape(
        d,
        globalAck == 'common'
            ? 'command_id outcome executed_at room_id room_revision affected_cycle_keys'
            : 'command_id outcome executed_at room_id membership_id persistent_membership_revision affected_cycle_keys room_ended revisions',
      );
      roleCheck(
        roleId(d['command_id']) == key &&
            roleId(d['room_id']) == room &&
            (globalAck == 'common'
                    ? {'applied', 'recorded', 'noop'}
                    : {'applied', 'noop'})
                .contains(d['outcome']),
      );
      roleUtc(d['executed_at']);
      final affected = raidList(
        d['affected_cycle_keys'],
      ).map(raidCycleKey).toSet();
      roleCheck(
        affected.length == raidList(d['affected_cycle_keys']).length &&
            ((globalAck == 'common' &&
                    d['outcome'] == 'noop' &&
                    affected.isEmpty) ||
                (affected.length == (affectedTargets ?? []).length &&
                    affected.containsAll(affectedTargets ?? []))),
      );
      if (globalAck == 'common') {
        rolePositive(d['room_revision']);
      } else {
        roleId(d['membership_id']);
        rolePositive(d['persistent_membership_revision']);
        raidBool(d['room_ended']);
        roleCheck(d['room_ended'] == (globalAck == 'end'));
        for (final raw in raidList(d['revisions'])) {
          final r = roleMap(raw);
          roleShape(r, 'resource id revision');
          raidText(r['resource']);
          roleId(r['id']);
          rolePositive(r['revision']);
        }
      }
      return;
    }
    CycleReadScope(scope, target);
    if (expectedScope != null) {
      roleCheck(
        scope['room_cycle_id'] == expectedScope['room_cycle_id'] &&
            scope['target_generation'] == expectedScope['target_generation'],
      );
    }
    final d = roleMap(j['data']);
    roleShape(
      d,
      applicationAck
          ? 'command_id room_id application_id revision state executed_at target_cycle_key'
          : 'command_id outcome executed_at room_id target_cycle_key revisions',
    );
    roleCheck(
      roleId(d['command_id']) == key &&
          roleId(d['room_id']) == room &&
          d['target_cycle_key'] == target,
    );
    roleUtc(d['executed_at']);
    if (applicationAck) {
      roleId(d['application_id']);
      rolePositive(d['revision']);
      roleCheck(applicationId == null || d['application_id'] == applicationId);
      roleCheck(applicationState == null || d['state'] == applicationState);
    } else {
      roleCheck({'applied', 'recorded', 'noop'}.contains(d['outcome']));
      if (resumeAck != null) {
        roleCheck(
          (resumeAck == 'create' ? {'recorded'} : {'recorded', 'applied'})
              .contains(d['outcome']),
        );
      }
      if (path.endsWith('/completion') ||
          path.endsWith('/personal-completion') ||
          path.endsWith('/weekly-incomplete-closures')) {
        roleCheck({'applied', 'noop'}.contains(d['outcome']));
      }
      for (final raw in raidList(d['revisions'])) {
        final r = roleMap(raw);
        roleShape(r, 'resource id revision');
        roleId(r['id']);
        rolePositive(r['revision']);
      }
      onOutcome?.call(d['outcome'] as String);
    }
  });
}
