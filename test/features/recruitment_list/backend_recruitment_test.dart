import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/account/domain/server_registration_api.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_detail_view_model.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/data/mappers/raid_catalog_mapper.dart';
import '../../support/server_account_read_fakes.dart';

const roomId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const membershipId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const groupId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const itemId = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const stamp = '2026-10-20T01:00:00Z';
RecruitmentDraft draft() => RecruitmentDraft(
  characterId: characterId,
  sharedPower: true,
  items: const [RecruitmentItemDraft('raid_a', 'hard')],
);
Map<String, dynamic> contextJson(
  RecruitmentDraft d, {
  int revision = 3,
  bool allowed = true,
}) => {
  'expected_cycle_key': '2026-10-14',
  'server_time': stamp,
  'catalog_version': 'v2',
  'policy_snapshot': 'snapshot',
  'context_token': 's1.${List.filled(64, 'a').join()}',
  'selection': {
    'registration_id': registrationId,
    'character_id': d.characterId,
    'selected_role': d.role,
    'expected_registration_version': revision,
    'expected_ownership_revision': 2,
    'expected_roster_revision': 3,
    'expected_lifecycle_revision': 4,
    'expected_role_summary_version': 5,
    'expected_limits_revision': 6,
    'expected_usage_revision': 7,
  },
  'targets': [
    for (final i in d.items) {...i.choice, 'expected_weekly_revision': 8},
  ],
  'group_revision': d.groupId == null ? null : 9,
  'settings_defaults': {
    'auto_open_default': false,
    'experience_unrestricted_value': null,
    'experience_levels': [
      for (final e in recruitmentExperiences.entries)
        {'value': e.key, 'label': e.value},
    ],
  },
  'comparison': {
    'selected_role': d.role,
    'requirement': null,
    'actual': '3480.12345',
    'state': 'unrestricted',
    'source': 'flutter_analysis',
    'trust': 'client_submitted',
    'current_summary_version': 5,
    'success_summary_version': 4,
    'power_revision': 1,
    'observed_at': stamp,
    'success_saved_at': stamp,
    'success_issues': <Object>[],
    'current_issues': [
      {'code': 'BUILD_REVIEW', 'severity': 'warning'},
    ],
  },
  'permissions': {
    'create': {
      'allowed': allowed,
      'reason': allowed ? null : 'RAID_ITEM_LEVEL_REQUIRED',
    },
  },
};
Map<String, dynamic> ackJson(String key) => {
  'command_id': key,
  'outcome': 'applied',
  'revisions': [
    {'resource': 'room', 'id': roomId, 'revision': 1},
    {'resource': 'membership', 'id': membershipId, 'revision': 1},
  ],
  'executed_at': stamp,
};
Map<String, dynamic> detailJson() => {
  'room': {
    'room_id': roomId,
    'revision': 1,
    'title': '레이드 A 모집',
    'scope': 'public',
    'group_id': null,
    'admission_mode': 'leader_only',
    'experience_level': null,
    'app_capacity': 8,
    'app_member_count': 1,
    'state': 'active',
    'items': [
      {
        'item_id': itemId,
        'raid_id': 'raid_a',
        'difficulty_id': 'hard',
        'game_party_size': 8,
      },
    ],
    'game_items': <Object>[],
    'leader_display': null,
    'created_at': stamp,
    'cycle_key': '2026-10-14',
    'phase': 'current',
    'restricted': false,
    'schedule_summary': {
      'mode': 'unscheduled',
      'occurrence_mode': null,
      'confirmed_starts_at': <Object>[],
      'earliest_start': null,
      'latest_start': null,
    },
    'combat_requirement': {
      'input_mode': 'shared',
      'dealer_min': null,
      'support_min': null,
    },
    'continuation_enabled': false,
    'permissions': {
      'view_detail': {'allowed': true, 'reason': null},
    },
  },
  'settings': null,
  'members_revision': 1,
  'members': [
    {
      'membership_id': membershipId,
      'revision': 1,
      'room_role': 'leader',
      'group_member': false,
      'joined_at': stamp,
      'character': {
        'character_id': characterId,
        'display': {'character_name': '검사', 'class_name': '버서커'},
        'selected_role': 'dealer',
      },
      'assignments': <Object>[],
      'comparison': null,
      'build': null,
      'is_me': true,
      'status': 'valid',
      'status_reason': null,
    },
  ],
  'my_membership': {
    'membership_id': membershipId,
    'revision': 1,
    'room_role': 'leader',
    'group_member': false,
  },
  'plan_revision': 1,
  'permissions': {
    'view_detail': {'allowed': true, 'reason': null},
  },
  'access': {
    'state': 'allowed',
    'policy_snapshot': 'snapshot',
    'evaluated_at': stamp,
    'issues': <Object>[],
  },
};
RaidCatalog testCatalog() => RaidCatalog(
  schemaVersion: 2,
  catalogVersion: 'v2',
  updatedAt: DateTime.parse(stamp),
  raids: const [
    RaidDefinition(
      raidId: 'raid_a',
      officialName: '레이드 A',
      displayName: '레이드 A',
      aliases: [],
      partySize: 8,
      partyCount: 2,
      requiredSupportCount: 2,
      maxDealerCountPerClass: 2,
      gateCount: 2,
      isActive: true,
      difficulties: [
        RaidDifficultyDefinition(
          difficultyId: 'hard',
          name: '하드',
          displayAlias: '하드',
          displayOrder: 1,
          minItemLevel: 1700,
          clearGold: 0,
          boundGold: 0,
          isActive: true,
        ),
      ],
    ),
  ],
);

