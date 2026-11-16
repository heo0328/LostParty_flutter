import 'package:flutter/material.dart';
import '../../domain/entities/local_game_account.dart';
import '../models/weekly_raid_status_item.dart';
import 'account_overview_frame.dart';
import 'account_character_card.dart';
import 'account_responsive_layout.dart';
import 'roster_account_header.dart';

/// Fixed presentation data. Does not construct a member, VM, store or client.
class AccountExample extends StatefulWidget {
  const AccountExample({
    super.key,
    required this.authActions,
    required this.onSettings,
    required this.onLogin,
  });
  final Widget authActions;
  final VoidCallback onSettings, onLogin;
  @override
  State<AccountExample> createState() => _AccountExampleState();
}

class _AccountExampleState extends State<AccountExample> {
  bool next = false;
  @override
  Widget build(BuildContext context) => AccountOverviewFrame(
    authActions: widget.authActions,
    onSettings: widget.onSettings,
    children: [
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '예시 데이터 · 실제 계정이나 예약이 아닙니다.\n로그인하면 내 원정대·캐릭터·가능 시간과 레이드 참여를 관리할 수 있습니다.',
          ),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('가능 시간·예약 예시'),
              const Text('수요일 20:00~23:00 · 금요일 19:00~23:00'),
              ExpansionTile(
                title: const Text('예약 예시 보기'),
                children: const [
                  ListTile(
                    title: Text('금요일 20:00~21:00'),
                    subtitle: Text('예시 레이드 · 예시 딜러'),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: widget.onLogin,
                child: const Text('내 가능 시간 설정'),
              ),
            ],
          ),
        ),
      ),
      RosterAccountHeader(
        label: '예시 원정대',
        onCharacters: widget.onLogin,
        onEdit: widget.onLogin,
        onVerify: widget.onLogin,
      ),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('이번 주 예시')),
          ButtonSegment(value: true, label: Text('다음 주 예시')),
        ],
        selected: {next},
        onSelectionChanged: (v) => setState(() => next = v.single),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 720 ? 2 : 1;
          final width = (box.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < 2; i++)
                SizedBox(
                  width: width.clamp(0, AccountResponsiveLayout.pageMaxWidth),
                  child: AccountCharacterCard(
                    character: LocalAccountCharacter(
                      id: i,
                      serverName: '예시 서버',
                      characterName: i == 0 ? '예시 딜러' : '예시 서포터',
                      characterLevel: 70,
                      characterClassName: i == 0 ? '버서커' : '바드',
                      itemLevel: 1700,
                      combatPower: i == 0 ? 1500 : 1400,
                      isVisible: true,
                      displayOrder: i,
                    ),
                    isRepresentative: i == 0,
                    readable: true,
                    memberWeeklyLayout: true,
                    roleLabel: i == 0 ? '딜러' : '서포터',
                    weeklyRaids: [
                      WeeklyRaidStatusItem(
                        raidId: 'example',
                        difficultyId: 'example',
                        label: '예시 레이드',
                        isCompleted: !next && i == 0,
                        toggleAllowed: false,
                        statusOverride: '예시 기록',
                      ),
                    ],
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('캐릭터 정보 예시'),
                        content: const Text(
                          '등록한 캐릭터의 역할별 전투력과 보석·아크패시브·아크그리드 정보를 확인할 수 있습니다.',
                        ),
                        actions: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: widget.onLogin,
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('원정대 등록·관리'),
        ),
      ),
    ],
  );
}
