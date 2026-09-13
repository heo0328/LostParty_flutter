import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/game_account_verification.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/entities/server_account_identity_binding.dart';
import '../../domain/repositories/account_identity_gateway.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/game_account_verification_gateway.dart';

class GameAccountVerificationPage extends StatefulWidget {
  const GameAccountVerificationPage({
    required this.accountRepository,
    required this.accountManagementRepository,
    required this.mappingRepository,
    required this.gateway,
    super.key,
  });

  final AccountRepository accountRepository;
  final AccountManagementRepository accountManagementRepository;
  final AccountIdentityMappingRepository mappingRepository;
  final GameAccountVerificationGateway gateway;

  @override
  State<GameAccountVerificationPage> createState() =>
      _GameAccountVerificationPageState();
}

class _GameAccountVerificationPageState
    extends State<GameAccountVerificationPage> {
  final _directController = TextEditingController();
  List<LocalGameAccount> _accounts = const [];
  LocalGameAccount? _selectedAccount;
  LocalAccountCharacter? _selectedCharacter;
  GameAccountVerificationChallenge? _challenge;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _challenge = widget.gateway.activeChallenge;
    _loadAccounts();
  }

  @override
  void dispose() {
    _directController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final accounts = await widget.accountRepository.loadAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _selectedAccount = accounts.firstOrNull;
      _selectedCharacter = accounts.firstOrNull?.characters.firstOrNull;
    });
  }

  Future<void> _start({required bool direct}) async {
    final characterName = direct
        ? _directController.text.trim()
        : _selectedCharacter?.characterName ?? '';
    if (characterName.isEmpty) {
      setState(() => _message = '인증할 캐릭터를 선택하거나 입력해 주세요.');
      return;
    }
    final matchingAccount = direct
        ? _findAccount(characterName)
        : _selectedAccount;
    await _run(() async {
      final challenge = await widget.gateway.start(
        characterName: characterName,
        source: direct ? 'directInput' : 'provisional',
        localAccountId: matchingAccount?.id,
      );
      setState(() {
        _selectedAccount = matchingAccount;
        _challenge = challenge;
        _message = null;
      });
    });
  }

  Future<void> _confirm() async {
    final challenge = _challenge;
    if (challenge == null) return;
    await _run(() async {
      final result = await widget.gateway.confirm(challenge.challengeId);
      if (result.status == 'verified') {
        await _saveBinding(
          result,
          verifiedCharacterName: challenge.characterName,
        );
        setState(() {
          _challenge = null;
          _message = '게임 계정 인증과 로컬 연결이 완료되었습니다.';
        });
        return;
      }
      setState(() => _message = _resultMessage(result));
    });
  }

  Future<void> _saveBinding(
    GameAccountVerificationResult result, {
    required String verifiedCharacterName,
  }) async {
    var account = _selectedAccount;
    final accountId = result.serverGameAccountId;
    if (accountId == null) {
      throw const FormatException('Missing server game account ID.');
    }
    if (account == null) {
      account = await widget.accountManagementRepository.addAccount(
        label: '인증 계정',
        lookupCharacterName: verifiedCharacterName,
      );
      _selectedAccount = account;
      _accounts = [..._accounts, account];
    }
    final remoteByKey = {
      for (final character in result.serverCharacters)
        '${character.serverName}\u0000${character.characterName}':
            character.serverCharacterId,
    };
    final mapping = <int, String>{};
    for (final character in account.characters) {
      final serverId =
          remoteByKey['${character.serverName}\u0000${character.characterName}'];
      if (serverId == null) {
        throw StateError('서버 캐릭터 목록과 로컬 계정이 일치하지 않습니다.');
      }
      mapping[character.id] = serverId;
    }
    await widget.mappingRepository.bindServerIdentity(
      ServerAccountIdentityBinding(
        localAccountId: account.id,
        serverGameAccountId: accountId,
        serverCharacterIdsByLocalId: mapping,
      ),
    );
    // 바인딩 직후 Drift를 다시 읽어 같은 세션의 신청/생성 후보에 즉시 반영한다.
    final boundAccountId = account.id;
    final refreshed = await widget.accountRepository.loadAccounts();
    if (!mounted) return;
    final matched = refreshed
        .where((item) => item.id == boundAccountId)
        .firstOrNull;
    setState(() {
      _accounts = refreshed;
      _selectedAccount = matched ?? account;
      _selectedCharacter =
          matched?.characters.firstOrNull ?? _selectedCharacter;
    });
  }

  LocalGameAccount? _findAccount(String characterName) {
    for (final account in _accounts) {
      if (account.characters.any(
        (character) => character.characterName == characterName,
      )) {
        return account;
      }
    }
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on GameAccountVerificationStartException catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error.failure) {
            GameAccountVerificationStartFailure.incompleteEquipment =>
              '인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.',
          },
        );
      }
    } on LostArkApiException catch (error) {
      if (mounted) {
        setState(() => _message = _apiErrorMessage(error.type));
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        setState(
          () => _message = error.code == 'permission-denied'
              ? 'Firebase 인증 권한이 없습니다. 앱을 다시 시작해 로그인 상태를 확인해 주세요.'
              : 'Firebase 계정 정보를 저장하지 못했습니다. 네트워크 연결을 확인해 주세요.',
        );
      }
    } on FormatException {
      if (mounted) {
        setState(() => _message = '캐릭터 또는 장비 정보를 처리할 수 없습니다.');
      }
    } on Object {
      if (mounted) {
        setState(() => _message = '인증 요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _apiErrorMessage(LostArkApiErrorType type) => switch (type) {
    LostArkApiErrorType.missingToken => '먼저 Lost Ark API 토큰을 등록해 주세요.',
    LostArkApiErrorType.unauthorized => 'Lost Ark API 토큰이 올바르지 않거나 만료되었습니다.',
    LostArkApiErrorType.notFound => '캐릭터를 찾을 수 없습니다.',
    LostArkApiErrorType.rateLimited => 'API 호출 한도를 초과했습니다. 잠시 후 다시 시도해 주세요.',
    LostArkApiErrorType.timeout => 'Lost Ark API 응답 시간이 초과되었습니다.',
    LostArkApiErrorType.network => '네트워크 연결을 확인해 주세요.',
    LostArkApiErrorType.server => 'Lost Ark API 서버에서 오류가 발생했습니다.',
    _ => 'Lost Ark API 응답을 처리하지 못했습니다.',
  };

  String _resultMessage(GameAccountVerificationResult result) =>
      switch (result.status) {
        'requiredSlotsStillEquipped' => '지정된 장비가 아직 장착되어 있습니다.',
        'unchallengedSlotChanged' => '지정되지 않은 장비가 변경되었습니다. 원래 장비로 복구해 주세요.',
        'invalidEquipmentSnapshot' => '장비 정보가 아직 갱신되지 않았습니다.',
        'expired' => '인증 시간이 만료되었습니다. 새로 시작해 주세요.',
        _ => '인증 상태를 확인할 수 없습니다.',
      };

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Scaffold(
      appBar: AppBar(title: const Text('내 게임계정 인증')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '가등록 캐릭터 선택',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LocalGameAccount>(
            initialValue: _selectedAccount,
            decoration: const InputDecoration(
              labelText: '게임 계정',
              border: OutlineInputBorder(),
            ),
            items: _accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account,
                    child: Text(account.label),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (account) => setState(() {
                    _selectedAccount = account;
                    _selectedCharacter = account?.characters.firstOrNull;
                  }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LocalAccountCharacter>(
            key: ValueKey(_selectedAccount?.id),
            initialValue: _selectedCharacter,
            decoration: const InputDecoration(
              labelText: '인증 캐릭터',
              border: OutlineInputBorder(),
            ),
            items: (_selectedAccount?.characters ?? const [])
                .map(
                  (character) => DropdownMenuItem(
                    value: character,
                    child: Text(
                      '${character.characterName} · ${character.serverName}',
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (character) => setState(() => _selectedCharacter = character),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || _selectedCharacter == null
                ? null
                : () => _start(direct: false),
            child: const Text('선택한 캐릭터로 인증'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          const Text(
            '또는 캐릭터명 직접 입력',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('verificationDirectCharacterField'),
            controller: _directController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: '캐릭터명',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : () => _start(direct: true),
            child: const Text('직접 입력으로 인증'),
          ),
          if (challenge != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${challenge.characterName} 인증 진행 중',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '다음 장비를 해제하세요: ${challenge.requiredUnequippedSlots.map(_slotLabel).join(', ')}',
                    ),
                    Text(
                      '만료: ${TimeOfDay.fromDateTime(challenge.expiresAt.toLocal()).format(context)}',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '장비 변경 후 캐릭터 선택 화면으로 이동하거나 접속을 한 번 종료해야 API 정보가 갱신됩니다.',
                    ),
                    const SizedBox(height: 8),
                    const Text('앱이 종료되면 남은 시간과 관계없이 현재 인증 시도가 종료됩니다.'),
                    const Text(
                      '원정대 인증은 인게임에서 장비를 바로 조작할 수 있는 상황에서 진행하는 것을 권장합니다.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : _confirm,
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('장비 변경 확인'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
        ],
      ),
    );
  }
}

String _slotLabel(String slot) =>
    const {
      'weapon': '무기',
      'head': '머리',
      'shoulders': '어깨',
      'chest': '상의',
      'legs': '하의',
      'hands': '장갑',
    }[slot] ??
    slot;
