import 'package:flutter/material.dart';

import '../../../../shared/formatters/korea_time_formatter.dart';
import '../../domain/entities/operator_user.dart';
import '../../domain/repositories/operator_access_repository.dart';

class OperatorUserDetailPage extends StatefulWidget {
  const OperatorUserDetailPage({
    required this.playerId,
    required this.repository,
    super.key,
  });

  final String playerId;
  final OperatorAccessRepository repository;

  @override
  State<OperatorUserDetailPage> createState() => _OperatorUserDetailPageState();
}

class _OperatorUserDetailPageState extends State<OperatorUserDetailPage> {
  late Future<OperatorUserDetail?> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.repository.loadUserDetail(widget.playerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용자 상세')),
      body: FutureBuilder<OperatorUserDetail?>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('사용자 정보를 불러오지 못했습니다.'));
          }
          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('사용자를 찾을 수 없습니다.'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _UserSection(user: detail.user),
              const Divider(),
              const ListTile(title: Text('서버 게임 계정')),
              if (detail.gameAccounts.isEmpty)
                const ListTile(title: Text('인증된 게임 계정이 없습니다.'))
              else
                for (final account in detail.gameAccounts)
                  _GameAccountTile(account: account),
            ],
          );
        },
      ),
    );
  }
}

class _UserSection extends StatelessWidget {
  const _UserSection({required this.user});

  final OperatorUserSummary user;

  @override
  Widget build(BuildContext context) {
    final createdAt = user.createdAt == null
        ? '기록 없음'
        : KoreaTimeFormatter.dayAndTime(user.createdAt!);
    final lastSeenAt = user.lastSeenAt == null
        ? '접속 기록 없음'
        : KoreaTimeFormatter.dayAndTime(user.lastSeenAt!);
    return Column(
      children: [
        ListTile(
          title: Text(user.displayId),
          subtitle: Text('상태 ${user.status}'),
        ),
        ListTile(
          title: const Text('대표 캐릭터'),
          subtitle: Text(user.representativeCharacterName ?? '대표 캐릭터 지정 안 됨'),
        ),
        ListTile(title: const Text('생성일'), subtitle: Text(createdAt)),
        ListTile(title: const Text('마지막 앱 접속'), subtitle: Text(lastSeenAt)),
      ],
    );
  }
}

class _GameAccountTile extends StatelessWidget {
  const _GameAccountTile({required this.account});

  final OperatorGameAccountSummary account;

  @override
  Widget build(BuildContext context) {
    final representative = account.representativeCharacter;
    return ExpansionTile(
      title: Text(account.lookupCharacterName ?? '계정 이름 없음'),
      subtitle: Text(
        '대표 ${representative?.characterName ?? '지정 안 됨'} · '
        '소유 ${account.ownershipStatus} · 계정 ${account.status}',
      ),
      children: account.characters.isEmpty
          ? const [ListTile(title: Text('서버 캐릭터가 없습니다.'))]
          : account.characters
                .map(
                  (character) => ListTile(
                    leading:
                        character.characterId ==
                            account.representativeCharacterId
                        ? const Icon(Icons.star)
                        : const Icon(Icons.person_outline),
                    title: Text(character.characterName),
                    subtitle: Text(
                      '${character.serverName} · ${character.className} · ${character.status}',
                    ),
                  ),
                )
                .toList(growable: false),
    );
  }
}
