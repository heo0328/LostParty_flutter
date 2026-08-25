import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_application_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_application_command_validator.dart';

void main() {
  const validator = PartyApplicationCommandValidator();
  test('accepts valid apply and withdraw commands', () {
    expect(validator.validateApply(const PartyApplyCommand(recruitmentId: 'r1', characterId: 'c1', requestedRole: PartyRole.support, cycleKey: '2026-08-26')), isNull);
    expect(validator.validateWithdraw(const PartyWithdrawApplicationCommand(recruitmentId: 'r1', expectedRevision: 1)), isNull);
  });
  test('rejects invalid ids and revisions', () {
    expect(validator.validateApply(const PartyApplyCommand(recruitmentId: 'r/1', characterId: 'c1', requestedRole: PartyRole.support, cycleKey: '2026-08-26')), PartyApplicationFailure.invalidRequest);
    expect(validator.validateWithdraw(const PartyWithdrawApplicationCommand(recruitmentId: 'r1', expectedRevision: 0)), PartyApplicationFailure.invalidRequest);
  });
}
