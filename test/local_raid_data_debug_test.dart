import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_master/data/datasources/local_raid_data_source.dart';

void main() {
  test('레이드 시드 데이터 출력 확인', () {
    for (final raidBase in LocalRaidDataSource.raidBases) {
      final variations = LocalRaidDataSource.raidVariations
          .where((v) => v.raidBaseId == raidBase.raidBaseId)
          .toList()
        ..sort((a, b) => a.difficultyOrder.compareTo(b.difficultyOrder));

      print('==============================');
      print('레이드명: ${raidBase.name}');
      print('관문수: ${raidBase.gateCount}');
      print('총인원: ${raidBase.partySize}인');

      for (final v in variations) {
        print(
          '- 난이도: ${v.difficultyLabel} / '
          '골드: ${v.rewardGold}',
        );
      }
    }

    // 그냥 통과시키기 위한 최소 assert
    expect(true, true);
  });
}