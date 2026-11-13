import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/data/backend_account_read_api.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_contract.dart';
import 'package:lost_party/features/recruitment_list/data/beta/beta_read.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_read_repository.dart';
import 'package:lost_party/features/recruitment_list/presentation/viewmodels/cycle_read_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import '../account/backend_read/member_cycles_test.dart' show settled;
import 'backend_recruitment_test.dart' as base;
import 'group_connection_contract_test.dart' as groups;
import 'membership_readers_test.dart' as records;

// Issue52: actual shared-reader contract, with all ordinary app opt-ins.
Map<String, dynamic> historyPage({required bool missingCycle}) {
  final raw = records.sample('ended_records_page');
  final item = (raw['data']['items'] as List).first;
  raw['data']['items'] = [item];
  item['beta_schedule'] = null;
  if (missingCycle) {
    final target = item['target'] as Map;
    for (final key in [
      'room_cycle_id',
      'target_generation',
      'target_revision',
      'target_state',
      'generation_state',
      'leadership',
    ]) {
      target[key] = null;
    }
    final viewer = item['viewer'] as Map;
    for (final key in [
      'cycle_member_id',
      'cycle_member_revision',
      'joined_order',
      'record_locator',
    ]) {
      viewer[key] = null;
    }
    viewer['mode'] = 'relation_only';
    viewer['cycle_member_state'] = 'not_selected';
  }
  raw['group_states'] = [];
  raw['cycle_groups'] = missingCycle
      ? []
      : [groups.policyFor(item['target'], groupId: null)];
  raw['character_issues'] = {
    'profile': 'roster-character-issues-1',
    'evaluated_at': raw['scope']['server_now'],
    'issues_revision': List.filled(64, 'a').join(),
    'items': [],
  };
  raw['participation_context'] = {
    'profile': 'remaining-active-1',
    'evaluated_at': raw['scope']['server_now'],
    'members': [],
  };
  return raw;
}

const current = '2026-10-21', following = '2026-10-28';

Map<String, dynamic> page({
  bool missing = false,
  bool empty = false,
  int identity = 1,
  String? cursor,
  String target = current,
}) {
  final raw = historyPage(missingCycle: missing);
  raw['scope']['target_cycle_key'] = target;
  raw['data']['next_cursor'] = cursor;
  final row = raw['data']['items'][0] as Map;
  row['target']['target_cycle_key'] = target;
  final viewer = row['viewer'] as Map;
  viewer['membership_id'] =
      '00000000-0000-4000-8000-${(1000 + identity).toString().padLeft(12, '0')}';
  if (!missing) {
    viewer['cycle_member_id'] =
        '00000000-0000-4000-8000-${(2000 + identity).toString().padLeft(12, '0')}';
    viewer['record_locator']['membership_id'] = viewer['membership_id'];
    viewer['record_locator']['cycle_member_id'] = viewer['cycle_member_id'];
    viewer['record_locator']['target_cycle_key'] = target;
    raw['cycle_groups'][0]['target_cycle_key'] = target;
  }
  if (empty) {
    raw['data']['items'] = [];
    raw['cycle_groups'] = [];
  }
  return raw;
}

class Harness {
  Harness(this.respond) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          calls.add(r);
          try {
            final raw = await respond(r);
            h.resolve(Response(requestOptions: r, statusCode: 200, data: raw));
          } catch (e) {
            h.reject(
              DioException(
                requestOptions: r,
                response: e is AccountReadException
                    ? Response(
                        requestOptions: r,
                        statusCode: 409,
                        data: {
                          'error': {'code': e.code},
                        },
                      )
                    : null,
              ),
            );
          }
        },
      ),
    );
    model = CycleReadViewModel(
      repository: CycleReadRepository(
        DioBackendAccountReadApi(dio, session),
        membershipProfile: true,
        includeGroupList: true,
        includeCharacterIssues: true,
        contractMode: RecruitmentContractMode.betaWire2,
      ),
      changes: changes,
      scopeKey: () => '${session.userId}/${session.generation}/$environment',
    );
    addTearDown(() {
      if (!disposed) model.dispose();
      changes.dispose();
      session.dispose();
      dio.close(force: true);
    });
  }
  final FutureOr<Map<String, dynamic>> Function(RequestOptions) respond;
  final session = ReadSessionFake();
  final changes = ChangeNotifier();
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  final calls = <RequestOptions>[];
  late final CycleReadViewModel model;
  String environment = 'dev';
  bool disposed = false;

  Future<void> select([String target = current, int section = 2]) async {
    model.select(target, section: section);
    await settled(() => !model.loading);
  }
}

