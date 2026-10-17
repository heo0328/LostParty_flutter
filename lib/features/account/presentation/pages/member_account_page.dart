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
import '../widgets/member_settings_controls.dart';
import '../widgets/representative_crown.dart';

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
    required this.onSettings,
    required this.onKey,
    required this.onVerify,
    required this.onManage,
    required this.onHistory,
    required this.onServerStatus,
    this.onCharacters,
    super.key,
  });
  final MemberAccountViewModel model;
  final MemberSettingsViewModel settings;
  final VoidCallback onSettings, onKey, onVerify, onManage, onHistory;
  final void Function(String) onServerStatus;
  final void Function(String)? onCharacters;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      model,
      settings,
      model.runner.source.cooldown,
    ]),
    builder: (context, _) {
      final r = model.runner;
      return Scaffold(
        appBar: AppBar(
          title: const Text('내 계정'),
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
              _progress(context),
              if (model.loading) const LinearProgressIndicator(),
              if (model.failure != null)
                Text(
                  memberAccountFailure(model.failure),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('원정대 등록·관리'),
                  ),
                  TextButton(onPressed: onVerify, child: const Text('원정대 인증')),
                  TextButton(onPressed: onKey, child: const Text('개인 API 키')),
                  TextButton(
                    onPressed: onHistory,
                    child: const Text('사라진 캐릭터 기록'),
                  ),
                  TextButton(
                    onPressed:
                        model.loading || r.isBusy || r.source.cooldown.active
                        ? null
                        : model.refresh,
                    child: const Text('목록·저장 정보 다시 확인'),
                  ),
                ],
              ),
              ExpansionTile(
                title: const Text('자동 갱신 설정'),
                children: [
                  MemberSettingsControls(
                    model: settings,
                    classes: '나이스단으로 분류한',
                    automaticRefreshAvailable: true,
                  ),
                ],
              ),
              if (model.sections.isEmpty && !model.loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '등록한 원정대가 없거나 아직 확인하지 못했습니다. 원정대를 등록한 뒤 목록을 다시 확인해 주세요.',
                  ),
                ),
              for (final section in model.sections) _section(context, section),
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
            Text(
              '${section.registration.label.isEmpty ? (section.registration.isMain ? '본계정' : '부계정') : section.registration.label}${section.registration.isMain ? ' · 본계정' : ' · 부계정'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (section.cached) const Text('이 기기의 이전 확인 정보'),
            if (onCharacters != null &&
                section.registration.ownershipStatus == 'owned')
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: model.managementBlocked
                      ? null
                      : () => onCharacters!(reg.registrationId),
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('캐릭터 관리'),
                ),
              ),
            if (section.registration.ownershipStatus != 'owned')
              const Text('소유 인증 후 회원별 캐릭터를 사용할 수 있습니다.'),
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
              const Text('표시 설정 확인 전 · 캐릭터의 확인 상태를 표시합니다.'),
            Wrap(
              children: [
                TextButton(
                  onPressed: () =>
                      onServerStatus(section.registration.registrationId),
                  child: const Text('서버 원정대 상태'),
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
                            !model.busy('count:${reg.registrationId}')
                        ? () => _count(context, reg, count.visibleCount)
                        : null,
                    child: Text('표시 ${count.visibleCount}명'),
                  ),
              ],
            ),
            if (count?.hasPending == true)
              _pendingSettings(context, reg, count!),
            for (final row in section.visible)
              _character(context, reg, row, main: section.registration.isMain),
            if (section.displayReady &&
                section.visible.isEmpty &&
                section.characters.isNotEmpty)
              const Text('표시하도록 선택한 캐릭터가 없습니다. 표시 설정에서 변경할 수 있습니다.'),
          ],
        ),
      ),
    );
  }

  Widget _character(
    BuildContext context,
    ScopedRegistrationRef reg,
    MemberCharacterState row, {
    required bool main,
  }) {
    final preferred = row.preferences?.preferences.preferredRole;
    final role =
        preferred ??
        (row.dealer?.displaySummary != null ||
                row.support?.displaySummary == null
            ? CharacterBuildRole.dealer
            : CharacterBuildRole.support);
    final summary = model.detailsAvailable(row.ref)
        ? row.role(role)?.displaySummary
        : null;
    return ListTile(
      key: ValueKey('member-character-${row.ref.characterId}'),
      title: Row(
        children: [
          Flexible(child: Text(row.observation.characterName)),
          if (main)
            RepresentativeCrown(
              selected:
                  model.representative(reg.registrationId)?.characterId ==
                  row.ref.characterId,
              busy:
                  model.busy('representative:${reg.registrationId}') &&
                  model.representativeTarget(reg.registrationId) ==
                      row.ref.characterId,
              label:
                  model.representative(reg.registrationId)?.characterId ==
                      row.ref.characterId
                  ? '대표 캐릭터'
                  : '${row.observation.characterName}을 대표 캐릭터로 변경',
              onPressed: model.representativeChoice(reg, row.ref) == null
                  ? null
                  : () => _representative(context, reg, row),
            ),
        ],
      ),
      subtitle: Text(
        '${row.observation.serverName} · ${preferred == null && summary == null ? '저장 역할 미확인' : roleLabel(role)} · 전투력 ${DisplayNumberFormatter.whole(summary?.combatPower, missing: '저장 정보 없음')}\n${integrityLabel(summary)}${row.cached ? ' · 이전 확인 정보' : ''}${row.preferences == null ? ' · 표시 설정 확인 필요' : ''}${row.observation.lifecycleState != 'active' ? ' · 기존 캐릭터 확인 필요' : ''}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
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
  ) async {
    final member = accountReadScope(model.runtime.session);
    final text = TextEditingController(text: '$old');
    String? error;
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('표시할 캐릭터 수'),
          content: TextField(
            controller: text,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: '1~200명', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(text.text);
                if (value == null || value < 1 || value > 200) {
                  set(() => error = '1~200 사이의 정수를 입력해 주세요.');
                  return;
                }
                Navigator.pop(ctx, value);
              },
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (count != null && _sameMember(model, member)) {
      await model.saveCount(reg, count);
    }
  }

  Future<void> _displaySettings(
    BuildContext context,
    String id,
  ) => showDialog<void>(
    context: context,
    builder: (ctx) => ListenableBuilder(
      listenable: model,
      builder: (ctx, _) {
        final section = model.sections
            .where((s) => s.registration.registrationId == id)
            .firstOrNull;
        return AlertDialog(
          title: const Text('캐릭터 표시 설정'),
          content: SizedBox(
            width: 440,
            height: 400,
            child: ListView(
              children: [
                if (section == null) const Text('현재 회원 정보를 다시 확인해 주세요.'),
                for (final row
                    in section?.characters ?? <MemberCharacterState>[])
                  Column(
                    children: [
                      ListTile(
                        title: Text(row.observation.characterName),
                        subtitle: Text(
                          row.preferences == null
                              ? '설정 확인 필요'
                              : row.preferences!.preferences.visible
                              ? '표시 · 순서 ${row.preferences!.preferences.displayOrder ?? '자동'}'
                              : '숨김',
                        ),
                        trailing: const Icon(Icons.tune),
                        onTap:
                            row.preferences != null &&
                                model.canEdit &&
                                !model.busy('prefs:${row.ref.characterId}')
                            ? () => editMemberPreferences(
                                ctx,
                                model,
                                ScopedRegistrationRef(row.ref.scope, id),
                                row,
                              )
                            : null,
                      ),
                      if (row.preferences?.hasPending == true)
                        memberPendingSettings(
                          ctx,
                          model,
                          ScopedRegistrationRef(row.ref.scope, id),
                          row.preferences!,
                          ref: row.ref,
                        ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    ),
  );
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
  var role = values.preferredRole, visible = values.visible;
  String? error;
  final order = TextEditingController(
    text: values.displayOrder?.toString() ?? '',
  );
  final result = await showDialog<PreferenceValues>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('${row.observation.characterName} 표시 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: role?.name ?? 'auto',
                decoration: const InputDecoration(labelText: '선호 역할'),
                items: [
                  const DropdownMenuItem(value: 'auto', child: Text('자동 선택')),
                  const DropdownMenuItem(value: 'dealer', child: Text('딜러')),
                  if (multiRole || role == CharacterBuildRole.support)
                    DropdownMenuItem(
                      value: 'support',
                      enabled: multiRole,
                      child: const Text('서포터'),
                    ),
                ],
                onChanged: (v) => set(
                  () => role = v == 'auto'
                      ? null
                      : CharacterBuildRole.values.byName(v!),
                ),
              ),
              CheckboxListTile(
                value: visible,
                title: const Text('내 계정에 표시'),
                onChanged: (v) => set(() => visible = v!),
              ),
              TextField(
                controller: order,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '표시 순서',
                  helperText: '비우면 자동 정렬 · 0~2147483647',
                  errorText: error,
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
              final raw = order.text.trim(),
                  rank = int.tryParse(order.text.trim());
              if (raw.isNotEmpty &&
                  (rank == null || rank < 0 || rank > 2147483647)) {
                set(() => error = '허용 범위의 정수를 입력해 주세요.');
                return;
              }
              Navigator.pop(
                ctx,
                PreferenceValues(
                  preferredRole: role,
                  visible: visible,
                  displayOrder: raw.isEmpty ? null : rank,
                ),
              );
            },
            child: const Text('변경'),
          ),
        ],
      ),
    ),
  );
  order.dispose();
  if (result != null && _sameMember(model, member)) {
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
                      child: const Text('선호 역할·표시 설정'),
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
                  for (final role in CharacterBuildRole.values)
                    _role(context, row, role),
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
