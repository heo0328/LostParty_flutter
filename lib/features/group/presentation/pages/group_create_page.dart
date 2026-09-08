import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/presentation/server_account_mismatch_alert.dart';
import '../../domain/entities/group_create_command.dart';
import '../../domain/entities/group_create_result.dart';
import '../viewmodels/group_create_view_model.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({required this.viewModel, super.key});

  final GroupCreateViewModel viewModel;

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  List<GroupCharacterOption> _characters = const [];
  GroupCharacterOption? _selected;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final characters = await widget.viewModel.loadAuthenticatedCharacters();
      if (!mounted) return;
      setState(() {
        _characters = characters;
        _selected = characters.firstOrNull;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = '인증된 캐릭터 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('그룹 만들기')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : _characters.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '게임 계정 인증이 완료된 캐릭터가 없습니다. 내 계정에서 인증을 먼저 진행해 주세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Form(key: _formKey, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final selected = _selected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _characterSelector(context),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('groupNameField'),
          controller: _name,
          maxLength: GroupCreateCommand.maxNameLength,
          decoration: InputDecoration(
            labelText: '그룹 이름 (선택)',
            border: const OutlineInputBorder(),
            helperText: selected == null
                ? null
                : '미입력 시 ${widget.viewModel.defaultNameFor(selected)}',
          ),
          validator: (value) => widget.viewModel.isValidName(value ?? '')
              ? null
              : '그룹 이름은 줄바꿈 없이 1~20자로 입력해 주세요.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('groupCreateSubmitButton'),
          onPressed: _saving || selected == null ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('그룹 생성'),
        ),
      ],
    );
  }

  Widget _characterSelector(BuildContext context) {
    final selected = _selected;
    return InkWell(
      key: const ValueKey('groupRepresentativeSelector'),
      onTap: _showCharacters,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '대표 캐릭터',
          border: const OutlineInputBorder(),
          errorText: selected == null ? '대표 캐릭터를 선택해 주세요.' : null,
          suffixIcon: const Icon(Icons.expand_more),
        ),
        child: Text(
          selected == null
              ? '캐릭터 선택'
              : '${selected.characterName} · ${selected.serverName} · ${selected.className}',
        ),
      ),
    );
  }

  Future<void> _showCharacters() async {
    final selected = await showModalBottomSheet<GroupCharacterOption>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('대표 캐릭터 선택', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final option in _characters)
                ListTile(
                  key: ValueKey('groupCharacter-${option.serverCharacterId}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text('${option.characterName} · ${option.className}'),
                  subtitle: Text(
                    '${option.accountLabel}${option.isMainAccount ? ' · 본계정' : ' · 부계정'} · ${option.serverName}',
                  ),
                  trailing: option.isRepresentative
                      ? const Chip(label: Text('대표'))
                      : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selected = selected);
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final selected = _selected;
    if (selected == null) return;
    setState(() => _saving = true);
    final result = await widget.viewModel.create(
      character: selected,
      name: _name.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isSuccess) {
      context.pushReplacement('/groups/${result.groupId}');
      return;
    }
    final failure = result.failure!;
    if (_isServerAccountMismatch(failure)) {
      await showServerAccountMismatchAlert(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(groupCreateFailureMessage(failure))),
    );
  }
}

bool _isServerAccountMismatch(GroupCreateFailure failure) => switch (failure) {
  GroupCreateFailure.unauthenticated ||
  GroupCreateFailure.playerBindingMissing ||
  GroupCreateFailure.serverDataMissing ||
  GroupCreateFailure.ownershipLost => true,
  _ => false,
};
