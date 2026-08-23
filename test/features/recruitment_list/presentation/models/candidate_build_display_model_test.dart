import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/presentation/models/candidate_build_display_model.dart';

void main() {
  test('후보 세팅 숫자는 소수점을 버리고 동일한 형식으로 표시한다', () {
    const model = CandidateBuildDisplayModel(
      role: PartyRole.dealer,
      itemLevel: 1700.99,
      combatPower: 338229.99,
      minCombatPower: 300000,
    );
    expect(model.label, '딜러 · 아이템 레벨 1,700 · 전투력 338,229');
  });

  test('전투력 없음과 최소 전투력 미달을 명확히 표시한다', () {
    const missing = CandidateBuildDisplayModel(
      role: PartyRole.support,
      itemLevel: null,
      combatPower: null,
      minCombatPower: 300000,
    );
    const below = CandidateBuildDisplayModel(
      role: PartyRole.support,
      itemLevel: 1700,
      combatPower: 299999.9,
      minCombatPower: 300000,
    );
    expect(missing.label, '서포터 · 아이템 레벨 없음 · 전투력 없음');
    expect(
      below.label,
      '서포터 · 아이템 레벨 1,700 · 전투력 299,999 · 최소 전투력 미달',
    );
  });
}
