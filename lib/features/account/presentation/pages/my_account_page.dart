import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../viewmodels/my_account_view_model.dart';
import '../widgets/account_character_card.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({
    required this.apiTokenStore,
    required this.accountRepository,
    super.key,
  });

  final ApiTokenStore apiTokenStore;
  final AccountRepository accountRepository;

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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openTokenSettings() async {
    await context.push('/account/api-token');
    await _viewModel.loadTokenStatus();
  }

  Future<void> _openCharacterManagement() async {
    await context.push('/account/characters/manage');
    await _viewModel.loadStoredAccount();
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
      appBar: AppBar(title: const Text('내 계정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_viewModel.isLoadingTokenStatus)
              const LinearProgressIndicator(),
            _buildTokenStatusPanel(context),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('representativeCharacterNameField'),
              controller: _characterNameController,
              enabled: !_viewModel.isFetchingCharacters,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '조회 캐릭터명',
                errorText: _characterNameError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!_viewModel.isFetchingCharacters) {
                  _requestAccountData();
                }
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('loadAccountDataButton'),
              onPressed: _viewModel.isFetchingCharacters
                  ? null
                  : _requestAccountData,
              icon: _viewModel.isFetchingCharacters
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: const Text('계정 데이터 불러오기'),
            ),
            if (_viewModel.hasFetchedCharacters) ...[
              const SizedBox(height: 24),
              if (_viewModel.lookupProfile case final profile?) ...[
                Text('조회 캐릭터', style: Theme.of(context).textTheme.titleMedium),
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
            if (_viewModel.mainAccount case final account?) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      account.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${account.visibleCharacters.length}/${account.characters.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: '캐릭터 관리',
                    onPressed: _openCharacterManagement,
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCharacterGrid(account),
            ],
          ],
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
        final crossAxisCount = switch (constraints.maxWidth) {
          < 600 => 2,
          < 900 => 3,
          _ => 4,
        };

        return GridView.builder(
          key: const ValueKey('mainAccountCharacterGrid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: characters.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) {
            final character = characters[index];
            return AccountCharacterCard(
              character: character,
              isRepresentative:
                  account.representativeCharacterId == character.id,
              onTap: () => _openCharacterDetail(character),
            );
          },
        );
      },
    );
  }

  String _formatNumber(double? value) {
    if (value == null) {
      return '-';
    }

    return value.toStringAsFixed(2);
  }
}
