import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/backend/group_models.dart';
import '../../data/backend/group_repository.dart';
import '../viewmodels/backend_group_view_model.dart';

/// Existing group entry points and card hierarchy, bound to current Backend data.
class BackendGroupPage extends StatefulWidget {
  const BackendGroupPage({
    required this.repository,
    required this.kind,
    required this.characters,
    required this.onLogin,
    this.groupId,
    super.key,
  });
  final GroupRepository repository;
  final GroupPageKind kind;
  final String? groupId;
  final Future<List<GroupCharacterChoice>> Function() characters;
  final VoidCallback onLogin;
  @override
  State<BackendGroupPage> createState() => _BackendGroupPageState();
}

class _BackendGroupPageState extends State<BackendGroupPage>
    with WidgetsBindingObserver {
  late final BackendGroupViewModel m;
  late String _memberBinding;
  final input = TextEditingController();
  List<Map<String, dynamic>> candidates = [];
  String get path => '/v1/groups/${widget.groupId}';
  String get route => '/groups/${widget.groupId}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    m = BackendGroupViewModel(
      widget.repository,
      widget.kind,
      groupId: widget.groupId,
    );
    _memberBinding = widget.repository.readScope;
    widget.repository.session.addListener(_memberChanged);
    unawaited(m.load());
  }

  void _memberChanged() {
    final next = widget.repository.readScope;
    if (next == _memberBinding) return;
    _memberBinding = next;
    input.clear();
    candidates = [];
  }

  @override
  void dispose() {
    widget.repository.session.removeListener(_memberChanged);
    WidgetsBinding.instance.removeObserver(this);
    m.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !m.busy) {
      candidates = [];
      unawaited(m.load());
    }
  }

  Future<void> open(String target) async {
    await context.push(target);
    if (mounted) {
      candidates = [];
      await m.load();
    }
  }

  Future<bool> confirm(String title, [String? text]) async {
    final binding = widget.repository.readScope, observation = m.observation;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Stack(
              alignment: Alignment.centerRight,
              children: [
                Align(alignment: Alignment.centerLeft, child: Text(title)),
                if (m.loading || m.busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            content: text == null ? null : Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인'),
              ),
            ],
          ),
        ) ??
        false;
    return mounted &&
        binding == widget.repository.readScope &&
        observation == m.observation &&
        accepted;
  }

  Future<GroupCharacterChoice?> choose() async {
    final binding = widget.repository.readScope;
    final choices = [...await widget.characters()]
      ..sort(GroupCharacterChoice.compare);
    if (!mounted || binding != widget.repository.readScope) return null;
    if (choices.isEmpty) {
      throw const AccountReadException('NO_ACTIVITY_CHARACTERS');
    }
    return showModalBottomSheet<GroupCharacterChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('표시할 활동 캐릭터 선택')),
            for (final choice in choices)
              ListTile(
                title: Text(choice.label),
                subtitle: Text('Lv. ${choice.itemLevel ?? '미확인'}'),
                onTap: () => Navigator.pop(context, choice),
              ),
          ],
        ),
      ),
    );
  }

  Future<T?> prepare<T>(Future<T?> Function() work) async {
    if (m.busy || !m.authenticated) return null;
    final scope = widget.repository.readScope, observation = m.observation;
    setState(() {
      m.busy = true;
      m.failure = null;
    });
    try {
      final result = await work();
      return mounted &&
              scope == widget.repository.readScope &&
              observation == m.observation
          ? result
          : null;
    } catch (error) {
      if (mounted && scope == widget.repository.readScope) {
        setState(() => m.failure = error);
      }
      return null;
    } finally {
      if (mounted && scope == widget.repository.readScope) {
        setState(() => m.busy = false);
      }
    }
  }

  Future<Map<String, dynamic>?> joinFields() async {
    final selected = await choose();
    if (selected == null) return null;
    final usage = await widget.repository.get('/v1/me/usage-limits');
    return {
      ...selected.selection,
      'expected_limits_revision': usage['limits_revision'],
      'expected_usage_revision': usage['usage_revision'],
    };
  }

  Future<void> create() async {
    final body = await prepare(() async {
      final fields = await joinFields();
      if (fields == null) return null;
      return {
        ...fields,
        if (input.text.trim().isNotEmpty) 'name': input.text.trim(),
      };
    });
    if (body == null || !mounted) return;
    final result = await m.act('POST', '/v1/groups', body);
    if (result != null && mounted) {
      context.go('/groups/${result['group']['group_id']}');
    }
  }

  Future<void> apply() async {
    final selected = await prepare(choose);
    if (selected == null || !mounted) return;
    if (!await confirm('${m.summary!['name']}에 가입 신청할까요?')) return;
    await m.act('POST', '$path/applications', {
      ...selected.selection,
      'expected_group_revision': m.summary!['revision'],
    });
  }

  Future<void> relation(
    Map<String, dynamic> r,
    String action, {
    bool block = false,
  }) async {
    final permissions = groupMap(r['permissions']);
    if (!groupAllowed(permissions, action)) return;
    final extra = action == 'accept'
        ? await prepare(joinFields)
        : <String, dynamic>{};
    if (extra == null || !mounted) return;
    final label = {
      'accept': '초대를 수락',
      'approve': '가입 신청을 승인',
      'reject': '요청을 거절',
      'cancel': '요청을 취소',
    }[action]!;
    if (!await confirm('$label할까요?', block ? '이후 가입 신청도 금지합니다.' : null)) return;
    final result = await m
        .act('POST', '/v1/group-relations/${r['relation_id']}/$action', {
          'expected_relation_revision': r['revision'],
          'expected_group_revision': r['group']['revision'],
          'expected_members_revision': r['members_revision'],
          ...extra,
          if (block) 'block_future': true,
        });
    if (result != null && action == 'accept' && mounted) {
      context.go('/groups/${result['group']['group_id']}');
    }
  }

  Future<void> searchInvite() async {
    await prepare(() async {
      final value = await widget.repository.get(
        '$path/invite-candidates',
        query: {'character_name': input.text.trim()},
      );
      if (mounted) setState(() => candidates = groupItems(value));
      return true;
    });
  }

  Future<void> invite(Map<String, dynamic> c) async {
    if (!await confirm('${groupName(c['display'])}님을 초대할까요?')) return;
    final result = await m.act(
      'POST',
      '$path/invitations',
      {
        'target_character_id': c['target_character_id'],
        'expected_target_ownership_revision': c['ownership_revision'],
        'expected_target_lifecycle_revision': c['lifecycle_revision'],
        'expected_group_revision': m.detail!.group['revision'],
        'expected_membership_revision': m.detail!.membership['revision'],
      },
      successNotice: '${groupName(c['display'])}님에게 초대를 보냈습니다. 상대가 수락하면 가입됩니다.',
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대를 보냈습니다. 요청 현황에서 확인할 수 있습니다.')),
      );
      setState(() => candidates = []);
    }
  }

  Future<void> previewCode() async {
    await prepare(() async {
      final value = await widget.repository.request(
        'POST',
        '/v1/group-join-codes/preview',
        body: {'code': input.text.trim().toUpperCase()},
      );
      if (mounted) setState(() => m.preview = value);
      return true;
    });
  }

  Future<void> joinCode() async {
    final preview = m.preview;
    if (preview == null) return;
    final fields = await prepare(joinFields);
    if (fields == null || !mounted) return;
    if (!await confirm(
      '${preview['group']['name']}에 가입할까요?',
      '그룹장 승인 없이 가입합니다.',
    )) {
      return;
    }
    final result = await m.act('POST', '/v1/group-join-codes/join', {
      ...fields,
      'code': input.text.trim().toUpperCase(),
      'expected_group_revision': preview['group']['revision'],
      'expected_members_revision': preview['members_revision'],
      'expected_code_id': preview['code_id'],
      'expected_code_revision': preview['code_revision'],
    });
    if (result != null && mounted) {
      input.clear();
      context.go('/groups/${result['group']['group_id']}');
    }
  }

  Future<void> codeCommand(String action, {bool? visible}) async {
    final value = m.code, detail = m.detail;
    if (value == null || detail == null) return;
    if (!await confirm(
      {
        'create': '초대코드를 생성할까요?',
        'regenerate': '코드를 재발급할까요?',
        'revoke': '코드를 폐기할까요?',
        'visibility': '코드 공개 설정을 변경할까요?',
      }[action]!,
      action == 'regenerate'
          ? '기존 코드는 즉시 사용할 수 없게 됩니다.'
          : action == 'visibility'
          ? '공개를 꺼도 이미 복사한 코드는 유효합니다.'
          : null,
    )) {
      return;
    }
    await m.act(
      action == 'visibility' ? 'PUT' : 'POST',
      '$path/join-code${action == 'create' ? '' : '/$action'}',
      {
        'expected_group_revision': detail.group['revision'],
        'expected_membership_revision': detail.membership['revision'],
        'expected_code_id': value['code_id'],
        'expected_code_revision': value['revision'],
        'visible_to_members': ?visible,
      },
    );
  }

  Future<void> manage(String action, {Map<String, dynamic>? member}) async {
    final management = m.management;
    if (management == null ||
        !groupAllowed(groupMap(management['permissions']), action)) {
      return;
    }
    Map<String, dynamic> extra = {};
    if (action == 'change_representative') {
      final selected = await prepare(choose);
      if (selected == null) return;
      extra = selected.selection;
    }
    if (!mounted ||
        !await confirm(
          switch (action) {
            'leave' => '그룹을 탈퇴할까요?',
            'disband' => '그룹을 해산할까요?',
            'remove_member' => '${groupName(member?['display'])}님을 추방할까요?',
            'transfer_leadership' =>
              '${groupName(member?['display'])}님에게 그룹장을 이전할까요?',
            _ => '그룹 대표를 변경할까요?',
          },
          action == 'transfer_leadership'
              ? '즉시 이전되며 나는 일반 멤버로 남습니다. 탈퇴는 별도로 진행합니다.'
              : null,
        )) {
      return;
    }
    final target = switch (action) {
      'remove_member' => '$path/members/${member!['membership_id']}/remove',
      'change_representative' => '$path/representative',
      'transfer_leadership' => '$path/leadership-transfer',
      _ => '$path/$action',
    };
    final result = await m.act(
      action == 'change_representative' ? 'PUT' : 'POST',
      target,
      {
        'expected_group_revision': management['group_revision'],
        'expected_members_revision': management['members_revision'],
        'expected_membership_id': management['my_membership']['membership_id'],
        'expected_membership_revision': management['my_membership']['revision'],
        if (action == 'transfer_leadership')
          'target_membership_id': member!['membership_id'],
        if (member != null)
          'expected_target_membership_revision': member['revision'],
        ...extra,
      },
    );
    if (result != null &&
        mounted &&
        (action == 'leave' || action == 'disband')) {
      context.go('/groups');
    }
  }

  Future<void> rename() async {
    if (!await confirm('그룹 이름을 변경할까요?')) return;
    await m.act('PATCH', path, {
      'name': input.text.trim(),
      'expected_revision': m.detail!.group['revision'],
      'expected_membership_revision': m.detail!.membership['revision'],
    });
  }

  Future<void> unblock(Map<String, dynamic> subject) async {
    if (!await confirm('${groupName(subject['display'])}님의 신청 금지를 해제할까요?')) {
      return;
    }
    await m
        .act('POST', '$path/join-subjects/${subject['subject_id']}/unblock', {
          'expected_subject_revision': subject['revision'],
          'expected_group_revision': m.detail!.group['revision'],
          'expected_membership_revision': m.detail!.membership['revision'],
        });
  }

  Widget button(String text, VoidCallback onTap, {bool enabled = true}) =>
      FilledButton.tonal(
        onPressed: enabled && !m.busy && !m.loading ? onTap : null,
        child: Text(text),
      );
  Widget field(
    String label,
    String hint,
    VoidCallback submit, {
    bool code = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: input,
      enabled: !m.busy,
      textCapitalization: code
          ? TextCapitalization.characters
          : TextCapitalization.none,
      onChanged: (_) {
        if (code && m.preview != null) setState(() => m.preview = null);
      },
      onSubmitted: (_) {
        if (!m.busy && !m.loading) submit();
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  Widget nav(String title, String suffix) => ListTile(
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: m.busy ? null : () => open('$route/$suffix'),
  );
  Widget summaryCard(Map<String, dynamic> value, {VoidCallback? onTap}) => Card(
    child: ListTile(
      title: Text(value['name']),
      subtitle: Text(
        '대표 · ${groupName(value['representative']['display'])}\n그룹장 · ${groupName(value['leader_display'])}  ${value['member_count']}명',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
  Widget relationCard(Map<String, dynamic> r) {
    final p = groupMap(r['permissions']);
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r['group']['name'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${r['kind'] == 'invitation' ? '초대' : '가입 신청'} · ${groupName(r['display'])} · 신청 ${r['application_count']}회',
          ),
          Text('만료 ${DateTime.parse(r['expires_at']).toLocal()}'),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'accept': '수락',
                'approve': '승인',
                'reject': '거절',
                'cancel': '취소',
              }.entries)
                if (groupAllowed(p, entry.key))
                  button(entry.value, () => relation(r, entry.key)),
              if (groupAllowed(p, 'block') && groupAllowed(p, 'reject'))
                button('거절 및 신청 금지', () => relation(r, 'reject', block: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget memberCard(Map<String, dynamic> member) {
    final id = member['membership_id'] as String;
    return Card(
      child: ExpansionTile(
        title: Text(
          '${groupName(member['display'])}${member['role'] == 'leader' ? ' · 그룹장' : ''}',
        ),
        subtitle: Text(groupSpecText(member['character_spec'])),
        onExpansionChanged: (expanded) {
          if (expanded) unawaited(m.activity(id));
        },
        children: [
          if (!m.activities.containsKey(id) &&
              !m.activityFailures.containsKey(id))
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          if (m.activityFailures[id] case final error?)
            ListTile(
              title: Text(groupFailure(error)),
              trailing: TextButton(
                onPressed: () => m.activity(id),
                child: const Text('다시 시도'),
              ),
            ),
          for (final c in m.activities[id] ?? <Map<String, dynamic>>[])
            ListTile(
              title: Text(groupName(c['display'])),
              subtitle: Text(
                '${c['display']['class_name'] ?? ''}\n${groupSpecText(c['character_spec'])}',
              ),
            ),
          if (m.activities[id]?.isEmpty == true)
            const ListTile(title: Text('현재 활동 캐릭터가 없습니다.')),
        ],
      ),
    );
  }

  List<Widget> content() {
    switch (widget.kind) {
      case GroupPageKind.home:
        return [
          if (m.countsFailure case final error?)
            Text('요청 수 확인 불가 · ${groupFailure(error)}'),
          if (m.homeTab == 0) ...[
            if (m.usage != null)
              Text(
                '가입 그룹 ${m.usage!['usage']['joined_groups']['used']} / ${m.usage!['limits']['joined_groups']}',
              ),
            for (final g in m.groups)
              summaryCard(
                groupMap(g['group']),
                onTap: () => open('/groups/${g['group']['group_id']}'),
              ),
            if (!m.loading && m.failure == null && m.groups.isEmpty)
              const Text('가입한 그룹이 없습니다. 검색·코드 입력으로 가입하거나 그룹을 만들어 보세요.'),
          ] else ...[
            DropdownButton<String>(
              value: m.relationView,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'received_invitations',
                  child: Text('받은 초대 / 관리할 신청'),
                ),
                DropdownMenuItem(
                  value: 'sent_applications',
                  child: Text('보낸 가입 신청'),
                ),
                DropdownMenuItem(
                  value: 'sent_invitations',
                  child: Text('보낸 초대'),
                ),
              ],
              onChanged: m.busy
                  ? null
                  : (v) {
                      m.relationView = v!;
                      unawaited(m.load());
                    },
            ),
            ...m.rows.map(relationCard),
            if (!m.loading && m.failure == null && m.rows.isEmpty)
              const Text('처리할 요청이 없습니다.'),
          ],
        ];
      case GroupPageKind.search:
        return [
          field('그룹 검색', '그룹명 또는 대표 캐릭터명', () {
            m.query = input.text;
            unawaited(m.load());
          }),
          button('검색', () {
            m.query = input.text;
            unawaited(m.load());
          }),
          for (final g in m.rows)
            summaryCard(g, onTap: () => open('/groups/${g['group_id']}')),
          if (m.cursor != null) button('더 보기', () => m.load(more: true)),
        ];
      case GroupPageKind.create:
        return [
          field('그룹 이름', '비워 두면 선택한 대표 캐릭터의 그룹으로 만듭니다.', create),
          button('대표 캐릭터 선택 후 만들기', create),
        ];
      case GroupPageKind.joinCode:
        return [
          field('초대코드', '6자리 코드', previewCode, code: true),
          button('그룹 확인', previewCode),
          if (m.preview != null) ...[
            summaryCard(groupMap(m.preview!['group'])),
            button('캐릭터 선택 후 가입', joinCode),
          ],
        ];
      case GroupPageKind.detail:
        return [
          if (m.summary != null) summaryCard(m.summary!),
          if (m.failure == null && m.detail == null && m.summary != null)
            button('가입 신청', apply),
          if (m.detail != null) ...[
            Text(
              '그룹원 ${m.detail!.wire['capacity']['used']} / ${m.detail!.wire['capacity']['limit']}',
            ),
            if (m.detail!.group['representative']['status'] == 'needs_update')
              const Text('그룹 대표 캐릭터 변경이 필요합니다.'),
            nav('사용자 초대', 'invite'),
            nav('초대코드', 'code'),
            nav('그룹 레이드', 'raids'),
            if (m.leader) ...[
              nav('그룹 정보 · 멤버 관리', 'info'),
              nav('초대 · 신청 관리', 'requests'),
              nav('신청 금지 인원', 'blocked'),
            ],
            for (final member
                in [...m.rows]..sort(
                  (a, b) => (a['role'] == 'leader' ? 0 : 1).compareTo(
                    b['role'] == 'leader' ? 0 : 1,
                  ),
                ))
              memberCard(member),
            if (m.management != null && !m.leader)
              button(
                '그룹 탈퇴',
                () => manage('leave'),
                enabled: groupAllowed(
                  groupMap(m.management!['permissions']),
                  'leave',
                ),
              ),
          ],
        ];
      case GroupPageKind.invite:
        return [
          if (m.detail != null) ...[
            field('캐릭터명', '정확한 캐릭터명', searchInvite),
            button('검색', searchInvite),
            for (final c in candidates)
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(groupName(c['display'])),
                    Text(
                      '${c['display']['server_name']} · ${c['display']['class_name'] ?? ''}\nLv. ${c['item_level'] ?? '미확인'} · 전투력 ${c['combat_power'] ?? '미확인'}',
                    ),
                    button('초대', () => invite(c)),
                  ],
                ),
              ),
          ],
        ];
      case GroupPageKind.requests:
        return m.detail == null ? [] : [...m.rows.map(relationCard)];
      case GroupPageKind.blocked:
        return [
          for (final s in m.rows)
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${groupName(s['display'])} · 신청 ${s['application_count']}회',
                  ),
                  Text(groupSpecText(s['character_spec'])),
                  button('신청 금지 해제', () => unblock(s)),
                ],
              ),
            ),
        ];
      case GroupPageKind.code:
        if (m.code == null) return [];
        final c = m.code!,
            next = DateTime.tryParse(
              c['regenerate_available_at'] as String? ?? '',
            );
        return [
          if (c['code'] is String)
            SelectableText(
              c['code'],
              style: Theme.of(context).textTheme.headlineMedium,
            )
          else
            Text(c['active'] == true ? '코드가 공개되지 않았습니다.' : '발급된 초대코드가 없습니다.'),
          if (c['code'] is String)
            button(
              '복사',
              () => Clipboard.setData(ClipboardData(text: c['code'])),
            ),
          if (m.leader) ...[
            SwitchListTile(
              title: const Text('그룹원에게 코드 공개'),
              subtitle: const Text('공개를 꺼도 기존 코드는 유효합니다.'),
              value: c['visible_to_members'],
              onChanged: m.busy || c['active'] != true
                  ? null
                  : (v) => codeCommand('visibility', visible: v),
            ),
            if (c['active'] != true)
              button('코드 생성', () => codeCommand('create')),
            if (c['active'] == true) ...[
              button(
                '재발급',
                () => codeCommand('regenerate'),
                enabled: next == null || !next.isAfter(DateTime.now().toUtc()),
              ),
              button('폐기', () => codeCommand('revoke')),
            ],
            if (next != null && next.isAfter(DateTime.now().toUtc()))
              Text('재발급 가능 ${next.toLocal()}'),
          ],
        ];
      case GroupPageKind.info:
        if (m.detail == null || !m.leader) return [];
        final permissions = m.management == null
            ? <String, dynamic>{}
            : groupMap(m.management!['permissions']);
        return [
          field('그룹 이름', m.detail!.name, rename),
          button('이름 변경', rename),
          button(
            '그룹 대표 변경',
            () => manage('change_representative'),
            enabled: groupAllowed(permissions, 'change_representative'),
          ),
          for (final member in m.rows.where((r) => r['is_me'] == false))
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(groupName(member['display'])),
                  Wrap(
                    spacing: 8,
                    children: [
                      button(
                        '그룹장 이전',
                        () => manage('transfer_leadership', member: member),
                        enabled: groupAllowed(
                          permissions,
                          'transfer_leadership',
                        ),
                      ),
                      button(
                        '추방',
                        () => manage('remove_member', member: member),
                        enabled: groupAllowed(permissions, 'remove_member'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Text('그룹장은 이전 완료 후 별도로 탈퇴할 수 있습니다.'),
          if (permissions['disband'] is Map &&
              permissions['disband']['allowed'] == false)
            Text(groupDisbandReason(permissions['disband']['reason'])),
          if (m.management?['recruitment_state'] != 'clear')
            nav('해산을 막는 그룹 레이드 확인', 'raids'),
          button(
            '그룹 해산',
            () => manage('disband'),
            enabled: groupAllowed(permissions, 'disband'),
          ),
        ];
      case GroupPageKind.raids:
        return [
          const Text('레이드는 해당 주차 공대장이 관리합니다.'),
          if (m.counts?['state'] == 'unavailable')
            const Text('그룹 레이드 상태를 확인하지 못했습니다. 0건으로 처리하지 않습니다.'),
          for (final room in m.rows)
            card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room['title']),
                  for (final t in (room['targets'] as List))
                    ListTile(
                      title: Text(
                        '${t['target_cycle_key']} · ${groupName(t['leader_display'])}',
                      ),
                      subtitle: Text(
                        t['detail_available'] == true
                            ? '기존 레이드 상세로 이동'
                            : '현재 상세를 확인할 수 없습니다.',
                      ),
                      onTap: t['detail_available'] != true
                          ? null
                          : () => open(
                              '/recruitments/${room['room_id']}?target_cycle_key=${t['target_cycle_key']}',
                            ),
                    ),
                ],
              ),
            ),
          if (m.cursor != null) button('더 보기', () => m.load(more: true)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) {
      final title = switch (widget.kind) {
        GroupPageKind.home => '그룹',
        GroupPageKind.search => '그룹 검색',
        GroupPageKind.create => '그룹 만들기',
        GroupPageKind.detail => '그룹 상세',
        GroupPageKind.invite => '사용자 초대',
        GroupPageKind.requests => '요청 관리',
        GroupPageKind.code => '초대코드',
        GroupPageKind.joinCode => '초대코드로 가입',
        GroupPageKind.info => '그룹 정보 · 관리',
        GroupPageKind.blocked => '신청 금지 인원',
        GroupPageKind.raids => '그룹 레이드',
      };
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          floatingActionButton: widget.kind == GroupPageKind.home
              ? FloatingActionButton.extended(
                  onPressed: m.busy ? null : () => open('/groups/create'),
                  icon: const Icon(Icons.add),
                  label: const Text('그룹 만들기'),
                )
              : null,
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (widget.kind == GroupPageKind.home) ...[
                IconButton(
                  onPressed: m.busy ? null : () => open('/groups/join-by-code'),
                  icon: const Icon(Icons.vpn_key_outlined),
                  tooltip: '초대코드로 가입',
                ),
                IconButton(
                  onPressed: m.busy ? null : () => open('/groups/search'),
                  icon: const Icon(Icons.search),
                  tooltip: '그룹 검색',
                ),
              ],
              IconButton(
                onPressed: m.busy
                    ? null
                    : () {
                        candidates = [];
                        unawaited(m.load());
                      },
                icon: const Icon(Icons.refresh),
                tooltip: '새로고침',
              ),
            ],
            bottom: widget.kind == GroupPageKind.home
                ? TabBar(
                    onTap: (index) {
                      m.homeTab = index;
                      unawaited(m.load());
                    },
                    tabs: [
                      const Tab(text: '내 그룹'),
                      Tab(
                        text:
                            '요청 현황${m.counts == null ? '' : ' (${m.counts!['action_required']})'}',
                      ),
                    ],
                  )
                : null,
          ),
          body: !m.authenticated
              ? Center(
                  child: FilledButton(
                    onPressed: widget.onLogin,
                    child: const Text('로그인 후 이용'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => m.load(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (m.notice != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(m.notice!),
                        ),
                      if (m.failure case final error?)
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(groupFailure(error)),
                              button('현재 목록 새로고침', () => m.load()),
                            ],
                          ),
                        ),
                      ...content(),
                      const SizedBox(height: 16),
                      if (m.hasPendingRequest)
                        TextButton(
                          onPressed: m.busy ? null : m.recover,
                          child: const Text('이전 요청 결과 확인'),
                        ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
