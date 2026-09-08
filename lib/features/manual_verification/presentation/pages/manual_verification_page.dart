import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../account/domain/character_identity_key.dart';
import '../../../account/domain/entities/game_account_verification.dart';
import '../../../account/domain/entities/local_game_account.dart';
import '../../../account/domain/entities/server_account_identity_binding.dart';
import '../../../account/domain/repositories/account_identity_gateway.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../domain/entities/manual_verification_request.dart';
import '../../domain/repositories/manual_verification_repository.dart';

class ManualVerificationPage extends StatefulWidget {
  const ManualVerificationPage({
    required this.accountRepository,
    required this.mappingRepository,
    required this.repository,
    this.onOpenUri,
    super.key,
  });

  final AccountRepository accountRepository;
  final AccountIdentityMappingRepository mappingRepository;
  final ManualVerificationRepository repository;
  final Future<bool> Function(Uri uri)? onOpenUri;

  @override
  State<ManualVerificationPage> createState() => _ManualVerificationPageState();
}

class _ManualVerificationPageState extends State<ManualVerificationPage> {
  static const instruction =
      '선택한 캐릭터로 게임에 접속한 뒤 일반 채팅에 인증 코드를 입력하세요. '
      '캐릭터명과 채팅 내용이 함께 보이도록 게임 화면 전체를 촬영하여 '
      '아래 오픈채팅방으로 보내주세요.';
  static final openChatUri = Uri.parse('https://open.kakao.com/o/sT9XQ2Ki');

  List<LocalGameAccount> _accounts = const [];
  LocalGameAccount? _selectedAccount;
  LocalAccountCharacter? _selectedCharacter;
  bool _busy = false;
  String? _message;
  final _boundRequestIds = <String>{};
  var _localRequests = <ManualVerificationRequest>[];
  late final Stream<List<ManualVerificationRequest>> _requestStream;
  late final Stream<List<ManualVerificationRequest>> _disputeStream;

  @override
  void initState() {
    super.initState();
    _requestStream = widget.repository.watchMyRequests();
    _disputeStream = widget.repository.watchIncomingDisputes();
    _loadAccounts();
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

  Future<void> _createDefense(ManualVerificationRequest dispute) async {
    final account = _selectedAccount;
    final character = _selectedCharacter;
    if (account == null || character == null) {
      setState(() => _message = '방어할 게임 계정과 캐릭터를 선택해 주세요.');
      return;
    }
    await _run(() async {
      final created = await widget.repository.createRequest(
        localAccountId: account.id,
        localAccountLabel: account.label,
        proofServerName: character.serverName,
        proofCharacterName: character.characterName,
        proofClassName: character.characterClassName,
        targetGameAccountId: dispute.targetGameAccountId,
        defenseOfRequestId: dispute.id,
        rosterIdentityKeys: [
          for (final item in account.characters)
            characterIdentityKey(item.serverName, item.characterName),
        ],
      );
      setState(() {
        _localRequests = [
          created,
          ..._localRequests.where((item) => item.id != created.id),
        ];
        _message = '방어용 인증 코드를 발급했습니다.';
      });
    });
  }

  Future<void> _create() async {
    final account = _selectedAccount;
    final character = _selectedCharacter;
    if (account == null || character == null) {
      setState(() => _message = '인증할 게임 계정과 캐릭터를 선택해 주세요.');
      return;
    }
    await _run(() async {
      final created = await widget.repository.createRequest(
        localAccountId: account.id,
        localAccountLabel: account.label,
        proofServerName: character.serverName,
        proofCharacterName: character.characterName,
        proofClassName: character.characterClassName,
        targetGameAccountId: account.serverGameAccountId,
        rosterIdentityKeys: [
          for (final item in account.characters)
            characterIdentityKey(item.serverName, item.characterName),
        ],
      );
      setState(() {
        _localRequests = [
          created,
          ..._localRequests.where((item) => item.id != created.id),
        ];
        _message = '인증 코드를 발급했습니다.';
      });
    });
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _message = '인증 코드를 복사했습니다.');
  }

