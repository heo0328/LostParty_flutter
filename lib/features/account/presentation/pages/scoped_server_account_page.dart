import '../../../../shared/formatters/display_number_formatter.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/ownership_notice_title.dart';

import '../../domain/account_read_session.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/server_character_lifecycle.dart';
import '../viewmodels/scoped_account_view_model.dart';
import '../widgets/scoped_account_status.dart';
import '../widgets/server_accounts_panel.dart';

class ScopedServerAccountPage extends StatefulWidget {
  const ScopedServerAccountPage({
    required this.model,
    required this.registrationId,
    required this.onLogin,
    required this.onPower,
    required this.onHistory,
    required this.onVerify,
    this.onCharacters,
    super.key,
  });
  final ScopedAccountViewModel model;
  final String registrationId;
  final VoidCallback onLogin, onVerify;
  final Future<void> Function() onPower, onHistory;
  final Future<void> Function()? onCharacters;
  @override
  State<ScopedServerAccountPage> createState() =>
      _ScopedServerAccountPageState();
}

class _ScopedServerAccountPageState extends State<ScopedServerAccountPage> {
  AccountReadScope? _openedSession;
  bool _navigating = false;
  bool _invalidId = false;
  void _ensureSession() {
    final m = widget.model;
    if (!m.canRead) {
      _openedSession = null;
      return;
    }
    final scope = accountReadScope(m.runtime.session);
    if (_openedSession == scope) return;
    _openedSession = scope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(m, widget.model) &&
          m.canRead &&
          accountReadScope(m.runtime.session) == scope) {
        unawaited(_read());
      }
    });
  }

  Future<void> _read({bool refresh = false}) async {
    try {
      await widget.model.openRoster(
        widget.model.runtime.reference(widget.registrationId),
        refresh: refresh,
      );
    } on ScopedCacheException {
      if (mounted) setState(() => _invalidId = true);
    }
  }

  @override
  void didUpdateWidget(covariant ScopedServerAccountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.registrationId != widget.registrationId ||
        !identical(oldWidget.model, widget.model)) {
      oldWidget.model.closeRoster();
      _openedSession = null;
      _invalidId = false;
    }
  }

  @override
  void dispose() {
    widget.model.closeRoster();
    super.dispose();
  }

  Future<void> _navigate(
    Future<void> Function() action, {
    bool reload = false,
  }) async {
    if (_navigating) return;
    final m = widget.model,
        scope = accountReadScope(widget.model.runtime.session);
    setState(() => _navigating = true);
    try {
      await action();
      if (mounted &&
          m.canRead &&
          accountReadScope(m.runtime.session) == scope &&
          reload) {
        await _read(refresh: true);
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model;
      _ensureSession();
      final state = m.roster(widget.registrationId), view = state.observation;
      final busy = state.loading || m.loading || _navigating;
      final seconds = m.needsMetadata
          ? m.retrySeconds
          : m.rosterRetrySeconds(widget.registrationId);
      final characters = view == null ? null : scopedRosterCharacters(view);
      return Scaffold(
        appBar: AppBar(
          title: const OwnershipNoticeTitle(child: Text('원정대 캐릭터')),
          actions: [
            IconButton(
              tooltip: '캐릭터 다시 조회',
              onPressed: !m.canRead || busy || seconds > 0
                  ? null
                  : () => _read(refresh: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: !m.canRead
            ? Center(
                child: TextButton(
                  onPressed: widget.onLogin,
                  child: const Text('로그인 후 조회할 수 있습니다.'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (busy) const LinearProgressIndicator(),
                  if (_invalidId) const Text('캐릭터 정보를 찾을 수 없습니다.'),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed:
                            busy ||
                                _invalidId ||
                                view?.registration.ownershipStatus != 'owned' ||
                                !state.current
                            ? null
                            : () => _navigate(widget.onPower, reload: true),
                        icon: const Icon(Icons.query_stats),
                        label: const Text('전투력 확인'),
                      ),
                      TextButton.icon(
                        onPressed: _navigating
                            ? null
                            : () => _navigate(widget.onHistory),
                        icon: const Icon(Icons.history),
                        label: const Text('사라진 캐릭터명 기록'),
                      ),
                    ],
                  ),
                  if (state.failure case final failure?)
                    ScopedAccountFailureMessage(
                      failure: failure,
                      seconds: seconds,
                      onVerify: widget.onVerify,
                    ),
                  if (view != null) ...[
                    if (!state.current)
                      Text(
                        state.failure == null
                            ? '이전 확인 정보 · 다시 확인 필요'
                            : '이전 확인 정보 · 최신 상태 확인 실패',
                      ),
                    if (serverOwnershipLabel(
                      view.registration.ownershipStatus,
                    ).isNotEmpty)
                      Text(
                        serverOwnershipLabel(view.registration.ownershipStatus),
                      ),
                    if (serverConfigurationLabel(
                      view.registration.settings.state,
                    ).isNotEmpty)
                      Text(
                        serverConfigurationLabel(
                          view.registration.settings.state,
                        ),
                      ),
                    Text(
                      '저장된 활동 선택 ${view.registration.settings.activityIds.length}명',
                    ),
                    Text('마지막 확인: ${scopedTime(view.registration.fetchedAt)}'),
                    if (view.registration.ownershipStatus == 'owned' &&
                        widget.onCharacters != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busy || !state.current
                              ? null
                              : () => _navigate(
                                  widget.onCharacters!,
                                  reload: true,
                                ),
                          child: const Text('캐릭터 관리'),
                        ),
                      ),
                    if (view.registration.ownershipStatus != 'owned')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busy ? null : widget.onVerify,
                          child: const Text('원정대 인증'),
                        ),
                      ),
                    if (state.coverage == ScopedRosterCoverage.metadataOnly)
                      const Text('캐릭터 상태 확인 필요')
                    else if (characters == null)
                      const Text('저장된 캐릭터 정보를 표시하지 못했습니다. 다시 조회해 주세요.')
                    else ...[
                      if (state.current && characters.isEmpty)
                        const Text('조회된 캐릭터가 없습니다.'),
                      for (final c in characters)
                        _character(
                          c,
                          view.registration.ownershipStatus == 'owned' &&
                              state.current,
                          view.registration.settings.activityIds,
                          view.registration.settings.representativeId,
                        ),
                    ],
                  ],
                ],
              ),
      );
    },
  );

  Widget _character(
    LifecycleCharacter c,
    bool details,
    List<String> activity,
    String? representative,
  ) => Card(
    child: ListTile(
      title: Text(c.characterName),
      subtitle: Text(
        '${c.serverName} · ${c.wire['class_name']}\n'
        '아이템 레벨 ${DisplayNumberFormatter.whole(c.wire['item_level'])}'
        '${details ? ' · 전투력 ${DisplayNumberFormatter.whole(c.wire['combat_power'])}${c.wire['power_stale'] == true ? ' · 최근 확인 필요' : ''}' : ' · 최신 정보 확인 필요'}\n'
        '${switch (c.blockedReason) {
          'OWNERSHIP_REQUIRED' => '미인증 미리보기 · 현재 사용 불가',
          'IDENTITY_CONFLICT' => '캐릭터 정보 충돌 · 현재 사용 불가',
          'CHARACTER_UNUSABLE' => '캐릭터 확인 필요 · 현재 사용 불가',
          _ => '원정대 소속 확인',
        }}'
        '${c.characterId == representative && c.characterId != null ? ' · 저장된 대표' : ''}'
        '${activity.contains(c.characterId) ? ' · 저장된 활동 선택' : ''}'
        '${c.wire['power_fetched_at'] == null ? '' : '\n전투력 확인: ${scopedTime(DateTime.parse(c.wire['power_fetched_at'] as String))}'}',
      ),
      trailing: c.usable
          ? null
          : const Icon(Icons.info_outline, semanticLabel: '확인 필요'),
    ),
  );
}
