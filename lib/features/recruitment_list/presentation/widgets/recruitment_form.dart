import 'package:flutter/material.dart';

import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../../shared/widgets/clearable_text_form_field.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/approval_policy.dart';
import '../models/recruitment_form_draft.dart';

/// 모집 폼 항목 사이 세로 간격. 기존 16에 5를 더해 답답함을 줄인다.
const double recruitmentFormFieldGap = 21;

class RecruitmentFormPairRow extends StatelessWidget {
  const RecruitmentFormPairRow({
    required this.start,
    required this.end,
    this.startFlex = 1,
    this.endFlex = 1,
    this.wrapBelow = 300,
    super.key,
  });

  final Widget start;
  final Widget end;
  final int startFlex;
  final int endFlex;
  final double wrapBelow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wrapWidth =
          wrapBelow * MediaQuery.textScalerOf(context).scale(1);
      if (constraints.maxWidth < wrapWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            start,
            const SizedBox(height: recruitmentFormFieldGap),
            end,
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: startFlex, child: start),
            const SizedBox(width: 12),
            Expanded(flex: endFlex, child: end),
          ],
        ),
      );
    },
  );
}

class RecruitmentForm extends StatelessWidget {
  const RecruitmentForm({
    required this.titleController,
    required this.combatPowerController,
    required this.draft,
    required this.raidOptions,
    required this.selectedRaid,
    required this.selectedDifficulty,
    required this.onTitleChanged,
    required this.onRaidChanged,
    required this.onDifficultyChanged,
    required this.onCombatPowerChanged,
    required this.onExperienceChanged,
    required this.onApprovalChanged,
    required this.onSubmit,
    required this.submitLabel,
    required this.submitting,
    this.beforeFields = const [],
    this.raidErrorText,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController combatPowerController;
  final RecruitmentFormDraft draft;
  final List<EligibleRaidOption> raidOptions;
  final RaidDefinition? selectedRaid;
  final RaidDifficultyDefinition? selectedDifficulty;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<RaidDefinition> onRaidChanged;
  final ValueChanged<RaidDifficultyDefinition> onDifficultyChanged;
  final ValueChanged<String> onCombatPowerChanged;
  final ValueChanged<ExperienceLevel?> onExperienceChanged;
  final ValueChanged<ApprovalMode> onApprovalChanged;
  final VoidCallback? onSubmit;
  final String submitLabel;
  final bool submitting;
  final List<Widget> beforeFields;
  final String? raidErrorText;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 21, 16, 21),
    children: [
      ...beforeFields,
      ClearableTextFormField(
        fieldKey: const ValueKey('recruitmentTitleField'),
        controller: titleController,
        labelText: '모집 제목',
        border: const OutlineInputBorder(),
        onChanged: onTitleChanged,
      ),
      const SizedBox(height: recruitmentFormFieldGap),
      RecruitmentFormPairRow(
        key: const ValueKey('raidDifficultyRow'),
        start: DropdownButtonFormField<RaidDefinition>(
          key: ValueKey('raid-${selectedRaid?.raidId ?? 'none'}'),
          isExpanded: true,
          hint: const Text('레이드 선택'),
          initialValue: raidOptions.any(
            (option) => option.raid.raidId == selectedRaid?.raidId,
          )
              ? selectedRaid
              : null,
          decoration: InputDecoration(
            labelText: '레이드',
            border: const OutlineInputBorder(),
            errorText: raidErrorText,
          ),
          items: [
            for (final option in raidOptions)
              DropdownMenuItem(
                key: ValueKey('raidOption-${option.raid.raidId}'),
                value: option.raid,
                child: Text(
                  option.raid.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onRaidChanged(value);
          },
        ),
        end: DropdownButtonFormField<RaidDifficultyDefinition>(
          key: ValueKey('difficulty-${selectedRaid?.raidId ?? 'none'}'),
          isExpanded: true,
          hint: Text(selectedRaid == null ? '레이드 먼저 선택' : '난이도 선택'),
          initialValue: _difficulties.any(
            (item) => item.difficultyId == selectedDifficulty?.difficultyId,
          )
              ? selectedDifficulty
              : null,
          decoration: const InputDecoration(
            labelText: '난이도',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final item in _difficulties)
              DropdownMenuItem(
                value: item,
                child: Text(
                  '${item.name} (${item.displayAlias})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onDifficultyChanged(value);
          },
        ),
      ),
      const SizedBox(height: recruitmentFormFieldGap),
      RecruitmentFormPairRow(
        key: const ValueKey('combatExperienceRow'),
        start: ClearableTextFormField(
          fieldKey: const ValueKey('minCombatPowerField'),
          controller: combatPowerController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          labelText: '최소 전투력',
          border: const OutlineInputBorder(),
          validator: _validateCombatPower,
          onChanged: onCombatPowerChanged,
        ),
        end: DropdownButtonFormField<ExperienceLevel?>(
          isExpanded: true,
          initialValue: draft.experienceLevel,
          decoration: const InputDecoration(
            labelText: '숙련도',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('제한 없음')),
            DropdownMenuItem(
              value: ExperienceLevel.tryLevel,
              child: Text('트라이'),
            ),
            DropdownMenuItem(value: ExperienceLevel.clearExp, child: Text('클경')),
            DropdownMenuItem(
              value: ExperienceLevel.multiClearExp,
              child: Text('다클경'),
            ),
            DropdownMenuItem(
              value: ExperienceLevel.semiExperienced,
              child: Text('반숙'),
            ),
            DropdownMenuItem(
              value: ExperienceLevel.experienced,
              child: Text('숙련'),
            ),
          ],
          onChanged: onExperienceChanged,
        ),
      ),
      const SizedBox(height: recruitmentFormFieldGap),
      DropdownButtonFormField<ApprovalMode>(
        initialValue: draft.approvalMode,
        decoration: const InputDecoration(
          labelText: '가입 승인',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(
            value: ApprovalMode.leaderOnly,
            child: Text('파티장 승인'),
          ),
          DropdownMenuItem(
            value: ApprovalMode.directJoin,
            child: Text('승인 없이 바로 가입'),
          ),
        ],
        onChanged: (value) {
          if (value != null) onApprovalChanged(value);
        },
      ),
      const SizedBox(height: recruitmentFormFieldGap + 8),
      FilledButton(
        key: const ValueKey('saveRecruitmentButton'),
        onPressed: submitting ? null : onSubmit,
        child: Text(submitting ? '저장 중...' : submitLabel),
      ),
    ],
  );

  List<RaidDifficultyDefinition> get _difficulties => raidOptions
      .where((option) => option.raid.raidId == selectedRaid?.raidId)
      .expand((option) => option.difficulties)
      .toList(growable: false);

  static String? _validateCombatPower(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = num.tryParse(value.replaceAll(',', ''));
    return parsed != null && parsed >= 0 ? null : '0 이상의 전투력을 입력해주세요.';
  }
}
