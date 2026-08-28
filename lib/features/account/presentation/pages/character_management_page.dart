import 'package:flutter/material.dart';

import '../../../../shared/formatters/display_number_formatter.dart';

import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/representative_character_sync_gateway.dart';
import '../viewmodels/character_management_view_model.dart';

class CharacterManagementPage extends StatefulWidget {
  const CharacterManagementPage({
    required this.accountRepository,
    this.representativeSyncGateway,
    this.accountId,
    super.key,
  });

  final AccountRepository accountRepository;
  final RepresentativeCharacterSyncGateway? representativeSyncGateway;
  final int? accountId;

  @override
  State<CharacterManagementPage> createState() =>
      _CharacterManagementPageState();
}

class _CharacterManagementPageState extends State<CharacterManagementPage> {
  late final CharacterManagementViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = CharacterManagementViewModel(
      accountRepository: widget.accountRepository,
      representativeSyncGateway: widget.representativeSyncGateway,
      accountId: widget.accountId,
    )..addListener(_onChanged);
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = _viewModel.account;
    return Scaffold(
      appBar: AppBar(title: const Text('캐릭터 관리')),
      body: SafeArea(
        child: switch ((_viewModel.isLoading, account)) {
          (true, _) => const Center(child: CircularProgressIndicator()),
          (false, null) => const Center(child: Text('저장된 계정이 없습니다.')),
          (false, final account?) => _buildContent(account),
        },
      ),
    );
  }

  Widget _buildContent(LocalGameAccount account) {
    return Column(
      children: [
        if (_viewModel.isSaving) const LinearProgressIndicator(),
        if (_viewModel.representativeMessage case final message?)
          _RepresentativeNotice(icon: Icons.error_outline, message: message)
        else if (_viewModel.representativeCooldownLabel case final label?)
          _RepresentativeNotice(icon: Icons.schedule, message: label),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(child: Text('메인 화면 표시 개수')),
              IconButton(
                tooltip: '표시 개수 줄이기',
                onPressed: _viewModel.isSaving || account.displayLimit <= 1
                    ? null
                    : () => _viewModel.changeDisplayLimit(-1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${account.displayLimit}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '표시 개수 늘리기',
                onPressed:
                    _viewModel.isSaving ||
                        account.displayLimit >= account.characters.length
                    ? null
                    : () => _viewModel.changeDisplayLimit(1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _viewModel.characters.length,
            onReorder: _viewModel.isSaving ? (_, _) {} : _viewModel.reorder,
            itemBuilder: (context, index) {
              final character = _viewModel.characters[index];
              return _CharacterManagementTile(
                key: ValueKey(character.id),
                character: character,
                isRepresentative:
                    account.representativeCharacterId == character.id,
                isEnabled: !_viewModel.isSaving,
                isRepresentativeEnabled: _viewModel.canSetRepresentative(
                  character,
                ),
                onVisibilityChanged: (value) => _viewModel
                    .setCharacterVisibility(character, value ?? false),
                onSetRepresentative: () =>
                    _viewModel.setRepresentative(character),
                dragHandle: ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CharacterManagementTile extends StatelessWidget {
  const _CharacterManagementTile({
    required this.character,
    required this.isRepresentative,
    required this.isEnabled,
    required this.isRepresentativeEnabled,
    required this.onVisibilityChanged,
    required this.onSetRepresentative,
    required this.dragHandle,
    super.key,
  });

  final LocalAccountCharacter character;
  final bool isRepresentative;
  final bool isEnabled;
  final bool isRepresentativeEnabled;
  final ValueChanged<bool?> onVisibilityChanged;
  final VoidCallback onSetRepresentative;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: character.isVisible,
        onChanged: isEnabled ? onVisibilityChanged : null,
      ),
      title: Text(character.characterName),
      subtitle: Text(
        '${character.characterClassName} · ${_formatItemLevel(character.itemLevel)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isRepresentative ? '현재 대표 캐릭터' : '대표 캐릭터로 설정',
            onPressed: isRepresentativeEnabled ? onSetRepresentative : null,
            icon: Icon(isRepresentative ? Icons.star : Icons.star_border),
          ),
          dragHandle,
        ],
      ),
    );
  }

  String _formatItemLevel(double? value) {
    return value == null
        ? '아이템 Lv. -'
        : '아이템 Lv. ${DisplayNumberFormatter.fixed(value)}';
  }
}

class _RepresentativeNotice extends StatelessWidget {
  const _RepresentativeNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
