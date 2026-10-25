import 'package:flutter/material.dart';
import 'recruitment_design.dart';
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
    final m = model, disabled = m.candidateLoading || m.groupLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: disabled ? null : m.refreshCandidates,
            child: const Text('후보 새로고침', style: TextStyle(fontSize: 11)),
          ),
        ),
        if (m.candidateLoading) const LinearProgressIndicator(),
        if (m.candidateFailure != null)
          Text(
            recruitmentFailureMessage(m.candidateFailure),
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
        if (m.selectionPending) ...[
          const Text('기존 선택 확인이 필요합니다.', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in m.filter.members.entries)
                TextButton(
                  onPressed: disabled
                      ? null
                      : () => m.selectMember(entry.key, false),
                  child: Text(
                    '${entry.value.isEmpty ? '그룹원 전체' : '캐릭터 ${entry.value.length}개'} 선택 해제',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],
        for (final member in m.candidateMembers)
          RecruitmentDesignCard(
            padding: 12,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: disabled
                      ? null
                      : () => m.selectMember(
                          member.ref,
                          !m.filter.members.containsKey(member.ref),
                        ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.representative ?? '대표 캐릭터 미설정',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (m.filter.members.containsKey(member.ref))
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (member.characters.isEmpty)
                  const Text('활동 캐릭터가 없습니다.', style: TextStyle(fontSize: 11)),
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      for (final c in member.characters)
                        SizedBox(
                          width: (box.maxWidth - 8) / 2,
                          child: Material(
                            color:
                                m.filter.members[member.ref]?.isEmpty == true ||
                                    m.filter.members[member.ref]?.contains(
                                          c.id,
                                        ) ==
                                        true
                                ? recruitmentSelectionFill
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: disabled
                                  ? null
                                  : () => m.selectCharacter(member.ref, c.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    line(
                                      member.representative ?? '대표 캐릭터 미설정',
                                      8,
                                    ),
                                    const SizedBox(height: 5),
                                    line(
                                      '${c.name} · ${c.className ?? '직업 미상'}',
                                      10,
                                    ),
                                    const SizedBox(height: 5),
                                    line(
                                      '${family(c)} · Lv.${c.level?.split('.').first ?? '미상'}',
                                      9,
                                    ),
                                    const SizedBox(height: 3),
                                    line(
                                      '딜 ${c.dealer.label} · 서폿 ${c.support.label}',
                                      9,
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
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '이 그룹원의 캐릭터가 더 있습니다.',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        if (m.candidateCursor != null)
          RecruitmentPrimaryButton(
            label: '캐릭터 더 보기',
            secondary: true,
            onPressed: disabled ? null : () => m.loadCandidates(more: true),
          ),
      ],
    );
  }
}
