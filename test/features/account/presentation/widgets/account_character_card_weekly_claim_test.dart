import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/presentation/models/weekly_raid_status_item.dart';
import 'package:lost_party/features/account/presentation/widgets/account_character_card.dart';

void main() {
  testWidgets('shows weekly claim state as a disabled checkbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 260,
            child: AccountCharacterCard(
              character: LocalAccountCharacter(
                id: 1,
                serverCharacterId: 'character-1',
                serverName: '루페온',
                characterName: '캐릭터',
                characterLevel: 70,
                characterClassName: '바드',
                itemLevel: 1760,
                combatPower: 1,
                isVisible: true,
                displayOrder: 0,
              ),
              isRepresentative: true,
              weeklyRaids: [
                WeeklyRaidStatusItem(
                  raidId: 'serca',
                  label: '세르카',
                  isCompleted: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(
      find.byKey(const ValueKey('weeklyRaidClaim-character-1-serca')),
    );
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNull);
    expect(find.text('주간 레이드 · 읽기 전용'), findsOneWidget);
  });
}
