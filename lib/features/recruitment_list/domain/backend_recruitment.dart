import 'dart:convert';

import '../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/member_cycle_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/services/character_build_role_policy.dart';
import 'policies/raid_cycle_schedule.dart';

const recruitmentExperiences = <String, String>{
  'tryLevel': '트라이',
  'clearExp': '클경',
  'multiClearExp': '다클경',
  'semiExperienced': '반숙',
  'experienced': '숙련',
};

class RecruitmentCharacter {
  const RecruitmentCharacter({
    required this.id,
    required this.registrationId,
    required this.name,
    required this.className,
    required this.accountLabel,
    this.itemLevel,
    this.representative = false,
    this.preferredRole,
  });
  final String id, registrationId, name, className, accountLabel;
  final String? itemLevel;
  final bool representative;
  final String? preferredRole;
  bool get supportsBothRoles =>
      const CharacterBuildRolePolicy().supportsMultipleRoles(className);
  String get initialRole => supportsBothRoles
      ? (preferredRole == 'dealer' ? 'dealer' : 'support')
      : 'dealer';
}

class RecruitmentGroupChoice {
  const RecruitmentGroupChoice(this.id, this.name);
  final String id, name;
}

class RecruitmentItemDraft {
  const RecruitmentItemDraft(this.raidId, this.difficultyId, {this.minutes});
  final String raidId, difficultyId;
  final int? minutes;
  Map<String, dynamic> get choice => {
    'raid_id': raidId,
    'difficulty_id': difficultyId,
  };
}

/// Editor values, never a cached permission or a server write plan.
class RecruitmentDraft {
  RecruitmentDraft({
    this.characterId,
    this.targetCycleKey,
    this.role = 'dealer',
    this.title = '',
    this.groupId,
    this.groupOnly = false,
    this.directJoin = false,
    this.experience,
    this.sharedPower = false,
    this.sharedMinimum = '',
    this.dealerMinimum = '',
    this.supportMinimum = '',
    this.continueTogether = false,
    List<RecruitmentItemDraft> items = const [],
    Set<int> weekdays = const {},
    this.startMinute,
    this.sameStart = true,
    Map<int, int> startsByDay = const {},
    this.eachDay = false,
  }) : items = List.unmodifiable(items),
       startsByDay = Map.unmodifiable(startsByDay),
       weekdays = Set.unmodifiable(weekdays);
  final String? characterId, groupId, experience, targetCycleKey;
  final String role, title, sharedMinimum, dealerMinimum, supportMinimum;
  final bool groupOnly, directJoin, sharedPower, continueTogether, eachDay;
  final List<RecruitmentItemDraft> items;
  final Set<int> weekdays;
  final int? startMinute;
  final bool sameStart;
  final Map<int, int> startsByDay;
  int? timeForDay(int day) =>
      sameStart ? startMinute : startsByDay[day] ?? startMinute;
  bool get hasManualTime => weekdays.any((day) => timeForDay(day) != null);
  // Use an explicit clone so the app-owned editor survives route recreation.
  RecruitmentDraft copy({
    String? characterId,
    String? targetCycleKey,
    String? role,
    String? title,
    String? groupId,
    bool clearGroup = false,
    bool? groupOnly,
    bool? directJoin,
    String? experience,
    bool clearExperience = false,
    bool? sharedPower,
    String? sharedMinimum,
    String? dealerMinimum,
    String? supportMinimum,
    bool? continueTogether,
    List<RecruitmentItemDraft>? items,
    Set<int>? weekdays,
    int? startMinute,
    bool? sameStart,
    Map<int, int>? startsByDay,
    bool clearStart = false,
    bool? eachDay,
  }) => RecruitmentDraft(
    characterId: characterId ?? this.characterId,
    targetCycleKey: targetCycleKey ?? this.targetCycleKey,
    role: role ?? this.role,
    title: title ?? this.title,
    groupId: clearGroup ? null : groupId ?? this.groupId,
    groupOnly: clearGroup ? false : groupOnly ?? this.groupOnly,
    directJoin: directJoin ?? this.directJoin,
    experience: clearExperience ? null : experience ?? this.experience,
    sharedPower: sharedPower ?? this.sharedPower,
    sharedMinimum: sharedMinimum ?? this.sharedMinimum,
    dealerMinimum: dealerMinimum ?? this.dealerMinimum,
    supportMinimum: supportMinimum ?? this.supportMinimum,
    continueTogether: continueTogether ?? this.continueTogether,
    items: items ?? this.items,
    weekdays: weekdays ?? this.weekdays,
    startMinute: clearStart ? null : startMinute ?? this.startMinute,
    sameStart: sameStart ?? this.sameStart,
    startsByDay: clearStart ? const {} : startsByDay ?? this.startsByDay,
    eachDay: eachDay ?? this.eachDay,
  );

