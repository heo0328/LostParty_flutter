import '../../../../shared/formatters/display_number_formatter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';

import '../../data/repositories/scoped_settings_repository.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/role_summary.dart';
import '../../domain/account_read_session.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/scoped_startup_refresh.dart';
import '../../domain/services/character_build_role_policy.dart';
import '../viewmodels/member_account_view_model.dart';
import '../viewmodels/member_settings_view_model.dart';
import '../viewmodels/member_weekly_view_model.dart';
import '../models/weekly_raid_status_item.dart';
import '../widgets/member_weekly_display_dialog.dart';
import '../widgets/member_settings_controls.dart';
import '../widgets/representative_crown.dart';
import '../widgets/account_character_card.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/services/weekly_raid_display_projector.dart';
import '../widgets/roster_account_header.dart';
import '../widgets/server_accounts_panel.dart';
import '../../domain/policies/account_label_policy.dart';

String memberAccountFailure(String? code) => switch (code) {
  'SETTINGS_NOT_READY' => '회원 설정을 확인해 주세요.',
  'KEY_NOT_READY' || 'KEY_CHANGED' => '개인 API 키를 등록하거나 복원해 주세요.',
  'RATE_LIMITED' => '호출 한도 대기 중입니다. 남은 시간 뒤 다시 시도해 주세요.',
  'ACCOUNT_CHANGE_PENDING' ||
  'ACCOUNT_OBSERVATION_CHANGED' => '원정대 변경 확인 후 다시 시도해 주세요.',
  'REVISION_CONFLICT' ||
  'CACHE_CONFLICT' ||
  'IDENTITY_CONFLICT' => '다른 변경이 확인됐습니다. 현재 서버 정보를 확인해 주세요.',
  'REPRESENTATIVE_UNCERTAIN' => '대표 변경 결과 확인이 필요합니다.',
  'NICE_GROUP_OFF' => '나이스단 OFF로 자동 검사 제외',
  'CHARACTER_UNUSABLE' || 'NO_LONGER_ACTIVE' => '현재 활동 캐릭터로 사용할 수 없어 제외',
  'RUN_CANCELLED' => '작업 중단 · 미완료만 다시 시도할 수 있습니다.',
  null => '',
  _ => '정보를 확인하거나 저장하지 못했습니다. 기존 정보는 보존됩니다.',
};
String roleLabel(CharacterBuildRole role) =>
    role == CharacterBuildRole.dealer ? '딜러' : '서포터';
CharacterBuildRole memberDisplayRole(MemberCharacterState row) {
  final className =
      (jsonDecode(row.observation.profileJson) as Map)['class_name']
          as String? ??
      '';
  final fixed = const CharacterBuildRolePolicy().fixedRole(className);
  return fixed ??
      row.preferences?.preferences.preferredRole ??
      (row.support?.displaySummary != null && row.dealer?.displaySummary == null
          ? CharacterBuildRole.support
          : CharacterBuildRole.dealer);
}

String memberPresentationToken(MemberAccountSection section) => jsonEncode([
  section.registration.version,
  section.registration.settings.version,
  section.registration.ownershipRevision,
  section.registration.rosterRevision,
  section.presentation?.displayValues,
  for (final c in section.characters)
    [c.ref.characterId, c.preferences?.displayValues],
]);

String integrityLabel(RoleSummary? summary) =>
    switch (summary?.integrity.name) {
      'clean' => '확인된 경고 없음',
      'review' => '확인 필요',
      'error' => '세팅 오류',
      'unavailable' => '확인 불가',
      _ => '저장된 정보 없음',
    };

Future<bool> _confirmServer(
  BuildContext context,
  MemberAccountViewModel model,
) async {
  final member = accountReadScope(model.runtime.session);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('서버 정보를 유지할까요?'),
      content: const Text(
        '이 기기의 미완료 변경 대신 현재 서버 정보를 사용합니다. 처리 중이던 요청은 나중에 반영될 수 있습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('서버 정보 사용'),
        ),
      ],
    ),
  );
  return confirmed == true && _sameMember(model, member);
}

bool _sameMember(MemberAccountViewModel model, AccountReadScope member) =>
    !model.runtime.disposed &&
    model.runtime.session.isAuthenticated &&
    model.runtime.session.userId == member.userId &&
    model.runtime.session.generation == member.generation;
