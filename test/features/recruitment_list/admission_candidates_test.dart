import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/admission_candidates.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/admission_selection_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_participation_widgets.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_interaction_test.dart' as f3;
import 'cycle_recruitment_test.dart' as f2;

Map<String, dynamic> clone(Object v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;
final examples =
    (jsonDecode(
              File(
                'test/fixtures/admission_candidates.json',
              ).readAsStringSync(),
            )
            as Map)['examples']
        as List;
Map<String, dynamic> example(String name) =>
    clone(examples.singleWhere((v) => v['name'] == name)['response']);
AdmissionCandidatePage parse(Map<String, dynamic> j) => AdmissionCandidatePage(
  j,
  room: j['data']['room_id'],
  target: j['scope']['target_cycle_key'],
  intent: j['data']['intent'],
);
Map<String, dynamic> wire({
  String name = 'ordinary-dealer-only',
  String target = f2.c,
}) {
  final j = example(name);
  j['scope'] = f3.admissionWire(target)['scope'];
  j['data']['room_id'] = base.roomId;
  return j;
}

class Gateway extends f3.TestGateway {
  Gateway(base.Api api) : super(api, f2.CycleGateway());
  int reads = 0, metadataReads = 0, previews = 0;
  Map<String, dynamic> value = wire();
  Future<AdmissionCandidatePage> Function(String?)? onCandidates;
  Future<List<RecruitmentCharacter>> Function()? onMetadata;
  int previewParty = 1;
  bool changedPreview = false;
  String? deniedReason;
  @override
  Future<AdmissionCandidatePage> admissionCandidates(
    String room,
    String target,
    String intent, {
    String? cursor,
  }) async {
    reads++;
    return onCandidates == null ? parse(value) : onCandidates!(cursor);
  }

  @override
  Future<List<RecruitmentCharacter>> characters() async {
    metadataReads++;
    if (onMetadata != null) return onMetadata!();
    return [
      for (final v in value['data']['items'])
        RecruitmentCharacter(
          id: v['character_id'],
          registrationId: v['registration_id'],
          name: v['character_name'],
          className: v['class_name'],
          accountLabel: '본계정',
          itemLevel: v['item_level'],
          representative: true,
          preferredRole: 'dealer',
        ),
    ];
  }

  @override
  Future<CycleAdmissionPreview> admission(
    String room,
    String target,
    String character,
    String role,
    String intent,
  ) async {
    previews++;
    final j = f3.admissionWire(target, intent: intent);
    if (deniedReason != null) {
      j['data']['permissions'][intent] = {
        'allowed': false,
        'reason': deniedReason,
        'next_change_at': null,
      };
    }
    j['data']['selection']['character_id'] = character;
    j['data']['selection']['selected_role'] = role;
    j['data']['selection']['registration_id'] =
        (value['data']['items'] as List).first['registration_id'];
    j['data']['targets'][0]['party_no'] = previewParty;
    if (changedPreview) j['data']['room_revision'] = 2;
    return CycleAdmissionPreview(
      j,
      room: room,
      target: target,
      character: character,
      role: role,
      intent: intent,
    );
  }

  @override
  Future<Map<String, dynamic>> characterBody(
    CycleAdmissionPreview p,
    Set<String> sessions,
  ) async => {
    ...p.body(sessions),
    'assignments': [
      for (final a in value['data']['actor']['assignments'])
        {
          'assignment_id': a['assignment_id'],
          'expected_revision': a['revision'],
        },
    ],
    'expected_cycle_member_revision':
        value['data']['actor']['cycle_member_revision'],
  };
}

void main() {
  for (final v in examples) {
    test(
      'published synthetic vector ${v['name']} (not runtime)',
      () => expect(parse(clone(v['response'])), isA<AdmissionCandidatePage>()),
    );
  }
  final mutations = <String, void Function(Map<String, dynamic>)>{
    'extra root': (j) => j['extra'] = true,
    'wrong room': (j) => j['data']['room_id'] = base.roomId,
    'wrong intent': (j) => j['data']['intent'] = 'join',
    'unknown policy': (j) => j['data']['eligibility_policy_version'] = 'old',
    'missing actor': (j) => j['data'].remove('actor'),
    'bool count': (j) => j['data']['raw_candidate_count'] = true,
    'count underflow': (j) => j['data']['raw_candidate_count'] = 0,
    'count summary': (j) => j['data']['raw_candidate_count'] = 2,
    'unknown role field': (j) =>
        j['data']['items'][0]['roles']['dealer']['extra'] = 0,
    'wrong comparison role': (j) =>
        j['data']['items'][0]['roles']['dealer']['comparison']['selected_role'] =
            'support',
    'power below marked meets': (j) =>
        j['data']['items'][0]['roles']['dealer']['comparison']['actual'] =
            '99.9',
    'no allowed role': (j) {
      j['data']['items'][0]['roles']['dealer']['allowed'] = false;
      j['data']['items'][0]['roles']['dealer']['reason'] = 'ROOM_FULL';
    },
    'unsupported comparison': (j) =>
        j['data']['items'][0]['roles']['support']['comparison'] = {},
    'duplicate character': (j) =>
        j['data']['items'].add(clone(j['data']['items'][0])),
    'unbounded cursor': (j) => j['data']['next_cursor'] = 'x' * 2049,
  };
  for (final entry in mutations.entries) {
    test('reject ${entry.key}', () {
      final j = example('ordinary-dealer-only');
      final room = j['data']['room_id'] as String;
      entry.value(j);
      expect(
        () => AdmissionCandidatePage(
          j,
          room: room,
          target: f2.c,
          intent: 'apply',
        ),
        throwsFormatException,
      );
    });
  }
  test('deep immutable comparison and actor', () {
    final p = parse(example('change-only-own-assignment-removed'));
    expect(
      () => p.actor!.assignments.first['revision'] = 999,
      throwsUnsupportedError,
    );
    expect(
      () => p.items.first.dealer.comparison!['actual'] = '0',
      throwsUnsupportedError,
    );
  });
  test('oversized candidate response is rejected before materialization', () {
    final j = example('ordinary-dealer-only');
    j['padding'] = 'x' * (1024 * 1024);
    expect(
      () => parse(j),
      throwsA(
        isA<AccountReadException>().having(
          (e) => e.code,
          'code',
          'RESPONSE_TOO_LARGE',
        ),
      ),
    );
  });

  group('HTTP and selection lifetime', () {
    late base.Api api;
    late Gateway gateway;
    late ReadSessionFake session;
    late ChangeNotifier changes;
    late CycleParticipationController controller;
    late AdmissionSelectionViewModel m;
    String environment = 'one';
    String scope() => '$environment/${session.userId}/${session.generation}';
    setUp(() {
      environment = 'one';
      api = base.Api();
      gateway = Gateway(api);
      session = ReadSessionFake();
      changes = ChangeNotifier();
      controller = CycleParticipationController(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: scope,
        now: () => DateTime.parse(f2.nowStamp),
      );
      m = AdmissionSelectionViewModel(
        controller: controller,
        room: base.roomId,
        target: f2.c,
        intent: 'apply',
      );
      api.respond = (path, q) async {
        final r = api.requests.last;
        if (path.endsWith('/character-changes')) {
          return f2.envelope(f2.c, {
            'command_id': r['key'],
            'room_id': base.roomId,
            'target_cycle_key': f2.c,
            'executed_at': f2.nowStamp,
            'outcome': 'applied',
            'revisions': [],
          }, created: true);
        }
        return f2.envelope(f2.c, {
          'command_id': r['key'],
          'room_id': base.roomId,
          'application_id': base.membershipId,
          'revision': 1,
          'state': 'pending',
          'executed_at': f2.nowStamp,
          'target_cycle_key': f2.c,
        }, created: true);
      };
    });
    tearDown(() {
      m.dispose();
      controller.dispose();
      changes.dispose();
      session.dispose();
    });
    test(
      'stale target permission blocks only this admission without a pending write',
      () async {
        gateway.deniedReason = 'TARGET_CONTEXT_STALE';
        await m.load();
        expect(m.characters, isNotEmpty);
        expect(m.preview!.permission.allowed, false);
        expect(m.preview!.permission.reason, 'TARGET_CONTEXT_STALE');
        await m.submit();
        expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
        expect(controller.hasPending, false);
        expect(controller.canAct, true);
        final reads = gateway.reads;
        gateway.deniedReason = null;
        await m.load(preserve: true);
        expect(gateway.reads, reads + 1);
        expect(m.preview!.permission.allowed, true);
        expect(api.requests.where((r) => r['method'] == 'POST'), isEmpty);
      },
    );
    AdmissionSelectionViewModel replacement() {
      gateway.value = wire(name: 'change-eight-opposite-party-valid');
      gateway.value['data']['actor']['assignments'] = [
        {
          'assignment_id': base.membershipId,
          'revision': 1,
          'item_id': base.itemId,
          'round_id': f2.cycleId,
          'character_id': characterId,
          'selected_role': 'dealer',
          'party_no': 1,
          'slot_no': 2,
        },
      ];
      gateway.previewParty = 2;
      return AdmissionSelectionViewModel(
        controller: controller,
        room: base.roomId,
        target: f2.c,
        intent: 'change_character',
      );
    }

    test(
      'change actor matches latest proof and successful replacement has exact receipt',
      () async {
        final change = replacement();
        await change.load();
        expect(change.failure, isNull);
        expect(change.placementMessage, contains('1파티 → 2파티'));
        await change.submit();
        expect(change.completed, true);
        expect(controller.admissionSuccess!.$4, 'change_character');
        await change.submit();
        expect(api.requests.length, 1);
        change.dispose();
      },
    );
    test('changed actor blocks replacement before original write', () async {
      final change = replacement();
      await change.load();
      gateway.value['data']['actor']['cycle_member_revision']++;
      await change.submit();
      expect(change.completed, false);
      expect(api.requests, isEmpty);
      expect(change.failure, 'REVISION_CONFLICT');
      change.dispose();
    });
    testWidgets(
      'party move is confirmed, cancel writes zero, changed destination requires reconfirmation',
      (tester) async {
        final change = replacement();
        change.dispose();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCycleAdmission(
                    context,
                    controller,
                    room: base.roomId,
                    target: f2.c,
                    intent: 'change_character',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('내 캐릭터 변경 · ${f2.c}'));
        await tester.tap(find.text('내 캐릭터 변경 · ${f2.c}'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1파티 → 2파티'), findsOneWidget);
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(api.requests, isEmpty);
        await tester.tap(find.text('내 캐릭터 변경 · ${f2.c}'));
        await tester.pumpAndSettle();
        gateway.previewParty = 1;
        await tester.tap(find.text('변경'));
        await tester.pumpAndSettle();
        expect(api.requests, isEmpty);
        expect(controller.failure, 'REVISION_CONFLICT');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    test('new reader exact GET query, no key and no fallback', () async {
      api.respond = (p, q) async => gateway.value;
      await AdmissionCandidatesReader(
        api,
      ).admissionCandidates(base.roomId, f2.c, 'apply');
      expect(
        api.requests.single['path'],
        '/v2/raid-rooms/${base.roomId}/admission-character-candidates',
      );
      expect(api.requests.single['method'], 'GET');
      expect(api.requests.single['query'], {
        'target_cycle_key': f2.c,
        'intent': 'apply',
        'limit': 100,
      });
      expect(api.requests.single['key'], isNull);
      api.respond = (p, q) async =>
          throw const AccountReadException('NOT_FOUND', status: 404);
      await expectLater(
        AdmissionCandidatesReader(
          api,
        ).admissionCandidates(base.roomId, f2.c, 'apply'),
        throwsA(isA<AccountReadException>()),
      );
      expect(api.requests.length, 2);
    });
    test(
      'support-only uses server eligibility, preserved metadata and no per-character context',
      () async {
        gateway.value = wire(
          name: 'valkyrie-support-only-same-class-other-role',
        );
        await m.load();
        expect(m.failure, isNull);
        expect(m.role, 'support');
        expect(m.roleAllowed('dealer'), false);
        expect(gateway.previews, 1);
        expect(gateway.metadataReads, 1);
        expect(m.characters.single.accountLabel, '본계정');
        await m.selectRole('dealer');
        expect(m.role, 'support');
        expect(gateway.previews, 1);
      },
    );
    test(
      'metadata missing retries once, never hides candidate as empty success',
      () async {
        gateway.onMetadata = () async => [];
        await m.load();
        expect(gateway.metadataReads, 2);
        expect(m.failure, 'CHARACTER_DATA_UNAVAILABLE');
        expect(m.characters, isEmpty);
      },
    );
    for (final name in [
      'no-source-candidates',
      'required-power-missing',
      'power-below',
    ]) {
      test('empty outcome $name distinct from read failure', () async {
        gateway.value = wire(name: name);
        await m.load();
        expect(m.failure, isNull);
        expect(m.characters, isEmpty);
        expect(gateway.metadataReads, 0);
        expect(gateway.previews, 0);
        expect(
          m.emptyMessage,
          contains(name == 'no-source-candidates' ? '인증' : '신청 가능한'),
        );
        if (name != 'no-source-candidates') {
          expect(
            m.exclusionMessages.single,
            contains(name == 'power-below' ? '미달' : '갱신'),
          );
        }
      });
    }
    test('read failure not converted into empty result', () async {
      gateway.onCandidates = (_) async =>
          throw const AccountReadException('SERVICE_UNAVAILABLE', status: 503);
      await m.load();
      expect(m.failure, 'SERVICE_UNAVAILABLE');
      expect(m.emptyMessage, '');
    });
    for (final fault in ['snapshot', 'duplicate', 'missing', 'loop']) {
      test('reject partial pages $fault before display or preview', () async {
        var call = 0;
        gateway.onCandidates = (cursor) async {
          final j = wire();
          j['data']['raw_candidate_count'] = 2;
          j['data']['eligible_candidate_count'] = 2;
          if (call++ == 0) {
            j['data']['next_cursor'] = 'next';
          } else {
            if (fault == 'snapshot') j['data']['snapshot_token'] = 'b' * 64;
            if (fault == 'missing') j['data']['items'] = [];
            if (fault == 'loop') j['data']['next_cursor'] = 'next';
          }
          return parse(j);
        };
        await m.load();
        expect(m.failure, isNotNull);
        expect(m.characters, isEmpty);
        expect(gateway.previews, 0);
      });
    }
    for (final action in ['logout', 'environment', 'dispose']) {
      test('late candidate ignored after $action', () async {
        final wait = Completer<AdmissionCandidatePage>();
        gateway.onCandidates = (_) => wait.future;
        final local = AdmissionSelectionViewModel(
          controller: controller,
          room: base.roomId,
          target: f2.c,
          intent: 'apply',
        );
        final loading = local.load();
        if (action == 'logout') session.change(authenticated: false);
        if (action == 'environment') {
          environment = 'two';
          changes.notifyListeners();
        }
        if (action == 'dispose') local.dispose();
        wait.complete(parse(gateway.value));
        await loading;
        expect(local.characters, isEmpty);
        expect(gateway.previews, 0);
        if (action != 'dispose') local.dispose();
      });
    }
    test(
      'complete pages publish atomically and later-page roles remain selectable',
      () async {
        final first = wire();
        final second = clone(first['data']['items'][0]);
        second['character_id'] = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
        second['item_level'] = '1800';
        gateway.value['data']['items'].add(second);
        final metadata = await gateway.characters();
        gateway.onMetadata = () async => metadata;
        first['data']['raw_candidate_count'] = 2;
        first['data']['eligible_candidate_count'] = 2;
        first['data']['next_cursor'] = 'second';
        final last = clone(first);
        last['data']['items'] = [second];
        last['data']['next_cursor'] = null;
        final wait = Completer<AdmissionCandidatePage>();
        gateway.onCandidates = (cursor) async =>
            cursor == null ? parse(first) : wait.future;
        final loading = m.load();
        await Future<void>.delayed(Duration.zero);
        expect(m.characters, isEmpty);
        expect(gateway.previews, 0);
        wait.complete(parse(last));
        await loading;
        expect(m.characters.length, 2);
        expect(m.characters.first.id, second['character_id']);
        await m.selectCharacter(second['character_id']);
        expect(m.roleAllowed('dealer'), true);
        expect(m.roleAllowed('invalid'), false);
        expect(m.preview, isNotNull);
      },
    );
    test(
      'join uses server candidates and preserves its own ACK and body',
      () async {
        gateway.value['data']['intent'] = 'join';
        final join = AdmissionSelectionViewModel(
          controller: controller,
          room: base.roomId,
          target: f2.c,
          intent: 'join',
        );
        addTearDown(join.dispose);
        await join.load();
        expect(join.filtered, true);
        expect(join.preview, isNotNull);
        expect(gateway.reads, 1);
        expect(
          join.characters.length,
          gateway.value['data']['eligible_candidate_count'],
        );
        final wrong = clone(gateway.value);
        wrong['data']['actor'] = example(
          'change-eight-opposite-party-valid',
        )['data']['actor'];
        expect(() => parse(wrong), throwsFormatException);
        api.respond = (path, q) async => f2.envelope(f2.c, {
          'command_id': api.requests.last['key'],
          'room_id': base.roomId,
          'target_cycle_key': f2.c,
          'executed_at': f2.nowStamp,
          'outcome': 'applied',
          'revisions': [],
        }, created: true);
        await join.submit();
        expect(join.completed, true);
        expect(controller.admissionSuccess!.$4, 'join');
        final posted = api.requests.where((r) => r['method'] == 'POST').single;
        expect(posted['path'], endsWith('/join'));
        expect((posted['body'] as Map).containsKey('application_memo'), false);
      },
    );
    test(
      'ACK identified only for own command and candidate token excluded from writes',
      () async {
        await m.load();
        await m.submit();
        expect(m.completed, true);
        expect(controller.admissionSuccess!.$4, 'apply');
        expect(api.requests.where((r) => r['method'] == 'POST').length, 1);
        expect(
          (api.requests.last['body'] as Map).containsKey('snapshot_token'),
          false,
        );
      },
    );
    test('ACK remains final when post-success refresh fails', () async {
      final localController = CycleParticipationController(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: scope,
        now: () => DateTime.parse(f2.nowStamp),
        onMutation: (_) async =>
            throw const AccountReadException('SERVICE_UNAVAILABLE'),
      );
      final local = AdmissionSelectionViewModel(
        controller: localController,
        room: base.roomId,
        target: f2.c,
        intent: 'apply',
      );
      await local.load();
      await local.submit();
      expect(local.completed, true);
      expect(localController.hasPending, false);
      await local.submit();
      expect(api.requests.where((r) => r['method'] == 'POST').length, 1);
      local.dispose();
      localController.dispose();
    });
    test(
      'fresh context changed: no write; refresh preserves only valid selection',
      () async {
        await m.load();
        gateway.changedPreview = true;
        await m.submit();
        expect(m.completed, false);
        expect(api.requests, isEmpty);
        expect(m.failure, 'REVISION_CONFLICT');
      },
    );
    test(
      'result unknown retries same original body/key and closes only on original ACK',
      () async {
        final original = api.respond;
        var writes = 0;
        api.respond = (p, q) async {
          if (writes++ == 0) {
            throw const AccountReadException('NETWORK_UNAVAILABLE');
          }
          return original!(p, q);
        };
        await m.load();
        await m.submit();
        expect(m.completed, false);
        expect(controller.hasPending, true);
        await controller.retry();
        expect(m.completed, true);
        expect(api.requests[0]['body'], api.requests[1]['body']);
        expect(api.requests[0]['key'], api.requests[1]['key']);
      },
    );
  });
}