void main() {
  for (final missingCycle in [false, true]) {
    test('ended group page: missing selected cycle=$missingCycle', () async {
      final raw = historyPage(missingCycle: missingCycle);
      final target = raw['scope']['target_cycle_key'] as String;
      // Base DTO and all metadata schema validation accept both shapes.
      final basePage = BetaResponse.parse(
        method: 'GET',
        path: '/v2/me/raid-room-memberships',
        status: 200,
        json: raw,
        parseLegacy: (j) => CycleOwnPage.profile(target, j),
      );
      expect(basePage.value.rows, hasLength(1));
      expect(basePage.value.rows.single.isEndedParticipation, isTrue);
      final api = base.Api()..respond = (_, _) async => raw;
      final read = readRecruitment(
        api: api,
        mode: RecruitmentContractMode.betaWire2,
        includeGroupList: true,
        path: '/v2/me/raid-room-memberships',
        query: {
          'target_cycle_key': target,
          'state': 'ended',
          'limit': 20,
          'reader_profile': 'membership-actions-1',
          'include_character_issues': 'true',
        },
        parse: (j) => CycleOwnPage.profile(target, j),
      );
      final decoded = await read;
      expect(decoded.value.rows, hasLength(1));
      final row = decoded.value.rows.single;
      expect(row.isSelectedCycleHistory, !missingCycle);
      final display = listDisplayData(
        decoded.metadata,
        raw['data']['items'][0],
        row.roomId,
        allowMissingMembershipCycle: true,
      );
      expect(display?['group_policy'], missingCycle ? isNull : isNotNull);
    });
  }

  test(
    'hidden first pages continue with identical profiles and one loading span',
    () async {
      final h = Harness(
        (r) => switch (r.queryParameters['cursor']) {
          null => page(missing: true, cursor: 'p2'),
          'p2' => page(missing: true, identity: 2, cursor: 'p3'),
          _ => page(),
        },
      );
      final loading = <bool>[];
      h.model.addListener(() => loading.add(h.model.loading));
      await h.select();
      expect(h.model.failure, isNull);
      expect(h.model.rows, hasLength(3));
      expect(h.model.visibleRows, hasLength(1));
      expect(h.calls, hasLength(3));
      expect(loading.where((v) => v).length, 1);
      for (final request in h.calls) {
        expect(request.method, 'GET');
        expect(request.path, '/v2/me/raid-room-memberships');
        expect(request.queryParameters, containsPair('state', 'ended'));
        expect(
          request.queryParameters,
          containsPair('target_cycle_key', current),
        );
        expect(
          request.queryParameters,
          containsPair('reader_profile', 'membership-actions-1'),
        );
        expect(
          request.queryParameters,
          containsPair('contract_profile', 'beta-recruitment-1'),
        );
        expect(
          request.queryParameters,
          containsPair('participation_profile', 'remaining-active-1'),
        );
        expect(
          request.queryParameters,
          containsPair('group_policy_version', 'cycle-group-policy-1'),
        );
        expect(
          request.queryParameters,
          containsPair('include_group_state', 'true'),
        );
        expect(
          request.queryParameters,
          containsPair('include_character_issues', 'true'),
        );
      }
    },
  );

  for (final empty in [true, false]) {
    test(
      'empty history finishes only at cursor end: actually empty=$empty',
      () async {
        final h = Harness(
          (r) => r.queryParameters['cursor'] == null
              ? page(empty: empty, missing: !empty, cursor: empty ? null : 'p2')
              : page(missing: true, identity: 2),
        );
        await h.select();
        expect(h.model.failure, isNull);
        expect(h.model.visibleRows, isEmpty);
        expect(h.model.cursor, isNull);
        expect(h.calls, hasLength(empty ? 1 : 2));
      },
    );
  }

  test(
    'mixed page stops at first visible batch; more skips another hidden batch',
    () async {
      final mixed = page(cursor: 'p2');
      mixed['data']['items'].add(page(missing: true)['data']['items'][0]);
      final h = Harness(
        (r) => switch (r.queryParameters['cursor']) {
          null => mixed,
          'p2' => page(missing: true, identity: 2, cursor: 'p3'),
          _ => page(identity: 3, cursor: 'p4'),
        },
      );
      await h.select();
      expect(h.calls, hasLength(1));
      expect(h.model.visibleRows, hasLength(1));
      await h.model.load(more: true);
      expect(h.model.failure, isNull);
      expect(h.calls, hasLength(3));
      expect(h.model.visibleRows, hasLength(2));
      expect(h.model.rows, hasLength(4));
      expect(h.model.cursor, 'p4');
    },
  );

  test(
    'cycle relation_only stays visible, shared rows stay available to other tabs',
    () async {
      final raw = page();
      final viewer = raw['data']['items'][0]['viewer'];
      viewer['mode'] = 'relation_only';
      viewer['role'] = 'none';
      viewer['cycle_member_id'] = null;
      viewer['cycle_member_revision'] = null;
      viewer['record_locator'] = null;
      viewer['joined_order'] = null;
      viewer['cycle_member_state'] = 'not_selected';
      final h = Harness((_) => raw);
      await h.select();
      expect(h.model.failure, isNull);
      expect(h.model.visibleRows.single.profile!.mode, 'relation_only');
      final hidden = Harness((_) => page(missing: true, cursor: 'p2'));
      await hidden.select(current, 0);
      expect(hidden.calls, hasLength(1));
      expect(hidden.model.rows.single.profile!.mode, 'relation_only');
      expect(hidden.model.cursor, 'p2');
    },
  );

  for (final fault in [
    'missing policy',
    'duplicate policy',
    'missing field',
    'invalid type',
    'extra policy',
  ]) {
    test('invalid history envelope remains rejected: $fault', () async {
      final raw = page(
        missing: fault == 'missing field' || fault == 'extra policy',
      );
      switch (fault) {
        case 'missing policy':
          raw['cycle_groups'] = [];
        case 'duplicate policy':
          raw['cycle_groups'].add(records.copy(raw['cycle_groups'][0]));
        case 'missing field':
          raw['data']['items'][0]['target'].remove('room_cycle_id');
        case 'invalid type':
          raw['data']['items'][0]['target']['room_cycle_id'] = 1;
        case 'extra policy':
          raw['cycle_groups'] = page()['cycle_groups'];
      }
      final h = Harness((_) => raw);
      await h.select();
      expect(h.model.failure, 'INVALID_RESPONSE');
      expect(h.model.rows, isEmpty);
    });
  }

  test('default group consumers still reject a missing cycle policy', () {
    final raw = page(missing: true);
    expect(() => groupListStates(raw), throwsFormatException);
    expect(
      () => listDisplayData(
        {'room_group_states': {}},
        raw['data']['items'][0],
        raw['data']['items'][0]['target']['room_id'],
      ),
      throwsFormatException,
    );
  });

  test(
    'readRecruitment never enables the exception without the membership profile',
    () async {
      final api = base.Api()..respond = (_, _) async => page(missing: true);
      await expectLater(
        readRecruitment(
          api: api,
          mode: RecruitmentContractMode.betaWire2,
          includeGroupList: true,
          path: '/v2/me/raid-room-memberships',
          query: {'target_cycle_key': current, 'state': 'ended'},
          parse: (j) => j,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'next-week hidden page continues within that week without reusing current records',
    () async {
      final h = Harness(
        (r) => r.queryParameters['cursor'] == null
            ? page(missing: true, target: following, cursor: 'next-page')
            : page(target: following),
      );
      await h.select(following);
      expect(h.model.failure, isNull);
      expect(
        h.model.visibleRows.single.profile!.target['target_cycle_key'],
        following,
      );
      expect(h.calls, hasLength(2));
      expect(
        h.calls.every(
          (r) => r.queryParameters['target_cycle_key'] == following,
        ),
        isTrue,
      );
    },
  );

  for (final duplicateIdentity in [false, true]) {
    test(
      'hidden chains reject ${duplicateIdentity ? 'duplicate identity' : 'repeated cursor'} atomically',
      () async {
        final h = Harness(
          (r) => r.queryParameters['cursor'] == null
              ? page(missing: true, cursor: 'p2')
              : page(
                  missing: true,
                  identity: duplicateIdentity ? 1 : 2,
                  cursor: duplicateIdentity ? null : 'p2',
                ),
        );
        await h.select();
        expect(h.model.failure, 'INVALID_RESPONSE');
        expect(h.model.rows, isEmpty);
        expect(h.model.cursor, isNull);
        expect(h.calls, hasLength(2));
      },
    );
  }

  test(
    'failure mid-more retains checkpoint, retry and refresh restart at correct cursors',
    () async {
      var fail = true;
      final h = Harness(
        (r) => switch (r.queryParameters['cursor']) {
          null => page(cursor: 'p2'),
          'p2' => page(missing: true, cursor: 'p3'),
          _ => fail ? throw StateError('offline') : page(identity: 2),
        },
      );
      await h.select();
      final previous = h.model.rows;
      await h.model.load(more: true);
      expect(h.model.failure, 'NETWORK_UNAVAILABLE');
      expect(h.model.rows, same(previous));
      expect(h.model.cursor, 'p2');
      fail = false;
      await h.model.load(more: true);
      expect(h.model.failure, isNull);
      expect(h.model.visibleRows, hasLength(2));
      expect(h.calls.map((r) => r.queryParameters['cursor']), [
        null,
        'p2',
        'p3',
        'p2',
        'p3',
      ]);
      await h.model.load();
      expect(h.calls.last.queryParameters['cursor'], isNull);
      expect(h.model.visibleRows, hasLength(1));
    },
  );

  for (final stale in [
    'CURSOR_STALE',
    'FILTER_CONTEXT_STALE',
    'CYCLE_CHANGED',
  ]) {
    test('$stale clears cache and restarts at page one', () async {
      var fail = true;
      final h = Harness((r) {
        if (fail && r.queryParameters['cursor'] != null) {
          throw AccountReadException(stale);
        }
        return page(cursor: 'p2');
      });
      await h.select();
      await h.model.load(more: true);
      expect(h.model.failure, stale);
      expect(h.model.rows, isEmpty);
      expect(h.model.cursor, isNull);
      fail = false;
      await h.model.load();
      expect(h.calls.last.queryParameters['cursor'], isNull);
      expect(h.model.failure, isNull);
    });
  }

  test(
    'C/N caches restore visited hidden cursors and reject loops after return',
    () async {
      var nCalls = 0;
      final h = Harness((r) {
        final target = r.queryParameters['target_cycle_key'] as String;
        if (target == following) {
          nCalls++;
          return page(empty: true, target: following);
        }
        return switch (r.queryParameters['cursor']) {
          null => page(missing: true, cursor: 'p2'),
          'p2' => page(cursor: 'p3'),
          _ => page(identity: 2, cursor: 'p2'),
        };
      });
      await h.select();
      expect(h.model.cursor, 'p3');
      await h.select(following);
      expect(h.model.visibleRows, isEmpty);
      final count = h.calls.length;
      await h.select();
      expect(h.calls, hasLength(count));
      expect(h.model.visibleRows, hasLength(1));
      await h.model.load(more: true);
      expect(h.model.failure, 'INVALID_RESPONSE');
      expect(h.model.cursor, 'p3');
      expect(h.model.visibleRows, hasLength(1));
      expect(nCalls, 1);
    },
  );

  for (final transition in [
    'week',
    'tab',
    'member',
    'environment',
    'dispose',
  ]) {
    test(
      'late hidden response cannot continue after $transition change',
      () async {
        final wait = Completer<Map<String, dynamic>>();
        var requests = 0;
        final h = Harness(
          (r) => ++requests == 1
              ? wait.future
              : page(
                  empty: true,
                  target: r.queryParameters['target_cycle_key'] as String,
                ),
        );
        h.model.select(current, section: 2);
        await settled(() => h.calls.length == 1);
        // An identical load while waiting must not issue a second request.
        await h.model.load();
        switch (transition) {
          case 'week':
            h.model.select(following, section: 2);
          case 'tab':
            h.model.select(current, section: 0);
          case 'member':
            h.session.change(authenticated: false);
          case 'environment':
            h.environment = 'other';
            h.changes.notifyListeners();
          case 'dispose':
            h.model.dispose();
            h.disposed = true;
        }
        if (transition == 'week' ||
            transition == 'tab' ||
            transition == 'environment') {
          await settled(() => h.calls.length == 2);
        }
        final count = h.calls.length;
        wait.complete(page(missing: true, cursor: 'must-not-follow'));
        if (!h.disposed) await settled(() => !h.model.loading);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(h.calls, hasLength(count));
        expect(h.model.rows, isEmpty);
      },
    );
  }
}
