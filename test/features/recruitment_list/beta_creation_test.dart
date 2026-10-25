import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/account/domain/scoped_cache_models.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_creation_gateway.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_store.dart';
import 'package:lost_party/features/recruitment_list/data/beta/recruitment_command_transport.dart';
import 'package:lost_party/features/recruitment_list/data/local/recruitment_command_database.dart';
import 'package:lost_party/features/recruitment_list/data/membership_readers.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/beta_schedule_draft.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import 'package:lost_party/features/recruitment_list/presentation/pages/backend_recruitment_create_page.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as old;
import 'cycle_recruitment_test.dart' as f;
import 'membership_readers_test.dart' as records;
import 'beta_foundation_test.dart' as a;

RecruitmentDraft draft({String target = f.c, bool together = false}) =>
    old.draft().copy(
      targetCycleKey: target,
      continueTogether: together,
      betaSchedules: {
        f.c: const BetaScheduleInput(weekday: 6, minute: 1080),
        f.n: const BetaScheduleInput(
          weekday: 1,
          minute: 1200,
          enabled: true,
          additional: 2,
        ),
      },
    );
Map<String, dynamic> contextWire(RecruitmentDraft d) {
  final data = f.creation(d);
  data['settings_defaults'].remove('auto_open_default');
  data['settings_defaults']['opening_mode'] = 'explicit';
  data['permissions']['create']['next_change_at'] = null;
  data['beta_schedule_targets'] = betaScheduleTargets(d).toWire();
  return f.envelope(d.targetCycleKey!, data);
}

class Gateway extends f.CycleGateway implements BetaCreationGateway {
  final api = old.Api();
  @override
  bool get betaContractActive => true;
  Future<Map<String, dynamic>> Function(RecruitmentDraft)? response;
  @override
  Future<RecruitmentCreationContext> context(RecruitmentDraft d) {
    contexts++;
    api.respond = (p, q) async =>
        response == null ? contextWire(d) : response!(d);
    return BetaCreationReader(api).context(d);
  }

  @override
  RecruitmentCommand prepareBetaCreation(
    RecruitmentDraft d,
    RecruitmentCreationContext c,
    String title,
    String key,
    DateTime createdAt,
  ) => BetaCreationReader.prepare(d, c, title, key, createdAt);
}

class CycleApi extends DioBackendAccountReadApi {
  CycleApi(ReadSessionFake session) : super(Dio(), session);
  final calls = old.Api();
  @override
  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? idempotencyKey,
    int expectedStatus = 200,
  }) => calls.request(
    path,
    method: method,
    body: body,
    query: query,
    idempotencyKey: idempotencyKey,
    expectedStatus: expectedStatus,
  );
}

