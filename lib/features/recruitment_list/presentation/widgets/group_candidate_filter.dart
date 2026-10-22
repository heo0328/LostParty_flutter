import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/game_catalog/data/catalogs/class_synergy_catalog.dart';
import '../../../../shared/game_catalog/domain/entities/game_catalog.dart';
import '../../data/group_character_candidates.dart';
import '../viewmodels/cycle_search_view_model.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';

class GroupCandidateFilter extends StatelessWidget {
  const GroupCandidateFilter({required this.model, super.key});
  final CycleSearchViewModel model;
  String family(CandidateCharacter c) {
    final definition = const ClassSynergyCatalog().findClass(c.className ?? '');
    if (definition == null) return '계열 미상';
    return definition.supportedRoles.contains(GameCatalogRole.support)
        ? '딜러/서포터계열'
        : '딜러계열';
  }

  Widget line(String text, double size) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(text, maxLines: 1, style: TextStyle(fontSize: size)),
  );
  @override
  Widget build(BuildContext context) {
    final m = model, error = m.candidateFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('그룹원 · 대표 캐릭터', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: m.candidateLoading || m.groupLoading
                  ? null
                  : m.refreshCandidates,
              child: const Text('후보 새로고침', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
        if (m.candidateLoading) const LinearProgressIndicator(),
        if (error != null)
          Text(
            recruitmentFailureMessage(error),
            style: const TextStyle(fontSize: 11),
          ),
        if (m.selectionPending) ...[
          const Text('기존 선택 확인이 필요합니다.', style: TextStyle(fontSize: 11)),
          Wrap(
            children: [
              for (final entry in m.filter.members.entries)
                InputChip(
                  label: Text(
                    entry.value.isEmpty
                        ? '그룹원 전체 선택'
                        : '선택 ${entry.value.length}개',
                    style: const TextStyle(fontSize: 10),
                  ),
                  onDeleted: m.candidateLoading || m.groupLoading
                      ? null
                      : () => m.selectMember(entry.key, false),
                ),
            ],
          ),
        ],
        for (final member in m.candidateMembers) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: Text(
                member.representative ?? '대표 캐릭터 미설정',
                style: const TextStyle(fontSize: 10),
              ),
              selected: m.filter.members.containsKey(member.ref),
              onSelected: m.candidateLoading || m.groupLoading
                  ? null
                  : (v) => m.selectMember(member.ref, v),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (member.characters.isEmpty)
            const Text('활동 캐릭터가 없습니다.', style: TextStyle(fontSize: 10)),
          LayoutBuilder(
            builder: (context, bounds) => Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in member.characters)
                  SizedBox(
                    width: (bounds.maxWidth - 4) / 2,
                    child: Material(
                      color:
                          m.filter.members[member.ref]?.contains(c.id) == true
                          ? AppColors.primarySubtle
                          : Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                        side: BorderSide(
                          color:
                              m.filter.members[member.ref]?.contains(c.id) ==
                                  true
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: m.candidateLoading || m.groupLoading
                            ? null
                            : () => m.selectCharacter(member.ref, c.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              line(member.representative ?? '대표 캐릭터 미설정', 8),
                              line('${c.name} · ${c.className ?? '직업 미상'}', 10),
                              line(
                                '${family(c)} · Lv.${c.level?.split('.').first ?? '미상'}',
                                9,
                              ),
                              Tooltip(
                                message: '회원이 저장한 역할별 전투력입니다.',
                                child: line(
                                  '딜 ${c.dealer.label} · 서폿 ${c.support.label}',
                                  9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (member.toNext)
            const Text('이 그룹원의 캐릭터가 더 있습니다.', style: TextStyle(fontSize: 9)),
          const SizedBox(height: 6),
        ],
        if (m.candidateCursor != null)
          TextButton(
            onPressed: m.candidateLoading || m.groupLoading
                ? null
                : () => m.loadCandidates(more: true),
            child: const Text('캐릭터 더 보기', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}
