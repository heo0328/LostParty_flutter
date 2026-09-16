import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('생성 후보 점유 조회는 원자 raidState와 생성 점유 정책을 사용한다', () {
    final source = File(
      'lib/features/recruitment_list/data/repositories/'
      'firestore_active_raid_assignment_lookup.dart',
    ).readAsStringSync();

    expect(source, contains(".collection('raidStates')"));
    expect(source, contains('PartyCreateOccupancyGate.decide('));
    expect(source, isNot(contains(".collection('activeRaidAssignments')")));
  });
}
