import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'backend_recruitment_test.dart' as b;
import 'cycle_interaction_test.dart' as search;
import 'cycle_management_test.dart' as management;
import 'cycle_recruitment_test.dart' as cycles;
import 'membership_readers_test.dart' as records;

const group = '10000000-0000-4000-8000-000000000001';
const beta = RecruitmentContractMode.betaWire2;
Map<String, dynamic> copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Map<String, dynamic> groupPage({String state = 'active'}) {
  final raw = search.searchWire(cycles.c);
  raw['data']['items'][0]['group_id'] = group;
  raw['data']['items'][0]['beta_schedule'] = null;
  raw['group_states'] = [
    {
      'group_id': group,
      'name': state == 'unavailable' ? null : '서버 그룹',
      'state': state,
    },
  ];
  raw['room_groups'] = <Map<String, dynamic>>[
    {'room_id': b.roomId, 'group_id': group},
  ];
  return raw;
}

void main() {
  test(
    'search requests metadata in query, retaining the exact search body',
    () async {
      const BetaContract(
        mode: beta,
      ).validateResponse('POST', '/v2/raid-rooms/search', 200, groupPage());
      final api = b.Api()..respond = (_, _) async => groupPage();
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: beta,
        includeGroupList: true,
      );
      final filter = CycleSearchFilter();
      final page = await repo.search(cycles.c, filter);
      expect(api.requests, hasLength(1));
      expect(api.requests.single['query']['include_group_state'], 'true');
      expect(api.requests.single['body'], filter.body(cycles.c));
      expect(retainedGroupLabel(page.rows.single.betaData), '서버 그룹');
      expect(page.rows.single.wire['group_id'], group);
    },
  );

  test(
    'membership page consumes current room directory without inventing historical content',
    () async {
      final raw = records.sample('current_unknown_generation_page');
      final item = raw['data']['items'][0];
      item['beta_schedule'] = null;
      final room = item['target']['room_id'] as String;
      raw['group_states'] = [
        {'group_id': group, 'name': '보존 그룹', 'state': 'ended'},
      ];
      raw['room_groups'] = [
        {'room_id': room, 'group_id': group},
      ];
      final api = b.Api()..respond = (_, _) async => raw;
      final result = await readRecruitment(
        api: api,
        mode: beta,
        path: '/v2/me/raid-room-memberships',
        includeGroupList: true,
        query: {
          'target_cycle_key': cycles.c,
          'reader_profile': membershipReaderProfile,
        },
        parse: (json) => CycleOwnPage.profile(cycles.c, json),
      );
      final row = result.value.rows.single;
      expect(row.card, isNull);
      expect(row.profile!.content, isNull);
      expect(
        retainedGroupLabel(listDisplayData(result.metadata, item, row.roomId)),
        '보존 그룹 · 해산된 그룹',
      );
    },
  );
  test(
    'list mappings reject omissions, duplicate rooms, wrong links and unknown states',
    () {
      for (final change in <void Function(Map<String, dynamic>)>[
        (raw) => raw.remove('group_states'),
        (raw) => raw['room_groups'] = <Map<String, dynamic>>[],
        (raw) => raw['room_groups'].add(copy(raw['room_groups'][0])),
        (raw) => raw['room_groups'][0]['group_id'] = null,
        (raw) => raw['group_states'][0]['state'] = 'unknown',
        (raw) => raw['group_states'][0]['group_id'] = b.membershipId,
      ]) {
        final raw = groupPage();
        change(raw);
        expect(() => groupListStates(raw), throwsFormatException);
      }
      final ended = groupListStates(groupPage(state: 'ended'));
      expect(
        retainedGroupLabel({'group_state': ended[b.roomId]}),
        '서버 그룹 · 해산된 그룹',
      );
      final missing = groupListStates(groupPage(state: 'unavailable'));
      expect(
        retainedGroupLabel({'group_state': missing[b.roomId]}),
        contains('확인 불가'),
      );
      expect(
        groupListStates({
          'data': {'items': []},
          'room_groups': [],
          'group_states': [],
        }),
        isEmpty,
      );
    },
  );

  test(
    'application origin is historical, membership content null is retained',
    () {
      final raw = groupPage();
      raw['data']['items'] = [
        {
          'room_id': b.roomId,
          'admission_origin': {'group_id': b.membershipId},
        },
      ];
      expect(groupListStates(raw)[b.roomId]['group_id'], group);
      raw['data']['items'] = [
        {
          'target': {'room_id': b.roomId},
          'content': null,
        },
      ];
      expect(groupListStates(raw)[b.roomId]['group_id'], group);
      expect(raw['data']['items'][0]['content'], isNull);
    },
  );

  test(
    'fixed beta root target survives decoding and binds the selected group',
    () async {
      final raw = management.managementWire('common');
      raw['target_group'] = {
        'group_id': group,
        'group_revision': 4,
        'members_revision': 6,
        'membership_id': b.membershipId,
        'membership_revision': 2,
        'permission': {'allowed': true, 'reason': null, 'next_change_at': null},
      };
      final api = b.Api()..respond = (_, _) async => raw;
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: beta,
      );
      final preview = await repo.management(
        b.roomId,
        cycles.c,
        'common',
        query: {'target_group_id': group},
      );
      expect(
        preview.body({
          'title': '연결',
          'group_id': group,
          'scope': 'group',
        })['expected_group_revision'],
        4,
      );
      final changed = copy(raw)..['target_group']['membership_revision'] = 3;
      api.respond = (_, _) async => changed;
      final next = await repo.management(
        b.roomId,
        cycles.c,
        'common',
        query: {'target_group_id': group},
      );
      expect(next.signature, isNot(preview.signature));
      raw['target_group']['group_id'] = b.membershipId;
      api.respond = (_, _) async => raw;
      await expectLater(
        repo.management(
          b.roomId,
          cycles.c,
          'common',
          query: {'target_group_id': group},
        ),
        throwsA(anything),
      );
    },
  );

  test(
    'all detail profiles preserve target affiliation for a non-group viewer',
    () {
      final wrapped = copy(records.normalDetail());
      final content = wrapped['data']['content'] as Map<String, dynamic>;
      final data = content['data'];
      data['room']['group_id'] = group;
      // The actor is outside the group; the displayed participant is in it.
      data['my_membership'] = {
        'membership_id': b.membershipId,
        'revision': 1,
        'group_member': false,
        'target_role': 'leader',
        'cycle_member_id': b.membershipId,
        'cycle_member_revision': 1,
        'joined_order': '1',
      };
      data['members'][0]['group_member'] = true;
      data['permissions'] = {
        for (final key in ['view_detail', 'view_plan'])
          key: {'allowed': true, 'reason': null, 'next_change_at': null},
      };
      data['recruitment_identity'] = {'number': 1, 'password': '00009'};
      data['beta_schedule'] = null;
      data['room']['beta_schedule'] = null;
      final base = BetaResponse.parse(
        method: 'GET',
        path: '/v2/raid-rooms/${b.roomId}/detail',
        status: 200,
        json: content,
        parseLegacy: (raw) => BackendRecruitmentRepository.parseCycleDetail(
          raw,
          b.roomId,
          cycles.c,
        ),
      );
      expect(base.value.members.single['group_member'], true);
      final application = copy(content);
      application['data']['my_application'] = null;
      final app = BetaResponse.parse(
        method: 'GET',
        path: '/v2/raid-rooms/${b.roomId}/detail',
        status: 200,
        json: application,
        parseLegacy: (raw) =>
            ApplicationDisplayDetail.fromJson(raw, b.roomId, cycles.c),
      );
      expect(app.value.detail.members.single['group_member'], true);
      wrapped['data']['beta_schedule'] = null;
      wrapped['data']['recruitment_identity'] = data['recruitment_identity'];
      final member = BetaResponse.parse(
        method: 'GET',
        path: '/v2/raid-rooms/${b.roomId}/detail',
        status: 200,
        json: wrapped,
        parseLegacy: (raw) =>
            MembershipReadView(b.roomId, cycles.c, 'detail', raw),
      );
      final detail = BackendRecruitmentRepository.parseCycleDetail(
        member.value.projection.content!,
        b.roomId,
        cycles.c,
      );
      expect(detail.members.single['group_member'], true);
      data['members'][0]['group_member'] = null;
      expect(
        () => BetaResponse.parse(
          method: 'GET',
          path: '/v2/raid-rooms/${b.roomId}/detail',
          status: 200,
          json: content,
          parseLegacy: (raw) => raw,
        ),
        throwsFormatException,
      );
    },
  );
}
