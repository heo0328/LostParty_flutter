import 'package:flutter/material.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/presentation/viewmodels/member_weekly_view_model.dart';
import '../../../account/presentation/widgets/member_cycle_selector.dart';
import '../../data/cycle_read_repository.dart';
import '../viewmodels/cycle_read_view_model.dart';
import '../viewmodels/cycle_own_card_info.dart';
import '../widgets/recruitment_section.dart';
import '../viewmodels/cycle_participation_controller.dart';
import '../widgets/cycle_participation_widgets.dart';
import '../../data/membership_readers.dart';
import '../widgets/membership_record_view.dart';

String cycleReadFailure(String? code) => switch (code) {
  'TARGET_NOT_OPEN' => '이 주차에는 열린 모집이 없습니다.',
  'ROOM_NOT_FOUND' || 'ROOM_MEMBERSHIP_REQUIRED' => '이 모집을 확인할 수 없습니다.',
  'CYCLE_CHANGED' || 'TARGET_CYCLE_OUT_OF_RANGE' => '주차가 바뀌었습니다. 다시 확인해 주세요.',
  'CURSOR_STALE' || 'FILTER_CONTEXT_STALE' => '목록이 변경됐습니다. 다시 불러와 주세요.',
  'LOGIN_REQUIRED' => '로그인 후 확인해 주세요.',
  _ => '정보를 불러오지 못했습니다. 다시 시도해 주세요.',
};

class CycleOwnRoomsPage extends StatefulWidget {
  const CycleOwnRoomsPage({
    required this.weekly,
    required this.repository,
    required this.scopeKey,
    required this.onLogin,
    required this.onRoom,
    required this.onApplicationRoom,
    this.mutations,
    this.initialTarget,
    this.onRecord,
    super.key,
  });
  final MemberWeeklyViewModel weekly;
  final String? initialTarget;
  final CycleParticipationController? mutations;
  final CycleReadRepository repository;
  final String Function() scopeKey;
  final VoidCallback onLogin;
  final void Function(String, String) onRoom;
  final void Function(String, String) onApplicationRoom;
  final void Function(String, String, MembershipRecordAnchor)? onRecord;
  @override
  State<CycleOwnRoomsPage> createState() => _CycleOwnRoomsPageState();
}

class _CycleOwnRoomsPageState extends State<CycleOwnRoomsPage> {
  late final CycleReadViewModel m;
  int _mutationVersion = 0;
  bool _initialApplied = false;
  String? _departureKey;
  String? _relationKey;
  @override
  void initState() {
    super.initState();
    m = CycleReadViewModel(
      repository: widget.repository,
      changes: Listenable.merge([widget.weekly.model, widget.weekly]),
      scopeKey: () =>
          '${widget.scopeKey()}/${widget.weekly.cycles?.current.key}',
    );
    widget.weekly.addListener(_meta);
    _departureKey = widget.mutations?.departureSuccess?.$1;
    _relationKey = widget.mutations?.relationEnded?.$1;
    _mutationVersion = widget.mutations?.mutationVersion ?? 0;
    widget.mutations?.addListener(_mutated);
    _meta();
  }

  void _mutated() {
    final c = widget.mutations!;
    final relation = c.relationEnded;
    if (relation != null && relation.$1 != _relationKey) {
      _relationKey = relation.$1;
      for (final target in relation.$3) {
        m.invalidateTarget(target);
      }
    }
    if (c.mutationVersion == _mutationVersion) return;
    _mutationVersion = c.mutationVersion;
    if (c.lastTarget != null) m.invalidateTarget(c.lastTarget!);
    final departure = c.departureSuccess;
    if (departure != null && departure.$1 != _departureKey) {
      _departureKey = departure.$1;
      if (widget.weekly.cycles?.find(departure.$3) != null) {
        m.select(departure.$3);
      }
    }
  }

