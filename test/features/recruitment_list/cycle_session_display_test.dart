import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/account_read_session.dart';
import 'package:lost_party/features/recruitment_list/data/cycle_session_display.dart';
import 'package:lost_party/features/recruitment_list/presentation/widgets/cycle_session_display_widgets.dart';
import 'cycle_recruitment_test.dart' as f2;
import '../account/backend_read/member_cycles_test.dart' as f1;
import 'session_display_fixtures.dart' as sd;

Map<String, dynamic> wire({String kind = 'existing'}) => sd.displayWire(
  f2.envelope(f1.next, {}, created: true)['scope'] as Map,
  kind: kind,
);
Map<String, dynamic> copy(Map<String, dynamic> v) =>
    jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

void main() {
  test('actual metadata remains deeply immutable and explicitly selected', () {
    final j = wire();
    j['sessions'] = [sd.actualDisplay(sd.displayId(1), required: true)];
    final d = CycleSessionDisplay(j);
    j['sessions'][0]['required'] = false;
    expect(d.selectionReady({}), false);
    expect(() => d.sessions[0]['required'] = false, throwsUnsupportedError);
    expect(
      () => d.sessions[0]['permission']['allowed'] = false,
      throwsUnsupportedError,
    );
    expect(
      () => d.selectedIds({}, DateTime.utc(2026)),
      throwsA(isA<AccountReadException>()),
    );
    expect(d.selectedIds({sd.displayId(1)}, DateTime.utc(2026)), [
      sd.displayId(1),
    ]);
  });
  test(
    '64 actual sessions are complete; duplicate, unsorted and 65 rejected',
    () {
      final j = wire();
      j['sessions'] = [
        for (var i = 0; i < 64; i++) sd.actualDisplay(sd.displayId(i)),
      ];
      expect(CycleSessionDisplay(j).sessions, hasLength(64));
      final duplicate = copy(j)..['sessions'][1] = j['sessions'][0];
      expect(() => CycleSessionDisplay(duplicate), throwsFormatException);
      final unsorted = copy(j)
        ..['sessions'] = (j['sessions'] as List).reversed.toList();
      expect(() => CycleSessionDisplay(unsorted), throwsFormatException);
      j['sessions'].add(sd.actualDisplay(sd.displayId(64)));
      expect(() => CycleSessionDisplay(j), throwsFormatException);
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'missing': (j) => j.remove('display_revision'),
    'extra': (j) => j['unexpected'] = true,
    'kind-mode': (j) => j['selection_mode'] = 'no_session_selection',
    'digest': (j) => j['display_revision'] = 'broken',
    'generation': (j) => j['target_generation'] = 0,
    'none-has-sessions': (j) {
      j['kind'] = 'none';
      j['selection_mode'] = 'no_session_selection';
    },
    'start-only-actual': (j) =>
        j['sessions'][0]['starts_at'] = '2026-10-29T03:00:00Z',
    'confirmed-null': (j) => j['sessions'][0]['state'] = 'confirmed',
    'reversed': (j) {
      j['sessions'][0]['starts_at'] = '2026-10-29T03:00:00Z';
      j['sessions'][0]['ends_at'] = '2026-10-29T02:00:00Z';
    },
  }.entries) {
    test('closed display rejects ${mutation.key}', () {
      final j = wire()..['sessions'] = [sd.actualDisplay(sd.displayId(1))];
      mutation.value(j);
      expect(() => CycleSessionDisplay(j), throwsFormatException);
    });
  }
  test(
    'actual dates can be present while unconfirmed; ended deadline blocks',
    () {
      final s = sd.actualDisplay(sd.displayId(1))
        ..addAll({
          'starts_at': '2026-10-29T15:00:00Z',
          'ends_at': '2026-10-29T16:00:00Z',
          'join_deadline': '2026-10-29T14:30:00Z',
        });
      final d = CycleSessionDisplay(wire()..['sessions'] = [s]);
      expect(d.sessions.single['state'], 'unconfirmed');
      expect(
        () => d.selectedIds({
          sd.displayId(1),
        }, DateTime.parse('2026-10-29T14:30:00Z')),
        throwsA(isA<AccountReadException>()),
      );
      s['permission'] = f1.permit(false);
      expect(
        () => CycleSessionDisplay(
          wire()..['sessions'] = [s],
        ).selectedIds({sd.displayId(1)}, DateTime.utc(2026)),
        throwsFormatException,
      );
    },
  );
  test(
    'display binding rejects another T, generation or plan and uses prospective scope',
    () {
      final scope =
          f2.envelope(f1.next, {}, created: true)['scope']
              as Map<String, dynamic>;
      final d = CycleSessionDisplay(wire());
      d.bind(scope, kind: 'existing', planRevision: 1);
      expect(
        () => d.bind({
          ...scope,
          'target_cycle_key': f1.current,
        }, kind: 'existing'),
        throwsFormatException,
      );
      expect(
        () => d.bind(scope, kind: 'existing', generation: 2),
        throwsFormatException,
      );
      expect(
        () => d.bind(scope, kind: 'existing', planRevision: 2),
        throwsFormatException,
      );
      final preview = CycleSessionDisplay(
        wire(kind: 'opening_preview')..['target_generation'] = 3,
      );
      preview.bind(
        {...scope, 'target_generation': null},
        kind: 'opening_preview',
        generation: 3,
      );
    },
  );
  for (final mode in ['manual', 'coordinated', 'unscheduled']) {
    test('$mode preview remains nonselectable and has no real ID', () {
      final j = wire(kind: 'opening_preview')
        ..['previews'] = [sd.previewGroup(mode: mode, count: 2)];
      final d = CycleSessionDisplay(j);
      expect(d.selectable, false);
      expect(d.sessions, isEmpty);
      expect(
        () => d.selectedIds({}, DateTime.utc(2026)),
        throwsFormatException,
      );
      final invalid = copy(j);
      invalid['previews'][0]['alternatives'][0]['session_id'] = sd.displayId(1);
      expect(() => CycleSessionDisplay(invalid), throwsFormatException);
      invalid['previews'][0]['alternatives'][0]['session_id'] = null;
      invalid['previews'][0]['alternatives'][0]['materialization'] = 'wrong';
      expect(() => CycleSessionDisplay(invalid), throwsFormatException);
    });
  }
  test(
    'preview groups preserve any-cycle empty coordination, each and unknown end',
    () {
      final j = wire(kind: 'opening_preview')
        ..['previews'] = [sd.previewGroup(mode: 'coordinated', count: 0)];
      expect(CycleSessionDisplay(j).previews.single['alternatives'], isEmpty);
      j['previews'] = [sd.previewGroup(occurrence: 'each', count: 2)];
      final d = CycleSessionDisplay(j);
      final a =
          (d.previews.single['alternatives'] as List).first
              as Map<String, dynamic>;
      expect(cycleDisplayTimeRange(a), contains('11/04 (수) 00:05'));
      expect(cycleDisplayTimeRange(a), contains('종료 미정'));
      final actual = sd.actualDisplay(sd.displayId(1))
        ..addAll({
          'starts_at': '2026-10-29T14:00:00Z',
          'ends_at': '2026-10-29T16:00:00Z',
        });
      expect(cycleDisplayTimeRange(actual), contains('10/30 (금) 01:00'));
    },
  );
  test('choice metadata ID/permission mismatch cannot be consumed', () {
    final s = sd.actualDisplay(sd.displayId(1));
    final d = CycleSessionDisplay(wire()..['sessions'] = [s]);
    final choice = {
      for (final k in ['session_id', 'required', 'join_deadline', 'permission'])
        k: s[k],
    };
    d.matchChoices([choice]);
    expect(() => d.matchChoices([]), throwsFormatException);
    expect(
      () => d.matchChoices([
        {...choice, 'permission': f1.permit(false)},
      ]),
      throwsFormatException,
    );
  });
}
