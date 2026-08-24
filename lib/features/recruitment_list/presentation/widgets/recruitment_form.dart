import 'package:flutter/material.dart';

import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../../shared/widgets/clearable_text_form_field.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/policies/approval_policy.dart';
import '../models/recruitment_form_draft.dart';

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
    this.selectedRole,
    this.roleOptions = const [],
    this.onRoleChanged,
    this.raidErrorText,
    super.key,
  });

  final TextEditingController titleController;
  final TextEditingController combatPowerController;
  final RecruitmentFormDraft draft;
  final List<EligibleRaidOption> raidOptions;
  final RaidDefinition selectedRaid;
  final RaidDifficultyDefinition selectedDifficulty;
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
  final PartyRole? selectedRole;
  final List<PartyRole> roleOptions;
  final ValueChanged<PartyRole>? onRoleChanged;
  final String? raidErrorText;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      ...beforeFields,
      ClearableTextFormField(
        fieldKey: const ValueKey('recruitmentTitleField'),
        controller: titleController,
        labelText: '모집 제목',
        border: const OutlineInputBorder(),
        onChanged: onTitleChanged,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<RaidDefinition>(
        key: ValueKey('raid-${selectedRaid.raidId}'),
        initialValue: raidOptions.any(
          (option) => option.raid.raidId == selectedRaid.raidId,
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
              child: Text(option.raid.displayName),
            ),
        ],
        onChanged: (value) {
          if (value != null) onRaidChanged(value);
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<RaidDifficultyDefinition>(
        key: ValueKey('difficulty-${selectedRaid.raidId}'),
        initialValue: _difficulties.any(
          (item) => item.difficultyId == selectedDifficulty.difficultyId,
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
              child: Text('${item.name} (${item.displayAlias})'),
            ),
        ],
        onChanged: (value) {
          if (value != null) onDifficultyChanged(value);
        },
      ),
      if (onRoleChanged != null) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<PartyRole>(
          initialValue: roleOptions.contains(selectedRole) ? selectedRole : null,
          decoration: const InputDecoration(
            labelText: '파티장 역할',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final role in roleOptions)
              DropdownMenuItem(value: role, child: Text(_roleLabel(role))),
          ],
          onChanged: (value) {
            if (value != null) onRoleChanged!(value);
          },
        ),
      ],
      const SizedBox(height: 16),
      ClearableTextFormField(
        fieldKey: const ValueKey('minCombatPowerField'),
        controller: combatPowerController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        labelText: '최소 전투력',
        border: const OutlineInputBorder(),
        validator: _validateCombatPower,
        onChanged: onCombatPowerChanged,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<ExperienceLevel?>(
        initialValue: draft.experienceLevel,
        decoration: const InputDecoration(
          labelText: '숙련도',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('제한 없음')),
          DropdownMenuItem(value: ExperienceLevel.tryLevel, child: Text('트라이')),
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
      const SizedBox(height: 16),
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
      const SizedBox(height: 24),
      FilledButton(
        key: const ValueKey('saveRecruitmentButton'),
        onPressed: submitting ? null : onSubmit,
        child: Text(submitting ? '저장 중...' : submitLabel),
      ),
    ],
  );

  List<RaidDifficultyDefinition> get _difficulties => raidOptions
      .where((option) => option.raid.raidId == selectedRaid.raidId)
      .expand((option) => option.difficulties)
      .toList(growable: false);

  static String? _validateCombatPower(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = num.tryParse(value.replaceAll(',', ''));
    return parsed != null && parsed >= 0 ? null : '0 이상의 전투력을 입력해주세요.';
  }

  static String _roleLabel(PartyRole role) =>
      role == PartyRole.support ? '서포터' : '딜러';
}