  @override
  void didUpdateWidget(covariant CycleOwnRoomsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTarget != widget.initialTarget) {
      _initialApplied = false;
      _meta();
    }
  }

  void _meta() {
    final c = widget.weekly.cycles;
    if (c != null && m.signedIn) {
      final requested = !_initialApplied
          ? c.find(widget.initialTarget ?? '')?.key
          : null;
      _initialApplied = true;
      m.select(
        requested ?? c.find(m.target ?? '')?.key ?? c.current.key,
        section: requested == null ? m.tab : 0,
      );
    }
  }

  @override
  void dispose() {
    widget.weekly.removeListener(_meta);
    widget.mutations?.removeListener(_mutated);
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([m, widget.weekly, widget.weekly.model]),
    builder: (context, _) {
      final cycles = widget.weekly.cycles;
      final hasParticipant =
          m.tab == 0 && m.visibleRows.any(CycleOwnCardInfo.supports);
      final names = hasParticipant
          ? scopedParticipationNames(
              widget.weekly.model.sections.expand((s) => s.characters),
              widget.weekly.model.runtime.scope,
            )
          : const <String, String>{};
      return Scaffold(
        appBar: AppBar(
          title: const Text('레이드 현황'),
          actions: [
            IconButton(
              onPressed: m.loading ? null : () => m.load(),
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
          ],
        ),
        body: !m.signedIn
            ? Center(
                child: FilledButton(
                  onPressed: widget.onLogin,
                  child: const Text('로그인 후 확인'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (cycles != null && m.target != null)
                    MemberCycleSelector(
                      cycles: cycles,
                      value: m.target!,
                      onChanged: (v) => m.select(v, section: m.tab),
                    ),
                  if (cycles == null) ...[
                    if (widget.weekly.loading) const LinearProgressIndicator(),
                    TextButton(
                      onPressed: () => widget.weekly.refresh(),
                      child: const Text('주차 다시 불러오기'),
                    ),
                  ],
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('참가 중')),
                      ButtonSegment(value: 1, label: Text('신청 중')),
                      ButtonSegment(value: 2, label: Text('기록')),
                    ],
                    selected: {m.tab},
                    onSelectionChanged: (v) {
                      if (m.target != null) {
                        m.select(m.target!, section: v.single);
                      }
                    },
                  ),
                  if (m.loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    ),
                  if (m.failure != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(cycleReadFailure(m.failure)),
                    ),
                  if (!m.loading &&
                      m.failure == null &&
                      m.visibleRows.isEmpty &&
                      m.target != null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('표시할 내역이 없습니다.', textAlign: TextAlign.center),
                    ),
                  if (widget.mutations != null)
                    CycleCommandBanner(controller: widget.mutations!),
                  for (final row in m.visibleRows)
                    Card(
                      key: ValueKey(row.identity),
                      child: ListTile(
                        title: Text(
                          row.title ??
                              (row.recoveryOnly
                                  ? '참가 정보 확인 필요'
                                  : m.tab == 1
                                  ? '신청한 모집'
                                  : '참가 이력'),
                        ),
                        subtitle: _cardSubtitle(
                          row,
                          names,
                          Text(
                            row.profile?.recovery['state'] != null &&
                                    row.profile!.recovery['state'] != 'none'
                                ? membershipRecoveryLabel(row.profile!)
                                : row.recoveryOnly
                                ? '주차 연결 정보를 확인해야 합니다. 최신 상태를 다시 불러와 주세요.'
                                : row.participationState == 'not_selected' ||
                                      row.participationState == 'legacy_intent'
                                ? '선택 주차 참가 없음 · 방 관계 보존'
                                : row.participationState == 'review_required'
                                ? '참가 정보 확인 필요'
                                : m.tab == 1
                                ? '승인 대기'
                                : row.participationState == 'completed'
                                ? '완료'
                                : row.participationState == 'stopped'
                                ? '미완료 종료'
                                : row.participationState == 'cancelled' ||
                                      row.historyOnly ||
                                      row.state == 'ended'
                                ? '참가 종료'
                                : row.profile != null && row.card == null
                                ? '참가 중'
                                : '${row.card?.count ?? 0}/${row.card?.capacity ?? 0}명',
                          ),
                        ),
                        trailing:
                            m.tab == 1 &&
                                row.state == 'pending' &&
                                widget.mutations != null
                            ? ListenableBuilder(
                                listenable: widget.mutations!,
                                builder: (context, _) => TextButton(
                                  onPressed: widget.mutations!.canAct
                                      ? () => showCycleApplicationDecision(
                                          context,
                                          widget.mutations!,
                                          row.id,
                                          m.target!,
                                          'withdraw',
                                          room: row.roomId,
                                        )
                                      : null,
                                  child: const Text('신청 철회'),
                                ),
                              )
                            : _canOpen(row)
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: _canOpen(row) ? () => _open(row) : null,
                      ),
                    ),
                  if (m.cursor != null)
                    TextButton(
                      onPressed: m.loading ? null : () => m.load(more: true),
                      child: const Text('더 보기'),
                    ),
                ],
              ),
      );
    },
  );

  Widget _cardSubtitle(
    CycleOwnRow row,
    Map<String, String> names,
    Widget status,
  ) {
    final info = m.tab == 0 && CycleOwnCardInfo.supports(row)
        ? CycleOwnCardInfo.fromRow(row, names, widget.weekly.catalog)
        : null;
    if (info == null) return status;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    info.role,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
              for (final name in info.characters) Text(name),
            ],
          ),
          const SizedBox(height: 4),
          for (final raid in info.raids) Text(raid),
          const SizedBox(height: 4),
          status,
        ],
      ),
    );
  }

  bool _recordRow(CycleOwnRow row) =>
      row.profile != null && (m.tab == 2 || row.profile!.isRecord);
  bool _canOpen(CycleOwnRow row) =>
      row.canView &&
      (!_recordRow(row) ||
          row.profile!.locator != null && widget.onRecord != null);
  void _open(CycleOwnRow row) {
    if (_recordRow(row)) {
      widget.onRecord!(row.roomId, m.target!, row.profile!.locator!.anchor);
    } else if (m.tab == 1) {
      widget.onApplicationRoom(row.roomId, m.target!);
    } else {
      widget.onRoom(row.roomId, m.target!);
    }
  }
}

