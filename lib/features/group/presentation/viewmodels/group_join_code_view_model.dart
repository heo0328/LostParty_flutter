import '../../../account/domain/repositories/account_repository.dart';
import '../../domain/entities/group_join_code_command.dart';
import '../../domain/entities/group_join_command.dart';
import '../../domain/repositories/group_join_code_command_repository.dart';
import '../../domain/repositories/group_read_repository.dart';
import 'group_character_options.dart';
import 'group_join_view_model.dart';

/// 초대코드 전용 실패 안내. 공통 가입 실패는 [groupJoinFailureMessage]를 재사용한다.
String groupJoinCodeFailureMessage(GroupJoinFailure failure) =>
    groupJoinFailureMessage(failure);

/// 계약 §7. 그룹장이 코드를 만들고 복사·폐기·표시 정책을 관리한다.
///
/// 생성 직후 코드는 ViewModel 메모리에만 둔다. 앱을 다시 열면 원문이 보이지
/// 않는다. 기간 만료가 아니므로 복사해 둔 코드를 다시 입력해야 폐기할 수 있다.
class GroupJoinCodeManageViewModel {
  GroupJoinCodeManageViewModel({
    required this.readRepository,
    required this.commandRepository,
  });

  final GroupReadRepository readRepository;
  final GroupJoinCodeCommandRepository commandRepository;

  /// groupId → 이 세션에서 생성한 정규화 코드.
  final Map<String, String> _codesByGroupId = {};

  String? rememberedCode(String groupId) => _codesByGroupId[groupId];

  Future<GroupJoinCodeCommandResult> createCode(String groupId) async {
    final result = await commandRepository.createCode(
      GroupJoinCodeCreateCommand(groupId: groupId),
    );
    final code = result.code;
    if (result.isSuccess && code != null) {
      _codesByGroupId[groupId] = code.value;
    }
    return result;
  }

  Future<GroupJoinCodeCommandResult> revokeCode({
    required String groupId,
    required String code,
  }) async {
    final result = await commandRepository.revokeCode(
      GroupJoinCodeRevokeCommand(groupId: groupId, code: code),
    );
    if (result.isSuccess) {
      _codesByGroupId.remove(groupId);
    }
    return result;
  }

  Future<GroupJoinCodeCommandResult> setVisibility({
    required String groupId,
    required bool visibleToMembers,
  }) => commandRepository.setVisibility(
    GroupJoinCodeVisibilityCommand(
      groupId: groupId,
      visibleToMembers: visibleToMembers,
    ),
  );
}

/// 계약 §8.7. 정확한 코드와 인증 Character로 즉시 가입한다.
class GroupJoinByCodeViewModel {
  const GroupJoinByCodeViewModel({
    required this.accountRepository,
    required this.commandRepository,
  });

  final AccountRepository accountRepository;
  final GroupJoinCodeCommandRepository commandRepository;

  Future<List<GroupCharacterOption>> loadAuthenticatedCharacters() =>
      GroupCharacterOptionLoader(accountRepository: accountRepository).load();

  Future<GroupJoinCodeCommandResult> join({
    required String code,
    required GroupCharacterOption character,
  }) => commandRepository.joinByCode(
    GroupJoinByCodeCommand(
      code: code,
      characterId: character.serverCharacterId,
    ),
  );
}
