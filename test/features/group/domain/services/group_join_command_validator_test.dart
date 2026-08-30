import 'package:flutter_test/flutter_test.dart';

import 'package:lost_party/features/group/domain/entities/group_join_code_command.dart';
import 'package:lost_party/features/group/domain/entities/group_join_command.dart';
import 'package:lost_party/features/group/domain/services/group_join_command_validator.dart';

void main() {
  const validator = GroupJoinCommandValidator();

  test('정상 초대·신청 명령은 형식 오류가 없다', () {
    expect(
      validator.validateInvite(
        const GroupInviteCommand(
          groupId: 'group-1',
          targetCharacterId: 'character-9',
        ),
      ),
      isNull,
    );
    expect(
      validator.validateApply(
        const GroupApplyCommand(groupId: 'group-1', characterId: 'character-2'),
      ),
      isNull,
    );
  });

  test('빈 ID와 경로 구분자를 담은 ID를 거절한다', () {
    expect(
      validator.validateInvite(
        const GroupInviteCommand(groupId: '  ', targetCharacterId: 'c-1'),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateInvite(
        const GroupInviteCommand(
          groupId: 'group-1',
          targetCharacterId: 'characters/c-1',
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateApply(
        const GroupApplyCommand(groupId: 'groups/group-1', characterId: 'c-1'),
      ),
      GroupJoinFailure.invalidRequest,
    );
  });

  test('수락·거절 명령은 관계 revision 1 이상을 요구한다', () {
    expect(
      validator.validateDecision(
        const GroupInvitationDecisionCommand(
          groupId: 'group-1',
          expectedRelationRevision: 1,
        ),
      ),
      isNull,
    );
    expect(
      validator.validateDecision(
        const GroupInvitationDecisionCommand(
          groupId: 'group-1',
          expectedRelationRevision: 0,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
  });

  test('취소 명령은 대상 Player ID와 revision을 함께 확인한다', () {
    expect(
      validator.validateCancel(
        const GroupInvitationCancelCommand(
          groupId: 'group-1',
          targetPlayerId: 'player-9',
          expectedRelationRevision: 2,
        ),
      ),
      isNull,
    );
    expect(
      validator.validateCancel(
        const GroupInvitationCancelCommand(
          groupId: 'group-1',
          targetPlayerId: '',
          expectedRelationRevision: 2,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateCancel(
        const GroupInvitationCancelCommand(
          groupId: 'group-1',
          targetPlayerId: 'player-9',
          expectedRelationRevision: -1,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
  });

  test('신청 승인·거절·금지 명령은 대상 Player와 revision을 함께 확인한다', () {
    expect(
      validator.validateApplicationDecision(
        const GroupApplicationDecisionCommand(
          groupId: 'group-1',
          targetPlayerId: 'player-2',
          expectedRelationRevision: 3,
        ),
      ),
      isNull,
    );
    expect(
      validator.validateApplicationDecision(
        const GroupApplicationDecisionCommand(
          groupId: 'group-1',
          targetPlayerId: 'players/player-2',
          expectedRelationRevision: 3,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateApplicationDecision(
        const GroupApplicationDecisionCommand(
          groupId: '',
          targetPlayerId: 'player-2',
          expectedRelationRevision: 3,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateApplicationDecision(
        const GroupApplicationDecisionCommand(
          groupId: 'group-1',
          targetPlayerId: 'player-2',
          expectedRelationRevision: 0,
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
  });

  test('금지 해제 명령은 revision 없이 대상 Player만 확인한다', () {
    expect(
      validator.validateBlockRelease(
        const GroupBlockReleaseCommand(
          groupId: 'group-1',
          targetPlayerId: 'player-2',
        ),
      ),
      isNull,
    );
    expect(
      validator.validateBlockRelease(
        const GroupBlockReleaseCommand(
          groupId: 'group-1',
          targetPlayerId: '  ',
        ),
      ),
      GroupJoinFailure.invalidRequest,
    );
  });

  test('초대 검색 입력은 공백·제어문자·과도한 길이를 거절한다', () {
    expect(validator.isValidCharacterNameQuery('초대대상'), isTrue);
    expect(validator.isValidCharacterNameQuery('  초대대상  '), isTrue);
    expect(validator.isValidCharacterNameQuery('   '), isFalse);
    expect(validator.isValidCharacterNameQuery('초대\n대상'), isFalse);
    expect(validator.isValidCharacterNameQuery('가' * 41), isFalse);
  });

  test('초대코드 생성·표시는 groupId만 확인하고 폐기는 코드 형식을 본다', () {
    expect(
      validator.validateJoinCodeCreate(
        const GroupJoinCodeCreateCommand(groupId: 'group-1'),
      ),
      isNull,
    );
    expect(
      validator.validateJoinCodeCreate(
        const GroupJoinCodeCreateCommand(groupId: 'groups/x'),
      ),
      GroupJoinFailure.invalidRequest,
    );
    expect(
      validator.validateJoinCodeRevoke(
        const GroupJoinCodeRevokeCommand(
          groupId: 'group-1',
          code: '23456789ABCDEFGHJKMN',
        ),
      ),
      isNull,
    );
    expect(
      validator.validateJoinCodeRevoke(
        const GroupJoinCodeRevokeCommand(groupId: 'group-1', code: 'bad'),
      ),
      GroupJoinFailure.joinCodeInvalid,
    );
    expect(
      validator.validateJoinByCode(
        const GroupJoinByCodeCommand(
          code: '23456789ABCDEFGHJKMN',
          characterId: 'character-1',
        ),
      ),
      isNull,
    );
    expect(
      validator.validateJoinByCode(
        const GroupJoinByCodeCommand(code: '0O1I', characterId: 'character-1'),
      ),
      GroupJoinFailure.joinCodeInvalid,
    );
  });
}
