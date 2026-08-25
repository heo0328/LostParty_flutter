import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_cycle_command.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_cycle_command_validator.dart';

void main() {
  const validator = PartyCycleCommandValidator();
  test('완료 명령의 회차 키와 revision을 검증한다', () {
    expect(validator.validateComplete(const PartyCompleteCycleCommand(recruitmentId: 'party', cycleKey: '2026-08-26', expectedRecruitmentRevision: 1)), isNull);
    expect(validator.validateComplete(const PartyCompleteCycleCommand(recruitmentId: 'party', cycleKey: '2026-08-27', expectedRecruitmentRevision: 1)), PartyCycleFailure.invalidRequest);
  });
  test('다음 회차는 현재 회차와 달라야 한다', () {
    expect(validator.validateAdvance(const PartyAdvanceCycleCommand(recruitmentId: 'party', expectedCycleKey: '2026-08-26', nextCycleKey: '2026-08-26', expectedRecruitmentRevision: 2)), PartyCycleFailure.invalidRequest);
  });
}
