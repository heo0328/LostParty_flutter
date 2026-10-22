import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/group_character_candidates.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_search_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as old;
import 'cycle_recruitment_test.dart' as f2;
import 'cycle_interaction_test.dart' as f3;
import '../account/backend_read/member_cycles_test.dart' as f1;

final ctxToken = 'a' * 64, memberRef = 'b' * 64, digest = 'c' * 64;
final candidateToken = 'd' * 64, nextToken = 'e' * 64;
const char1 = '11111111-1111-4111-8111-111111111111';
const char2 = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> contextWire({String? ref, String? membership}) => {
  ...f3.filterWire(),
  'filter_context_token': ctxToken,
  'scope_digest': digest,
  'members': [
    {
      'member_ref': ref ?? memberRef,
      'aliases': [
        {'group_id': old.groupId, 'group_membership_id': membership ?? f3.app},
      ],
      'display': {'character_name': '대표'},
    },
  ],
};
Map<String, dynamic> power({String? value, bool hidden = false}) => {
  'value': value,
  'source': value != null
      ? 'stored_role_success'
      : hidden
      ? 'not_disclosed'
      : 'unavailable',
  'trust': value == null ? null : 'client_submitted',
  'observed_at': value == null ? null : f2.nowStamp,
  'saved_at': value == null ? null : f2.nowStamp,
  'power_revision': value == null ? null : 1,
  'integrity_status': value == null ? null : 'clean',
};
Map<String, dynamic> character(String id, String? level) => {
  'character_id': id,
  'server_name': '서버',
  'character_name': '캐릭터',
  'class_name': '바드',
  'role_family': null,
  'item_level': level,
  'item_level_source': level == null
      ? 'unavailable'
      : 'stored_character_summary',
  'summary_fetched_at': f2.nowStamp,
  'ownership_revision': 1,
  'lifecycle_revision': 1,
  'ownership_state': 'owned',
  'activity_state': 'selected',
  'lifecycle_state': 'active',
  'dealer': power(),
  'support': power(value: '123.45'),
};
Map<String, dynamic> pageWire({
  String? token,
  bool from = false,
  bool to = false,
  String? cursor,
  List<Map<String, dynamic>>? characters,
  String? ref,
  String? membership,
}) => {
  'group_id': old.groupId,
  'filter_context_token': ctxToken,
  'scope_digest': digest,
  'candidate_token': token ?? candidateToken,
  'evaluated_at': f2.nowStamp,
  'groups': [
    {
      'member_ref': ref ?? memberRef,
      'alias': {
        'group_id': old.groupId,
        'group_membership_id': membership ?? f3.app,
      },
      'display': {
        'server_name': '서버',
        'character_name': '대표',
        'class_name': null,
      },
      'continues_from_previous': from,
      'continues_on_next': to,
      'characters': characters ?? [character(char1, '1770.00')],
    },
  ],
  'next_cursor': cursor,
};
CandidatePage decode(Map<String, dynamic> wire) => CandidatePage(
  wire,
  group: old.groupId,
  contextToken: ctxToken,
  scopeDigest: digest,
  aliases: {memberRef: f3.app},
);

