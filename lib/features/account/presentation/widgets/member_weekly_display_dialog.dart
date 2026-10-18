import 'package:flutter/material.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/services/weekly_raid_display_projector.dart';
import '../viewmodels/member_weekly_view_model.dart';

Future<void> editMemberRosterWeeklyDisplay(
  BuildContext context,
  MemberWeeklyViewModel model,
  String id,
) async {
  if (!model.canEditRosterDisplay(id)) return;
  final member = accountReadScope(model.model.runtime.session);
  final token = model.rosterDisplayToken(id)!;
  var count = WeeklyRaidDisplayProjector.defaultDisplayCount;
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('원정대 주간 레이드 표시'),
        content: Wrap(
          spacing: 8,
          children: [
            for (
              var n = 0;
              n <= WeeklyRaidDisplayProjector.maxDisplayCount;
              n++
            )
              ChoiceChip(
                label: Text('$n'),
                selected: count == n,
                onSelected: (_) => set(() => count = n),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, count),
            child: const Text('적용'),
          ),
        ],
      ),
    ),
  );
  if (result == null ||
      !model.model.signedIn ||
      accountReadScope(model.model.runtime.session) != member) {
    return;
  }
  if (model.rosterDisplayToken(id) != token) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('정보가 변경됐습니다. 다시 선택해 주세요.')));
    }
    return;
  }
  await model.saveRosterDisplay(id, result, token);
}

/// Reuses the existing 0..5 count/raid selection flow; this is a device setting,
/// independent of the server's weekly completion ledger.
Future<void> editMemberWeeklyDisplay(
  BuildContext context,
  MemberWeeklyViewModel model,
  ScopedCharacterRef ref,
) async {
  if (!model.canEditDisplay(ref)) return;
  final member = accountReadScope(model.model.runtime.session);
  final eligible = model.eligible(ref);
  if (eligible.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('입장 가능한 주간 레이드가 없습니다.')));
    return;
  }
  final preference = model.preference(ref.characterId);
  final maxCount = eligible.length.clamp(
    0,
    WeeklyRaidDisplayProjector.maxDisplayCount,
  );
  var count =
      (preference?.displayCount ??
              WeeklyRaidDisplayProjector.defaultDisplayCount)
          .clamp(0, maxCount);
  final selected = model.displayed(ref).map((c) => c.raidId).toSet();
  final result = await showDialog<({int count, List<String> raids})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('표기 레이드 설정'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('표시 개수'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var n = 0; n <= maxCount; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: count == n,
                        onSelected: (_) => set(() {
                          count = n;
                          while (selected.length > count) {
                            selected.remove(selected.last);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(count == 0 ? '표시할 레이드를 숨깁니다.' : '레이드를 $count개 선택하세요.'),
                if (count > 0)
                  for (final c in eligible)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.label),
                      subtitle: Text(
                        '입장 ${DisplayNumberFormatter.whole(c.minItemLevel.toString())} · 골드 ${DisplayNumberFormatter.integer(c.gold)}',
                      ),
                      value: selected.contains(c.raidId),
                      onChanged: (checked) => set(() {
                        if (checked == true) {
                          if (selected.length < count) selected.add(c.raidId);
                        } else {
                          selected.remove(c.raidId);
                        }
                      }),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          if (preference != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, (count: -1, raids: <String>[])),
              child: const Text('기본값'),
            ),
          FilledButton(
            onPressed: selected.length == count
                ? () => Navigator.pop(ctx, (
                    count: count,
                    raids: [
                      for (final c in eligible)
                        if (selected.contains(c.raidId)) c.raidId,
                    ],
                  ))
                : null,
            child: const Text('저장'),
          ),
        ],
      ),
    ),
  );
  if (result == null ||
      !model.model.signedIn ||
      accountReadScope(model.model.runtime.session) != member ||
      !model.canEditDisplay(ref)) {
    return;
  }
  await model.saveDisplay(
    ref,
    result.count < 0
        ? null
        : CharacterWeeklyRaidDisplayPreference(
            characterId: 0,
            displayCount: result.count,
            raidIds: result.raids,
          ),
  );
}
