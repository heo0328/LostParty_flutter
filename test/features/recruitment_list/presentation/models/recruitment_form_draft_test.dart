import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/presentation/models/recruitment_form_draft.dart';

void main() {
  test('최소 전투력 빈 값과 0은 제한 없음으로 정규화한다', () {
    expect(RecruitmentFormDraft.normalizeMinCombatPower(''), isNull);
    expect(RecruitmentFormDraft.normalizeMinCombatPower('0'), isNull);
  });

  test('최소 전투력은 쉼표를 허용하고 소수점을 버린다', () {
    expect(
      RecruitmentFormDraft.normalizeMinCombatPower('338,229.99'),
      338229,
    );
  });
}
