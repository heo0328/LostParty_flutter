import 'dart:async';
import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/app/theme/app_theme.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'package:lost_party/features/recruitment_list/data/application_messages.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/application_memo_policy.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/application_memo_draft.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/application_messages_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_participation_controller.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/application_memo_widgets.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/recruitment_character_card.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import 'beta_foundation_test.dart' as foundation;
import 'backend_recruitment_test.dart' as base;
import 'cycle_interaction_test.dart' as interaction;
import 'cycle_recruitment_test.dart' as cycles;
import 'application_display_test.dart' as display;
import '../../support/server_account_read_fakes.dart';

const presetId = '11111111-1111-4111-8111-111111111111';
Map<String, dynamic> doc({
  int version = 1,
  List<Map<String, dynamic>> items = const [],
}) => {
  'version': version,
  'items': items,
  'saved_at': version == 1 ? null : cycles.nowStamp,
};
List<Map<String, dynamic>> rows(String text) => [
  {'id': presetId, 'text': text},
];
void main() {
  test('NFC, exact allowlist/20 codepoints, blank memo vs blank preset', () {
    expect(ApplicationMemoPolicy.check('  가  ').text, '가');
    expect(ApplicationMemoPolicy.check('가' * 20).valid, isTrue);
    expect(ApplicationMemoPolicy.check('가' * 21).valid, isFalse);
    expect(ApplicationMemoPolicy.check(' .,!?~()-_/@#&+ ').valid, isTrue);
    expect(ApplicationMemoPolicy.check('ㅋㅋ ㅎㅎ ㄱㅏ').valid, isTrue);
    expect(ApplicationMemoPolicy.check('   ').valid, isTrue);
    expect(ApplicationMemoPolicy.check('   ', required: true).valid, isFalse);
    for (final text in [
      '😀',
      '👨‍👩‍👧',
      'a\n',
      'a\t',
      'a\u200d',
      'a\ufe0f',
      'Ａ',
      'a\u0301',
    ]) {
      expect(ApplicationMemoPolicy.check(text).valid, isFalse, reason: text);
    }
  });
  test(
    'all printable keyboard ASCII is accepted locally and by stored memo DTO',
    () {
      for (var value = 0x21; value <= 0x7e; value++) {
        final symbol = String.fromCharCode(value);
        expect(
          ApplicationMemoPolicy.check(symbol, required: true).valid,
          isTrue,
          reason: symbol,
        );
        expect(
          () => BetaContract.definition('Proposed_MemoStored', symbol),
          returnsNormally,
          reason: symbol,
        );
      }
      for (final value in [0, 9, 10, 13, 31, 127, 0xa0, 0xff01, 0x1f600]) {
        expect(
          ApplicationMemoPolicy.check(String.fromCharCode(value)).valid,
          isFalse,
        );
      }
    },
  );
  test(
    'server errors distinguish action and cause without leaking arbitrary text',
    () {
      expect(
        recruitmentFailureMessage('RAID_ITEM_LEVEL_REQUIRED'),
        contains('입장 레벨보다 낮'),
      );
      expect(
        recruitmentFailureMessage('MEMBER_RAID_LIMIT_REACHED'),
        contains('모집방 수'),
      );
      expect(
        recruitmentFailureMessage('INVALID_RESPONSE'),
        contains('이미 처리됐을 수'),
      );
      expect(
        recruitmentFailureMessage('NETWORK_UNAVAILABLE'),
        contains('인터넷 연결'),
      );
      expect(
        recruitmentFailureMessage('APPLICATION_MEMO_TOO_LONG'),
        contains('20자'),
      );
      expect(
        recruitmentFailureMessage('UNKNOWN_NEW_CODE'),
        contains('UNKNOWN_NEW_CODE'),
      );
      expect(
        recruitmentFailureMessage('private server exception text'),
        isNot(contains('private')),
      );
    },
  );
  test(
    'local Korean/English words, separator evasion, normal words not substrings',
    () {
      for (final text in [
        '씨발',
        '시.발',
        '개 새끼',
        '병신아',
        '섹스',
        'f.u.c.k',
        'fuck',
        'ㅅㅂ',
      ]) {
        expect(
          ApplicationMemoPolicy.check(text).error,
          contains('금칙어'),
          reason: text,
        );
      }
      for (final text in [
        'class support',
        '보지 못했어요',
        '자지 않고 트라이',
        '시발점부터',
        '트라이 같이 해요',
      ]) {
        expect(ApplicationMemoPolicy.check(text).valid, isTrue, reason: text);
      }
    },
  );
  test('IME composition is preserved and blocks submit until committed', () {
    final draft = ApplicationMemoDraft();
    addTearDown(draft.dispose);
    draft.input.value = const TextEditingValue(
      text: 'ᄀ',
      composing: TextRange(start: 0, end: 1),
    );
    expect(draft.input.text, 'ᄀ');
    expect(draft.composing, isTrue);
    expect(draft.canSubmit, isFalse);
    draft.input.value = const TextEditingValue(text: '가');
    expect(draft.canSubmit, isTrue);
    draft.select('😀');
    expect(draft.input.text, '😀');
    expect(draft.canSubmit, isFalse);
  });
  group('preset read/write owner', () {
    late base.Api api;
    late foundation.JournalSession session;
    late ChangeNotifier changes;
    late foundation.FaultStore store;
    late RecruitmentCommandTransport transport;
    late ApplicationMessagesController m;
    late Future<Map<String, dynamic>> Function(RecruitmentCommand) respond;
    late List<RecruitmentCommand> writes;
    var binding = 'env/member/1';
    var time = DateTime.parse(cycles.nowStamp);
    setUp(() {
      binding = 'env/member/1';
      time = DateTime.parse(cycles.nowStamp);
      api = base.Api()..respond = (_, _) async => doc();
      session = foundation.JournalSession()..userId = foundation.user;
      changes = ChangeNotifier();
      store = foundation.FaultStore(
        DriftRecruitmentCommandStore(
          databaseFactory: () =>
              RecruitmentCommandDatabase(NativeDatabase.memory()),
        ),
      );
      writes = [];
      respond = (c) async {
        final body = jsonDecode(c.rawBody);
        return doc(
          version: body['expected_version'] + 1,
          items: (body['items'] as List).cast<Map<String, dynamic>>(),
        );
      };
      transport = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => 'https://example.com',
        mode: RecruitmentContractMode.betaWire2,
        clock: () => time,
        send: (c, _) {
          writes.add(c);
          return respond(c);
        },
      );
      m = ApplicationMessagesController(
        gateway: ApplicationMessagesReader(api),
        session: session,
        scopeKey: () => binding,
        changes: changes,
        transport: transport,
        now: () => time,
      );
    });
    tearDown(() async {
      m.dispose();
      await transport.dispose();
      changes.dispose();
      session.dispose();
    });
    test(
      'unprofiled GET/PUT, normalized snapshot and own ACK, no extra refresh write',
      () async {
        await m.load();
        expect(m.failure, isNull);
        expect(api.requests.single['query'], isNull);
        expect(await m.save(rows('  가  '), 1), isTrue);
        expect(m.items.single['text'], '가');
        expect(m.pending, isNull);
        final command = writes.single;
        expect(command.query, isEmpty);
        expect(command.targetCycles, isEmpty);
        expect(command.owner, RecruitmentCommandOwner.presets);
        expect(jsonDecode(command.rawBody)['items'][0]['text'], '가');
        expect(
          await transport.restore(RecruitmentCommandOwner.presets),
          isNull,
        );
        expect(await m.retry(), isFalse);
        expect(writes, hasLength(1));
      },
    );
    test(
      'empty default no-op acknowledges unchanged version and null saved_at',
      () async {
        respond = (_) async => doc();
        await m.load();
        expect(await m.save([], 1), isTrue);
        expect(m.document!.wire['version'], 1);
        expect(m.pending, isNull);
      },
    );
    test(
      'storage failure sends zero HTTP, preserves original request',
      () async {
        store.failInsert = true;
        await m.load();
        expect(await m.save(rows('초행이에요'), 1), isFalse);
        expect(writes, isEmpty);
        expect(m.pending, isNotNull);
        store.failInsert = false;
        expect(await m.retry(), isTrue);
        expect(writes, hasLength(1));
      },
    );
    test(
      'unknown response restores without automatic send; retry preserves original bytes/key',
      () async {
        var lose = true;
        respond = (c) async {
          if (lose) {
            lose = false;
            throw const AccountReadException('NETWORK_UNAVAILABLE');
          }
          final body = jsonDecode(c.rawBody);
          return doc(
            version: 2,
            items: (body['items'] as List).cast<Map<String, dynamic>>(),
          );
        };
        await m.load();
        expect(await m.save(rows('트라이 함께해요'), 1), isFalse);
        final original = m.pending!;
        m.dispose();
        m = ApplicationMessagesController(
          gateway: ApplicationMessagesReader(api),
          session: session,
          scopeKey: () => binding,
          changes: changes,
          transport: transport,
          now: () => time,
        );
        await m.load();
        expect(writes, hasLength(1));
        expect(m.pending!.key, original.key);
        expect(await m.retry(), isTrue);
        expect(writes[0].rawBody, writes[1].rawBody);
        expect(writes[0].key, writes[1].key);
      },
    );
    test(
      'ACK disk failure retries persistence without repeating successful HTTP',
      () async {
        await m.load();
        store.failAck = true;
        expect(await m.save(rows('숙련이에요'), 1), isFalse);
        expect(writes, hasLength(1));
        store.failAck = false;
        expect(await m.retry(), isTrue);
        expect(writes, hasLength(1));
      },
    );
    test('wrong snapshot ACK does not become saved', () async {
      await m.load();
      respond = (_) async => doc(version: 2, items: rows('다른 문구'));
      expect(await m.save(rows('내 문구'), 1), isFalse);
      expect(m.pending, isNotNull);
      expect(m.items, isEmpty);
    });
    test(
      'CAS rejection is resolved but draft stays unchanged; explicit new save uses new key',
      () async {
        final draft = rows('현재 작성한 문구');
        await m.load();
        respond = (_) async =>
            throw const AccountReadException('REVISION_CONFLICT', status: 409);
        expect(await m.save(draft, 1), isFalse);
        expect(m.pending, isNull);
        expect(draft.single['text'], '현재 작성한 문구');
        final key = writes.single.key;
        api.respond = (_, _) async => doc(version: 2, items: rows('다른 기기 문구'));
        await m.load();
        respond = (c) async => doc(
          version: 3,
          items: (jsonDecode(c.rawBody)['items'] as List)
              .cast<Map<String, dynamic>>(),
        );
        expect(await m.save(draft, 2), isTrue);
        expect(writes.last.key, isNot(key));
        expect(m.items.single['text'], '현재 작성한 문구');
      },
    );
    test(
      'expiry blocks sending and does not generate replacement key',
      () async {
        await m.load();
        respond = (_) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await m.save(rows('메모'), 1);
        final key = m.pending!.key;
        time = time.add(const Duration(hours: 24));
        expect(await m.retry(), isFalse);
        expect(writes, hasLength(1));
        expect(m.pending!.key, key);
      },
    );
    test(
      'member change and late GET do not refill another account UI',
      () async {
        final reply = Completer<Map<String, dynamic>>();
        api.respond = (_, _) => reply.future;
        final loading = m.load();
        await Future<void>.delayed(Duration.zero);
        binding = 'env/other/2';
        session.sameIdentityNotification();
        reply.complete(doc(version: 2, items: rows('이전 계정')));
        await loading;
        expect(m.document, isNull);
        expect(m.pending, isNull);
      },
    );
    test(
      'bad preset read leaves free-form/empty memo usable; invalid text causes zero writes',
      () async {
        api.respond = (_, _) async => {'version': 1};
        await m.load();
        expect(m.failure, isNotNull);
        final draft = ApplicationMemoDraft();
        addTearDown(draft.dispose);
        expect(draft.canSubmit, isTrue);
        expect(await m.save(rows('씨발'), 1), isFalse);
        expect(writes, isEmpty);
      },
    );
    testWidgets(
      '320px composer selection is local; invalid text stays visible; manager is explicit',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        api.respond = (_, _) async => doc(version: 2, items: rows('초행이에요'));
        await m.load();
        final draft = ApplicationMemoDraft();
        addTearDown(draft.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: ListView(
                children: [
                  ApplicationMemoComposer(
                    draft: draft,
                    messages: m,
                    enabled: true,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.text('초행이에요'));
        await tester.pump();
        expect(draft.input.text, '초행이에요');
        draft.select('씨발');
        await tester.pump();
        expect(find.textContaining('금칙어'), findsOneWidget);
        expect(draft.input.text, '씨발');
        expect(api.requests, hasLength(1));
        expect(writes, isEmpty);
        await tester.tap(find.text('문구 관리'));
        await tester.pumpAndSettle();
        expect(find.text('저장 문구 관리'), findsOneWidget);
        expect(writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
  test(
    'beta application list preserves submitted memo without new per-card requests',
    () async {
      final raw = display.wire();
      raw['data']['items'][0]['application_memo'] = '초행이에요';
      raw['data']['items'][0]['beta_schedule'] = null;
      final api = base.Api()..respond = (_, _) async => raw;
      final scope = raw['scope'] as Map,
          room = raw['data']['items'][0]['room_id'] as String;
      const BetaContract(
        mode: RecruitmentContractMode.betaWire2,
      ).validateResponse('GET', '/v2/raid-rooms/$room/applications', 200, raw);
      final page = await ApplicationDisplayReader(
        api,
        contractMode: RecruitmentContractMode.betaWire2,
      ).applicationDisplayPage(room, scope['target_cycle_key'] as String);
      expect(page.items.single.applicationMemo, '초행이에요');
      expect(api.requests, hasLength(1));
      raw['data']['items'][0]['application_memo'] = null;
      final next = await ApplicationDisplayReader(
        api,
        contractMode: RecruitmentContractMode.betaWire2,
      ).applicationDisplayPage(room, scope['target_cycle_key'] as String);
      expect(next.items.single.applicationMemo, isNull);
    },
  );
  test(
    'beta own/review application reads preserve the same submitted snapshot',
    () async {
      final api = base.Api();
      final repo = CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      );
      for (final leader in [false, true]) {
        final raw = interaction.appWire(interaction.n, leader: leader);
        final app = (leader ? raw['data']['application'] : raw['data']) as Map;
        app['beta_schedule'] = null;
        if (leader) raw['data']['beta_schedule'] = null;
        app['application_memo'] = '신청 당시 메모';
        api.respond = (_, _) async => raw;
        const BetaContract(
          mode: RecruitmentContractMode.betaWire2,
        ).validateResponse(
          'GET',
          '/v2/raid-room-applications/${interaction.app}',
          200,
          raw,
        );
        final result = await repo.application(interaction.app, interaction.n);
        expect(result.applicationMemo, '신청 당시 메모');
        expect(result.review != null, leader);
      }
      expect(api.requests, hasLength(2));
    },
  );
  test('apply freezes normalized memo in original pending body/key', () async {
    final api = base.Api();
    final session = ReadSessionFake(), changes = ChangeNotifier();
    final c = CycleParticipationController(
      gateway: CycleInteractionRepository(
        api: api,
        recruitment: cycles.CycleGateway(),
        contractMode: RecruitmentContractMode.betaWire2,
      ),
      session: session,
      changes: changes,
      scopeKey: () => 'fixed',
      now: () => DateTime.parse(cycles.nowStamp),
    );
    addTearDown(() {
      c.dispose();
      changes.dispose();
      session.dispose();
    });
    var lose = true;
    api.respond = (path, _) async {
      final req = api.requests.last;
      if (req['method'] == 'GET') {
        final raw = interaction.admissionWire(interaction.n, intent: 'apply');
        raw['data']['beta_schedule'] = null;
        return raw;
      }
      if (lose) {
        lose = false;
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      return cycles.envelope(interaction.n, {
        'command_id': req['key'],
        'room_id': base.roomId,
        'application_id': base.membershipId,
        'revision': 2,
        'state': 'pending',
        'executed_at': cycles.nowStamp,
        'target_cycle_key': interaction.n,
      }, created: true);
    };
    final p = await c.preview(
      base.roomId,
      interaction.n,
      characterId,
      'dealer',
      'apply',
    );
    await c.admit(p!, {}, applicationMemo: '  가  ');
    expect(c.hasPending, isTrue);
    await c.retry();
    expect(c.hasPending, isFalse);
    final writes = api.requests.where((r) => r['method'] == 'POST').toList();
    expect(writes, hasLength(2));
    expect(writes.first['body']['application_memo'], '가');
    expect(writes.first['body'], writes.last['body']);
    expect(writes.first['key'], writes.last['key']);
    expect(c.admissionSuccess!.$1, writes.last['key']);
  });
  testWidgets('card shows only submitted memo and no empty row', (
    tester,
  ) async {
    Widget card(String? memo) => MaterialApp(
      home: Scaffold(
        body: RecruitmentCharacterCard(
          name: '신청자',
          className: '바드',
          role: '서포터',
          itemLevel: '1700',
          power: '1000',
          status: '승인 대기',
          memo: memo,
        ),
      ),
    );
    await tester.pumpWidget(card('초행이에요'));
    expect(find.text('한마디 · 초행이에요'), findsOneWidget);
    await tester.pumpWidget(card(null));
    expect(find.textContaining('한마디'), findsNothing);
  });
}
