import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_join_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_join_command_validator.dart';

void main() {
  const validator = PartyJoinCommandValidator();

  test('즉시 가입은 유효한 문서 ID와 모집 revision을 요구한다', () {
    const valid = PartyDirectJoinCommand(
      recruitmentId: 'raid-1', characterId: 'character-1',
      role: PartyRole.dealer, cycleKey: '2026-W34',
      expectedRecruitmentRevision: 2,
    );
    const invalid = PartyDirectJoinCommand(
      recruitmentId: 'raid/1', characterId: 'character-1',
      role: PartyRole.dealer, cycleKey: '2026-W34',
      expectedRecruitmentRevision: 2,
    );

    expect(validator.validateDirectJoin(valid), isNull);
    expect(validator.validateDirectJoin(invalid), PartyJoinFailure.invalidRequest);
  });

  test('승인·거절은 신청과 모집 revision을 모두 요구한다', () {
    const command = PartyDecideApplicationCommand(
      recruitmentId: 'raid-1', applicantPlayerId: 'player-2',
      expectedApplicationRevision: 0, expectedRecruitmentRevision: 2,
    );

    expect(validator.validateDecision(command), PartyJoinFailure.invalidRequest);
  });
}