void main() {
  late old.Api api;
  late f3.TestGateway gateway;
  late ReadSessionFake session;
  late ChangeNotifier changes;
  late CycleSearchViewModel model;
  late String token;
  late int candidateReads, searches;
  setUp(() {
    token = candidateToken;
    candidateReads = searches = 0;
    api = old.Api();
    session = ReadSessionFake();
    changes = ChangeNotifier();
    gateway = f3.TestGateway(api, f2.CycleGateway());
    api.respond = (path, q) async {
      if (path.endsWith('filter-context')) return contextWire();
      if (path.endsWith('character-candidates')) {
        candidateReads++;
        return pageWire(token: token);
      }
      if (path.endsWith('/search')) {
        searches++;
        return f3.searchWire(
          (api.requests.last['body'] as Map)['target_cycle_key'] as String,
        );
      }
      throw StateError(path);
    };
    model = CycleSearchViewModel(
      gateway: gateway,
      session: session,
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}',
    );
  });
  tearDown(() {
    model.dispose();
    changes.dispose();
  });
  Future<void> selected() async {
    await model.load();
    await model.selectGroup(old.groupId);
    model.selectCharacter(memberRef, char1);
    await f1.settled(() => !model.loading);
  }

  test(
    'candidate GET has exact read query and token omitted from legacy search',
    () async {
      final ctx = CycleFilterContext(contextWire(), old.groupId);
      await gateway.candidates(old.groupId, ctx);
      expect(api.requests.single['query'], {
        'filter_context_token': ctxToken,
        'limit': 50,
      });
      expect(api.requests.single['key'], isNull);
      expect(
        CycleSearchFilter()
            .body(f3.c)
            .containsKey('group_character_candidates_token'),
        false,
      );
      final body = CycleSearchFilter(
        groupId: old.groupId,
        token: ctxToken,
        candidateToken: candidateToken,
        members: {
          memberRef: {char1},
        },
      ).body(f3.n);
      expect(body['group_character_candidates_token'], candidateToken);
      expect(body['target_cycle_key'], f3.n);
    },
  );
  test('decimal numeric ordering/null last and stable UUID ties', () {
    expect(compareCandidateLevels('1000.0', '999.9'), lessThan(0));
    expect(compareCandidateLevels('001.00', '1.0'), 0);
    expect(compareCandidateLevels(null, '0'), greaterThan(0));
    expect(
      compareCandidateLevels(
        '999999999999999999999.2',
        '999999999999999999999.1',
      ),
      lessThan(0),
    );
    expect(
      decode(
        pageWire(
          characters: [character(char1, '1770'), character(char2, null)],
        ),
      ).members.single.characters.length,
      2,
    );
  });
  test(
    'member fragment append preserves one member and rejects invalid continuation',
    () {
      final first = decode(pageWire(to: true, cursor: 'next'));
      final second = decode(
        pageWire(from: true, characters: [character(char2, '1760')]),
      );
      final merged = second.appendTo(first.appendTo([]));
      expect(merged.single.characters.map((v) => v.id), [char1, char2]);
      expect(() => second.appendTo([]), throwsFormatException);
      expect(
        () => decode(
          pageWire(from: false, characters: [character(char2, '1760')]),
        ).appendTo(first.members),
        throwsFormatException,
      );
    },
  );
  for (final issue in [
    'wrong_group',
    'wrong_token',
    'wrong_alias',
    'duplicate',
    'order',
    'empty_continuation',
    'power',
    'unknown_field',
  ]) {
    test('strict candidate DTO rejects $issue', () {
      final j = pageWire();
      final m = (j['groups'] as List).single as Map;
      final c = (m['characters'] as List).single as Map;
      switch (issue) {
        case 'wrong_group':
          j['group_id'] = f3.room;
        case 'wrong_token':
          j['filter_context_token'] = nextToken;
        case 'wrong_alias':
          m['alias']['group_membership_id'] = f3.room;
        case 'duplicate':
          m['characters'] = [
            character(char1, '1770'),
            character(char1, '1760'),
          ];
        case 'order':
          m['characters'] = [
            character(char1, '999.9'),
            character(char2, '1000'),
          ];
        case 'empty_continuation':
          m['characters'] = [];
          m['continues_from_previous'] = true;
        case 'power':
          c['dealer']['value'] = '123';
        case 'unknown_field':
          c['account_id'] = f3.room;
      }
      expect(() => decode(j), throwsFormatException);
    });
  }
  test('empty member and unavailable/not_disclosed are distinct', () {
    expect(decode(pageWire(characters: [])).members.single.characters, isEmpty);
    expect(CandidatePower(power()).label, '정보 없음');
    expect(CandidatePower(power(hidden: true)).label, '비공개');
  });
  test(
    'refresh keeps off-page UUID; 200 empty search confirms selection',
    () async {
      await selected();
      token = nextToken;
      api.respond = (path, q) async {
        if (path.endsWith('filter-context')) return contextWire();
        if (path.endsWith('character-candidates')) {
          candidateReads++;
          return pageWire(
            token: token,
            characters: [character(char2, '1800')],
            to: true,
            cursor: 'next',
          );
        }
        if (path.endsWith('/search')) {
          searches++;
          return f2.envelope(f3.c, {
            'items': [],
            'directory_revision': 1,
            'filter_scope_digest': digest,
            'next_cursor': null,
            'evaluated_at': f2.nowStamp,
          });
        }
        throw StateError(path);
      };
      final before = candidateReads;
      await model.refreshCandidates();
      expect(candidateReads, before + 1);
      expect(searches, greaterThan(0));
      expect(model.filter.members[memberRef], {char1});
      expect(model.selectionPending, false);
      expect(model.rows, isEmpty);
      expect(model.filter.candidateToken, nextToken);
    },
  );
  test(
    'stale recovery budget one; repeated error holds UUID without broadening',
    () async {
      await selected();
      final before = candidateReads;
      var calls = 0;
      gateway.onSearch = (t, f, cursor) async {
        calls++;
        throw const AccountReadException(
          'GROUP_CHARACTER_CANDIDATES_STALE',
          status: 409,
        );
      };
      token = nextToken;
      await model.search();
      expect(calls, 2);
      expect(candidateReads, before + 1);
      expect(model.filter.members[memberRef], {char1});
      expect(model.selectionPending, true);
      expect(model.rows, isEmpty);
    },
  );
  test('400 invalid UUID does not retry or clear chosen conditions', () async {
    await selected();
    final before = candidateReads;
    gateway.onSearch = (t, f, cursor) async =>
        throw const AccountReadException('INVALID_REQUEST', status: 400);
    await model.search();
    expect(candidateReads, before);
    expect(model.selectionPending, true);
    expect(model.filter.members[memberRef], {char1});
  });
  test(
    'last character deselection removes member rather than selecting entire member',
    () async {
      await selected();
      model.selectCharacter(memberRef, char1);
      await f1.settled(() => !model.loading);
      expect(model.filter.members.containsKey(memberRef), false);
      model.selectMember(memberRef, true);
      expect(model.filter.members[memberRef], isEmpty);
    },
  );
  test(
    'same membership ref rotation preserves UUID; rejoin never inherits selection',
    () async {
      await selected();
      final newRef = 'f' * 64;
      api.respond = (path, q) async {
        if (path.endsWith('filter-context')) return contextWire(ref: newRef);
        if (path.endsWith('character-candidates')) {
          return pageWire(ref: newRef, token: nextToken);
        }
        return f3.searchWire(f3.c);
      };
      await model.refreshCandidates();
      expect(model.filter.members[newRef], {char1});
      api.respond = (path, q) async =>
          contextWire(ref: memberRef, membership: f3.room);
      await model.refreshCandidates();
      expect(model.filter.members[newRef], {char1});
      expect(model.groupFailure, 'FILTER_CONTEXT_STALE');
      expect(model.selectionPending, true);
    },
  );
  test(
    'candidate pages append explicitly; C/N cache shares candidates and clears token for multi group',
    () async {
      await model.load();
      api.respond = (path, q) async {
        if (path.endsWith('filter-context')) return contextWire();
        if (path.endsWith('character-candidates')) {
          candidateReads++;
          return q?['cursor'] == null
              ? pageWire(to: true, cursor: 'next')
              : pageWire(from: true, characters: [character(char2, '1760')]);
        }
        return f3.searchWire(
          (api.requests.last['body'] as Map)['target_cycle_key'] as String,
        );
      };
      await model.selectGroup(old.groupId);
      expect(candidateReads, 1);
      await model.loadCandidates(more: true);
      expect(model.candidateMembers.single.characters.map((c) => c.id), [
        char1,
        char2,
      ]);
      model.selectTarget(f3.n);
      await f1.settled(() => !model.loading);
      model.selectTarget(f3.c);
      await f1.settled(() => !model.loading);
      expect(candidateReads, 2);
      model.selectGroups({old.groupId, f3.room});
      expect(model.filter.candidateToken, isNull);
      expect(model.candidateMembers, isEmpty);
    },
  );
  test(
    'next candidate page stale refreshes first page once and retains selected UUID',
    () async {
      await selected();
      api.respond = (path, q) async {
        if (path.endsWith('filter-context')) return contextWire();
        if (path.endsWith('character-candidates')) {
          candidateReads++;
          if (q?['cursor'] != null) {
            throw const AccountReadException('CURSOR_STALE', status: 409);
          }
          return pageWire(to: true, cursor: 'next', token: token);
        }
        return f3.searchWire(f3.c);
      };
      await model.refreshCandidates();
      final before = candidateReads;
      token = nextToken;
      await model.loadCandidates(more: true);
      expect(candidateReads, before + 2);
      expect(model.filter.members[memberRef], {char1});
      expect(model.filter.candidateToken, nextToken);
      expect(model.selectionPending, false);
    },
  );
  test('late group context preserves newer raid filters', () async {
    await model.load();
    final wait = Completer<Map<String, dynamic>>();
    final respond = api.respond;
    api.respond = (path, q) async =>
        path.endsWith('filter-context') ? wait.future : respond!(path, q);
    final loading = model.selectGroup(old.groupId);
    model.update(model.filter.copy(raids: {'changed-raid'}, descending: false));
    wait.complete(contextWire());
    await loading;
    expect(model.filter.raids, {'changed-raid'});
    expect(model.filter.descending, false);
    expect(model.filter.candidateToken, candidateToken);
  });
  test('logout discards late candidate page and private selection', () async {
    await model.load();
    final wait = Completer<Map<String, dynamic>>();
    api.respond = (p, q) async =>
        p.endsWith('filter-context') ? contextWire() : wait.future;
    final loading = model.selectGroup(old.groupId);
    await f1.settled(() => model.candidateLoading);
    session.change(authenticated: false);
    wait.complete(pageWire());
    await loading;
    expect(model.candidateMembers, isEmpty);
    expect(model.filter.members, isEmpty);
    expect(model.groupContext, isNull);
  });
}
