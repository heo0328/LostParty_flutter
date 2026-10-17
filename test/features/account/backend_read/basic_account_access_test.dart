import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/server_account_models.dart';
import 'package:lost_party/features/account/domain/server_character_lifecycle.dart';
import '../../../support/server_account_read_fakes.dart';
import 'server_character_lifecycle_client_test.dart' as wire;

void main() {
  for (final state in ['unverified', 'ownership_lost']) {
    test(
      '$state V1 power and timestamps are suppressed after strict parsing',
      () {
        final json = charactersJson()..['ownership_status'] = state;
        final row = (json['characters'] as Map)['items'][0] as Map;
        row['combat_power'] = '999';
        row['power_status'] = 'available';
        row['power_fetched_at'] = serverTime;
        final parsed = ServerCharactersResponse.fromJson(
          json,
        ).characters.items.single;
        expect(parsed.combatPower, isNull);
        expect(parsed.power.value, isNull);
        expect(parsed.power.fetchedAt, isNull);
        expect(parsed.power.status, 'unknown');
        expect(row['combat_power'], '999');
      },
    );
  }
  test('unverified V2 wire projection cannot persist cached power', () {
    final json = wire.roster()..['ownership_status'] = 'unverified';
    json['game_account_id'] = null;
    json['ownership_revision'] = null;
    json['items'] = [
      {
        ...wire.item(),
        'character_id': null,
        'lifecycle_state': 'preview',
        'lifecycle_revision': null,
        'usable': false,
        'blocked_reason': 'OWNERSHIP_REQUIRED',
        'combat_power': '999',
        'power_status': 'available',
      },
    ];
    final row = LifecycleCharacterPage.fromJson(json).items.single;
    expect(row.wire['combat_power'], isNull);
    expect(row.wire['power_status'], 'unknown');
  });
  test(
    'owned observations retain power independently of activity configuration',
    () {
      final json = charactersJson();
      (json['characters'] as Map)['items'] = [
        characterJson()
          ..['combat_power'] = '321'
          ..['power_status'] = 'available',
      ];
      expect(
        ServerCharactersResponse.fromJson(
          json,
        ).characters.items.single.power.value,
        321,
      );
    },
  );
}
