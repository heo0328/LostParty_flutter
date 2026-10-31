import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/group/data/backend/group_repository.dart';
import 'package:lost_party/features/group/presentation/pages/backend_group_page.dart';
import 'package:lost_party/features/group/presentation/viewmodels/backend_group_view_model.dart';
import '../../support/server_account_read_fakes.dart';
import 'backend_group_test.dart' as fixtures;

class DetailRepository extends GroupRepository {
  DetailRepository(this.actor)
    : super(
        Dio(BaseOptions(baseUrl: 'http://localhost')),
        actor,
        GroupChanges(),
      );
  @override
  String get readScope => 'test/${actor.userId}/${actor.generation}';
  final ReadSessionFake actor;
  bool leader = true,
      failRequests = false,
      failCode = false,
      failMembers = false;
  bool failManagement = false;
  Completer<List<Map<String, dynamic>>>? requestGate;
  final reads = <String>[];
  final writes = <Map<String, dynamic>>[];
  Map<String, dynamic> group = {
    ...fixtures.summary(),
    'name': '함께하는수요일밤레이드원정대',
    'leader_display': {'character_name': '달빛바드'},
  };
  Map<String, dynamic> get member => {
    'membership_id': fixtures.mid,
    'revision': 1,
    'role': 'member',
    'is_me': false,
    'display': {'character_name': '아주긴이름의은빛소서리스'},
    'character_spec': null,
  };
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic> query = const {},
  }) async {
    reads.add(path);
    if (path == '/v1/groups/${fixtures.gid}') return group;
    if (path == '/v1/me/groups/${fixtures.gid}') {
      return {
        'group': group,
        'members_revision': 1,
        'my_membership': {
          'membership_id': 'self',
          'revision': 1,
          'role': leader ? 'leader' : 'member',
        },
        'permissions': {
          'rename': {'allowed': leader},
        },
        'capacity': {'used': 2, 'limit': 15},
      };
    }
    if (path.endsWith('/management')) {
      if (failManagement) {
        throw const AccountReadException('NETWORK_UNAVAILABLE');
      }
      return {
        'group_revision': 1,
        'members_revision': 1,
        'my_membership': {'membership_id': 'self', 'revision': 1},
        'permissions': {
          for (final a in [
            'transfer_leadership',
            'remove_member',
            'change_representative',
            'leave',
            'disband',
          ])
            a: {'allowed': a == 'leave' ? !leader : leader, 'reason': null},
        },
        'recruitment_state': 'clear',
      };
    }
    if (path.endsWith('/join-code')) {
      if (failCode) throw const AccountReadException('NETWORK_UNAVAILABLE');
      return {
        'code': 'AB7K9C',
        'active': true,
        'visible_to_members': true,
        'code_id': fixtures.mid,
        'revision': 1,
        'regenerate_available_at': null,
      };
    }
    throw StateError(path);
  }

  @override
  Future<List<Map<String, dynamic>>> all(
    String path, {
    Map<String, dynamic> query = const {},
  }) async {
    reads.add(path);
    if (path.endsWith('/join-relations')) {
      if (failRequests) throw const AccountReadException('NETWORK_UNAVAILABLE');
      if (requestGate != null) return requestGate!.future;
      return [];
    }
    if (path.endsWith('/members')) {
      if (failMembers) throw const AccountReadException('NETWORK_UNAVAILABLE');
      return [member];
    }
    if (path.endsWith('/activity-characters')) return [];
    throw StateError(path);
  }

  @override
  Future<Map<String, dynamic>?> pending() async => null;
  @override
  Future<Map<String, dynamic>> command(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    writes.add({'method': method, 'path': path, 'body': body});
    if (path.endsWith('/leadership-transfer')) {
      leader = false;
      group = {...group, 'leader_display': member['display']};
    }
    return {'ok': true};
  }
}