  String get selectionSignature => jsonEncode({
    'character': characterId,
    if (targetCycleKey != null) 'target': targetCycleKey,
    if (targetCycleKey != null) 'continuation': continueTogether,
    'role': role,
    'group': groupId,
    'items': items.map((i) => i.choice).toList(),
  });

  String? validate() {
    if (characterId == null || items.isEmpty) return '캐릭터와 레이드를 선택해 주세요.';
    if (title.trim().runes.length > 60 ||
        RegExp(r'[\x00-\x1f\x7f\u2028\u2029]').hasMatch(title)) {
      return '모집 제목은 줄바꿈 없이 60자까지 입력해 주세요.';
    }
    if (groupOnly && groupId == null) return '연결 그룹을 선택해 주세요.';
    if (items.map((i) => i.raidId).toSet().length != items.length) {
      return '같은 레이드는 한 번만 추가해 주세요.';
    }
    if (items.any(
      (i) =>
          i.minutes != null &&
          (i.minutes! < 10 || i.minutes! > 1440 || i.minutes! % 5 != 0),
    )) {
      return '진행시간은 10분~24시간, 5분 단위로 설정해 주세요.';
    }
    final values = sharedPower
        ? [sharedMinimum]
        : [dealerMinimum, supportMinimum];
    if (values.any(
      (v) =>
          v.trim().isNotEmpty &&
          (v.trim().length > 32 ||
              !RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(v.trim())),
    )) {
      return '최소 전투력을 숫자로 입력해 주세요.';
    }
    if (startMinute != null &&
        (weekdays.isEmpty ||
            startMinute! < 0 ||
            startMinute! >= 1440 ||
            startMinute! % 5 != 0)) {
      return '출발 요일과 5분 단위 시각을 선택해 주세요.';
    }
    if (weekdays.any((d) => d < 1 || d > 7)) return '출발 요일을 확인해 주세요.';
    if (hasManualTime && weekdays.any((day) => timeForDay(day) == null)) {
      return '선택한 요일의 출발 시각을 모두 지정하거나 모두 미정으로 설정해 주세요.';
    }
    if (weekdays.any((day) {
      final minute = timeForDay(day);
      return minute != null &&
          (minute < 0 || minute >= 1440 || minute % 5 != 0);
    })) {
      return '출발 시각은 5분 단위로 설정해 주세요.';
    }
    return null;
  }

  List<Map<String, dynamic>> get schedules {
    if (weekdays.isEmpty) return [];
    return [
      {
        'client_group_key': 'initial',
        'existing_group_id': null,
        'expected_group_revision': null,
        'occurrence_mode': eachDay ? 'each' : 'one_of',
        'planning_mode': hasManualTime ? 'manual' : 'unscheduled',
        'required': true,
        'auto_confirm_additional_members': null,
        'day_scope': 'selected_weekdays',
        'alternatives': [
          for (final day in [...weekdays]..sort())
            {
              'client_alternative_key': 'day_$day',
              'existing_session_id': null,
              'expected_session_revision': null,
              'weekday': day,
              'starts_local': timeForDay(day) == null
                  ? null
                  : minuteClock(timeForDay(day)!),
              'leader_latest_start_local': null,
              'item_order': items.map((i) => i.raidId).toList(),
            },
        ],
      },
    ];
  }