class CycleRoomReadPage extends StatefulWidget {
  const CycleRoomReadPage({
    required this.repository,
    required this.roomId,
    required this.target,
    required this.scopeKey,
    required this.changes,
    required this.onLogin,
    this.catalog,
    super.key,
  });
  final RaidCatalog? catalog;
  final CycleReadRepository repository;
  final String roomId, target;
  final String Function() scopeKey;
  final Listenable changes;
  final VoidCallback onLogin;
  @override
  State<CycleRoomReadPage> createState() => _CycleRoomReadPageState();
}

class _CycleRoomReadPageState extends State<CycleRoomReadPage> {
  late final CycleReadViewModel m;
  @override
  void initState() {
    super.initState();
    m = CycleReadViewModel(
      repository: widget.repository,
      changes: widget.changes,
      scopeKey: widget.scopeKey,
      roomId: widget.roomId,
    )..select(widget.target);
  }

  @override
  void dispose() {
    m.dispose();
    super.dispose();
  }

  String _raidLabel(Map<String, dynamic> item) {
    final raid = widget.catalog?.raids
        .where((r) => r.raidId == item['raid_id'])
        .firstOrNull;
    final diff = raid?.difficulties
        .where((d) => d.difficultyId == item['difficulty_id'])
        .firstOrNull;
    return '${raid?.displayName ?? item['raid_id']} · ${diff?.name ?? item['difficulty_id']}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) {
      final c = m.card;
      return Scaffold(
        appBar: AppBar(
          title: const Text('모집 상세'),
          actions: [
            IconButton(
              onPressed: m.loading ? null : () => m.load(),
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
          ],
        ),
        body: !m.signedIn
            ? Center(
                child: FilledButton(
                  onPressed: widget.onLogin,
                  child: const Text('로그인 후 확인'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '대상 주차 · ${widget.target}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (m.loading) const LinearProgressIndicator(),
                  if (m.failure != null) Text(cycleReadFailure(m.failure)),
                  if (c != null)
                    RecruitmentSection(
                      title: c.title,
                      children: [
                        Text(
                          '${c.count}/${c.capacity}명 · ${c.wire['scope'] == 'group' ? '그룹 전용' : '전체 공개'}',
                        ),
                        for (final i in c.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_raidLabel(i)),
                          ),
                        Text(
                          c.starts.isEmpty
                              ? '출발 미정'
                              : c.starts
                                    .map(
                                      (v) => v
                                          .add(const Duration(hours: 9))
                                          .toIso8601String()
                                          .substring(0, 16)
                                          .replaceAll('T', ' '),
                                    )
                                    .join('\n'),
                        ),
                      ],
                    ),
                  if (!m.loading && m.failure != null)
                    TextButton(
                      onPressed: () => m.load(),
                      child: const Text('다시 불러오기'),
                    ),
                ],
              ),
      );
    },
  );
}