void main() {
  test(
    'detail areas keep independent failure and retry; no empty synthesis',
    () async {
      final r = DetailRepository(ReadSessionFake())..failRequests = true;
      final m = BackendGroupViewModel(
        r,
        GroupPageKind.detail,
        groupId: fixtures.gid,
      );
      await m.load();
      expect(m.failure, isNull);
      expect(m.areaFailures.keys, [GroupDetailArea.requests]);
      expect(m.areaLoaded.contains(GroupDetailArea.requests), isFalse);
      expect(m.rows, isNotEmpty);
      expect(m.code!['code'], 'AB7K9C');
      final count = r.reads.length;
      r.failRequests = false;
      await m.reloadArea(GroupDetailArea.requests);
      expect(r.reads.length, count + 1);
      expect(m.areaFailures, isEmpty);
      expect(m.areaLoaded.contains(GroupDetailArea.requests), isTrue);
      m.dispose();
    },
  );
  test(
    'code and member failure preserve successful requests and management',
    () async {
      final r = DetailRepository(ReadSessionFake())
        ..failCode = true
        ..failMembers = true;
      final m = BackendGroupViewModel(
        r,
        GroupPageKind.detail,
        groupId: fixtures.gid,
      );
      await m.load();
      expect(m.areaFailures.keys.toSet(), {
        GroupDetailArea.code,
        GroupDetailArea.members,
      });
      expect(
        m.areaLoaded,
        containsAll([GroupDetailArea.requests, GroupDetailArea.management]),
      );
      expect(m.code, isNull);
      expect(m.failure, isNull);
      m.dispose();
    },
  );
  test(
    'late area response after role refresh cannot restore leader requests',
    () async {
      final r = DetailRepository(ReadSessionFake())..requestGate = Completer();
      final m = BackendGroupViewModel(
        r,
        GroupPageKind.detail,
        groupId: fixtures.gid,
      );
      final first = m.load();
      await Future<void>.delayed(Duration.zero);
      final gate = r.requestGate!;
      r.leader = false;
      r.requestGate = null;
      await m.load();
      gate.complete([
        {'relation_id': 'old'},
      ]);
      await first;
      expect(m.leader, isFalse);
      expect(m.requests, isEmpty);
      expect(m.areaLoaded.contains(GroupDetailArea.requests), isFalse);
      m.dispose();
    },
  );
  test(
    'late area response after logout cannot repopulate private data',
    () async {
      final actor = ReadSessionFake();
      final r = DetailRepository(actor)..requestGate = Completer();
      final m = BackendGroupViewModel(
        r,
        GroupPageKind.detail,
        groupId: fixtures.gid,
      );
      final loading = m.load();
      await Future<void>.delayed(Duration.zero);
      actor.change(authenticated: false);
      r.requestGate!.complete([
        {'relation_id': 'old'},
      ]);
      await loading;
      expect(m.detail, isNull);
      expect(m.requests, isEmpty);
      expect(m.code, isNull);
      expect(m.areaLoaded, isEmpty);
      m.dispose();
    },
  );
  test(
    'success with failed area refresh remains success without command resend',
    () async {
      final r = DetailRepository(ReadSessionFake());
      final m = BackendGroupViewModel(
        r,
        GroupPageKind.detail,
        groupId: fixtures.gid,
      );
      await m.load();
      r.failCode = true;
      expect(await m.act('POST', '/command', {}), isNotNull);
      expect(m.notice, isNotNull);
      expect(m.areaFailures, contains(GroupDetailArea.code));
      r.failCode = false;
      await m.reloadArea(GroupDetailArea.code);
      expect(r.writes.length, 1);
      m.dispose();
    },
  );
  testWidgets(
    'transfer selection keeps CAS and refresh removes former leader controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = DetailRepository(ReadSessionFake());
      await tester.pumpWidget(
        MaterialApp(
          home: BackendGroupPage(
            repository: r,
            kind: GroupPageKind.detail,
            groupId: fixtures.gid,
            characters: () async => [],
            onLogin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '그룹장 이전'));
      await tester.pumpAndSettle();
      expect(r.writes, isEmpty);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('아주긴이름의은빛소서리스'),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();
      expect(r.writes, isEmpty);
      expect(find.textContaining('즉시 이전되며'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(r.writes.length, 1);
      expect(r.writes.single['body'], {
        'expected_group_revision': 1,
        'expected_members_revision': 1,
        'expected_membership_id': 'self',
        'expected_membership_revision': 1,
        'target_membership_id': fixtures.mid,
        'expected_target_membership_revision': 1,
      });
      expect(find.byTooltip('그룹 이름 변경'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, '그룹장 이전'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320px detail preserves equal actions, cancel writes nothing and expanded removal has 48px target',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = DetailRepository(ReadSessionFake());
      await tester.pumpWidget(
        MaterialApp(
          home: BackendGroupPage(
            repository: r,
            kind: GroupPageKind.detail,
            groupId: fixtures.gid,
            characters: () async => [],
            onLogin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('그룹 이름 변경'));
      await tester.pumpAndSettle();
      expect(find.text('1~20자 · 앞뒤 공백 제외'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(r.writes, isEmpty);
      final invite = find.widgetWithText(FilledButton, '사용자 초대');
      final raid = find.widgetWithText(FilledButton, '그룹 레이드');
      await tester.ensureVisible(invite);
      expect(tester.getSize(invite), const Size(138, 44));
      expect(tester.getSize(raid), const Size(138, 44));
      final member = find.byType(ExpansionTile);
      await tester.ensureVisible(member);
      await tester.tap(member);
      await tester.pumpAndSettle();
      final remove = find.widgetWithText(TextButton, '추방');
      await tester.ensureVisible(remove);
      expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.textContaining('님을 추방할까요?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(r.writes, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