  Map<String, dynamic> body(
    RecruitmentCreationContext context,
    String defaultTitle,
  ) {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    roleCheck(context.signature == selectionSignature);
    String? minimum(String v) => v.trim().isEmpty ? null : v.trim();
    return {
      'title': title.trim().isEmpty ? defaultTitle : title.trim(),
      'scope': groupOnly ? 'group' : 'public',
      'group_id': groupId,
      'admission_mode': directJoin ? 'direct_join' : 'leader_only',
      'app_mode': items.length == 1 ? 'single' : 'mixed_bundle',
      'items': [
        for (var i = 0; i < items.length; i++)
          {
            ...items[i].choice,
            'duration_minutes': items[i].minutes,
            'expected_weekly_revision':
                context.targets[i]['expected_weekly_revision'],
            'party_no': 1,
          },
      ],
      'selection': context.selection,
      'selection_context': {'context_token': context.token},
      'experience_level': experience,
      'combat_requirement': {
        'input_mode': sharedPower ? 'shared' : 'per_role',
        'dealer_min': minimum(sharedPower ? sharedMinimum : dealerMinimum),
        'support_min': minimum(sharedPower ? sharedMinimum : supportMinimum),
      },
      'continuation': context.targetKey == null
          ? {'enabled': continueTogether, 'auto_open_enabled': false}
          : {
              'enabled': continueTogether,
              'next_selection': context.nextSelection,
            },
      if (context.targetKey != null) ...{
        'target_cycle_key': context.targetKey,
        'expected_target_revision': context.targetRevision,
      },
      'schedule_groups': schedules,
      'expected_cycle_key': context.cycleKey,
      'expected_catalog_version': context.catalogVersion,
      'expected_group_revision': context.groupRevision,
    };
  }
}

String minuteClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class RecruitmentCreationContext {
  RecruitmentCreationContext.fromJson(
    Map<String, dynamic> json,
    RecruitmentDraft draft, {
    bool cycle = false,
  }) : signature = draft.selectionSignature {
    roleShape(
      json,
      'expected_cycle_key server_time catalog_version policy_snapshot context_token selection targets group_revision settings_defaults comparison permissions',
    );
    cycleKey = raidCycleKey(json['expected_cycle_key']);
    serverTime = roleUtc(json['server_time']);
    catalogVersion = raidText(json['catalog_version']);
    token = raidText(json['context_token']);
    roleCheck(
      cycle
          ? token.isNotEmpty && token.length <= 4096
          : RegExp(r'^s1\.[a-f0-9]{64}$').hasMatch(token),
    );
    final selected = roleMap(json['selection']);
    roleShape(
      selected,
      'registration_id character_id selected_role expected_registration_version expected_ownership_revision expected_roster_revision expected_lifecycle_revision expected_role_summary_version expected_limits_revision expected_usage_revision',
    );
    roleId(selected['registration_id']);
    roleCheck(
      roleId(selected['character_id']) == draft.characterId &&
          selected['selected_role'] == draft.role,
    );
    for (final key in selected.keys.where((k) => k.startsWith('expected_'))) {
      rolePositive(selected[key]);
    }
    selection = Map.unmodifiable(selected);
    targets = List.unmodifiable(
      raidList(json['targets']).map((v) {
        final t = roleMap(v);
        roleShape(t, 'raid_id difficulty_id expected_weekly_revision');
        raidIdentifier(t['raid_id']);
        raidIdentifier(t['difficulty_id']);
        rolePositive(t['expected_weekly_revision']);
        return Map<String, dynamic>.unmodifiable(t);
      }),
    );
    roleCheck(targets.length == draft.items.length);
    for (var i = 0; i < targets.length; i++) {
      roleCheck(
        targets[i]['raid_id'] == draft.items[i].raidId &&
            targets[i]['difficulty_id'] == draft.items[i].difficultyId,
      );
    }
    groupRevision = json['group_revision'] == null
        ? null
        : rolePositive(json['group_revision']);
    roleCheck((draft.groupId == null) == (groupRevision == null));
    final permission = roleMap(roleMap(json['permissions'])['create']);
    allowed = raidBool(permission['allowed']);
    reason = permission['reason'] as String?;
    final comparison = roleMap(json['comparison']);
    roleShape(
      comparison,
      'selected_role requirement actual state source trust current_summary_version success_summary_version power_revision observed_at success_saved_at success_issues current_issues',
    );
    roleCheck(comparison['selected_role'] == draft.role);
    roleCheck(
      comparison['source'] == 'flutter_analysis' &&
          comparison['trust'] == 'client_submitted',
    );
    rolePositive(comparison['current_summary_version']);
    rolePositive(comparison['power_revision']);
    roleCheck(
      {
        'unrestricted',
        'missing',
        'below',
        'meets',
      }.contains(comparison['state']),
    );
    actualPower = comparison['actual'] as String?;
    final issues = [
      ...raidList(comparison['current_issues']),
      ...raidList(comparison['success_issues']),
    ];
    hasBuildWarning = issues.isNotEmpty;
    if (actualPower != null) {
      roleCheck(RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(actualPower!));
    }
  }
  factory RecruitmentCreationContext.fromCycleJson(
    Map<String, dynamic> j,
    RecruitmentDraft draft,
  ) {
    const oldKeys =
        'expected_cycle_key server_time catalog_version policy_snapshot context_token selection targets group_revision settings_defaults comparison permissions';
    roleShape(
      j,
      '$oldKeys target_cycle_key expected_target_revision issued_at expires_at prospective_room_id target_creation next_cycle_creation continuation_effect',
    );
    final value = RecruitmentCreationContext.fromJson(
      {for (final k in oldKeys.split(' ')) k: j[k]},
      draft,
      cycle: true,
    );
    CyclePermission.fromJson(roleMap(roleMap(j['permissions'])['create']));
    value.targetKey = raidCycleKey(j['target_cycle_key']);
    roleCheck(value.targetKey == draft.targetCycleKey);
    value.targetRevision = j['expected_target_revision'] == null
        ? null
        : rolePositive(j['expected_target_revision']);
    roleCheck(value.targetRevision == null);
    value.prospectiveRoomId = roleId(j['prospective_room_id']);
    final issued = roleUtc(j['issued_at']);
    value.expiresAt = roleUtc(j['expires_at']);
    roleCheck(
      !issued.isAfter(value.serverTime) &&
          value.expiresAt!.isAfter(value.serverTime),
    );
    final nextKey = DateTime.parse(
      '${value.cycleKey}T00:00:00Z',
    ).add(const Duration(days: 7)).toIso8601String().substring(0, 10);
    roleCheck(value.targetKey == value.cycleKey || value.targetKey == nextKey);
    roleCheck(!draft.continueTogether || value.targetKey == value.cycleKey);
    final effect = draft.continueTogether ? 'target_and_next' : 'target_only';
    roleCheck(j['continuation_effect'] == effect);
    value.effect = effect;
    Map<String, dynamic> prospective(Object? raw, String t) {
      final p = roleMap(raw);
      roleShape(
        p,
        'target_cycle_key room_cycle_id generation initial_target_revision selection targets permission conflicts',
      );
      roleCheck(
        raidCycleKey(p['target_cycle_key']) == t &&
            p['generation'] == 1 &&
            p['initial_target_revision'] == 1,
      );
      roleId(p['room_cycle_id']);
      final selection = roleMap(p['selection']);
      roleShape(selection, value.selection.keys.join(' '));
      roleCheck(
        selection['character_id'] == draft.characterId &&
            selection['selected_role'] == draft.role &&
            selection['registration_id'] == value.selection['registration_id'],
      );
      for (final k in selection.keys.where((k) => k.startsWith('expected_'))) {
        rolePositive(selection[k]);
      }
      final targets = raidList(p['targets']);
      roleCheck(targets.length == draft.items.length);
      for (var i = 0; i < targets.length; i++) {
        final item = roleMap(targets[i]);
        roleShape(
          item,
          'item_id round_id raid_id difficulty_id party_no expected_round_revision expected_weekly_revision',
        );
        roleId(item['item_id']);
        roleId(item['round_id']);
        roleCheck(
          item['raid_id'] == draft.items[i].raidId &&
              item['difficulty_id'] == draft.items[i].difficultyId &&
              item['party_no'] == 1 &&
              item['expected_round_revision'] == 1,
        );
        rolePositive(item['expected_weekly_revision']);
      }
      final permission = CyclePermission.fromJson(roleMap(p['permission']));
      final conflicts = raidList(p['conflicts']);
      roleCheck(conflicts.length <= 5);
      for (final raw in conflicts) {
        final c = roleMap(raw);
        roleShape(
          c,
          'room_id target_cycle_key raid_id character_id can_view_detail room_title',
        );
        roleCheck(c['target_cycle_key'] == t);
        roleId(c['character_id']);
        raidIdentifier(c['raid_id']);
        raidBool(c['can_view_detail']);
        if (c['room_id'] != null) roleId(c['room_id']);
        if (c['room_title'] != null) raidText(c['room_title']);
      }
      if (!permission.allowed) {
        value.allowed = false;
        value.reason = permission.reason;
      }
      return Map.unmodifiable(p);
    }

    value.prospective = [prospective(j['target_creation'], value.targetKey!)];
    if (draft.continueTogether) {
      final n = prospective(j['next_cycle_creation'], nextKey);
      value.nextSelection = Map.unmodifiable(roleMap(n['selection']));
      value.prospective!.add(n);
    } else {
      roleCheck(j['next_cycle_creation'] == null);
    }
    return value;
  }
  String? targetKey, prospectiveRoomId, effect;
  int? targetRevision;
  DateTime? expiresAt;
  Map<String, dynamic>? nextSelection;
  List<Map<String, dynamic>>? prospective;
  final String signature;
  late final String cycleKey, catalogVersion, token;
  late final DateTime serverTime;
  late final Map<String, dynamic> selection;
  late final List<Map<String, dynamic>> targets;
  late final int? groupRevision;
  late bool allowed;
  late final bool hasBuildWarning;
  late String? reason;
  late final String? actualPower;
}