Widget memberPendingSettings(
  BuildContext context,
  MemberAccountViewModel model,
  ScopedRegistrationRef reg,
  ScopedSettingsState state, {
  ScopedCharacterRef? ref,
}) {
  final cmd = state.command;
  final now = model.runner.source.cooldown.now();
  final seconds = cmd?.retryAt == null
      ? 0
      : (cmd!.retryAt!.difference(now).inMilliseconds / 1000).ceil().clamp(
          0,
          86400,
        );
  final review = {'conflict', 'review', 'blocked'}.contains(cmd?.state);
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        seconds > 0
            ? '서버 저장 대기 · 약 $seconds초 후 재시도'
            : '서버 저장 대기${review ? ' · 변경 확인 필요' : ''}',
      ),
      TextButton(
        onPressed:
            model.canEdit &&
                seconds == 0 &&
                !model.busy(
                  ref == null
                      ? 'count:${reg.registrationId}'
                      : 'prefs:${ref.characterId}',
                )
            ? () async {
                if (!review || await _confirmServer(context, model)) {
                  await model.resolveSettings(reg, ref: ref, useServer: review);
                }
              }
            : null,
        child: Text(review ? '서버 정보 사용' : '저장 재시도'),
      ),
    ],
  );
}

class MemberAccountPage extends StatelessWidget {
  const MemberAccountPage({
    required this.model,
    required this.settings,
    this.weekly,
    required this.onSettings,
    required this.onKey,
    required this.onVerify,
    required this.onManage,
    required this.onHistory,
    required this.onServerStatus,
    this.onCharacters,
    this.onEdit,
    this.onVerifyRegistration,
    this.automaticRefreshAvailable = true,
    super.key,
  });
  final MemberAccountViewModel model;
  final MemberSettingsViewModel settings;
  final MemberWeeklyViewModel? weekly;
  final VoidCallback onSettings, onKey, onVerify, onManage, onHistory;
  final void Function(String) onServerStatus;
  final void Function(String)? onCharacters, onEdit, onVerifyRegistration;
  final bool automaticRefreshAvailable;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      model,
      settings,
      ?weekly,
      model.runner.source.cooldown,
    ]),
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('내 계정'),
          flexibleSpace: IgnorePointer(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: model.loading || model.restoring || weekly?.busy == true
                  ? const LinearProgressIndicator(
                      key: ValueKey('member-network-progress'),
                      minHeight: 2,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          actions: [
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: '설정',
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (automaticRefreshAvailable) _progress(context),
              if (weekly != null) _weeklyStatus(context, weekly!),
              if (model.failure != null)
                Text(
                  memberAccountFailure(model.failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (model.restoreRetrySeconds > 0)
                Text('${model.restoreRetrySeconds}초 후 다시 시도해 주세요.'),
              if (model.sections.isEmpty &&
                  !model.loading &&
                  model.failure == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('등록한 원정대가 없습니다.'),
                ),
              for (final section in model.sections.where(
                (s) => s.registration.isMain,
              ))
                _section(context, section),
              for (final section in model.sections.where(
                (s) => !s.registration.isMain,
              ))
                _section(context, section),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '계정 도구',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: onManage,
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('원정대 등록·관리'),
                          ),
                          TextButton(
                            onPressed: onVerify,
                            child: const Text('원정대 인증'),
                          ),
                          TextButton(
                            onPressed: onKey,
                            child: const Text('로스트아크 API 관리'),
                          ),
                          TextButton(
                            onPressed: onHistory,
                            child: const Text('사라진 캐릭터명 기록'),
                          ),
                          TextButton(
                            onPressed: model.canRefresh ? model.refresh : null,
                            child: const Text('서버 정보 다시 불러오기'),
                          ),
                        ],
                      ),
                      const Divider(),
                      MemberSettingsControls(
                        model: settings,
                        classes: '나이스단으로 분류한',
                        automaticRefreshAvailable: automaticRefreshAvailable,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  Widget _progress(BuildContext context) {
    final r = model.runner, cooldown = r.source.cooldown;
    final title = switch (r.phase) {
      ScopedRefreshPhase.preparing => '자동 갱신 준비 중',
      ScopedRefreshPhase.running => '캐릭터 자동 갱신 중',
      ScopedRefreshPhase.completed => '자동 갱신 결과',
      ScopedRefreshPhase.blocked => '자동 갱신 준비 확인 필요',
      _ => '자동 갱신 준비',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (r.isBusy) const LinearProgressIndicator(),
            if (r.rosterProgress.isNotEmpty) ...[
              Text(
                '원정대 목록 갱신 ${r.rosterProgress.where((p) => p.phase == RosterRefreshPhase.updated).length}/${r.rosterProgress.length}',
              ),
              for (final p in r.rosterProgress)
                Text(
                  '${p.label} · ${switch (p.phase) {
                    RosterRefreshPhase.queued => '목록 갱신 대기',
                    RosterRefreshPhase.refreshing => '목록 갱신 중',
                    RosterRefreshPhase.updated => '목록 반영 완료 · 신규 ${p.added}명 · 확인 필요 ${p.suspect}명',
                    RosterRefreshPhase.failed => '목록 갱신 미완료 · ${memberAccountFailure(p.code)}',
                  }}',
                ),
            ],
            if (r.consumed)
              Text(
                '처리 ${r.processedCount}/${r.totalCount} · 저장 ${r.savedCount} · 경고 ${r.warningCount}\n미완료 ${r.incompleteCount} · 정책 제외 ${r.excludedCount} · 서버 저장 대기 ${r.pendingServerCount}',
              ),
            if (r.failure != null) Text(memberAccountFailure(r.failure)),
            if (cooldown.active)
              Text('약 ${cooldown.seconds}초 후 다시 시도할 수 있습니다.'),
            if (r.settingsChanged)
              const Text('설정 변경은 다음 갱신부터 적용됩니다. 현재 작업은 시작 당시 설정을 사용합니다.'),
            Wrap(
              spacing: 8,
              children: [
                if (!r.consumed)
                  TextButton(
                    onPressed: r.isBusy || cooldown.active
                        ? null
                        : () async {
                            await settings.reload();
                            await model.refresh();
                            await r.startIfReady();
                          },
                    child: const Text('준비 상태 다시 확인'),
                  ),
                if (r.incompleteCount > 0)
                  TextButton(
                    onPressed: r.canRetry ? r.retryIncomplete : null,
                    child: const Text('미완료 캐릭터 다시 시도'),
                  ),
                if (r.pendingServerCount > 0)
                  TextButton(
                    onPressed: r.canRetryServer ? r.retryServerSaved : null,
                    child: const Text('서버 저장만 다시 시도'),
                  ),
              ],
            ),
            for (final item in r.items.where(
              (i) => i.status != ScopedRefreshStatus.saved || i.serverPending,
            ))
              Text(
                '${item.target.character.characterName} · ${item.serverPending ? '서버 저장 대기' : memberAccountFailure(item.code)}',
              ),
          ],
        ),
      ),
    );
  }

  String _label(MemberAccountSection section) => AccountLabelPolicy.display(
    customLabel: section.registration.label,
    isMain: section.registration.isMain,
    subAccountNumber:
        model.sections
            .where((s) => !s.registration.isMain)
            .toList()
            .indexOf(section) +
        1,
  );

  Widget _section(BuildContext context, MemberAccountSection section) {
    final reg = ScopedRegistrationRef(
      model.runtime.scope,
      section.registration.registrationId,
    );
    final count = section.presentation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RosterAccountHeader(
              label: _label(section),
              showEdit: onEdit != null,
              showCharacters:
                  onCharacters != null &&
                  section.registration.ownershipStatus == 'owned',
              showVerify: section.registration.ownershipStatus != 'owned',
              onEdit: onEdit == null || model.managementBlocked
                  ? null
                  : () => onEdit!(reg.registrationId),
              onCharacters:
                  onCharacters == null ||
                      model.managementBlocked ||
                      section.registration.ownershipStatus != 'owned'
                  ? null
                  : () => onCharacters!(reg.registrationId),
              onVerify:
                  section.registration.ownershipStatus == 'owned' ||
                      model.managementBlocked
                  ? null
                  : () => onVerifyRegistration != null
                        ? onVerifyRegistration!(reg.registrationId)
                        : onVerify(),
            ),
            if (section.cached) const Text('이전 확인 정보'),
            if (serverAccountActionLabel(
              section.registration.ownershipStatus,
              section.registration.settings.state,
            ).isNotEmpty)
              Text(
                serverAccountActionLabel(
                  section.registration.ownershipStatus,
                  section.registration.settings.state,
                ),
              ),
            if (section.failure != null)
              Text(memberAccountFailure(section.failure)),
            if (section.registration.isMain &&
                model.representativeFailure(reg.registrationId) != null &&
                !model.representativePending(reg.registrationId))
              const Text('대표 상태 확인이 필요합니다. 목록을 다시 확인해 주세요.'),
            if (model.representativePending(reg.registrationId))
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    model.representativeRetrySeconds(reg.registrationId) > 0
                        ? '대표 변경 결과 확인 필요 · ${model.representativeRetrySeconds(reg.registrationId)}초 후 재시도'
                        : '대표 변경 결과 확인이 필요합니다.',
                  ),
                  TextButton(
                    onPressed:
                        model.canEdit &&
                            model.representativeRetrySeconds(
                                  reg.registrationId,
                                ) ==
                                0
                        ? () => model.retryRepresentative(reg)
                        : null,
                    child: const Text('같은 변경 재시도'),
                  ),
                  TextButton(
                    onPressed: model.canEdit ? model.refresh : null,
                    child: const Text('대표 캐릭터 다시 조회'),
                  ),
                ],
              ),
            if (!section.displayReady && section.characters.isNotEmpty)
              const Text('표시 설정 확인 필요'),
            Wrap(
              children: [
                if (weekly != null)
                  OutlinedButton.icon(
                    key: ValueKey('member-roster-weekly-${reg.registrationId}'),
                    onPressed: weekly!.canEditRosterDisplay(reg.registrationId)
                        ? () => editMemberRosterWeeklyDisplay(
                            context,
                            weekly!,
                            reg.registrationId,
                          )
                        : null,
                    icon: const Icon(Icons.checklist_outlined, size: 18),
                    label: const Text('원정대 주간레이드수정'),
                  ),
                if (section.characters.isNotEmpty)
                  TextButton(
                    onPressed: () => _displaySettings(
                      context,
                      section.registration.registrationId,
                    ),
                    child: const Text('캐릭터 표시 설정'),
                  ),
                if (count != null)
                  TextButton(
                    onPressed:
                        model.canEdit &&
                            !model.busy('count:${reg.registrationId}') &&
                            section.registration.settings.activityIds.isNotEmpty
                        ? () => _count(
                            context,
                            reg,
                            count.visibleCount,
                            section.registration.settings.activityIds.length,
                          )
                        : null,
                    child: Text(
                      '표시 ${section.registration.settings.activityIds.isEmpty ? 0 : count.visibleCount.clamp(1, section.registration.settings.activityIds.length)}명',
                    ),
                  ),
              ],
            ),
            if (count?.hasPending == true)
              _pendingSettings(context, reg, count!),
            _characterGrid(context, reg, section),
            if (section.displayReady &&
                section.visible.isEmpty &&
                section.characters.isNotEmpty)
              const Text('표시하도록 선택한 캐릭터가 없습니다. 표시 설정에서 변경할 수 있습니다.'),
          ],
        ),
      ),
    );
  }

  Widget _characterGrid(
    BuildContext context,
    ScopedRegistrationRef reg,
    MemberAccountSection section,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final columns = switch (constraints.maxWidth) {
        < 600 => 2,
        < 900 => 3,
        _ => 4,
      };
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        key: ValueKey('member-character-grid-${reg.registrationId}'),
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final row in section.visible)
            SizedBox(
              width: width,
              child: _character(
                context,
                reg,
                row,
                main: section.registration.isMain,
              ),
            ),
        ],
      );
    },
  );

  Widget _character(
    BuildContext context,
    ScopedRegistrationRef reg,
    MemberCharacterState row, {
    required bool main,
  }) {
    final preferred = row.preferences?.preferences.preferredRole;
    final role = memberDisplayRole(row);
    // Last confirmed member-scoped summaries are display data, not write access.
    final summary = row.role(role)?.displaySummary;
    final profile =
        jsonDecode(row.observation.profileJson) as Map<String, dynamic>;
    final selected = main
        ? model.representative(reg.registrationId)?.characterId ==
              row.ref.characterId
        : model.sections
                  .where(
                    (s) => s.registration.registrationId == reg.registrationId,
                  )
                  .firstOrNull
                  ?.registration
                  .settings
                  .representativeId ==
              row.ref.characterId;
    // View data only. Server actions below always retain the scoped UUID ref.
    final display = LocalAccountCharacter(
      id: 0,
      serverCharacterId: row.ref.characterId,
      serverName: row.observation.serverName,
      characterName: row.observation.characterName,
      characterLevel: profile['character_level'] as int? ?? 0,
      characterClassName: profile['class_name'] as String? ?? '직업 미확인',
      itemLevel: double.tryParse(
        (profile['item_level'] as String? ?? '').replaceAll(',', ''),
      ),
      combatPower: double.tryParse(summary?.combatPower ?? ''),
      isVisible: true,
      displayOrder: row.preferences?.preferences.displayOrder,
      preferredRole: preferred,
    );
    return AccountCharacterCard(
      key: ValueKey('member-character-${row.ref.characterId}'),
      character: display,
      isRepresentative: selected,
      representativeControl: main
          ? RepresentativeCrown(
              selected: selected,
              unselectedOpacity: 0.5,
              busy:
                  model.busy('representative:${reg.registrationId}') &&
                  model.representativeTarget(reg.registrationId) ==
                      row.ref.characterId,
              label: selected
                  ? '대표 캐릭터'
                  : '${row.observation.characterName}을 대표 캐릭터로 변경',
              onPressed: model.representativeChoice(reg, row.ref) == null
                  ? null
                  : () => _representative(context, reg, row),
            )
          : null,
      combatPowerNote: preferred == null && summary == null
          ? null
          : roleLabel(role),
      status: Text(
        '${summary == null ? '상세 조회 필요' : integrityLabel(summary)}${row.cached ? ' · 이전 확인 정보' : ''}${row.preferences == null ? ' · 표시 설정 확인 필요' : ''}${row.observation.lifecycleState != 'active' ? ' · 기존 캐릭터 확인 필요' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      weeklyRaids: weekly?.items(row.ref) ?? const [],
      showWeeklyRaidEditor: weekly?.catalog != null,
      weeklyRaidHiddenByPreference:
          weekly?.preference(row.ref.characterId)?.displayCount == 0,
      onEditWeeklyRaids: weekly?.canEditDisplay(row.ref) != true
          ? null
          : () => editMemberWeeklyDisplay(context, weekly!, row.ref),
      onWeeklyRaidChanged: weekly == null
          ? null
          : (raid, completed) =>
                _weeklyChange(context, row.ref, raid, completed),
      busyRaidIds: weekly?.pendingCharacter == row.ref.characterId
          ? {weekly!.pendingRaid!}
          : const {},
      reservedWeeklyRaidRows:
          weekly?.preference(row.ref.characterId)?.displayCount == 0
          ? 0
          : WeeklyRaidDisplayProjector.defaultDisplayCount,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MemberCharacterPage(
            model: model,
            registration: reg,
            ref: row.ref,
          ),
        ),
      ),
    );
  }

  Widget _weeklyStatus(BuildContext context, MemberWeeklyViewModel state) {
    if (state.busy || (state.failure == null && !state.hasPending)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.failure != null) Text(memberWeeklyFailure(state.failure)),
        if (state.hasPending) const Text('주간 레이드 저장 확인 필요'),
        if (state.retrySeconds > 0)
          Text('${state.retrySeconds}초 후 다시 시도해 주세요.'),
        if (!state.loading)
          Wrap(
            children: [
              TextButton(
                onPressed: state.writing || state.retrySeconds > 0
                    ? null
                    : () => state.refresh(reloadCatalog: true),
                child: const Text('주간 레이드 다시 불러오기'),
              ),
              if (state.hasPending && !state.pendingFailed)
                TextButton(
                  onPressed: state.canRetry ? state.retry : null,
                  child: const Text('저장 재시도'),
                ),
              if (state.canUseCurrent)
                TextButton(
                  onPressed: state.useCurrent,
                  child: const Text('현재 상태 유지'),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _weeklyChange(
    BuildContext context,
    ScopedCharacterRef ref,
    WeeklyRaidStatusItem raid,
    bool completed,
  ) async {
    final state = weekly;
    if (state == null || !state.canChange(ref, raid.raidId)) return;
    final member = accountReadScope(model.runtime.session),
        before = state.entry(ref, raid.raidId);
    final name = model.character(ref)?.observation.characterName ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(completed ? '레이드 완료 처리' : '레이드 완료 해제'),
        content: Text(
          completed
              ? '$name 캐릭터의 ${raid.label} 레이드를 완료 처리할까요?'
              : '$name 캐릭터의 ${raid.label} 수동 완료를 해제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(completed ? '완료 처리' : '완료 해제'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        _sameMember(model, member) &&
        identical(before, state.entry(ref, raid.raidId)) &&
        state.canChange(ref, raid.raidId)) {
      await state.change(ref, raid, completed);
    }
  }

  Future<void> _representative(
    BuildContext context,
    ScopedRegistrationRef reg,
    MemberCharacterState row,
  ) async {
    final choice = model.representativeChoice(reg, row.ref);
    if (choice == null || !model.openRepresentativeDialog(choice)) return;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => ListenableBuilder(
          listenable: model,
          builder: (_, _) {
            final valid =
                _sameMember(model, choice.session) &&
                model.representativeChoice(reg, row.ref)?.before ==
                    choice.before;
            return AlertDialog(
              title: const Text('대표 캐릭터 변경'),
              content: Text(
                valid
                    ? '‘${row.observation.characterName}’ 캐릭터로 대표 캐릭터를 변경하시겠습니까?'
                    : '회원 또는 캐릭터 상태가 변경됐습니다. 목록을 다시 확인해 주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: valid ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('변경'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      model.closeRepresentativeDialog(choice);
    }
    if (confirmed != true ||
        !context.mounted ||
        !_sameMember(model, choice.session)) {
      return;
    }
    await model.changeRepresentative(choice);
    if (context.mounted &&
        _sameMember(model, choice.session) &&
        !model.representativePending(reg.registrationId) &&
        model.representative(reg.registrationId)?.characterId ==
            row.ref.characterId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('대표 캐릭터를 변경했습니다.')));
    }
  }

  Widget _pendingSettings(
    BuildContext context,
    ScopedRegistrationRef reg,
    ScopedSettingsState state, {
    ScopedCharacterRef? ref,
  }) => memberPendingSettings(context, model, reg, state, ref: ref);
  Future<void> _count(
    BuildContext context,
    ScopedRegistrationRef reg,
    int old,
    int maximum,
  ) async {
    final member = accountReadScope(model.runtime.session);
    if (maximum == 0) return;
    var value = old.clamp(1, maximum);
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('표시할 캐릭터 수'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$value명'),
              if (maximum > 1)
                Slider(
                  value: value.toDouble(),
                  min: 1,
                  max: maximum.toDouble(),
                  divisions: maximum - 1,
                  label: '$value명',
                  onChanged: (next) => set(() => value = next.round()),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value),
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );
    if (count != null && _sameMember(model, member)) {
      await model.saveCount(reg, count);
    }
  }

  Future<void> _displaySettings(BuildContext context, String id) async {
    final member = accountReadScope(model.runtime.session);
    final section = model.sections
        .where((s) => s.registration.registrationId == id)
        .firstOrNull;
    if (section == null || !section.displayReady || !model.canEdit) return;
    final token = memberPresentationToken(section);
    final rows = section.ordered
        .where(
          (c) => section.registration.settings.activityIds.contains(
            c.ref.characterId,
          ),
        )
        .toList();
    final draft = {
      for (final row in rows) row.ref.characterId: row.preferences!.preferences,
    };
    var reordered = false;
    final result = await showDialog<Map<String, PreferenceValues>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('캐릭터 표시 설정'),
          content: SizedBox(
            width: 440,
            height: 400,
            child: rows.isEmpty
                ? const Center(child: Text('사용할 캐릭터를 선택해 주세요.'))
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: rows.length,
                    onReorder: (from, to) => set(() {
                      if (to > from) to--;
                      rows.insert(to, rows.removeAt(from));
                      reordered = true;
                    }),
                    itemBuilder: (ctx, index) {
                      final row = rows[index],
                          value = draft[row.ref.characterId]!;
                      return Material(
                        key: ValueKey(row.ref.characterId),
                        color: index.isEven
                            ? Theme.of(ctx).colorScheme.surfaceContainerLow
                            : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${row.ref.characterId == section.registration.settings.representativeId ? '♛ ' : ''}${row.observation.characterName}',
                                    ),
                                    RadioGroup<bool>(
                                      groupValue: value.visible,
                                      onChanged: (v) => set(() {
                                        draft[row
                                            .ref
                                            .characterId] = PreferenceValues(
                                          preferredRole: value.preferredRole,
                                          visible: v!,
                                          displayOrder: value.displayOrder,
                                        );
                                      }),
                                      child: Row(
                                        children: [
                                          const Radio<bool>(value: true),
                                          const Text('활성'),
                                          const Radio<bool>(value: false),
                                          const Text('비활성'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (reordered) {
                  for (var i = 0; i < rows.length; i++) {
                    final key = rows[i].ref.characterId,
                        old = draft[rows[i].ref.characterId]!;
                    draft[key] = PreferenceValues(
                      preferredRole: old.preferredRole,
                      visible: old.visible,
                      displayOrder: i,
                    );
                  }
                }
                Navigator.pop(ctx, draft);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null && _sameMember(model, member)) {
      final current = model.sections
          .where((s) => s.registration.registrationId == id)
          .firstOrNull;
      if (current == null || token != memberPresentationToken(current)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('정보가 변경됐습니다. 다시 선택해 주세요.')),
          );
        }
        return;
      }
      await model.saveDisplaySettings(
        ScopedRegistrationRef(model.runtime.scope, id),
        result,
      );
    }
  }
}

Future<void> editMemberPreferences(
  BuildContext context,
  MemberAccountViewModel model,
  ScopedRegistrationRef reg,
  MemberCharacterState row,
) async {
  final member = accountReadScope(model.runtime.session);
  final values = row.preferences!.preferences;
  final multiRole = const CharacterBuildRolePolicy().supportsMultipleRoles(
    (jsonDecode(row.observation.profileJson) as Map)['class_name'] as String,
  );
  var role = multiRole ? memberDisplayRole(row) : CharacterBuildRole.dealer;
  var visible = values.visible;
  final result = await showDialog<PreferenceValues>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('${row.observation.characterName} 표시 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (multiRole)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final choice in CharacterBuildRole.values)
                      ChoiceChip(
                        label: Text(roleLabel(choice)),
                        selected: role == choice,
                        onSelected: (_) => set(() => role = choice),
                      ),
                  ],
                ),
              RadioGroup<bool>(
                groupValue: visible,
                onChanged: (v) => set(() => visible = v!),
                child: const Row(
                  children: [
                    Radio<bool>(value: true),
                    Text('활성'),
                    Radio<bool>(value: false),
                    Text('비활성'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                ctx,
                PreferenceValues(
                  preferredRole: role,
                  visible: visible,
                  displayOrder: values.displayOrder,
                ),
              );
            },
            child: const Text('변경'),
          ),
        ],
      ),
    ),
  );
  if (result != null && _sameMember(model, member)) {
    final latest = model.character(row.ref)?.preferences?.preferences;
    if (latest == null ||
        jsonEncode(latest.toJson()) != jsonEncode(values.toJson())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보가 변경됐습니다. 다시 선택해 주세요.')),
        );
      }
      return;
    }
    await model.savePreferences(reg, row.ref, result);
  }
}

