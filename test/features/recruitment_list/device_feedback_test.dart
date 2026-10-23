import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/data/member_raid_client.dart';
import 'package:lost_party/features/account/domain/server_account_read_repository.dart';
import 'package:lost_party/features/recruitment_list/data/backend_recruitment_repository.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/domain/backend_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/backend_recruitment_create_view_model.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'backend_recruitment_test.dart' as v1;
import 'cycle_recruitment_test.dart' as f2;

class AvailabilityGateway extends f2.CycleGateway
    implements RecruitmentAvailabilityGateway {
  final reads = <List<String>>[];
  Future<Set<String>> Function(List<String>)? respond;
  @override
  Future<Set<String>> unavailableRaids(
    String character,
    List<String> targets,
    RaidCatalog catalog,
  ) async {
    reads.add(targets);
    return respond == null ? <String>{} : await respond!(targets);
  }

  @override
  Future<List<RecruitmentCharacter>> characters() async => const [
    RecruitmentCharacter(
      id: characterId,
      registrationId: registrationId,
      name: '지원',
      className: '바드',
      accountLabel: '본계정',
      itemLevel: '1770',
      preferredRole: 'support',
    ),
    RecruitmentCharacter(
      id: secondCharacterId,
      registrationId: registrationId,
      name: '공격',
      className: '바드',
      accountLabel: '본계정',
      itemLevel: '1770',
      preferredRole: 'dealer',
    ),
  ];
}

void main() {
  late ReadSessionFake session;
  late v1.Access access;
  late AvailabilityGateway gateway;
  late BackendRecruitmentCreateViewModel model;
  setUp(() {
    session = ReadSessionFake();
    access = v1.Access();
    gateway = AvailabilityGateway();
    model = BackendRecruitmentCreateViewModel(
      gateway: gateway,
      session: session,
      accessChanges: access,
      hasVerifiedAccount: () => true,
      now: () => DateTime.parse(f2.nowStamp),
    );
  });
  tearDown(() {
    model.dispose();
    access.dispose();
    session.dispose();
  });

  test(
    'support preference initializes role; explicit other role remains allowed',
    () async {
      await model.activate();
      expect(model.draft.role, 'support');
      model.update(model.draft.copy(role: 'dealer'));
      expect(model.draft.role, 'dealer');
      await model.load();
      expect(model.draft.role, 'dealer');
      model.update(model.draft.copy(characterId: secondCharacterId));
      expect(model.draft.role, 'dealer');
      model.update(model.draft.copy(characterId: characterId));
      expect(model.draft.role, 'support');
    },
  );
  test(
    'one summary per character/target selection excludes occupied or completed raids',
    () async {
      gateway.respond = (targets) async =>
          targets.contains(f2.c) ? {'raid_a'} : {};
      await model.activate();
      expect(model.raidOptions, isEmpty);
      expect(model.draft.items, isEmpty);
      expect(gateway.contexts, 0);
      await model.selectCycle(f2.n);
      await f1.settled(() => !model.contextLoading);
      expect(model.raidOptions.single.raid.raidId, 'raid_a');
      expect(gateway.reads, [
        [f2.c],
        [f2.n],
      ]);
      model.update(model.draft.copy(role: 'dealer'));
      await f1.settled(() => !model.contextLoading);
      expect(gateway.reads.length, 2);
    },
  );
  test(
    'together checks both actual weeks in one read and reentry refreshes status',
    () async {
      gateway.respond = (targets) async =>
          targets.contains(f2.n) ? {'raid_a'} : {};
      await model.activate();
      model.update(model.draft.copy(continueTogether: true));
      await f1.settled(() => !model.contextLoading);
      expect(gateway.reads.last, [f2.c, f2.n]);
      expect(model.raidOptions, isEmpty);
      model.update(model.draft.copy(continueTogether: false));
      await f1.settled(() => !model.contextLoading);
      expect(model.raidOptions, isNotEmpty);
      gateway.respond = (_) async => {'raid_a'};
      await model.activate();
      expect(model.raidOptions, isEmpty);
    },
  );
  test(
    'stale weekly response cannot replace newer target availability',
    () async {
      await model.activate();
      final old = Completer<Set<String>>();
      gateway.respond = (targets) =>
          targets.contains(f2.n) ? old.future : Future.value({});
      await model.selectCycle(f2.n);
      expect(model.raidOptions, isEmpty);
      await model.selectCycle(f2.c);
      await f1.settled(() => !model.contextLoading);
      old.complete({'raid_a'});
      await Future<void>.delayed(Duration.zero);
      expect(model.draft.targetCycleKey, f2.c);
      expect(model.raidOptions, isNotEmpty);
    },
  );
  test(
    'active membership display excludes legacy/history/completed and preserves review',
    () {
      CycleOwnRow row(String state) => CycleOwnRow(
        {
          ...f1.membership(),
          'target_participation_state': state,
          'room': f1.roomCard(),
          'target_generation': 1,
        },
        f2.c,
        false,
      );
      expect(row('participating').isActiveParticipation, true);
      expect(row('review_required').isActiveParticipation, true);
      for (final state in [
        'completed',
        'stopped',
        'cancelled',
        'legacy_intent',
        'not_selected',
      ]) {
        expect(row(state).isActiveParticipation, false, reason: state);
      }
    },
  );
  test(
    'summary read rejects omitted entries and combines party/manual/participation by actual week',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close());
      var omit = false;
      var party = false;
      final calls = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            calls.add(r);
            final body = r.data as Map;
            final entries = [
              for (final t in body['target_cycle_keys'])
                f1.summaryEntry(
                  characterId,
                  'raid_a',
                  t as String,
                  joined: t == f2.n,
                  completed: t == f2.c,
                ),
            ];
            if (party) {
              (entries.first['permissions'] as Map)['clear_manual_completion'] =
                  f1.permit(false);
              entries.first['completion_sources'] = [
                {
                  'source': 'party',
                  'completed_at': f2.nowStamp,
                  'difficulty_id': 'hard',
                  'party_id': f1.room,
                },
              ];
            }
            h.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
                data: {
                  'server_now': f2.nowStamp,
                  'current_cycle_key': f2.c,
                  'target_cycle_keys': body['target_cycle_keys'],
                  'catalog_version': 'v2',
                  'entries': omit ? [] : entries,
                },
              ),
            );
          },
        ),
      );
      final api = DioBackendAccountReadApi(dio, session);
      final repository = BackendRecruitmentRepository(
        api: api,
        accounts: ServerAccountReadRepository(api, session),
        raids: MemberRaidClient(api),
        twoCycleEnabled: true,
      );
      expect(
        await repository.unavailableRaids(characterId, [
          f2.c,
          f2.n,
        ], v1.testCatalog()),
        {'raid_a'},
      );
      expect(calls.length, 1);
      party = true;
      expect(
        await repository.unavailableRaids(characterId, [
          f2.c,
        ], v1.testCatalog()),
        {'raid_a'},
      );
      omit = true;
      await expectLater(
        repository.unavailableRaids(characterId, [f2.c], v1.testCatalog()),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