class RecruitmentCreationAck {
  RecruitmentCreationAck.fromJson(Map<String, dynamic> json, String key) {
    roleShape(json, 'command_id outcome revisions executed_at');
    roleCheck(roleId(json['command_id']) == key);
    roleCheck({'applied', 'recorded', 'noop'}.contains(json['outcome']));
    roleUtc(json['executed_at']);
    final rooms = <String>[];
    for (final raw in raidList(json['revisions'])) {
      final r = roleMap(raw);
      roleShape(r, 'resource id revision');
      final id = roleId(r['id']);
      rolePositive(r['revision']);
      if (r['resource'] == 'room') rooms.add(id);
    }
    roleCheck(rooms.length == 1);
    roomId = rooms.single;
  }
  RecruitmentCreationAck.fromCycleJson(
    Map<String, dynamic> j,
    String key,
    Map<String, dynamic> body,
  ) {
    roleShape(
      j,
      'command_id outcome executed_at room_id target_cycle_key revisions created_cycles continuation_effect',
    );
    roleCheck(
      roleId(j['command_id']) == key &&
          {'applied', 'recorded', 'noop'}.contains(j['outcome']),
    );
    roleUtc(j['executed_at']);
    roomId = roleId(j['room_id']);
    targetKey = raidCycleKey(j['target_cycle_key']);
    roleCheck(targetKey == body['target_cycle_key']);
    final together = roleMap(body['continuation'])['enabled'] == true;
    final expected = <String>{
      targetKey!,
      if (together)
        DateTime.parse(
          '${targetKey}T00:00:00Z',
        ).add(const Duration(days: 7)).toIso8601String().substring(0, 10),
    };
    effect = j['continuation_effect'] as String;
    roleCheck(effect == (together ? 'target_and_next' : 'target_only'));
    created = raidList(j['created_cycles']).map((raw) {
      final c = roleMap(raw);
      roleShape(
        c,
        'target_cycle_key room_cycle_id generation target_revision leader_cycle_member_id',
      );
      roleCheck(expected.remove(raidCycleKey(c['target_cycle_key'])));
      roleId(c['room_cycle_id']);
      roleId(c['leader_cycle_member_id']);
      rolePositive(c['generation']);
      rolePositive(c['target_revision']);
      return Map<String, dynamic>.unmodifiable(c);
    }).toList();
    roleCheck(expected.isEmpty);
    final roomRevisions = <String>[];
    for (final raw in raidList(j['revisions'])) {
      final v = roleMap(raw);
      roleShape(v, 'resource id revision');
      roleId(v['id']);
      rolePositive(v['revision']);
      if (v['resource'] == 'room') roomRevisions.add(v['id'] as String);
    }
    roleCheck(roomRevisions.length == 1 && roomRevisions.single == roomId);
  }
  String? targetKey, effect;
  List<Map<String, dynamic>>? created;
  late final String roomId;
}