class MemberCharacterPage extends StatelessWidget {
  const MemberCharacterPage({
    required this.model,
    required this.registration,
    required this.ref,
    super.key,
  });
  final MemberAccountViewModel model;
  final ScopedRegistrationRef registration;
  final ScopedCharacterRef ref;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, model.runner.source.cooldown]),
    builder: (context, _) {
      final row = model.character(ref);
      return Scaffold(
        appBar: AppBar(title: Text(row?.observation.characterName ?? '캐릭터')),
        body: row == null || !model.detailsAvailable(ref)
            ? const Center(
                child: Text('현재 소유와 캐릭터 사용 자격을 확인한 후 상세 정보를 볼 수 있습니다.'),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (row.observation.lifecycleState != 'active')
                    const Text('기존 캐릭터 확인 필요 · 새로운 사용 전에 원정대를 확인해 주세요.'),
                  if (row.preferences != null &&
                      const CharacterBuildRolePolicy().supportsMultipleRoles(
                        (jsonDecode(row.observation.profileJson)
                                    as Map)['class_name']
                                as String? ??
                            '',
                      ))
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final role in CharacterBuildRole.values)
                          ChoiceChip(
                            label: Text(roleLabel(role)),
                            selected: memberDisplayRole(row) == role,
                            onSelected:
                                model.canEdit &&
                                    !model.busy('prefs:${ref.characterId}')
                                ? (_) => model.savePreferences(
                                    registration,
                                    ref,
                                    PreferenceValues(
                                      preferredRole: role,
                                      visible:
                                          row.preferences!.preferences.visible,
                                      displayOrder: row
                                          .preferences!
                                          .preferences
                                          .displayOrder,
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),
                  if (row.preferences != null)
                    TextButton(
                      onPressed:
                          model.canEdit &&
                              !model.busy('prefs:${ref.characterId}')
                          ? () => editMemberPreferences(
                              context,
                              model,
                              registration,
                              row,
                            )
                          : null,
                      child: const Text('표시 설정'),
                    ),
                  if (row.preferences?.hasPending == true)
                    memberPendingSettings(
                      context,
                      model,
                      registration,
                      row.preferences!,
                      ref: ref,
                    ),
                  if (row.failure != null)
                    Text(memberAccountFailure(row.failure)),
                  if (model.failure != null)
                    Text(memberAccountFailure(model.failure)),
                  _role(context, row, memberDisplayRole(row)),
                ],
              ),
      );
    },
  );
  Widget _role(
    BuildContext context,
    MemberCharacterState row,
    CharacterBuildRole role,
  ) {
    final state = row.role(role),
        summary = state?.displaySummary,
        command = state?.command;
    final review = {'conflict', 'review', 'blocked'}.contains(command?.state);
    final seconds = command?.retryAt == null
        ? 0
        : (command!.retryAt!
                      .difference(model.runner.source.cooldown.now())
                      .inMilliseconds /
                  1000)
              .ceil()
              .clamp(0, 86400);
    final waiting = seconds > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              roleLabel(role),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(integrityLabel(summary)),
            if (summary != null) ...[
              Text(
                '전투력 ${DisplayNumberFormatter.whole(summary.combatPower, missing: '확인되지 않음')} · 아이템 레벨 ${DisplayNumberFormatter.whole(summary.itemLevel, missing: '확인되지 않음')}',
              ),
              Text('확인 ${localDateTimeToSeconds(summary.analyzedAt)}'),
              if (summary.lifecycleRevision !=
                  row.observation.lifecycleRevision)
                const Text('이전 캐릭터 상태에서 확인한 정보입니다.'),
              for (final issue in summary.issues) Text(_issueLabel(issue.code)),
            ],
            if (state?.hasPending == true) ...[
              const Text('서버 저장 대기 · 현재 기기에 저장된 결과입니다.'),
              if (waiting) Text('약 $seconds초 후 다시 시도할 수 있습니다.'),
              TextButton(
                onPressed:
                    model.canEdit &&
                        !waiting &&
                        !model.busy('role:${ref.characterId}:${role.name}')
                    ? () async {
                        if (!review || await _confirmServer(context, model)) {
                          await model.resolveRole(
                            registration,
                            ref,
                            role,
                            useServer: review,
                          );
                        }
                      }
                    : null,
                child: Text(review ? '현재 서버 정보 사용' : '이 역할 서버 저장 재시도'),
              ),
            ],
            if (state?.rawMatchesDisplay != true)
              const Text('현재 요약의 상세 원본이 이 기기에 없습니다. 마지막 저장 요약을 표시합니다.')
            else
              ExpansionTile(
                title: const Text('보석·아크패시브·아크그리드 상세'),
                children: [
                  _MemberAnalysis(
                    model: model,
                    ref: ref,
                    role: role,
                    raw: state!.rawJson!,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

String _issueLabel(String code) => switch (code) {
  'GEM_SLOT_COUNT' => '장착 보석 개수 확인 필요',
  'FOREIGN_CLASS_GEM' => '다른 직업의 보석이 포함되어 있습니다.',
  'UNMATCHED_SKILL_GEM' => '보석과 스킬 일치 확인 필요',
  'SAME_CLASS_GEM_UNVERIFIED' => '같은 직업 보석의 적용 대상 확인 필요',
  'GEM_UNAVAILABLE' => '보석 정보 확인 불가',
  'ARK_GRID_MINIMUM' => '아크그리드 최소 조건 확인 필요',
  'ARK_GRID_CONDITION' => '아크그리드 조건 불일치',
  'ARK_GRID_RELIC_POINT' => '아크그리드 포인트 확인 필요',
  'RUNE_COUNT' => '룬 개수 확인 필요',
  _ => '추가 세팅 확인 항목이 있습니다.',
};

class _MemberAnalysis extends StatefulWidget {
  const _MemberAnalysis({
    required this.model,
    required this.ref,
    required this.role,
    required this.raw,
  });
  final MemberAccountViewModel model;
  final ScopedCharacterRef ref;
  final CharacterBuildRole role;
  final String raw;
  @override
  State<_MemberAnalysis> createState() => _MemberAnalysisState();
}

class _MemberAnalysisState extends State<_MemberAnalysis> {
  Future<CharacterBuildAnalysis?>? _future;
  @override
  void initState() {
    super.initState();
    _future = widget.model.analysis(widget.ref, widget.role);
  }

  @override
  void didUpdateWidget(covariant _MemberAnalysis old) {
    super.didUpdateWidget(old);
    if (old.raw != widget.raw) {
      _future = widget.model.analysis(widget.ref, widget.role);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<CharacterBuildAnalysis?>(
    future: _future,
    builder: (context, snapshot) {
      final a = snapshot.data;
      if (a == null) {
        return Text(
          snapshot.connectionState == ConnectionState.waiting
              ? '상세 정보를 읽는 중입니다.'
              : '상세 정보를 표시하지 못했습니다. 저장 요약은 보존됩니다.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in a.notices) Text(n.message),
          Text(
            '아크패시브 · ${a.catalogDetection?.branchDisplayName ?? '계열 확인 불가'}',
          ),
          if (a.catalogDetection?.matchedTier1Node != null)
            Text(a.catalogDetection!.matchedTier1Node!),
          for (final node
              in a.catalogDetection?.matchedRelatedNodes ?? <String>[])
            Text(node),
          Text(
            '룬 ${a.runeCount}/8 · 보석 ${a.equippedGemCount?.toString() ?? '확인 불가'}개',
          ),
          for (final gem in a.gemEffects)
            ListTile(
              title: Text('${gem.gemLevel}레벨 · ${gem.skillName}'),
              subtitle: Text(gem.descriptions.join(' · ')),
            ),
          for (final core in a.arkGridCorePoints)
            ListTile(
              title: Text(core.coreName),
              subtitle: Text(
                '${core.grade} · ${core.point}P / 권장 ${core.recommendedPoint}P',
              ),
            ),
          for (final c in a.arkGridConditions)
            ListTile(title: Text(c.coreName), subtitle: Text(c.conditionText)),
        ],
      );
    },
  );
}
