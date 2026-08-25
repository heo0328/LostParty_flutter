import 'package:flutter/material.dart';

import '../../../../shared/widgets/clearable_text_form_field.dart';

import '../../../../shared/lost_ark_api/auth/api_token.dart';
import '../../../../shared/lost_ark_api/auth/api_token_store.dart';

class ApiTokenSettingsPage extends StatefulWidget {
  const ApiTokenSettingsPage({required this.apiTokenStore, super.key});

  final ApiTokenStore apiTokenStore;

  @override
  State<ApiTokenSettingsPage> createState() => _ApiTokenSettingsPageState();
}

class _ApiTokenSettingsPageState extends State<ApiTokenSettingsPage> {
  final _tokenController = TextEditingController();

  bool _isLoading = true;
  bool _hasStoredToken = false;
  bool _isSaving = false;
  bool _obscureToken = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadTokenStatus();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadTokenStatus() async {
    final hasStoredToken = await widget.apiTokenStore.read() != null;
    if (!mounted) {
      return;
    }

    setState(() {
      _hasStoredToken = hasStoredToken;
      _isLoading = false;
    });
  }

  Future<void> _saveToken() async {
    ApiToken token;
    try {
      token = ApiToken(_tokenController.text);
    } on FormatException {
      setState(() {
        _errorText = '토큰을 입력해 주세요.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    await widget.apiTokenStore.write(token);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('API 토큰을 삭제할까요?'),
        content: const Text(
          '토큰을 삭제하면 계정 데이터 조회와 게임계정 인증 등 '
          'Lost Ark API를 사용하는 기능이 정상 작동하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });
    await widget.apiTokenStore.delete();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API 토큰')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text(
                _hasStoredToken ? '토큰 등록됨' : '토큰 미등록',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ClearableTextFormField(
                fieldKey: const ValueKey('apiTokenField'),
                controller: _tokenController,
                obscureText: _obscureToken,
                autocorrect: false,
                enableSuggestions: false,
                labelText: _hasStoredToken ? '새 토큰' : 'JWT 토큰',
                errorText: _errorText,
                border: const OutlineInputBorder(),
                trailing: IconButton(
                  tooltip: _obscureToken ? '토큰 표시' : '토큰 숨기기',
                  onPressed: () {
                    setState(() {
                      _obscureToken = !_obscureToken;
                    });
                  },
                  icon: Icon(
                    _obscureToken ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
                onSubmitted: (_) => _isSaving ? null : _saveToken(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveToken,
                icon: const Icon(Icons.save_outlined),
                label: Text(_hasStoredToken ? '토큰 변경' : '토큰 저장'),
              ),
              if (_hasStoredToken) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isSaving ? null : _deleteToken,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('토큰 삭제'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
