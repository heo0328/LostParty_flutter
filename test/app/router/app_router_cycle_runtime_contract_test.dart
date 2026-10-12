import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Router는 앱 시작 시각 Snapshot 대신 runtime 회차를 사용한다', () {
    final source = File('lib/app/router/app_router.dart').readAsStringSync();

    expect(source, contains('refreshListenable: cycleRuntime'));
    expect(source, contains('cycleKey: cycle.key'));
    expect('=> CycleBoundPage('.allMatches(source).length, 3);
    expect(source, contains('currentCycleKey: cycleRuntime.refreshAndGetKey'));
    expect(
      source,
      isNot(
        contains('final currentCycleKey = cyclePolicy.keyFor(DateTime.now())'),
      ),
    );
  });
}
