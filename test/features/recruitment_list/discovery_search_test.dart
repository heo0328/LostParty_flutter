import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_search_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_recruitment_test.dart' as base;
import 'cycle_recruitment_test.dart' as cycles;
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_interaction_repository.dart';
import 'discovery_fixtures.dart';
import 'cycle_interaction_test.dart' as f;

void main() {
  test('pinned discovery projection and request validate', () {
    final raw = discoveryWire(f.searchWire(f.c));
    final contract = BetaContract(mode: RecruitmentContractMode.betaWire2);
    final q = contract.query('POST', '/v2/raid-rooms/search', {
      'response_profile': 'discovery-1',
    });
    contract.validateRequest(
      'POST',
      '/v2/raid-rooms/search',
      q,
      CycleSearchFilter().body(f.c),
    );
    final result = CycleSearchPage.discovery(raw, f.c, groups: false);
    expect(result.totalCount, 1);
  });
  test(
    'discovery rejects missing count, invalid permission and progress combinations',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (j) => (j['data'] as Map).remove('total_count'),
        (j) =>
            j['data']['items'][0]['view_detail_permission']['allowed'] = 'true',
        (j) => j['data']['result_revision'] = 'invalid',
        (j) => j['data']['items'][0]['unknown'] = true,
      ]) {
        final raw = discoveryWire(f.searchWire(f.c));
        mutate(raw);
        expect(
          () => CycleSearchPage.discovery(raw, f.c, groups: false),
          throwsFormatException,
        );
      }
      expect(
        () => BetaContract.definition('CoordinationProgress', {
          'status': 'waiting_members',
          'missing_members': null,
        }),
        throwsFormatException,
      );
      expect(
        () => BetaContract.definition('CoordinationProgress', {
          'status': 'coordinating',
          'missing_members': 2,
        }),
        throwsFormatException,
      );
    },
  );
  group('discovery cache', () {
    late DateTime now;
    late CycleSearchViewModel model;
    late f.TestGateway gateway;
    late ChangeNotifier changes;
    late ReadSessionFake session;
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    CycleSearchPage page({
      String? cursor,
      String id = f.room,
      int count = 100,
    }) {
      final raw = discoveryWire(f.searchWire(f.c, id: id, cursor: cursor));
      raw['data']['total_count'] = count;
      return CycleSearchPage.discovery(raw, f.c, groups: false);
    }

    setUp(() async {
      now = DateTime.utc(2026, 11, 12);
      changes = ChangeNotifier();
      session = ReadSessionFake();
      gateway = f.TestGateway(base.Api(), cycles.CycleGateway());
      gateway.onSearch = (t, filter, cursor) async => page(
        cursor: cursor == null ? 'next' : null,
        id: cursor == null ? f.room : f.app,
      );
      model = CycleSearchViewModel(
        gateway: gateway,
        session: session,
        changes: changes,
        scopeKey: () => 'member/environment',
        clock: () => now,
      );
      await model.load();
    });
    tearDown(() {
      model.dispose();
      changes.dispose();
      session.dispose();
    });
    test(
      '59 seconds reuse, append does not extend TTL, 60 seconds replaces',
      () async {
        now = now.add(const Duration(seconds: 59));
        model.update(model.filter);
        await settle();
        expect(gateway.searches, 1);
        await model.search(more: true);
        expect(model.rows, hasLength(2));
        now = now.add(const Duration(seconds: 1));
        expect(model.cacheFresh, false);
        model.update(model.filter);
        await settle();
        expect(gateway.searches, 3);
        expect(model.rows, hasLength(1));
      },
    );
    test(
      'quick controls change only applied fields and preserve pending detail edits',
      () async {
        final draft = model.draft();
        addTearDown(draft.dispose);
        draft.update(draft.filter.copy(raids: {'raid_a'}));
        final before = gateway.searches;
        expect(model.updateQuick(category: 'general', draft: draft), true);
        await settle();
        expect(gateway.searches, before + 1);
        expect(model.filter.category, 'general');
        expect(model.filter.raids, isEmpty);
        expect(draft.filter.raids, {'raid_a'});
        model.updateQuick(descending: false, draft: draft);
        await settle();
        expect(model.filter.descending, false);
        expect(draft.filter.descending, false);
        expect(draft.filter.raids, {'raid_a'});
        final calls = gateway.searches;
        expect(model.updateQuick(category: 'general', draft: draft), false);
        expect(gateway.searches, calls);
      },
    );
    test(
      'detail reset preserves category and sort without redundant repeat search',
      () async {
        model.update(
          CycleSearchFilter(
            category: 'general',
            descending: false,
            raids: {'raid_a'},
            remaining: {2},
          ),
        );
        await settle();
        expect(model.resetDetails(), true);
        await settle();
        expect(model.filter.category, 'general');
        expect(model.filter.descending, false);
        expect(model.filter.raids, isEmpty);
        expect(model.filter.remaining, isEmpty);
        final calls = gateway.searches;
        expect(model.resetDetails(), false);
        expect(gateway.searches, calls);
      },
    );
    test(
      'LRU retains five conditions and evicts least recently used',
      () async {
        for (var i = 1; i <= 5; i++) {
          model.update(CycleSearchFilter(remaining: {i}));
          await settle();
        }
        final count = gateway.searches;
        model.update(CycleSearchFilter(remaining: {5}));
        await settle();
        expect(gateway.searches, count);
        model.update(CycleSearchFilter());
        await settle();
        expect(gateway.searches, count + 1);
      },
    );
    test(
      'count integrity mismatch replaces instead of appending and old responses are ignored',
      () async {
        gateway.onSearch = (t, filter, cursor) async => page(
          count: cursor == null ? 100 : 101,
          id: cursor == null ? f.room : f.app,
        );
        await model.search(more: true);
        expect(model.rows, hasLength(1));
        expect(model.totalCount, 100);
        final pending = Completer<CycleSearchPage>();
        gateway.onSearch = (t, filter, cursor) => pending.future;
        model.update(CycleSearchFilter(remaining: {2}));
        gateway.onSearch = (t, filter, cursor) async => page(id: f.app);
        model.update(CycleSearchFilter(remaining: {3}));
        await settle();
        pending.complete(page());
        await settle();
        expect(model.rows.single.id, f.app);
      },
    );
  });
}
