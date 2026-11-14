import 'package:flutter/material.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/scoped_cache_models.dart';
import '../viewmodels/member_weekly_view_model.dart';

Future<void> editMemberRosterWeeklyDisplay(
  BuildContext context,
  MemberWeeklyViewModel model,
  String id,
) async {
  if (!model.canEditRosterDisplay(id)) return;
  final member = accountReadScope(model.model.runtime.session);
  final token = model.rosterDisplayToken(id)!;
  final choices = model.rosterDisplaySelection(id);
  final result = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('원정대 주간 레이드 표시'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('체크한 종류로 전체 캐릭터에 적용합니다. 일부만 선택된 항목은 체크해야 포함됩니다.'),
                for (final raid in model.catalog!.raids.where(
                  (r) => r.isActive,
                ))
                  CheckboxListTile(
                    title: Text(raid.displayName),
                    contentPadding: EdgeInsets.zero,
                    tristate: true,
                    value: choices[raid.raidId],
                    onChanged: (_) => set(
                      () => choices[raid.raidId] = choices[raid.raidId] != true,
                    ),
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
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              choices.entries
                  .where((e) => e.value == true)
                  .map((e) => e.key)
                  .toList(),
            ),
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
    if (context.mounted) _changed(context);
    return;
  }
  await model.saveRosterDisplay(id, result, token);
}

void _changed(BuildContext context) => ScaffoldMessenger.of(
  context,
).showSnackBar(const SnackBar(content: Text('정보가 변경됐습니다. 다시 선택해 주세요.')));

Future<void> editMemberWeeklyDisplay(
  BuildContext context,
  MemberWeeklyViewModel model,
  ScopedCharacterRef ref,
) async {
  if (!model.canEditDisplay(ref)) return;
  final member = accountReadScope(model.model.runtime.session);
  final token = model.displayToken(ref);
  final eligible = model.eligible(ref);
  final preference = model.preference(ref.characterId);
  final selected = model.selectedDisplayIds(ref).toSet();
  final eligibleIds = eligible.map((c) => c.raidId).toSet();
  final retained = selected.difference(eligibleIds);
  final result = await showDialog<({bool reset, List<String> raids})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('표기 레이드 설정'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eligible.isEmpty) const Text('입장 가능한 주간 레이드가 없습니다.'),
                if (retained.isNotEmpty)
                  const Text('현재 입장할 수 없는 레이드의 기존 선택은 유지됩니다.'),
                for (final c in eligible)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.label),
                    subtitle: Text(
                      '${c.difficulty.displayName} · 클리어 골드 ${DisplayNumberFormatter.integer(c.gold)}',
                    ),
                    value: selected.contains(c.raidId),
                    onChanged: (checked) => set(() {
                      if (checked == true) {
                        selected.add(c.raidId);
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
                  Navigator.pop(ctx, (reset: true, raids: <String>[])),
              child: const Text('기본값'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, (reset: false, raids: selected.toList())),
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
  if (model.displayToken(ref) != token) {
    if (context.mounted) _changed(context);
    return;
  }
  await model.saveDisplay(
    ref,
    result.reset
        ? null
        : CharacterWeeklyRaidDisplayPreference(
            characterId: 0,
            displayCount: result.raids.length,
            raidIds: result.raids,
          ),
  );
}
