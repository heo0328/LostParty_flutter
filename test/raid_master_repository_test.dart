import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/shared/raid_master/data/repositories/raid_master_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maps the validated catalog to the legacy raid master contract',
    () async {
      final repository = RaidMasterRepositoryImpl();

      final bases = await repository.getRaidBases();
      final variations = await repository.getRaidVariations();

      expect(bases, hasLength(5));
    expect(variations, hasLength(13));
      expect(bases.first.raidBaseId, 'kazeros_act4');
      expect(bases.first.difficultyIds, [
        'kazeros_act4_normal',
        'kazeros_act4_hard',
      ]);
      expect(variations.first.rewardGold, 27000);
    },
  );
}
