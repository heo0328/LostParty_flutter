import '../../../../shared/formatters/display_number_formatter.dart';
import 'package:flutter/material.dart';
import '../widgets/ownership_notice_title.dart';
import '../../../../shared/formatters/local_date_time_formatter.dart';

import '../../domain/account_read_session.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/services/roster_character_order.dart';
import '../viewmodels/server_account_read_view_model.dart';
import '../widgets/server_accounts_panel.dart';
import '../widgets/server_power_controls.dart';
import '../viewmodels/server_combat_power_view_model.dart';

class ServerAccountCharactersPage extends StatefulWidget {
  const ServerAccountCharactersPage({
    required this.registrationId,
    required this.repository,
    required this.session,
    required this.onLogin,
    this.powers,
    super.key,
  });
  final String registrationId;
  final ServerAccountReadRepository repository;
  final AccountReadSession session;
  final VoidCallback onLogin;
  final ServerCombatPowerViewModel? powers;
  @override
  State<ServerAccountCharactersPage> createState() =>
      _ServerAccountCharactersPageState();
}

class _ServerAccountCharactersPageState
    extends State<ServerAccountCharactersPage> {
  late ServerAccountReadViewModel viewModel;
  @override
  void initState() {
    super.initState();
    viewModel = ServerAccountReadViewModel(
      widget.repository,
      widget.session,
      registrationId: widget.registrationId,
      onRoster: widget.powers?.store,
    );
  }

  @override
  void didUpdateWidget(covariant ServerAccountCharactersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.registrationId != oldWidget.registrationId ||
        !identical(widget.repository, oldWidget.repository) ||
        !identical(widget.session, oldWidget.session)) {
      viewModel.dispose();
      viewModel = ServerAccountReadViewModel(
        widget.repository,
        widget.session,
        registrationId: widget.registrationId,
        onRoster: widget.powers?.store,
      );
    }
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('원정대 캐릭터')),
        actions: [
          IconButton(
            tooltip: '캐릭터 다시 조회',
            onPressed: viewModel.canRead && !viewModel.loading
                ? viewModel.load
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !viewModel.canRead
          ? Center(
              child: TextButton(
                onPressed: widget.onLogin,
                child: const Text('로그인 후 조회할 수 있습니다.'),
              ),
            )
          : viewModel.loading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.failure != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: AccountReadFailure(failure: viewModel.failure!),
            )
          : viewModel.roster == null
          ? const SizedBox.shrink()
          : _roster(),
    ),
  );

  Widget _roster() {
    final roster = viewModel.roster!;
    final settings = roster.settings;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (roster.ownershipStatus == 'owned')
          if (widget.powers case final powers?)
            ServerPowerControls(
              model: powers,
              onRefresh: () async {
                await powers.refreshServerRoster(
                  widget.registrationId,
                  viewModel.roster!.characters,
                );
                if (mounted) await viewModel.load();
              },
            ),
        if (serverOwnershipLabel(roster.ownershipStatus).isNotEmpty)
          Text(serverOwnershipLabel(roster.ownershipStatus)),
        if (serverConfigurationLabel(settings.configurationState).isNotEmpty)
          Text(serverConfigurationLabel(settings.configurationState)),
        Text('선택한 활동 캐릭터 ${settings.activityCharacterIds.length}명'),
        if (settings.ineligibleCharacterIds.isNotEmpty)
          const Text('확인이 필요한 캐릭터가 있습니다. 기존 선택은 보존되며 현재 사용 자격이 제한됩니다.'),
        if (settings.nextChangeAt != null)
          Text(
            '대표 변경 가능 시각: ${localDateTimeToSeconds(settings.nextChangeAt!)}',
          ),
        const SizedBox(height: 12),
        if (roster.characters.isEmpty) const Text('조회된 캐릭터가 없습니다.'),
        for (final character in rosterByItemLevel(
          roster.characters,
          (c) => c.itemLevel,
        ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(character.characterName),
            subtitle: Text(
              '${character.serverName} · ${character.className}\n'
              '아이템 레벨 ${DisplayNumberFormatter.whole(character.itemLevel)}'
              '${roster.ownershipStatus != 'owned' ? '\n소유 인증 후 상세 확인 가능' : ' · 전투력 ${DisplayNumberFormatter.whole(character.combatPower)}${character.powerStale ? ' (최근 확인 필요)' : ''}\n${character.power.displayState}${character.powerFetchedAt == null ? '' : ' · ${localDateTimeToSeconds(character.powerFetchedAt!)}'}'}\n'
              '${_status(character.rosterStatus)}'
              '${character.eligible ? '' : ' · 현재 활동 조건 미충족'}'
              '${character.requiresRefresh ? ' · 정보 갱신 필요' : ''}',
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (character.characterId != null &&
                    character.characterId == settings.representativeCharacterId)
                  const Text('대표'),
                if (character.characterId != null &&
                    settings.activityCharacterIds.contains(
                      character.characterId,
                    ))
                  const Text('활동 선택'),
              ],
            ),
          ),
      ],
    );
  }

  String _status(String state) => switch (state) {
    'confirmed' => '원정대 소속 확인',
    'suspect' => '누락 의심 · 재확인 필요',
    'missing' => '최근 원정대에서 누락',
    _ => '미인증 미리보기',
  };
}