class BackendRecruitmentDetail {
  BackendRecruitmentDetail.fromJson(Map<String, dynamic> json, String id) {
    roleShape(
      json,
      'room settings members_revision members my_membership plan_revision permissions access',
    );
    room = Map.unmodifiable(roleMap(json['room']));
    roleCheck(roleId(room['room_id']) == id);
    title = raidText(room['title']);
    rolePositive(room['revision']);
    capacity = rolePositive(room['app_capacity']);
    memberCount = raidNonnegative(room['app_member_count']);
    roleCheck({4, 8}.contains(capacity) && memberCount <= capacity);
    raidCycleKey(room['cycle_key']);
    membersRevision = rolePositive(json['members_revision']);
    planRevision = rolePositive(json['plan_revision']);
    members = List.unmodifiable(
      raidList(json['members']).map((raw) {
        final m = roleMap(raw);
        roleShape(
          m,
          'membership_id revision room_role group_member joined_at character assignments comparison build is_me status status_reason',
        );
        roleId(m['membership_id']);
        roleCheck(m['room_role'] == 'leader' || m['room_role'] == 'member');
        raidBool(m['group_member']);
        raidBool(m['is_me']);
        if (m['character'] != null) {
          final c = roleMap(m['character']);
          roleId(c['character_id']);
          roleCheck({'dealer', 'support'}.contains(c['selected_role']));
          roleMap(c['display']);
        }
        return Map<String, dynamic>.unmodifiable(m);
      }),
    );
    starts = List.unmodifiable(
      raidList(
        roleMap(room['schedule_summary'])['confirmed_starts_at'],
      ).map(roleUtc),
    );
    for (final i in raidList(room['items'])) {
      final item = roleMap(i);
      raidIdentifier(item['raid_id']);
      raidIdentifier(item['difficulty_id']);
    }
    roleMap(room['combat_requirement']);
    roleCheck(
      roleMap(roleMap(json['permissions'])['view_detail'])['allowed'] == true,
    );
    roleCheck(roleMap(json['access'])['state'] == 'allowed');
  }
  String? targetKey;
  List<Map<String, dynamic>> formation = const [];
  Map<String, String> cycleMemberIds = const {};
  late final Map<String, dynamic> room;
  late final String title;
  late final int capacity, memberCount;
  late final int membersRevision, planRevision;
  late final List<Map<String, dynamic>> members;
  late final List<DateTime> starts;
  bool get hasMultipleScheduledDays =>
      starts
          .map((start) {
            final date = start.toUtc().add(const RaidCycleSchedule().utcOffset);
            return (date.year, date.month, date.day);
          })
          .toSet()
          .length >
      1;
}

abstract interface class CycleRecruitmentGateway implements RecruitmentGateway {
  bool get twoCycleEnabled;
  Future<MemberCycles> cycles();
  Future<BackendRecruitmentDetail> cycleDetail(String id, String target);
  Future<List<String>> roomIdsFor(String target);
}

/// One summary read for a character and its actual selected cycle(s).
abstract interface class RecruitmentAvailabilityGateway {
  Future<Set<String>> unavailableRaids(
    String character,
    List<String> targets,
    RaidCatalog catalog,
  );
}

abstract interface class RecruitmentGateway {
  Future<RaidCatalog> catalog();
  Future<List<RecruitmentCharacter>> characters();
  Future<List<RecruitmentGroupChoice>> groups();
  Future<RecruitmentCreationContext> context(RecruitmentDraft draft);
  Future<RecruitmentCreationAck> create(String key, Map<String, dynamic> body);
  Future<BackendRecruitmentDetail> detail(String id);
  Future<List<String>> currentRoomIds();
}
