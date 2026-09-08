import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/repositories/account_repository.dart';
import 'package:lost_party/features/group/domain/entities/group_create_command.dart';
import 'package:lost_party/features/group/domain/entities/group_create_result.dart';
import 'package:lost_party/features/group/domain/repositories/group_create_repository.dart';
import 'package:lost_party/features/group/presentation/pages/group_create_page.dart';
import 'package:lost_party/features/group/presentation/viewmodels/group_create_view_model.dart';

void main() {
  testWidgets('서버 소유권 연결이 사라진 그룹 생성 실패는 앱 데이터 초기화를 안내한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupCreatePage(
          viewModel: GroupCreateViewModel(
            accountRepository: _Accounts(),
            createRepository: _LostOwnershipGroupCreateRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('groupCreateSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('계정 정보를 확인해 주세요'), findsOneWidget);
    expect(
      find.textContaining('앱을 재설치하거나 앱 데이터를 삭제한 뒤'),
      findsOneWidget,
    );
  });
}

class _LostOwnershipGroupCreateRepository implements GroupCreateRepository {
  @override
  Future<GroupCreateResult> create(GroupCreateCommand command) async =>
      const GroupCreateResult.failure(GroupCreateFailure.ownershipLost);
}

class _Accounts extends Fake implements AccountRepository {
  @override
  Future<List<LocalGameAccount>> loadAccounts() async => const [
    LocalGameAccount(
      id: 1,
      label: '계정',
      isMain: true,
      lookupCharacterName: '대표',
      representativeCharacterId: 1,
      displayLimit: 1,
      serverOwnershipStatus: 'active',
      characters: [
        LocalAccountCharacter(
          id: 1,
          serverCharacterId: 'character-1',
          serverName: '루페온',
          characterName: '대표',
          characterLevel: 70,
          characterClassName: '바드',
          itemLevel: 1750,
          combatPower: 3100,
          isVisible: true,
          displayOrder: 0,
        ),
      ],
    ),
  ];
}
