import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/minimum_combat_power_policy.dart';

void main() {
  const policy = MinimumCombatPowerPolicy();

  test('제한이 없으면 전투력 정보가 없어도 허용한다', () {
    expect(
      policy.evaluate(minimum: null, actual: null),
      MinimumCombatPowerDecision.unrestricted,
    );
  });

  test('제한이 있는데 전투력 정보가 없으면 차단한다', () {
    expect(
      policy.evaluate(minimum: 300000, actual: null),
      MinimumCombatPowerDecision.missing,
    );
  });

  test('제한 미달은 차단하고 경계값은 허용한다', () {
    expect(
      policy.evaluate(minimum: 300000, actual: 299999),
      MinimumCombatPowerDecision.belowMinimum,
    );
    expect(
      policy.evaluate(minimum: 300000, actual: 300000),
      MinimumCombatPowerDecision.satisfied,
    );
  });
}
