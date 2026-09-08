import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/entities/local_game_account.dart';
import 'package:lost_party/features/account/domain/entities/character_build_analysis.dart';
import 'package:lost_party/features/account/presentation/models/weekly_raid_status_item.dart';
import 'package:lost_party/features/account/presentation/widgets/account_character_card.dart';

void main() {
  testWidgets('shows only foreign gems as a red account-card warning', (
    tester,
  ) async {
    const summary = GemValidationSummary(
      totalCount: 11,
      verifiedCount: 10,
      unverifiedSameClassCount: 0,
      foreignClassCount: 1,
      unavailableCount: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountCharacterCard(
            character: _character,
            isRepresentative: false,
            gemValidationSummary: summary,
          ),
        ),
      ),
    );

    expect(find.text('다른 직업 보석 1개 · 확인 필요'), findsOneWidget);
    final text = tester.widget<Text>(find.text('다른 직업 보석 1개 · 확인 필요'));
    final context = tester.element(find.byType(AccountCharacterCard));
    expect(text.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('shows same-class unverified gems as neutral information', (
    tester,
  ) async {
    const summary = GemValidationSummary(
      totalCount: 11,
      verifiedCount: 10,
      unverifiedSameClassCount: 1,
      foreignClassCount: 0,
      unavailableCount: 0,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountCharacterCard(
            character: _character,
            isRepresentative: false,
            gemValidationSummary: summary,
          ),
        ),
      ),
    );

    expect(find.text('동일 직업 보석 · 현재 스킬에서 미확인 1개'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

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
                  difficultyId: 'hard',
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
    expect(find.text('주간 레이드'), findsOneWidget);
  });

  testWidgets('enables a weekly claim checkbox when a command is connected', (
    tester,
  ) async {
    WeeklyRaidStatusItem? changedRaid;
    bool? changedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 260,
            child: AccountCharacterCard(
              character: const LocalAccountCharacter(
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
              weeklyRaids: const [
                WeeklyRaidStatusItem(
                  raidId: 'serca',
                  difficultyId: 'hard',
                  label: '세르카',
                  isCompleted: false,
                ),
              ],
              onWeeklyRaidChanged: (raid, value) {
                changedRaid = raid;
                changedValue = value;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('weeklyRaidClaim-character-1-serca')),
    );

    expect(changedRaid?.raidId, 'serca');
    expect(changedValue, isTrue);
  });
}

const _character = LocalAccountCharacter(
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
);