  Future<void> _openChat() async {
    final open = widget.onOpenUri;
    if (open != null) {
      await open(openChatUri);
      return;
    }
    await launchUrl(openChatUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _bindIfApproved(List<ManualVerificationRequest> requests) async {
    for (final request in requests) {
      if (request.status != ManualVerificationStatus.approved &&
          request.status != ManualVerificationStatus.transferred) {
        continue;
      }
      if (!_boundRequestIds.add(request.id)) continue;
      try {
        final result = await widget.repository.loadApprovedResult(request.id);
        await _saveBinding(result, request);
      } catch (_) {
        if (mounted) {
          setState(() {
            _message = '승인된 인증 결과를 이 기기의 원정대에 연결하지 못했습니다. 다시 시도해 주세요.';
          });
        }
      }
    }
  }

  Future<void> _saveBinding(
    GameAccountVerificationResult result,
    ManualVerificationRequest request,
  ) async {
    final accountId = result.serverGameAccountId;
    if (accountId == null) return;
    LocalGameAccount? account;
    for (final item in _accounts) {
      if (item.characters.any(
        (character) =>
            character.serverName == request.proofServerName &&
            character.characterName == request.proofCharacterName,
      )) {
        account = item;
        break;
      }
    }
    if (account == null) return;
    final remoteByKey = {
      for (final character in result.serverCharacters)
        '${character.serverName}\u0000${character.characterName}':
            character.serverCharacterId,
    };
    final mapping = <int, String>{};
    for (final character in account.characters) {
      final serverId =
          remoteByKey['${character.serverName}\u0000${character.characterName}'];
      if (serverId != null) mapping[character.id] = serverId;
    }
    if (mapping.isEmpty) return;
    await widget.mappingRepository.bindServerIdentity(
      ServerAccountIdentityBinding(
        localAccountId: account.id,
        serverGameAccountId: accountId,
        serverCharacterIdsByLocalId: mapping,
      ),
    );
    await _loadAccounts();
    if (!mounted) return;
    setState(() => _message = '게임 계정 인증과 로컬 연결이 완료되었습니다.');
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ManualVerificationException catch (error) {
      if (mounted) setState(() => _message = error.message ?? error.code);
    } catch (_) {
      if (mounted) {
        setState(() => _message = '요청을 처리하지 못했습니다. 네트워크를 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<ManualVerificationRequest> _mergeRequests(
    List<ManualVerificationRequest> remote,
  ) {
    final byId = {for (final request in remote) request.id: request};
    for (final request in _localRequests) {
      byId.putIfAbsent(request.id, () => request);
    }
    return byId.values
        .where(
          (request) =>
              request.isPending || request.isAwaitingOwnerResponse,
        )
        .toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  String _statusLabel(ManualVerificationRequest request) {
    final expired = request.isExpiredAt(DateTime.now());
    return switch (request.status) {
      ManualVerificationStatus.approved => '승인됨',
      ManualVerificationStatus.transferred => '소유권 이전 완료',
      ManualVerificationStatus.defended => '기존 소유자 방어로 종료',
      ManualVerificationStatus.cancelled => '취소됨',
      ManualVerificationStatus.blocked => '인증 금지',
      ManualVerificationStatus.awaitingOwnerResponse => '기존 소유자 응답 대기',
      ManualVerificationStatus.expired => '만료됨',
      ManualVerificationStatus.pendingProof =>
        expired ? '만료됨' : request.isDefenseRequest ? '방어 증명 대기' : '증명 대기',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('수동 인증')),
      body: StreamBuilder<List<ManualVerificationRequest>>(
        stream: _disputeStream,
        builder: (context, disputeSnapshot) {
          final incomingDisputes = disputeSnapshot.data ?? const [];
          return StreamBuilder<List<ManualVerificationRequest>>(
            stream: _requestStream,
            builder: (context, snapshot) {
              final remoteRequests = snapshot.data ?? const [];
              final requests = _mergeRequests(remoteRequests);
              if (remoteRequests.any(
                (request) =>
                    request.status == ManualVerificationStatus.approved ||
                    request.status == ManualVerificationStatus.transferred,
              )) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _bindIfApproved(remoteRequests);
                });
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    key: const ValueKey('manualVerificationCompletionNotice'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '수동 인증 완료 후 이 페이지에 다시 진입해야 계정 연동이 완료됩니다.\n'
                            '인증 완료 알림은 별도로 전송되지 않으니 수동 인증 페이지를 확인해 주세요.\n\n'
                            '반복되거나 부정확한 수동 인증 요청은 운영자 판단에 따라 '
                            '해당 게임 계정의 추가 인증이 제한될 수 있습니다.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (incomingDisputes.isNotEmpty) ...[
                    const Text(
                      '소유권 방어 필요',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final dispute in incomingDisputes)
                      Card(
                        margin: const EdgeInsets.only(top: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '다른 사용자가 ${dispute.localAccountLabelSnapshot} '
                                '계정의 수동 인증을 제출했습니다.',
                              ),
                              if (dispute.ownerResponseDeadlineAt != null)
                                Text(
                                  '방어 기한 '
                                  '${KoreaTimeFormatter.dayAndTime(dispute.ownerResponseDeadlineAt!)}',
                                ),
                              const SizedBox(height: 8),
                              FilledButton(
                                key: ValueKey(
                                  'manualVerificationDefense-${dispute.id}',
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _createDefense(dispute),
                                child: const Text('방어용 인증 코드 발급'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
              if (_accounts.isEmpty)
                const Text('먼저 내 계정에서 게임 계정을 등록해 주세요.')
              else ...[
                DropdownButtonFormField<LocalGameAccount>(
                  key: const ValueKey('manualVerificationAccount'),
                  initialValue: _selectedAccount,
                  decoration: const InputDecoration(labelText: '게임 계정'),
                  items: [
                    for (final account in _accounts)
                      DropdownMenuItem(
                        value: account,
                        child: Text(account.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() {
                            _selectedAccount = value;
                            _selectedCharacter = value?.characters.firstOrNull;
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LocalAccountCharacter>(
                  key: ValueKey('manualVerificationCharacter-${_selectedAccount?.id}'),
                  initialValue: _selectedCharacter,
                  decoration: const InputDecoration(labelText: '인증 캐릭터'),
                  items: [
                    for (final character
                        in _selectedAccount?.characters ??
                            const <LocalAccountCharacter>[])
                      DropdownMenuItem(
                        value: character,
                        child: Text(
                          '${character.characterName} · ${character.serverName}',
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _selectedCharacter = value),
                ),
                if (_selectedAccount?.hasActiveOwnership == true) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '이미 인증한 게임 계정입니다. 수동 인증을 다시 요청할 수 없습니다.',
                  ),
                ] else if (_selectedAccount?.hasServerMismatch == true) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '서버 데이터가 로컬 계정과 일치하지 않습니다. 이 원정대로 재인증할 수 있습니다.',
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('manualVerificationCreate'),
                  onPressed: _busy || _selectedAccount?.hasActiveOwnership == true
                      ? null
                      : _create,
                  child: const Text('인증 코드 발급'),
                ),
              ],
              const SizedBox(height: 16),
              const Text(instruction),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('manualVerificationOpenChat'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _openChat,
                  child: const Text(
                    '인증사진 전송 오픈채팅방',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '내 요청',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              if (snapshot.hasError && requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('요청 목록을 불러오지 못했습니다.'),
                )
              else if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('진행 중인 수동 인증 요청이 없습니다.'),
                )
              else
                for (final request in requests)
                  _RequestCard(
                    request: request,
                    statusLabel: _statusLabel(request),
                    busy: _busy,
                    onCopy: () => _copy(request.verificationCode),
                    onCancel: () => _run(() async {
                      await widget.repository.cancelRequest(request.id);
                      _localRequests = _localRequests
                          .where((item) => item.id != request.id)
                          .toList(growable: false);
                    }),
                  ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.statusLabel,
    required this.busy,
    required this.onCopy,
    required this.onCancel,
  });

  final ManualVerificationRequest request;
  final String statusLabel;
  final bool busy;
  final VoidCallback onCopy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final expired = request.isExpiredAt(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${request.localAccountLabelSnapshot} · $statusLabel'),
            Text(
              '${request.proofCharacterName} · ${request.proofServerName}',
            ),
            if (request.isAwaitingOwnerResponse &&
                request.ownerResponseDeadlineAt != null)
              Text(
                '기존 소유자 응답 기한 '
                '${KoreaTimeFormatter.dayAndTime(request.ownerResponseDeadlineAt!)}',
              ),
            if (request.isPending) ...[
              const SizedBox(height: 8),
              SelectableText(
                request.verificationCode,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('만료 ${KoreaTimeFormatter.dayAndTime(request.expiresAt)}'),
            ],
            Text(
              '대상 요청 ${request.attemptNumberForTarget}회 · '
              '전체 ${request.totalAttemptNumberForPlayer}회',
            ),
            if (request.reviewReason != null &&
                request.reviewReason!.isNotEmpty)
              Text('사유: ${request.reviewReason}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (request.isPending) ...[
                  OutlinedButton(
                    key: ValueKey('manualVerificationCopy-${request.id}'),
                    onPressed: busy ? null : onCopy,
                    child: const Text('코드 복사'),
                  ),
                  if (!expired)
                    OutlinedButton(
                      onPressed: busy ? null : onCancel,
                      child: const Text('요청 취소'),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