class Access extends ChangeNotifier {
  bool verified = true;
  void lose() {
    verified = false;
    notifyListeners();
  }
}

class Gateway implements RecruitmentGateway {
  final writes = <({String key, String body})>[];
  int contexts = 0, details = 0;
  Future<RecruitmentCreationContext> Function(RecruitmentDraft)? onContext;
  Future<RecruitmentCreationAck> Function(String, Map<String, dynamic>)?
  onWrite;
  bool failDetail = false;
  @override
  Future<RaidCatalog> catalog() async => testCatalog();
  @override
  Future<List<RecruitmentCharacter>> characters() async => const [
    RecruitmentCharacter(
      id: characterId,
      registrationId: registrationId,
      name: '검사',
      className: '버서커',
      accountLabel: '본계정',
      itemLevel: '1770',
      representative: true,
    ),
  ];
  @override
  Future<List<RecruitmentGroupChoice>> groups() async =>
      throw const AccountReadException('SERVICE_UNAVAILABLE', status: 503);
  @override
  Future<RecruitmentCreationContext> context(RecruitmentDraft d) async {
    contexts++;
    return onContext == null
        ? RecruitmentCreationContext.fromJson(
            contextJson(d, revision: contexts),
            d,
          )
        : onContext!(d);
  }

  @override
  Future<RecruitmentCreationAck> create(
    String key,
    Map<String, dynamic> body,
  ) async {
    writes.add((key: key, body: jsonEncode(body)));
    return onWrite == null
        ? RecruitmentCreationAck.fromJson(ackJson(key), key)
        : onWrite!(key, body);
  }

  @override
  Future<BackendRecruitmentDetail> detail(String id) async {
    details++;
    if (failDetail) throw const AccountReadException('NETWORK_UNAVAILABLE');
    return BackendRecruitmentDetail.fromJson(detailJson(), id);
  }

  @override
  Future<List<String>> currentRoomIds() async => [roomId];
}

class Api implements BackendRegistrationApi {
  final requests = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>?)? respond;
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) async {
    requests.add({
      'path': path,
      'method': method,
      'body': body,
      'query': query,
      'key': idempotencyKey,
      'status': expectedStatus,
    });
    if (respond != null) return respond!(path, query);
    if (method == 'POST') return ackJson(idempotencyKey!);
    return contextJson(draft());
  }
}

