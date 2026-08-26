import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_membership_command.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/services/party_membership_command_validator.dart';

void main() {
  const validator = PartyMembershipCommandValidator();
  test('캐릭터 변경은 유효한 ID와 revision을 요구한다', () {
    const command = PartyChangeCharacterCommand(recruitmentId: 'party', newCharacterId: 'new/character', newRole: PartyRole.dealer, expectedRecruitmentRevision: 1);
    expect(validator.validateChange(command), PartyMembershipFailure.invalidRequest);
  });
  test('탈퇴·추방 대상 Player ID를 검증한다', () {
    const command = PartyRemoveMemberCommand(recruitmentId: 'party', targetPlayerId: '', expectedRecruitmentRevision: 1);
    expect(validator.validateRemove(command), PartyMembershipFailure.invalidRequest);
  });
  test('승인권 변경은 양수 revision을 요구한다', () {
    const command = PartySetApprovalPermissionCommand(recruitmentId: 'party', targetPlayerId: 'member', enabled: true, expectedRecruitmentRevision: 0);
    expect(validator.validatePermission(command), PartyMembershipFailure.invalidRequest);
  });
}
