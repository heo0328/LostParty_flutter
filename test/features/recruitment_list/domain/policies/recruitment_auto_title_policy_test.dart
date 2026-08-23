import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/recruitment_auto_title_policy.dart';

void main() {
  const policy = RecruitmentAutoTitlePolicy();

  test('비어 있거나 0인 최소 전투력은 자동 제목에서 생략한다', () {
    expect(
      policy.build(
        difficultyAlias: '하르카',
        experienceLevel: null,
        minCombatPower: 0,
      ),
      '하르카 모집',
    );
  });

  test('숙련도와 최소 전투력을 순서대로 표시하고 소수점은 버린다', () {
    expect(
      policy.build(
        difficultyAlias: '나르카',
        experienceLevel: ExperienceLevel.semiExperienced,
        minCombatPower: 5000.99,
      ),
      '나르카 반숙 5,000 모집',
    );
  });
}