void main() {
  test(
    'wire preserves nullable fields, decimal strings, versions and default unscheduled',
    () {
      final d = draft().copy(
        groupId: groupId,
        sharedMinimum: '3000.123456789012345',
      );
      final c = RecruitmentCreationContext.fromJson(contextJson(d), d),
          body = d.body(c, '기본 제목');
      expect(body.keys.toSet(), {
        'title',
        'scope',
        'group_id',
        'admission_mode',
        'app_mode',
        'items',
        'selection',
        'selection_context',
        'experience_level',
        'combat_requirement',
        'continuation',
        'schedule_groups',
        'expected_cycle_key',
        'expected_catalog_version',
        'expected_group_revision',
      });
      expect(body['schedule_groups'], isEmpty);
      expect(body['experience_level'], isNull);
      expect(
        (body['combat_requirement'] as Map)['dealer_min'],
        '3000.123456789012345',
      );
      expect((body['items'] as List).single, {
        'raid_id': 'raid_a',
        'difficulty_id': 'hard',
        'duration_minutes': null,
        'expected_weekly_revision': 8,
        'party_no': 1,
      });
      expect(body['expected_group_revision'], 9);
      expect(c.hasBuildWarning, true);
    },
  );
  test(
    'manual mixed bundle has KST weekdays, full item order, no arbitrary timestamps',
    () {
      final d = draft().copy(
        items: const [
          RecruitmentItemDraft('raid_a', 'hard', minutes: 10),
          RecruitmentItemDraft('raid_b', 'normal'),
        ],
        weekdays: {6, 3},
        startMinute: 1205,
        eachDay: true,
      );
      final body = d.body(
        RecruitmentCreationContext.fromJson(contextJson(d), d),
        '묶음',
      );
      expect(body['app_mode'], 'mixed_bundle');
      final s = (body['schedule_groups'] as List).single as Map;
      expect(s['occurrence_mode'], 'each');
      expect(s['planning_mode'], 'manual');
      expect((s['alternatives'] as List).first, {
        'client_alternative_key': 'day_3',
        'existing_session_id': null,
        'expected_session_revision': null,
        'weekday': 3,
        'starts_local': '20:05',
        'leader_latest_start_local': null,
        'item_order': ['raid_a', 'raid_b'],
      });
      expect(
        draft().copy(weekdays: {6}).schedules.single['planning_mode'],
        'unscheduled',
      );
    },
  );
  test(
    'invalid duration, duplicate raid, title controls and invalid decimals reject before send',
    () {
      expect(
        draft()
            .copy(
              items: const [
                RecruitmentItemDraft('raid_a', 'hard', minutes: 1440),
              ],
            )
            .validate(),
        isNull,
      );
      for (final minutes in [0, 9, 1445, 11]) {
        expect(
          draft()
              .copy(
                items: [
                  RecruitmentItemDraft('raid_a', 'hard', minutes: minutes),
                ],
              )
              .validate(),
          isNotNull,
        );
      }
      expect(
        draft().copy(items: [...draft().items, ...draft().items]).validate(),
        isNotNull,
      );
      expect(draft().copy(title: '줄\n바꿈').validate(), isNotNull);
      expect(draft().copy(sharedMinimum: '1e9').validate(), isNotNull);
    },
  );
  test(
    'weekday-specific manual times stay within each alternative; incomplete edits cannot save',
    () {
      final base = draft().copy(
        weekdays: {4, 6},
        sameStart: false,
        startsByDay: {4: 1200},
      );
      expect(base.validate(), isNotNull);
      final d = base.copy(startsByDay: {4: 1200, 6: 1235});
      expect(d.validate(), isNull);
      final alternatives = d.schedules.single['alternatives'] as List;
      expect(alternatives.map((a) => a['starts_local']), ['20:00', '20:35']);
      expect(
        d
            .copy(sameStart: true, startMinute: 1260)
            .schedules
            .single['alternatives'],
        everyElement(containsPair('starts_local', '21:00')),
      );
      expect(d.copy(clearStart: true).hasManualTime, false);
    },
  );
  test(
    'context rejects wrong identity, target order, missing CAS and malformed token',
    () {
      final d = draft();
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => (j['selection'] as Map)['character_id'] = secondCharacterId,
        (j) => (j['targets'] as List).clear(),
        (j) => (j['selection'] as Map).remove('expected_usage_revision'),
        (j) => j['context_token'] = 'not-a-context',
      ]) {
        final j = contextJson(d);
        mutate(j);
        expect(
          () => RecruitmentCreationContext.fromJson(j, d),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'ACK binds key and exactly one room UUID; unrelated detail ID rejected',
    () {
      expect(
        () => RecruitmentCreationAck.fromJson(
          ackJson(characterId),
          registrationId,
        ),
        throwsFormatException,
      );
      final j = ackJson(characterId);
      (j['revisions'] as List).add({
        'resource': 'room',
        'id': roomId,
        'revision': 1,
      });
      expect(
        () => RecruitmentCreationAck.fromJson(j, characterId),
        throwsFormatException,
      );
      expect(
        () => BackendRecruitmentDetail.fromJson(detailJson(), characterId),
        throwsFormatException,
      );
    },
  );
  test(
    'repository uses JSON items query and required 201 with immutable command key',
    () async {
      final session = ReadSessionFake(), api = Api(), dio = Dio();
      final repository = BackendRecruitmentRepository(
        api: api,
        accounts: ServerAccountReadRepository(ReadApiFake(), session),
        raids: MemberRaidClient(DioBackendAccountReadApi(dio, session)),
      );
      await repository.context(draft());
      expect(api.requests.single['query'], {
        'character_id': characterId,
        'selected_role': 'dealer',
        'items': '[{"raid_id":"raid_a","difficulty_id":"hard"}]',
      });
      final body = draft().body(
        RecruitmentCreationContext.fromJson(contextJson(draft()), draft()),
        '제목',
      );
      final ack = await repository.create(characterId, body);
      expect(api.requests.last['status'], 201);
      expect(api.requests.last['key'], characterId);
      expect(ack.roomId, roomId);
      dio.close();
      session.dispose();
    },
  );

  group('app-owned command lifecycle', () {
    late ReadSessionFake session;
    late Gateway gateway;
    late Access access;
    late BackendRecruitmentCreateViewModel m;
    late DateTime now;
    setUp(() async {
      now = DateTime.parse(stamp);
      session = ReadSessionFake();
      gateway = Gateway();
      access = Access();
      m = BackendRecruitmentCreateViewModel(
        gateway: gateway,
        session: session,
        accessChanges: access,
        hasVerifiedAccount: () => access.verified,
        now: () => now,
      );
      await m.activate();
    });
    tearDown(() {
      m.dispose();
      access.dispose();
      session.dispose();
    });
    test(
      '1770 Belgardin defaults to hard; character change repairs only ineligible choices',
      () async {
        m.catalog = const RaidCatalogMapper().fromJson(
          jsonDecode(
                File(
                  'assets/raid_catalog/raid_catalog.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        m.update(
          m.draft.copy(
            title: '보존',
            items: [const RecruitmentItemDraft('belgardin', 'nightmare')],
          ),
        );
        final option = m.raidOptions.firstWhere(
          (o) => o.raid.raidId == 'belgardin',
        );
        expect(option.difficulties.map((d) => d.difficultyId), [
          'normal',
          'hard',
        ]);
        expect(m.draft.items.single.difficultyId, 'hard');
        m.update(
          m.draft.copy(
            items: [const RecruitmentItemDraft('belgardin', 'normal')],
          ),
        );
        expect(m.draft.items.single.difficultyId, 'normal');
        const other = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
        m.characters = [
          ...m.characters,
          const RecruitmentCharacter(
            id: other,
            registrationId: registrationId,
            name: '다른 캐릭터',
            className: '바드',
            accountLabel: '본계정',
            itemLevel: '1740',
          ),
        ];
        m.update(m.draft.copy(characterId: other));
        expect(m.raidOptions.any((o) => o.raid.raidId == 'belgardin'), false);
        expect(m.draft.items.single.raidId, isNot('belgardin'));
        expect(m.draft.title, '보존');
        m.characters = [];
        m.update(m.draft.copy(characterId: characterId));
        expect(m.raidOptions, isEmpty);
        expect(m.draft.items, isEmpty);
        expect(m.validationMessage, isNotNull);
      },
    );
    test(
      'local manual schedule blocks past days without a write and checks all common days',
      () async {
        m.update(
          m.draft.copy(weekdays: {1, 2}, startMinute: 1200, eachDay: true),
        );
        final requests = gateway.contexts;
        expect(m.canStart(1200), false);
        expect(m.canStart(1200, day: 2), true);
        expect(m.canSelectDay(1), false);
        await m.submit();
        expect(gateway.contexts, requests);
        expect(gateway.writes, isEmpty);
        m.update(m.draft.copy(weekdays: {2}));
        expect(m.validationMessage, isNull);
        expect(m.canStart(1200), true);
        now = DateTime.parse('2026-10-20T10:30:01Z');
        expect(m.canStart(1200), false);
      },
    );
    test(
      'bundle duration uses explicit OR fallback per item, never adds both',
      () async {
        m.catalog = const RaidCatalogMapper().fromJson(
          jsonDecode(
                File(
                  'assets/raid_catalog/raid_catalog.v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
        );
        m.update(
          m.draft.copy(
            items: [
              const RecruitmentItemDraft('serca', 'nightmare', minutes: 40),
              const RecruitmentItemDraft('belgardin', 'hard'),
            ],
          ),
        );
        expect(m.durationMinutes, 60);
        m.update(
          m.draft.copy(
            items: [
              const RecruitmentItemDraft('serca', 'nightmare', minutes: 1440),
              const RecruitmentItemDraft('belgardin', 'hard'),
            ],
          ),
        );
        expect(m.durationMinutes, 1460);
        expect(m.validationMessage, contains('24시간'));
        await m.submit();
        expect(gateway.writes, isEmpty);
      },
    );
    test('new create entry resets only a completed command', () async {
      m.update(m.draft.copy(title: '이전 모집', weekdays: {2}, startMinute: 1320));
      await m.submit();
      expect(m.createdRoomId, roomId);
      await m.activate();
      expect(m.createdRoomId, isNull);
      expect(m.draft.title, isEmpty);
      expect(m.draft.weekdays, isEmpty);
      expect(m.draft.startMinute, isNull);
      expect(m.editable, true);
      expect(m.selection, isNotNull);
      expect(gateway.writes.length, 1);
      await m.submit();
      expect(gateway.writes.length, 2);
      expect(gateway.writes[0].key, isNot(gateway.writes[1].key));
    });
    test(
      'rejected schedule keeps draft on re-entry and allows correction',
      () async {
        m.update(
          m.draft.copy(title: '수동 모집', weekdays: {2}, startMinute: 1320),
        );
        gateway.onWrite = (key, body) async => throw const AccountReadException(
          'SCHEDULE_BEFORE_FLOOR',
          status: 409,
        );
        await m.submit();
        expect(m.hasPending, false);
        await m.activate();
        expect(m.draft.title, '수동 모집');
        expect(m.draft.startMinute, 1320);
        expect(m.failure, 'SCHEDULE_BEFORE_FLOOR');
        expect(recruitmentFailureMessage(m.failure), contains('30분'));
        expect(recruitmentFailureMessage('SCHEDULE_IN_PAST'), contains('지난'));
        expect(recruitmentFailureMessage('MAINTENANCE_WINDOW'), contains('점검'));
        m.update(m.draft.copy(startMinute: 1380));
        expect(m.editable, true);
        expect(m.failure, isNull);
        expect(gateway.writes.length, 1);
      },
    );
    test(
      'submit refreshes preview CAS, does not block on build warnings',
      () async {
        expect(m.draft.sharedPower, false);
        final before = gateway.contexts;
        await m.submit();
        expect(gateway.contexts, before + 1);
        expect(m.createdRoomId, roomId);
        expect(
          (jsonDecode(gateway.writes.single.body)['selection']
              as Map)['expected_registration_version'],
          before + 1,
        );
      },
    );
    test(
      'unknown outcome freezes draft and retries exact body/key across route activation',
      () async {
        gateway.onWrite = (key, body) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await m.submit();
        expect(m.hasPending, true);
        final before = m.draft.title;
        m.update(m.draft.copy(title: '변경'));
        expect(m.draft.title, before);
        await m.activate();
        await m.submit();
        expect(gateway.writes.length, 1);
        gateway.onWrite = null;
        await m.retry();
        expect(gateway.writes[0], gateway.writes[1]);
        expect(m.createdRoomId, roomId);
      },
    );
    test(
      'definite conflict preserves input and requires fresh explicit command/context',
      () async {
        m.update(m.draft.copy(title: '보존할 제목'));
        gateway.onWrite = (key, body) async => throw const AccountReadException(
          'SELECTION_CONTEXT_CHANGED',
          status: 409,
        );
        await m.submit();
        expect(m.hasPending, false);
        expect(m.draft.title, '보존할 제목');
        expect(m.selection, isNull);
        gateway.onWrite = null;
        await m.submit();
        expect(gateway.writes[0].key, isNot(gateway.writes[1].key));
      },
    );
    test(
      'in-progress honors Retry-After and does not allocate another key',
      () async {
        gateway.onWrite = (key, body) async => throw const AccountReadException(
          'REQUEST_IN_PROGRESS',
          status: 409,
          retryAfter: Duration(seconds: 2),
        );
        await m.submit();
        expect(m.canRetry, false);
        await m.retry();
        expect(gateway.writes.length, 1);
        now = now.add(const Duration(seconds: 2));
        gateway.onWrite = null;
        await m.retry();
        expect(gateway.writes[0], gateway.writes[1]);
      },
    );
    test(
      'expired unknown command stays frozen; current memberships lookup never creates',
      () async {
        gateway.onWrite = (key, body) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await m.submit();
        now = now.add(const Duration(hours: 24));
        expect(m.retryExpired, true);
        await m.retry();
        await m.submit();
        await m.checkCurrentRooms();
        expect(gateway.writes.length, 1);
        expect(m.recoveryRooms, [roomId]);
        expect(m.hasPending, true);
      },
    );
    test('late context response cannot replace a newer selection', () async {
      final old = Completer<RecruitmentCreationContext>();
      final snapshot = m.draft;
      gateway.onContext = (d) => d.role == 'dealer'
          ? old.future
          : Future.value(
              RecruitmentCreationContext.fromJson(contextJson(d), d),
            );
      final pending = m.refreshContext();
      m.update(m.draft.copy(role: 'support'));
      await Future<void>.delayed(Duration.zero);
      old.complete(
        RecruitmentCreationContext.fromJson(contextJson(snapshot), snapshot),
      );
      await pending;
      expect(m.selection!.selection['selected_role'], 'support');
    });
    test(
      'session switch ignores late successful create and clears previous member data',
      () async {
        final result = Completer<RecruitmentCreationAck>();
        String? key;
        gateway.onWrite = (k, b) {
          key = k;
          return result.future;
        };
        final pending = m.submit();
        await Future<void>.delayed(Duration.zero);
        session.change(authenticated: false);
        result.complete(RecruitmentCreationAck.fromJson(ackJson(key!), key!));
        await pending;
        expect(m.createdRoomId, isNull);
        expect(m.characters, isEmpty);
        expect(m.hasPending, false);
      },
    );
    test('ownership loss during context read blocks submission', () async {
      final result = Completer<RecruitmentCreationContext>();
      final snapshot = m.draft;
      gateway.onContext = (_) => result.future;
      final pending = m.submit();
      access.lose();
      result.complete(
        RecruitmentCreationContext.fromJson(contextJson(snapshot), snapshot),
      );
      await pending;
      expect(gateway.writes, isEmpty);
      expect(m.eligible, false);
    });
    test('group lookup failure does not block public creation', () async {
      await m.loadGroups();
      expect(m.groupFailure, isNotNull);
      await m.submit();
      expect(m.createdRoomId, roomId);
    });
    test(
      'ACK then detail failure retries only detail, never re-creates',
      () async {
        await m.submit();
        gateway.failDetail = true;
        final detail = BackendRecruitmentDetailViewModel(
          gateway: gateway,
          session: session,
          roomId: m.createdRoomId!,
        );
        await detail.load();
        expect(detail.failure, 'NETWORK_UNAVAILABLE');
        gateway.failDetail = false;
        await detail.load();
        expect(detail.value!.title, '레이드 A 모집');
        expect(gateway.writes.length, 1);
        expect(gateway.details, 2);
        detail.dispose();
      },
    );
    test(
      'expired recovery binds leader, selected character, items and original title',
      () async {
        gateway.onWrite = (key, body) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await m.submit();
        now = now.add(const Duration(hours: 24));
        await m.checkCurrentRooms();
        await m.confirmRecoveredRoom(roomId);
        expect(m.createdRoomId, roomId);
        expect(m.hasPending, false);
        expect(gateway.writes.length, 1);
      },
    );
    test('another room cannot clear an unknown command', () async {
      m.update(m.draft.copy(title: '다른 제목'));
      gateway.onWrite = (key, body) async =>
          throw const AccountReadException('NETWORK_UNAVAILABLE');
      await m.submit();
      await m.checkCurrentRooms();
      await m.confirmRecoveredRoom(roomId);
      expect(m.createdRoomId, isNull);
      expect(m.hasPending, true);
      expect(m.notice, isNotNull);
    });
  });
}