class ErrorAdapter implements HttpClientAdapter {
  ErrorAdapter(this.valid);
  final bool valid;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'error': {
        'code': 'INVALID_REQUEST',
        if (valid) ...{
          'message': 'invalid synthetic request',
          'request_id': a.key,
          'details': null,
        },
      },
    }),
    400,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  group('beta creation and durable UI ownership', () {
    late ReadSessionFake session;
    late old.Access access;
    late Gateway gateway;
    late RecruitmentCommandTransport transport;
    late RecruitmentCommandDatabase db;
    late a.FaultStore store;
    late BackendRecruitmentCreateViewModel model;
    late DateTime now;
    late List<RecruitmentCommand> sends;
    late Future<Map<String, dynamic>> Function(RecruitmentCommand) respond;
    BackendRecruitmentCreateViewModel makeModel() =>
        BackendRecruitmentCreateViewModel(
          gateway: gateway,
          session: session,
          accessChanges: access,
          hasVerifiedAccount: () => access.verified,
          commandTransport: transport,
          now: () => now,
        );
    Future<void> ready({bool together = false, String target = f.c}) async {
      await model.activate(target: target);
      model.update(
        model.draft.copy(
          continueTogether: together,
          betaSchedules: draft().betaSchedules,
        ),
      );
    }

    setUp(() {
      session = ReadSessionFake()..userId = a.user;
      access = old.Access();
      gateway = Gateway();
      now = DateTime.parse(f.nowStamp);
      db = RecruitmentCommandDatabase(NativeDatabase.memory());
      store = a.FaultStore(
        DriftRecruitmentCommandStore(databaseFactory: () => db),
      );
      sends = [];
      respond = (c) async => f.envelope(
        c.targetCycles.first,
        f.ack(c.key, jsonDecode(c.rawBody)),
        created: true,
      );
      transport = RecruitmentCommandTransport(
        store: store,
        session: session,
        baseUrl: () => 'https://example.com',
        mode: RecruitmentContractMode.betaWire2,
        clock: () => now,
        send: (c, b) async {
          sends.add(c);
          return respond(c);
        },
      );
      model = makeModel();
    });
    tearDown(() async {
      model.dispose();
      access.dispose();
      await transport.dispose();
      await db.close();
      session.dispose();
    });
    for (final target in [f.c, f.n]) {
      test(
        'single $target sends only its explicit schedule and no next query',
        () async {
          await ready(target: target);
          await model.submit();
          expect(model.createdTargetKey, target);
          expect(sends, hasLength(1));
          final body = jsonDecode(sends.single.rawBody) as Map;
          expect(body.containsKey('schedule_groups'), isFalse);
          expect(body['beta_schedule_targets'], hasLength(1));
          expect(
            gateway.api.requests.last['query'].keys.where(
              (k) => k.toString().startsWith('next_'),
            ),
            isEmpty,
          );
          expect(sends.single.version, 2);
          expect(sends.single.validationSnapshot, isNotNull);
        },
      );
    }
    test(
      'C/N inputs are independent, distinct base times and profile are preserved',
      () async {
        await ready(together: true);
        await model.submit();
        final c = sends.single, body = jsonDecode(c.rawBody) as Map;
        expect(model.createdTargetKeys, [f.c, f.n]);
        expect(
          body['beta_schedule_targets'][0]['base_starts_at'],
          '2026-10-24T09:00:00.000Z',
        );
        expect(
          body['beta_schedule_targets'][1]['base_starts_at'],
          '2026-11-02T11:00:00.000Z',
        );
        expect(c.query, {'contract_profile': BetaContract.profile});
        expect(
          gateway.api.requests.last['query']['next_early_additional_members'],
          2,
        );
      },
    );
    test(
      'missing next time blocks creation; toggling keeps editor values without sending N',
      () async {
        await ready();
        model.update(
          model.draft.copy(
            continueTogether: true,
            betaSchedules: {f.c: draft().betaSchedules[f.c]!},
          ),
        );
        await model.submit();
        expect(sends, isEmpty);
        expect(model.validationMessage, isNotNull);
        model.update(model.draft.copy(betaSchedules: draft().betaSchedules));
        model.update(model.draft.copy(continueTogether: false));
        expect(model.draft.betaSchedules[f.n]!.minute, 1200);
        await model.submit();
        expect(sends.single.targetCycles, [f.c]);
      },
    );
    test(
      'duration, time and coordination changes invalidate context signatures',
      () async {
        await ready();
        await model.refreshContext();
        final before = model.draft.selectionSignature;
        model.updateBeta(
          f.c,
          model.betaInput(f.c).copy(enabled: true, additional: 3),
        );
        expect(model.selection, isNull);
        expect(model.draft.selectionSignature, isNot(before));
        final previous = model.draft.selectionSignature;
        model.update(
          model.draft.copy(
            items: [const RecruitmentItemDraft('raid_a', 'hard', minutes: 30)],
          ),
        );
        expect(model.draft.selectionSignature, isNot(previous));
      },
    );
    test(
      'invalid time and four-person additional limit block before POST',
      () async {
        await ready();
        model.updateBeta(
          f.c,
          model.betaInput(f.c).copy(weekday: 4, minute: 720),
        );
        await model.submit();
        expect(sends, isEmpty);
        model.update(model.draft.copy(betaSchedules: draft().betaSchedules));
        // Isolate the existing mixed-bundle four-person rule from this fixture's single-raid catalog.
        model.draft = model.draft.copy(
          items: [
            const RecruitmentItemDraft('raid_a', 'hard'),
            const RecruitmentItemDraft('raid_b', 'normal'),
          ],
        );
        model.draft = model.draft.copy(
          betaSchedules: {
            f.c: model.betaInput(f.c).copy(enabled: true, additional: 4),
          },
        );
        expect(model.betaValidation, isNotNull);
        await model.submit();
        expect(sends, isEmpty);
      },
    );
    test(
      'unknown result restores after VM restart without fetching a new context or POST',
      () async {
        await ready();
        respond = (c) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await model.submit();
        final original = sends.single;
        expect(model.hasPending, isTrue);
        final contexts = gateway.contexts;
        model.dispose();
        model = makeModel();
        await model.activate();
        expect(sends, hasLength(1));
        expect(gateway.contexts, contexts);
        respond = (c) async {
          expect(c.rawBody, original.rawBody);
          expect(c.rawQuery, original.rawQuery);
          expect(c.key, original.key);
          return f.envelope(
            c.targetCycles.first,
            f.ack(c.key, jsonDecode(c.rawBody)),
            created: true,
          );
        };
        await model.retry();
        expect(sends, hasLength(2));
        expect(model.createdRoomId, old.roomId);
      },
    );
    test(
      'definite rejection resolves only original request and keeps editable input',
      () async {
        await ready();
        model.update(model.draft.copy(title: '남길 입력'));
        respond = (c) async => throw const AccountReadException(
          'SELECTION_CONTEXT_CHANGED',
          status: 409,
        );
        await model.submit();
        expect(model.hasPending, isFalse);
        expect(model.editable, isTrue);
        expect(model.draft.title, '남길 입력');
        expect(
          await transport.restore(RecruitmentCommandOwner.creation),
          isNull,
        );
      },
    );
    test(
      'storage failure prevents HTTP; ACK storage retry does not repeat creation',
      () async {
        await ready();
        store.failInsert = true;
        await model.submit();
        expect(sends, isEmpty);
        expect(model.hasPending, isTrue);
        store.failInsert = false;
        store.failAck = true;
        await model.retry();
        expect(sends, hasLength(1));
        expect(model.createdRoomId, isNull);
        store.failAck = false;
        await model.retry();
        expect(sends, hasLength(1));
        expect(model.createdRoomId, old.roomId);
      },
    );
    test(
      'context with changed schedule or duplicated targets is rejected before POST',
      () async {
        await ready(together: true);
        gateway.response = (d) async {
          final raw = contextWire(d);
          raw['data']['beta_schedule_targets'][1] =
              raw['data']['beta_schedule_targets'][0];
          return raw;
        };
        await model.submit();
        expect(sends, isEmpty);
        expect(model.failure, 'INVALID_RESPONSE');
        expect(model.hasPending, isFalse);
      },
    );
    test(
      'corrupt journal blocks new creation without inventing a target or issuing requests',
      () async {
        await db.customStatement(
          'INSERT INTO recruitment_command_rows(environment,user_id,owner,payload) VALUES (?,?,?,?)',
          ['https://example.com', a.user, 'creation', '{broken'],
        );
        await model.activate();
        await model.checkCurrentRooms();
        expect(model.journalUnavailable, isTrue);
        expect(model.hasPending, isTrue);
        expect(model.canRetry, isFalse);
        expect(sends, isEmpty);
        expect(gateway.api.requests, isEmpty);
      },
    );
    test(
      'expired unknown creation remains review-only after restart',
      () async {
        await ready();
        respond = (c) async =>
            throw const AccountReadException('NETWORK_UNAVAILABLE');
        await model.submit();
        now = now.add(const Duration(hours: 24));
        model.dispose();
        model = makeModel();
        await model.activate();
        await model.retry();
        expect(sends, hasLength(1));
        expect(model.retryExpired, isTrue);
        expect(
          (await transport.restore(RecruitmentCommandOwner.creation))!.state,
          RecruitmentCommandState.needsReview,
        );
      },
    );
    for (final code in [
      'REQUEST_IN_PROGRESS',
      'IDEMPOTENCY_EXPIRED',
      'UNKNOWN_CONFLICT',
    ]) {
      test('$code is not treated as a definite rejection', () async {
        await ready();
        respond = (c) async => throw AccountReadException(code, status: 409);
        await model.submit();
        expect(model.hasPending, isTrue);
        expect(model.createdRoomId, isNull);
      });
    }
    test(
      'ACK persists before success, consumption allows a fresh create entry',
      () async {
        await ready();
        await model.submit();
        expect(model.createdRoomId, old.roomId);
        expect(
          (await transport.restore(RecruitmentCommandOwner.creation))!.state,
          RecruitmentCommandState.acknowledged,
        );
        await model.consumeCreatedSuccess();
        await model.activate();
        expect(model.createdRoomId, isNull);
        expect(model.hasPending, isFalse);
        expect(model.draft.betaSchedules, isEmpty);
        expect(sends, hasLength(1));
      },
    );
    test(
      'saved ACK restores success with no request, then permits fresh creation',
      () async {
        await ready();
        await model.submit();
        model.dispose();
        model = makeModel();
        await model.activate();
        expect(model.createdRoomId, old.roomId);
        expect(sends, hasLength(1));
        await model.consumeCreatedSuccess();
        await model.activate();
        expect(model.createdRoomId, isNull);
      },
    );
    test(
      'original verification evidence rejects mismatched ACK room and generation',
      () async {
        final d = draft(),
            c = RecruitmentCreationContext.fromCycleJson(f.creation(d), d);
        final original = BetaCreationReader.prepare(d, c, '제목', a.key, now);
        final raw = f.envelope(
          f.c,
          f.ack(a.key, jsonDecode(original.rawBody)),
          created: true,
        );
        raw['data']['room_id'] = a.otherKey;
        expect(
          () => validateBetaCreationAck(original, raw),
          throwsFormatException,
        );
        final changed = original.toJson();
        changed['validation_snapshot'] = {
          ...original.validationSnapshot!,
          'target_cycle_key': f.n,
        };
        expect(
          () => RecruitmentCommand.decode(jsonEncode(changed)),
          throwsFormatException,
        );
      },
    );
    test(
      'legacy v1 missing creation evidence is retained for review with POST zero',
      () async {
        final d = draft(),
            c = RecruitmentCreationContext.fromCycleJson(f.creation(d), d);
        final original = BetaCreationReader.prepare(d, c, '제목', a.key, now);
        final json = original.toJson()
          ..['version'] = 1
          ..remove('validation_snapshot')
          ..remove('rejection');
        final v1 = RecruitmentCommand.decode(jsonEncode(json));
        expect(v1.encode(), jsonEncode(json));
        await store.insert(aScope(session), v1);
        await model.activate();
        await model.retry();
        expect(model.retryExpired, isTrue);
        expect(sends, isEmpty);
      },
    );
    test(
      'late ACK after account switch never changes new user screen',
      () async {
        await ready();
        final waiting = Completer<Map<String, dynamic>>();
        respond = (c) => waiting.future;
        final work = model.submit();
        while (sends.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        final c = sends.single;
        session.change(authenticated: true, user: a.otherKey);
        waiting.complete(
          f.envelope(f.c, f.ack(c.key, jsonDecode(c.rawBody)), created: true),
        );
        await work;
        expect(model.createdRoomId, isNull);
        expect(model.hasPending, isFalse);
      },
    );
    testWidgets(
      'C/N schedule sections are stacked; unavailable reset/multiple-date UI absent',
      (tester) async {
        await ready(together: true);
        await tester.pumpWidget(
          MaterialApp(
            home: BackendRecruitmentCreatePage(model: model, onLogin: () {}),
          ),
        );
        await tester.pump();
        expect(find.text('이번 주 출발 일정'), findsOneWidget);
        expect(find.text('다음 주 출발 일정'), findsOneWidget);
        expect(find.text('아래 날짜 중 1회'), findsNothing);
        expect(find.text('선택일마다 진행'), findsNothing);
        expect(
          tester.getTopLeft(find.text('이번 주 출발 일정')).dy,
          lessThan(tester.getTopLeft(find.text('다음 주 출발 일정')).dy),
        );
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        model = makeModel();
      },
    );
    testWidgets(
      'success navigates once; next create entry remains a fresh editor',
      (tester) async {
        await ready(together: true);
        await model.submit();
        var callbacks = 0;
        final router = GoRouter(
          initialLocation: '/create',
          routes: [
            GoRoute(
              path: '/create',
              builder: (c, s) => BackendRecruitmentCreatePage(
                model: model,
                onLogin: () {},
                onCreated: (r, t) => callbacks++,
              ),
            ),
            GoRoute(
              path: '/recruitments/:roomId',
              builder: (c, s) => const Scaffold(body: Text('생성 상세')),
            ),
          ],
        );
        // Use the repository's actual detail route, avoiding a synthetic navigation contract.
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(callbacks, 2);
        expect(sends, hasLength(1));
        expect(find.text('생성 상세'), findsOneWidget);
        router.go('/create');
        await tester.pumpAndSettle();
        expect(model.createdRoomId, isNull);
        expect(find.text('모집 만들기'), findsOneWidget);
        expect(callbacks, 2);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        model.dispose();
        model = makeModel();
      },
    );
  });
  group('beta read profiles and display', () {
    for (final valid in [true, false]) {
      test(
        'Dio error validates closed server evidence before resolving request: $valid',
        () async {
          final session = ReadSessionFake()..userId = a.user;
          final db = RecruitmentCommandDatabase(NativeDatabase.memory());
          final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
            ..httpClientAdapter = ErrorAdapter(valid);
          final transport = RecruitmentCommandTransport(
            store: DriftRecruitmentCommandStore(databaseFactory: () => db),
            session: session,
            baseUrl: () => 'https://example.com',
            mode: RecruitmentContractMode.betaWire2,
            clock: () => DateTime.parse(f.nowStamp),
            send: DioRecruitmentCommandSender(dio, session).call,
          );
          try {
            final d = draft(),
                c = RecruitmentCreationContext.fromCycleJson(f.creation(d), d);
            final original = BetaCreationReader.prepare(
              d,
              c,
              '제목',
              a.key,
              DateTime.parse(f.nowStamp),
            );
            await expectLater(
              transport.submit(
                original,
                validateAck: (j) => validateBetaCreationAck(original, j),
              ),
              throwsA(isA<AccountReadException>()),
            );
            final saved = (await transport.restore(original.owner))!;
            expect(
              saved.state,
              valid
                  ? RecruitmentCommandState.rejected
                  : RecruitmentCommandState.pending,
            );
            expect(saved.rawBody, original.rawBody);
            expect(saved.key, original.key);
          } finally {
            await transport.dispose();
            await db.close();
            dio.close();
            session.dispose();
          }
        },
      );
    }
    test(
      'search consumes effective server time from one page with no card-detail GET',
      () async {
        final api = old.Api();
        final schedule = {
          ...a.schedule(),
          'early_coordination_enabled': true,
          'early_additional_members': 1,
          'coordination_state': 'early_confirmed',
          'confirmed_starts_at': '2026-10-23T09:00:00Z',
          'confirmed_ends_at': '2026-10-23T10:00:00Z',
          'effective_starts_at': '2026-10-23T09:00:00Z',
          'effective_ends_at': '2026-10-23T10:00:00Z',
          'admission_deadline': '2026-10-23T08:30:00Z',
        };
        final card = f.detail(f.c)['data']['room'] as Map<String, dynamic>;
        card['beta_schedule'] = schedule;
        api.respond = (p, q) async => f.envelope(f.c, {
          'items': [card],
          'directory_revision': 1,
          'filter_scope_digest': null,
          'next_cursor': null,
          'evaluated_at': f.nowStamp,
        });
        final page = await CycleInteractionRepository(
          api: api,
          recruitment: f.CycleGateway(),
          contractMode: RecruitmentContractMode.betaWire2,
        ).search(f.c, CycleSearchFilter());
        expect(api.requests, hasLength(1));
        expect(api.requests.single['method'], 'POST');
        expect(page.rows.single.starts, isEmpty);
        expect(
          betaDepartureText(page.rows.single.betaData!),
          contains('10-23 18:00'),
        );
        expect(betaScheduleLabel(page.rows.single.betaData!), '자동 조율로 확정');
      },
    );
    test(
      'membership page keeps recovery row without manufacturing a current room',
      () async {
        final session = ReadSessionFake()..userId = a.user;
        final api = CycleApi(session);
        final raw = records.sample('current_unknown_generation_page');
        for (final item in raw['data']['items'] as List) {
          item['beta_schedule'] = null;
        }
        api.calls.respond = (p, q) async => raw;
        final rows = await CycleReadRepository(
          api,
          membershipProfile: true,
          contractMode: RecruitmentContractMode.betaWire2,
        ).own(raw['scope']['target_cycle_key']);
        expect(rows.rows.single.card, isNull);
        expect(rows.rows.single.recoveryOnly, isTrue);
        expect(api.calls.requests, hasLength(1));
        expect(
          api.calls.requests.single['query']['reader_profile'],
          membershipReaderProfile,
        );
        session.dispose();
        api.dio.close();
      },
    );
    test(
      'normal detail reports server effective time and leading-zero participant identity',
      () async {
        final api = old.Api();
        final json = f.detail(f.c), d = json['data'] as Map<String, dynamic>;
        d['beta_schedule'] = a.schedule();
        d['room']['beta_schedule'] = a.schedule();
        d['recruitment_identity'] = {'number': 1, 'password': '00009'};
        d['permissions'] = {
          'view_detail': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
          'view_plan': {
            'allowed': true,
            'reason': null,
            'next_change_at': null,
          },
        };
        d['my_membership'] = {
          'membership_id': old.membershipId,
          'revision': 1,
          'group_member': false,
          'target_role': 'leader',
          'cycle_member_id': old.membershipId,
          'cycle_member_revision': 1,
          'joined_order': '1',
        };
        d['my_application'] = null;
        api.respond = (p, q) async => json;
        final result = await ApplicationDisplayReader(
          api,
          contractMode: RecruitmentContractMode.betaWire2,
        ).applicationDisplayDetail(old.roomId, f.c);
        expect(
          result.detail.betaData!['recruitment_identity']['password'],
          '00009',
        );
        expect(
          betaDepartureText(result.detail.betaData!),
          contains('10-24 18:00'),
        );
        expect(
          api.requests.single['query']['reader_profile'],
          'application-display-1',
        );
        expect(
          api.requests.single['query']['contract_profile'],
          BetaContract.profile,
        );
        d['members'][0]['target_state'] = 'review_required';
        const BetaContract(
          mode: RecruitmentContractMode.betaWire2,
        ).validateResponse(
          'GET',
          '/v2/raid-rooms/${old.roomId}/detail',
          200,
          json,
        );
        await expectLater(
          ApplicationDisplayReader(
            api,
            contractMode: RecruitmentContractMode.betaWire2,
          ).applicationDisplayDetail(old.roomId, f.c),
          throwsA(isA<AccountReadException>()),
        );
      },
    );
    test(
      'record profile keeps null content/identity and original anchor without fallback',
      () async {
        final raw = records.sample('ended_completed_detail');
        raw['data']['beta_schedule'] = null;
        raw['data']['recruitment_identity'] = null;
        final api = old.Api()..respond = (p, q) async => raw;
        final room = raw['data']['target']['room_id'] as String,
            t = raw['scope']['target_cycle_key'] as String;
        final locator = raw['data']['record']['locator'];
        final result =
            await MembershipReadRepository(
              api,
              contractMode: RecruitmentContractMode.betaWire2,
            ).detail(
              room,
              t,
              anchor: MembershipRecordAnchor(
                locator['membership_id'],
                locator['cycle_member_id'],
              ),
            );
        expect(result.projection.isRecord, isTrue);
        expect(result.projection.content, isNull);
        expect(result.betaData!['recruitment_identity'], isNull);
        expect(api.requests, hasLength(1));
        raw['data']['recruitment_identity'] = {
          'number': 1,
          'password': '00000',
        };
        await expectLater(
          MembershipReadRepository(
            api,
            contractMode: RecruitmentContractMode.betaWire2,
          ).detail(room, t),
          throwsA(isA<AccountReadException>()),
        );
        expect(api.requests, hasLength(2));
      },
    );
    test(
      'all explicit states are distinct; missing schedule is not unscheduled',
      () {
        final labels = <String>{};
        for (final state in [
          'base_committed',
          'coordinating',
          'early_confirmed',
          'base_confirmed',
          'proposal_confirmed',
          'deadline_pending',
          'needs_review',
          'ended',
        ]) {
          labels.add(
            betaScheduleLabel({
              'beta_schedule': {'coordination_state': state},
            }),
          );
        }
        expect(labels, hasLength(8));
        expect(betaScheduleLabel({'beta_schedule': null}), isNot('출발 미정'));
      },
    );
  });
}

// Uses the same normalized production scope without sharing account DB ownership.
StorageScope aScope(ReadSessionFake session) =>
    StorageScope(baseUrl: 'https://example.com', userId: session.userId!);
