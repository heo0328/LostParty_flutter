import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/group/domain/entities/group_join_code.dart';
import 'package:lost_party/features/group/domain/entities/group_join_command.dart';
import 'package:lost_party/features/group/domain/entities/group_join_code_command.dart';
import 'package:lost_party/features/group/domain/entities/group_member.dart';
import 'package:lost_party/features/group/domain/entities/group_summary.dart';
import 'package:lost_party/features/group/domain/repositories/group_application_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_join_code_command_repository.dart';
import 'package:lost_party/features/group/domain/repositories/group_read_repository.dart';
import 'package:lost_party/features/group/presentation/pages/group_join_code_page.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_application_view_model.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_join_code_view_model.dart';

final _now = DateTime(2026, 9, 1);

GroupPublicSummary _group({
  required bool hasActiveJoinCode,
  String? activeJoinCode,
}) => GroupPublicSummary(
  groupId: 'group-1',
  name: '그룹',
  status: GroupStatus.active,
  representativeCharacterNameSnapshot: '대표캐릭터',
  representativeServerNameSnapshot: '서버',
  leaderDisplayCharacterNameSnapshot: '대표캐릭터',
  memberCount: 1,
  revision: 1,
  hasActiveJoinCode: hasActiveJoinCode,
  activeJoinCode: activeJoinCode,
  joinCodeVisibleToMembers: false,
  createdAt: _now,
  lastActivityAt: _now,
);

class _Reads extends Fake implements GroupReadRepository {
  _Reads(this.group);

  final GroupPublicSummary group;

  @override
  Future<GroupPublicSummary?> loadGroup(String groupId) async => group;

  @override
  Future<GroupMember?> loadGroupMember({
    required String groupId,
    required String playerId,
  }) async => GroupMember(
    groupId: groupId,
    playerId: playerId,
    role: GroupMemberRole.leader,
    joinedAt: _now,
    joinSequence: 1,
    joinedBy: GroupJoinedBy.created,
    displayCharacterIdSnapshot: 'character-1',
    displayCharacterNameSnapshot: '대표캐릭터',
    revision: 1,
  );
}

class _Codes extends Fake implements GroupJoinCodeCommandRepository {
  _Codes({this.createdCode});

  final GroupJoinCode? createdCode;
  var revokeCalls = 0;

  @override
  Future<GroupJoinCodeCommandResult> createCode(
    GroupJoinCodeCreateCommand command,
  ) async {
    final code = createdCode;
    if (code == null) {
      return const GroupJoinCodeCommandResult.failure(GroupJoinFailure.unknown);
    }
    return GroupJoinCodeCommandResult.success(code: code);
  }

  @override
  Future<GroupJoinCodeCommandResult> revokeCode(
    GroupJoinCodeRevokeCommand command,
  ) async {
    revokeCalls++;
    return const GroupJoinCodeCommandResult.success();
  }
}

class _Apps extends Fake implements GroupApplicationCommandRepository {}

Widget _page({
  required GroupPublicSummary group,
  required GroupJoinCodeManageViewModel viewModel,
}) {
  final reads = _Reads(group);
  return MaterialApp(
    home: GroupJoinCodePage(
      groupId: group.groupId,
      playerId: 'player-1',
      readRepository: reads,
      viewModel: viewModel,
      leadershipViewModel: GroupApplicationsViewModel(
        readRepository: reads,
        commandRepository: _Apps(),
      ),
    ),
  );
}

void main() {
  testWidgets('앱을 다시 열어도 그룹에 저장된 활성 코드를 표시한다', (tester) async {
    await tester.pumpWidget(
      _page(
        group: _group(hasActiveJoinCode: true, activeJoinCode: '234567'),
        viewModel: GroupJoinCodeManageViewModel(
          readRepository: _Reads(_group(hasActiveJoinCode: true)),
          commandRepository: _Codes(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('groupJoinCodeStatus')), findsOneWidget);
    expect(find.textContaining('기간이 지나 만료되지 않으며'), findsOneWidget);
    expect(find.byKey(const ValueKey('groupJoinCodeValue')), findsOneWidget);
    expect(find.text('234567'), findsOneWidget);
  });

  testWidgets('세션에 원문이 있으면 코드를 보여 준다', (tester) async {
    const remembered = '234567';
    final codes = _Codes(createdCode: GroupJoinCode.tryParse(remembered));
    final viewModel = GroupJoinCodeManageViewModel(
      readRepository: _Reads(_group(hasActiveJoinCode: true)),
      commandRepository: codes,
    );
    await viewModel.createCode('group-1');

    await tester.pumpWidget(
      _page(group: _group(hasActiveJoinCode: true), viewModel: viewModel),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('groupJoinCodeValue')), findsOneWidget);
    expect(find.text(remembered), findsOneWidget);
  });

  testWidgets('코드 재입력 없이 확인만으로 활성 코드를 폐기한다', (tester) async {
    final codes = _Codes();
    await tester.pumpWidget(
      _page(
        group: _group(hasActiveJoinCode: true, activeJoinCode: '234567'),
        viewModel: GroupJoinCodeManageViewModel(
          readRepository: _Reads(_group(hasActiveJoinCode: true)),
          commandRepository: codes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('groupJoinCodeRevokeButton')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('groupJoinCodeRevokeField')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('groupJoinCodeRevokeConfirm')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(codes.revokeCalls, 1);
  });
}
