import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../../../shared/widgets/clearable_text_form_field.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/weekly_raid_claim_command.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/character_weekly_raid_display_repository.dart';
import '../../domain/repositories/weekly_raid_claim_repository.dart';
import '../../domain/repositories/weekly_raid_claim_command_repository.dart';
import '../../domain/services/character_summary_sync_service.dart';
import '../../domain/services/representative_character_sync_service.dart';
import '../../domain/services/weekly_raid_display_projector.dart';
import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';
import '../models/weekly_raid_status_item.dart';
import '../viewmodels/my_account_view_model.dart';
import '../widgets/account_character_card.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({
    required this.apiTokenStore,
    required this.accountRepository,
    this.summarySyncService,
    this.representativeSyncService,
    this.weeklyRaidClaimRepository,
    this.raidCatalogRepository,
    this.weeklyRaidDisplayRepository,
    this.playerId,
    this.cycleKey,
    this.cycleStartedAt,
    this.cycleEndsAt,
    this.weeklyRaidClaimCommandRepository,
    super.key,
  });

  final ApiTokenStore apiTokenStore;
  final AccountRepository accountRepository;
  final CharacterSummarySyncService? summarySyncService;
  final RepresentativeCharacterSyncService? representativeSyncService;
  final WeeklyRaidClaimRepository? weeklyRaidClaimRepository;
  final RaidCatalogRepository? raidCatalogRepository;
  final CharacterWeeklyRaidDisplayRepository? weeklyRaidDisplayRepository;
  final String? playerId;
  final String? cycleKey;
  final DateTime? cycleStartedAt;
  final DateTime? cycleEndsAt;
  final WeeklyRaidClaimCommandRepository? weeklyRaidClaimCommandRepository;

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final _characterNameController = TextEditingController();
  late final MyAccountViewModel _viewModel;

  String? _characterNameError;

  @override
  void initState() {
    super.initState();
    _viewModel = MyAccountViewModel(
      apiTokenStore: widget.apiTokenStore,
      accountRepository: widget.accountRepository,
      summarySyncService: widget.summarySyncService,
      representativeSyncService: widget.representativeSyncService,
      weeklyRaidClaimRepository: widget.weeklyRaidClaimRepository,
      raidCatalogRepository: widget.raidCatalogRepository,
      weeklyRaidDisplayRepository: widget.weeklyRaidDisplayRepository,
      playerId: widget.playerId,
      cycleKey: widget.cycleKey,
      cycleStartedAt: widget.cycleStartedAt,
      cycleEndsAt: widget.cycleEndsAt,
      weeklyRaidClaimCommandRepository: widget.weeklyRaidClaimCommandRepository,
    );
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _characterNameController.dispose();
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    _prefillLookupCharacterNameIfNeeded();
    if (mounted) {
      setState(() {});
    }
  }

  void _prefillLookupCharacterNameIfNeeded() {
    if (_characterNameController.text.trim().isNotEmpty) {
      return;
    }
    final name = _mainRepresentativeCharacterName(_viewModel.mainAccount);
    if (name == null || name.isEmpty) {
      return;
    }
    _characterNameController.text = name;
  }

  String? _mainRepresentativeCharacterName(LocalGameAccount? account) {
    if (account == null) {
      return null;
    }
    final representativeId = account.representativeCharacterId;
    if (representativeId != null) {
      for (final character in account.characters) {
        if (character.id == representativeId && !character.isRosterMissing) {
          return character.characterName;
        }
      }
    }
    final lookupName = account.lookupCharacterName.trim();
    return lookupName.isEmpty ? null : lookupName;
  }

  Future<void> _openTokenSettings() async {
    await context.push('/settings/api-token');
    await _viewModel.loadTokenStatus();
  }

  Future<void> _openGameAccountVerification() async {
    await context.push('/settings/game-account-verification');
    await _viewModel.loadStoredAccount();
  }

  Future<void> _openCharacterManagement(LocalGameAccount account) async {
    await context.push('/account/characters/manage', extra: account.id);
    await _viewModel.loadStoredAccount();
  }

  Future<void> _showAddAccountDialog() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => const _AddAccountDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _viewModel.addAccount(
        label: result.$1,
        lookupCharacterName: result.$2,
      );
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? '이미 등록된 계정입니다.'
          : '부계정을 추가하지 못했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showEditAccountDialog(LocalGameAccount account) async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (dialogContext) => _EditAccountDialog(account: account),
    );
    if (result == null || !mounted) return;
    try {
      await _viewModel.updateAccount(
        accountId: account.id,
        label: result.$1,
        isMain: result.$2,
      );
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이미 사용 중인 계정 표시명입니다.')));
    }
  }

  Future<void> _confirmDeleteAccount(LocalGameAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('부계정 삭제'),
        content: Text('${account.label}과 저장된 캐릭터 정보를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _viewModel.deleteAccount(account.id);
  }

  Future<void> _confirmDeleteMissingCharacter(
    LocalGameAccount account,
    LocalAccountCharacter character,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('확인되지 않는 캐릭터 삭제'),
        content: Text(
          '${character.characterName} 캐릭터는 최근 원정대 조회에서 확인되지 않았습니다. '
          '로컬 저장 정보도 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _viewModel.deleteMissingCharacter(
      accountId: account.id,
      characterId: character.id,
    );
  }

  Future<void> _openCharacterDetail(LocalAccountCharacter character) async {
    await context.push('/account/characters/${character.id}', extra: character);
    await _viewModel.loadStoredAccount();
  }

  Future<void> _requestAccountData() async {
    if (!_viewModel.hasApiToken) {
      await _showMissingTokenDialog();
      return;
    }

    final characterName = _characterNameController.text.trim();
    if (characterName.isEmpty) {
      setState(() {
        _characterNameError = '조회할 캐릭터명을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _characterNameError = null;
    });

    await _viewModel.fetchCharacters(characterName);
    if (!mounted) {
      return;
    }

    final errorType = _viewModel.errorType;
    if (errorType == LostArkApiErrorType.missingToken) {
      await _viewModel.loadTokenStatus();
      await _showMissingTokenDialog();
    } else if (errorType != null) {
      await _showApiErrorDialog(errorType);
    } else if (_viewModel.serverSyncFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('로컬 정보는 갱신됐지만 서버 반영에 실패했습니다. 다시 새로고침해 주세요.'),
          action: SnackBarAction(
            label: '재시도',
            onPressed: () {
              _requestAccountData();
            },
          ),
        ),
      );
    }
  }

  Future<void> _showMissingTokenDialog() async {
    final shouldRegister = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('API 토큰 필요'),
          content: const Text('계정 데이터를 불러오려면 Lost Ark API 토큰을 등록해야 합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('토큰 등록'),
            ),
          ],
        );
      },
    );

    if (shouldRegister == true && mounted) {
      await _openTokenSettings();
    }
  }

  Future<void> _showApiErrorDialog(LostArkApiErrorType errorType) {
    final message = switch (errorType) {
      LostArkApiErrorType.unauthorized => 'API 토큰이 올바르지 않거나 만료되었습니다.',
      LostArkApiErrorType.notFound => '캐릭터를 찾을 수 없습니다.',
      LostArkApiErrorType.rateLimited => 'API 호출 한도를 초과했습니다. 잠시 후 다시 시도해 주세요.',
      LostArkApiErrorType.timeout => '요청 시간이 초과되었습니다.',
      LostArkApiErrorType.network => '네트워크 연결을 확인해 주세요.',
      LostArkApiErrorType.server => 'Lost Ark API 서버에서 오류가 발생했습니다.',
      LostArkApiErrorType.invalidResponse => 'API 응답을 처리할 수 없습니다.',
      LostArkApiErrorType.cancelled => '요청이 취소되었습니다.',
      _ => '계정 데이터를 불러오지 못했습니다.',
    };

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('계정 조회 실패'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 계정'),
        actions: [
          IconButton(
            key: const ValueKey('myAccountSettingsButton'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_viewModel.isLoadingTokenStatus)
                const LinearProgressIndicator(),
              _buildTokenStatusPanel(context),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const ValueKey('gameAccountVerificationButton'),
                onPressed: _openGameAccountVerification,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('내 게임계정 인증'),
              ),
              const SizedBox(height: 16),
              ClearableTextFormField(
                fieldKey: const ValueKey('representativeCharacterNameField'),
                controller: _characterNameController,
                enabled: !_viewModel.isNetworkBusy,
                textInputAction: TextInputAction.search,
                labelText: '조회 캐릭터명',
                errorText: _characterNameError,
                border: const OutlineInputBorder(),
                onSubmitted: (_) {
                  if (!_viewModel.isNetworkBusy) {
                    _requestAccountData();
                  }
                },
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('loadAccountDataButton'),
                onPressed: _viewModel.isNetworkBusy
                    ? null
                    : _requestAccountData,
                icon: _viewModel.isNetworkBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_download_outlined),
                label: Text(
                  _viewModel.isFetchingCharacters ? '불러오는 중...' : '계정 데이터 불러오기',
                ),
              ),
              if (_viewModel.accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('addSubAccountButton'),
                  onPressed: _viewModel.isNetworkBusy
                      ? null
                      : _showAddAccountDialog,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('부계정 추가'),
                ),
              ],
              if (_viewModel.hasFetchedCharacters) ...[
                const SizedBox(height: 24),
                if (_viewModel.lookupProfile case final profile?) ...[
                  Text(
                    '조회 캐릭터',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    key: const ValueKey('lookupCharacterProfileCard'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.characterName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${profile.serverName} · ${profile.characterClassName} · 전투 Lv. ${profile.characterLevel}',
                          ),
                          const SizedBox(height: 12),
                          Text('아이템 레벨 ${_formatNumber(profile.itemLevel)}'),
                          Text('전투력 ${_formatNumber(profile.combatPower)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
              for (final account in _viewModel.accounts) ...[
                const SizedBox(height: 24),
                Text(
                  account.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(account.isMain ? '본계정' : '부계정'),
                          ),
                          if (account.hasActiveOwnership)
                            const Chip(
                              key: ValueKey('verifiedGameAccountChip'),
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(Icons.verified, size: 16),
                              label: Text('계정 인증 완료'),
                            )
                          else if (account.hasLostOwnership)
                            Chip(
                              key: const ValueKey('lostOwnershipChip'),
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(
                                Icons.gpp_bad_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              label: const Text('인증 상실'),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${account.visibleCharacters.length}/${account.characters.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      tooltip: '계정 수정',
                      onPressed: () => _showEditAccountDialog(account),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '캐릭터 관리',
                      onPressed: () => _openCharacterManagement(account),
                      icon: const Icon(Icons.tune),
                    ),
                    if (!account.isMain)
                      IconButton(
                        key: ValueKey('deleteAccountButton-${account.id}'),
                        tooltip: '부계정 삭제',
                        onPressed: () => _confirmDeleteAccount(account),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                if (_viewModel.canEditWeeklyRaidDisplay) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: ValueKey(
                        'rosterWeeklyRaidDisplayButton-${account.id}',
                      ),
                      onPressed: () => _editRosterWeeklyRaidDisplay(account),
                      icon: const Icon(Icons.checklist_outlined, size: 18),
                      label: const Text('원정대 주간레이드수정'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (account.characters
                    .where((character) => character.isRosterMissing)
                    .isNotEmpty) ...[
                  _buildMissingCharactersWarning(account),
                  const SizedBox(height: 8),
                ],
                _buildCharacterGrid(account),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenStatusPanel(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _viewModel.hasApiToken
                  ? Icons.verified_user_outlined
                  : Icons.key_off_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lost Ark API 토큰',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(_viewModel.hasApiToken ? '등록됨' : '등록 필요'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'API 토큰 설정',
              onPressed: _openTokenSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterGrid(LocalGameAccount account) {
    final characters = account.visibleCharacters;
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final crossAxisCount = switch (constraints.maxWidth) {
          < 600 => 2,
          < 900 => 3,
          _ => 4,
        };
        final itemWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;

        return Wrap(
          key: account.isMain
              ? const ValueKey('mainAccountCharacterGrid')
              : ValueKey('accountCharacterGrid-${account.id}'),
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final character in characters)
              SizedBox(
                width: itemWidth,
                child: AccountCharacterCard(
                  character: character,
                  isRepresentative:
                      account.representativeCharacterId == character.id,
                  weeklyRaids: _viewModel.weeklyRaidStatusesFor(character),
                  showWeeklyRaidEditor:
                      _viewModel.canEditWeeklyRaidDisplay &&
                      character.itemLevel != null,
                  weeklyRaidHiddenByPreference:
                      _viewModel.hasWeeklyRaidDisplayConfigured(character) &&
                      _viewModel.weeklyRaidResolvedCount(character) == 0,
                  busyRaidIds: {
                    for (final raid in _viewModel.weeklyRaidStatusesFor(
                      character,
                    ))
                      if (_viewModel.isClaimCommandBusy(character, raid.raidId))
                        raid.raidId,
                  },
                  onWeeklyRaidChanged:
                      widget.weeklyRaidClaimCommandRepository == null
                      ? null
                      : (raid, value) => _confirmWeeklyRaidChange(
                          character: character,
                          raid: raid,
                          completed: value,
                        ),
                  onEditWeeklyRaids: !_viewModel.canEditWeeklyRaidDisplay
                      ? null
                      : () => _editWeeklyRaidDisplay(character),
                  onTap: () => _openCharacterDetail(character),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _editRosterWeeklyRaidDisplay(LocalGameAccount account) async {
    var displayCount = WeeklyRaidDisplayProjector.defaultDisplayCount;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('원정대 주간 레이드 표시'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '모든 캐릭터에 같은 표시 개수를 적용합니다. '
                      '입장 가능한 레이드가 더 적으면 그만큼만 표시됩니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (
                          var count = 0;
                          count <= WeeklyRaidDisplayProjector.maxDisplayCount;
                          count++
                        )
                          ChoiceChip(
                            key: ValueKey(
                              'rosterWeeklyRaidDisplayCount-$count',
                            ),
                            label: Text('$count'),
                            selected: displayCount == count,
                            onSelected: (_) {
                              setDialogState(() => displayCount = count);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const ValueKey('applyRosterWeeklyRaidDisplayButton'),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(displayCount),
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    final applied = await _viewModel.applyRosterWeeklyRaidDisplayCount(
      account: account,
      displayCount: result,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? '원정대 주간 레이드 표시를 $result개로 맞췄습니다.'
              : '원정대 주간 레이드 표시를 적용하지 못했습니다.',
        ),
      ),
    );
  }

  Future<void> _editWeeklyRaidDisplay(LocalAccountCharacter character) async {
    final eligible = _viewModel.eligibleWeeklyRaidsFor(character);
    if (eligible.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('입장 가능한 주간 레이드가 없습니다.')));
      return;
    }
    final preference = _viewModel.weeklyRaidDisplayPreferenceFor(character);
    final maxCount =
        eligible.length < WeeklyRaidDisplayProjector.maxDisplayCount
        ? eligible.length
        : WeeklyRaidDisplayProjector.maxDisplayCount;
    var displayCount =
        preference?.displayCount ??
        (eligible.length < WeeklyRaidDisplayProjector.defaultDisplayCount
            ? eligible.length
            : WeeklyRaidDisplayProjector.defaultDisplayCount);
    if (displayCount > maxCount) displayCount = maxCount;
    final selected = <String>{
      ...(preference?.raidIds ??
          _viewModel
              .weeklyRaidStatusesFor(character)
              .map((raid) => raid.raidId)),
    };
    selected.removeWhere(
      (raidId) => !eligible.any((candidate) => candidate.raidId == raidId),
    );

    final result = await showDialog<({int count, List<String> raidIds})?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm = selected.length == displayCount;
            return AlertDialog(
              title: const Text('표기 레이드 설정'),
              content: SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '표시 개수',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (var count = 0; count <= maxCount; count++)
                            ChoiceChip(
                              key: ValueKey('weeklyRaidDisplayCount-$count'),
                              label: Text('$count'),
                              selected: displayCount == count,
                              onSelected: (_) {
                                setDialogState(() {
                                  displayCount = count;
                                  while (selected.length > displayCount) {
                                    selected.remove(selected.last);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayCount == 0
                            ? '표시할 레이드를 숨깁니다.'
                            : '레이드를 $displayCount개 선택하세요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (displayCount > 0) ...[
                        const SizedBox(height: 8),
                        for (final candidate in eligible)
                          CheckboxListTile(
                            key: ValueKey(
                              'weeklyRaidDisplayOption-${candidate.raidId}',
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(candidate.label),
                            subtitle: Text(
                              '입장 ${candidate.minItemLevel} · 골드 ${candidate.gold}',
                            ),
                            value: selected.contains(candidate.raidId),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  if (selected.length >= displayCount) return;
                                  selected.add(candidate.raidId);
                                } else {
                                  selected.remove(candidate.raidId);
                                }
                              });
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                if (preference != null)
                  TextButton(
                    key: const ValueKey('resetWeeklyRaidDisplayButton'),
                    onPressed: () => Navigator.of(
                      dialogContext,
                    ).pop((count: -1, raidIds: const <String>[])),
                    child: const Text('기본값'),
                  ),
                FilledButton(
                  key: const ValueKey('saveWeeklyRaidDisplayButton'),
                  onPressed: !canConfirm
                      ? null
                      : () {
                          final ordered = <String>[
                            for (final candidate in eligible)
                              if (selected.contains(candidate.raidId))
                                candidate.raidId,
                          ];
                          Navigator.of(
                            dialogContext,
                          ).pop((count: displayCount, raidIds: ordered));
                        },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    if (result.count < 0) {
      await _viewModel.clearWeeklyRaidDisplayPreference(character);
      return;
    }
    await _viewModel.saveWeeklyRaidDisplayPreference(
      character: character,
      displayCount: result.count,
      raidIds: result.raidIds,
    );
  }

  Future<void> _confirmWeeklyRaidChange({
    required LocalAccountCharacter character,
    required WeeklyRaidStatusItem raid,
    required bool completed,
  }) async {
    ManualWeeklyRaidClaimImpact? impact;
    if (completed) {
      final impactResult = await _viewModel.inspectWeeklyRaidCompletionImpact(
        character: character,
        raid: raid,
      );
      if (!mounted) return;
      if (!impactResult.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_claimFailureMessage(impactResult.failure!))),
        );
        return;
      }
      impact = impactResult.impact;
    }
    final resolveConflicts = impact?.requiresConfirmation == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(completed ? '레이드 완료 처리' : '레이드 완료 해제'),
        content: Text(
          completed
              ? _weeklyRaidCompletionConfirmation(character, raid, impact!)
              : '${character.characterName} 캐릭터의 ${raid.label} 완료를 해제할까요? 이전 파티에는 자동으로 복귀하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              completed && impact!.hasActiveRecruitment
                  ? '탈퇴하고 완료 처리'
                  : '완료 처리',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _viewModel.setWeeklyRaidCompleted(
      character: character,
      raid: raid,
      completed: completed,
      resolveConflicts: resolveConflicts,
    );
    if (!mounted) return;
    final message = result.isSuccess
        ? (completed ? '이번 주 완료로 처리했습니다.' : '완료 처리를 해제했습니다.')
        : _claimFailureMessage(result.failure!);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _weeklyRaidCompletionConfirmation(
    LocalAccountCharacter character,
    WeeklyRaidStatusItem raid,
    ManualWeeklyRaidClaimImpact impact,
  ) {
    final lines = <String>[
      '${character.characterName} 캐릭터의 ${raid.label} 레이드를 이번 주 완료로 처리할까요?',
    ];
    if (impact.hasActiveRecruitment) {
      final title = impact.activeRecruitmentTitle ?? '참가 중인 파티';
      if (impact.willDisbandRecruitment) {
        lines.add('$title에서 탈퇴하면 남은 인원이 없어 모집이 해산됩니다.');
      } else if (impact.isRecruitmentLeader) {
        final nextLeader = impact.nextLeaderCharacterName ?? '다음 파티원';
        lines.add('$title에서 탈퇴하고 책임자가 $nextLeader 캐릭터로 승계됩니다.');
      } else {
        lines.add('$title에서 탈퇴 처리됩니다.');
      }
    }
    if (impact.pendingApplicationCount > 0) {
      lines.add(
        '같은 레이드 승인 대기 신청 ${impact.pendingApplicationCount}건이 함께 종료됩니다.',
      );
    }
    lines.add('완료 해제 시 이전 파티와 신청에는 자동으로 복귀하지 않습니다.');
    return lines.join('\n\n');
  }

  String _claimFailureMessage(WeeklyRaidClaimCommandFailure failure) =>
      switch (failure) {
        WeeklyRaidClaimCommandFailure.activeAssignment =>
          '현재 참가 중인 파티가 있어 완료 처리할 수 없습니다.',
        WeeklyRaidClaimCommandFailure.pendingApplication =>
          '승인 대기 중인 신청이 있어 먼저 철회해야 합니다.',
        WeeklyRaidClaimCommandFailure.unauthenticated => '로그인 상태를 다시 확인해 주세요.',
        WeeklyRaidClaimCommandFailure.permissionDenied =>
          '완료 상태를 변경할 권한이 없습니다.',
        WeeklyRaidClaimCommandFailure.temporarilyUnavailable =>
          '현재 처리할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        WeeklyRaidClaimCommandFailure.invalidRequest =>
          '캐릭터 또는 주차 정보를 확인할 수 없어 완료 상태를 변경하지 못했습니다.',
        WeeklyRaidClaimCommandFailure.unknown =>
          '서버 처리 중 오류가 발생해 완료 상태를 변경하지 못했습니다.',
      };

  Widget _buildMissingCharactersWarning(LocalGameAccount account) {
    final missing = account.characters
        .where((character) => character.isRosterMissing)
        .toList(growable: false);
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded),
                SizedBox(width: 8),
                Expanded(child: Text('최근 원정대에서 확인되지 않는 캐릭터가 있습니다.')),
              ],
            ),
            for (final character in missing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(character.characterName),
                subtitle: Text(character.serverName),
                trailing: TextButton(
                  key: ValueKey('deleteMissingCharacter-${character.id}'),
                  onPressed: () =>
                      _confirmDeleteMissingCharacter(account, character),
                  child: const Text('삭제'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '-';
    }

    return DisplayNumberFormatter.fixed(value);
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _labelController = TextEditingController();
  final _characterController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('부계정 추가'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClearableTextFormField(
          fieldKey: const ValueKey('accountLabelField'),
          controller: _labelController,
          labelText: '계정 표시명',
          hintText: '비워두면 부계정1처럼 자동 지정',
          helperText: '같은 이름이 있으면 다음 번호를 사용합니다.',
        ),
        ClearableTextFormField(
          fieldKey: const ValueKey('subAccountCharacterNameField'),
          controller: _characterController,
          labelText: '조회 캐릭터명',
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () {
          final label = _labelController.text.trim();
          final character = _characterController.text.trim();
          if (character.isNotEmpty) {
            Navigator.pop(context, (label, character));
          }
        },
        child: const Text('추가'),
      ),
    ],
  );
}

class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({required this.account});

  final LocalGameAccount account;

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  late final TextEditingController _labelController;
  late bool _makeMain;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.account.label);
    _makeMain = widget.account.isMain;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('계정 수정'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClearableTextFormField(
          fieldKey: const ValueKey('editAccountLabelField'),
          controller: _labelController,
          labelText: '계정 표시명',
          helperText: '비워두면 현재 이름을 유지합니다.',
        ),
        SwitchListTile(
          key: const ValueKey('mainAccountSwitch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('본계정으로 설정'),
          value: _makeMain,
          onChanged: widget.account.isMain
              ? null
              : (value) => setState(() => _makeMain = value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: () {
          final label = _labelController.text.trim();
          Navigator.pop(context, (label, _makeMain));
        },
        child: const Text('저장'),
      ),
    ],
  );
}
