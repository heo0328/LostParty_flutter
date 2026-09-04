import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/group_character_options.dart';
import '../viewmodels/group_join_code_view_model.dart';
import '../widgets/group_character_refresh_guard.dart';

/// 계약 §8.7. 정확한 초대코드와 인증 Character로 즉시 가입한다.
class GroupJoinByCodePage extends StatefulWidget {
  const GroupJoinByCodePage({
    required this.viewModel,
    super.key,
  });

  final GroupJoinByCodeViewModel viewModel;

  @override
  State<GroupJoinByCodePage> createState() => _GroupJoinByCodePageState();
}

class _GroupJoinByCodePageState extends State<GroupJoinByCodePage> {
  final _codeController = TextEditingController();
  GroupCharacterOption? _character;
  List<GroupCharacterOption>? _options;
  bool _busy = false;
  String? _message;
  int _selectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    try {
      final options = await widget.viewModel.loadAuthenticatedCharacters();
      if (!mounted) return;
      setState(() {
        _options = options;
        _character = options.isEmpty ? null : options.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options = const [];
        _message = '인증 캐릭터를 불러오지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      appBar: AppBar(title: const Text('초대코드로 가입')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const ValueKey('groupJoinByCodeField'),
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '초대코드',
              helperText: '공백 없이 받은 코드를 그대로 입력하세요.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (options == null)
            const Center(child: CircularProgressIndicator())
          else if (options.isEmpty)
            const Text('인증한 캐릭터가 없습니다. 내 계정에서 캐릭터를 인증해 주세요.')
          else
            DropdownButtonFormField<GroupCharacterOption>(
              key: const ValueKey('groupJoinByCodeCharacter'),
              // ignore: deprecated_member_use
              value: _character,
              decoration: const InputDecoration(
                labelText: '표시 캐릭터',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(
                      '${option.characterName} · ${option.serverName}',
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _character = value),
            ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('groupJoinByCodeSubmit'),
            onPressed: _busy || _character == null ? null : _join,
            icon: const Icon(Icons.login),
            label: const Text('가입하기'),
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    final character = _character;
    if (character == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final generation = ++_selectionGeneration;
    final refresh = await widget.viewModel.ensureFresh(
      character,
      generation: generation,
    );
    if (!mounted ||
        !await confirmGroupCharacterRefresh(
          context,
          refresh,
          characterId: character.localCharacterId,
          generation: _selectionGeneration,
        )) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final result = await widget.viewModel.join(
      code: _codeController.text,
      character: character,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.failure != null) {
      final message = groupJoinCodeFailureMessage(result.failure!);
      setState(() => _message = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('그룹에 가입했습니다.')));
    context.go('/groups');
  }
}
