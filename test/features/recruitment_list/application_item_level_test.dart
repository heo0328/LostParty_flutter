import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/application_display.dart';
import 'application_display_test.dart' as previous;

Map<String, dynamic> display({
  Object? value = '1750.12345678901234567890',
  Object? source = 'current_saved',
  Object? stamp = '2026-10-25T01:00:00.123456Z',
}) => {
  'character_name': '신청 캐릭터',
  'item_level': value,
  'item_level_source': source,
  'item_level_fetched_at': stamp,
};

void main() {
  test(
    'exact decimal text and source are immutable; never round or use power',
    () {
      final raw = display();
      final level = ApplicationItemLevel.fromDisplay(raw);
      raw['item_level'] = '0';
      expect(level.value, '1750.12345678901234567890');
      expect(level.label, '아이템 레벨 1750.12345678901234567890 · 현재 저장 정보');
      expect(level.fetchedAt, DateTime.parse('2026-10-25T01:00:00.123456Z'));
    },
  );
  test(
    'stored snapshot stays distinct; unknown original time is not invented',
    () {
      final level = ApplicationItemLevel.fromDisplay(
        display(value: '1700', source: 'application_snapshot', stamp: null),
      );
      expect(level.label, '아이템 레벨 1700');
      expect(level.fetchedAt, null);
      expect(
        ApplicationItemLevel.fromDisplay(display(stamp: null)).fetchedAt,
        null,
      );
    },
  );
  test('unavailable never asks for user confirmation or supplies zero', () {
    final level = ApplicationItemLevel.fromDisplay(
      display(value: null, source: 'unavailable', stamp: null),
    );
    expect(level.label, '아이템 레벨 조회 불가');
    expect(level.value, null);
  });
  for (final key in [
    'item_level',
    'item_level_source',
    'item_level_fetched_at',
  ]) {
    test('missing required nullable or source key: $key', () {
      final raw = display()..remove(key);
      expect(
        () => ApplicationItemLevel.fromDisplay(raw),
        throwsFormatException,
      );
    });
  }
  for (final value in <Object?>[
    true,
    1750,
    -1,
    'NaN',
    'Infinity',
    '-1',
    '+1',
    '1e3',
    '1,750',
    ' 1750',
    '1750 ',
    '',
    '.5',
    '1.',
    '1' * 65,
  ]) {
    test('reject malformed level $value (${value.runtimeType})', () {
      expect(
        () => ApplicationItemLevel.fromDisplay(display(value: value)),
        throwsFormatException,
      );
    });
  }
  for (final raw in [
    display(source: null),
    display(source: 'latest'),
    display(source: true),
    display(value: null),
    display(value: null, source: 'application_snapshot'),
    display(source: 'unavailable', stamp: null),
    display(value: null, source: 'unavailable'),
    display(stamp: '2026-10-25T10:00:00+09:00'),
    display(stamp: '2026-10-25T01:00:00'),
    display(stamp: '2026-02-30T01:00:00Z'),
    display(stamp: true),
  ].indexed) {
    test('reject source/value/time mismatch ${raw.$1}', () {
      expect(
        () => ApplicationItemLevel.fromDisplay(raw.$2),
        throwsFormatException,
      );
    });
  }
  test(
    'zero and 64-character decimal are valid, no application level threshold',
    () {
      for (final value in ['0', '0.0000', '1' * 64]) {
        expect(
          ApplicationItemLevel.fromDisplay(display(value: value)).value,
          value,
        );
      }
    },
  );
  test('level and analysis/display reason remain independent', () {
    final raw = previous.wire('current_error_retained_success');
    final item = raw['data']['items'][0];
    (item['display'] as Map).addAll(
      display(value: '1700', source: 'application_snapshot'),
    );
    final parsed = previous.page(raw).items.single;
    expect(parsed.itemLevel.label, '아이템 레벨 1700');
    expect(parsed.status, contains('분석 오류'));
    expect(parsed.status, contains('마지막 성공'));
    item['display_reason'] = 'APPLICATION_CONTEXT_CHANGED';
    item['comparison'] = null;
    item['analysis'] = null;
    expect(previous.page(raw).items.single.itemLevel.label, '아이템 레벨 1700');
    item['display']['item_level_source'] = 'current_saved';
    expect(() => previous.page(raw), throwsFormatException);
  });
}
