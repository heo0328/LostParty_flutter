import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/presentation/widgets/ownership_notice_title.dart';
import '../../domain/backend_recruitment.dart';
import '../viewmodels/backend_recruitment_create_view_model.dart';
import '../viewmodels/backend_recruitment_detail_view_model.dart';
import '../widgets/recruitment_section.dart';

class BackendRecruitmentDetailPage extends StatefulWidget {
  const BackendRecruitmentDetailPage({
    required this.gateway,
    required this.session,
    required this.roomId,
    required this.onLogin,
    required this.onCreateAnother,
    super.key,
  });
  final RecruitmentGateway gateway;
  final AccountReadSession session;
  final String roomId;
  final VoidCallback onLogin, onCreateAnother;
  @override
  State<BackendRecruitmentDetailPage> createState() =>
      _BackendRecruitmentDetailPageState();
}

class _BackendRecruitmentDetailPageState
    extends State<BackendRecruitmentDetailPage> {
  late final BackendRecruitmentDetailViewModel m;
  @override
  void initState() {
    super.initState();
    m = BackendRecruitmentDetailViewModel(
      gateway: widget.gateway,
      session: widget.session,
      roomId: widget.roomId,
    );
    unawaited(m.load());
  }

  @override
  void dispose() {
    m.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: m,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const OwnershipNoticeTitle(child: Text('모집 상세')),
        actions: [
          IconButton(
            onPressed: m.loading ? null : m.load,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: !widget.session.isAuthenticated
          ? Center(
              child: FilledButton(
                onPressed: widget.onLogin,
                child: const Text('로그인 후 확인'),
              ),
            )
          : m.value == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: m.loading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.failure == 'ROOM_NOT_FOUND' ||
                                    m.failure == 'ROOM_MEMBERSHIP_REQUIRED'
                                ? '현재 이 모집을 확인할 수 없습니다.'
                                : recruitmentFailureMessage(m.failure),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: m.load,
                            child: const Text('상세 다시 불러오기'),
                          ),
                        ],
                      ),
              ),
            )
          : RefreshIndicator(onRefresh: m.load, child: _detail()),
    ),
  );

  String _raidLabel(Map item) {
    final r = m.catalog?.raids
        .where((r) => r.raidId == item['raid_id'])
        .firstOrNull;
    final d = r?.difficulties
        .where((d) => d.difficultyId == item['difficulty_id'])
        .firstOrNull;
    return '${r?.displayName ?? item['raid_id']} · ${d?.name ?? item['difficulty_id']}';
  }

  Widget _detail() {
    final value = m.value!, room = value.room;
    final items = room['items'] as List;
    final combat = room['combat_requirement'] as Map;
    final group = room['group_id'];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        RecruitmentSection(
          title: value.title,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                RecruitmentBadge(
                  room['state'] == 'ended'
                      ? '종료'
                      : value.starts.isEmpty
                      ? '출발 미정'
                      : '시간 확정',
                  success: value.starts.isNotEmpty,
                ),
                RecruitmentBadge(room['scope'] == 'group' ? '그룹 전용' : '전체 공개'),
                if (room['restricted'] == true) const RecruitmentBadge('진행 제한'),
              ],
            ),
            const SizedBox(height: 14),
            for (final raw in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  _raidLabel(raw as Map),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            Text(
              '숙련도 · ${recruitmentExperiences[room['experience_level']] ?? '제한 없음'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (group != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  m.groupName == null ? '그룹 연결 모집' : '연결 그룹 ${m.groupName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '참가 ${value.memberCount}/${value.capacity} · ${room['admission_mode'] == 'direct_join' ? '바로 가입' : '파티장 승인'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '딜러 ${DisplayNumberFormatter.whole(combat['dealer_min'], missing: '제한 없음')} / 서포터 ${DisplayNumberFormatter.whole(combat['support_min'], missing: '제한 없음')}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        RecruitmentSection(
          title: '이번 주 진행 일정',
          children: [
            if (value.starts.isEmpty)
              const Text(
                '출발 미정 · 확정된 시간 예약은 없어요.',
                style: TextStyle(fontSize: 13),
              ),
            for (final start in value.starts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _time(start),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '앱 모집 마감 ${_time(start.subtract(const Duration(minutes: 30)))}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const OutlinedButton(onPressed: null, child: Text('공대원 일정 전체 확인')),
          ],
        ),
        RecruitmentSection(
          title: '파티 구성',
          children: [
            for (final member in value.members) _member(member, group != null),
          ],
        ),
        RecruitmentSection(
          title: '진행 · 다음 주',
          children: [
            Text(
              room['continuation_enabled'] == true
                  ? '다음 주도 함께하기 ON'
                  : '다음 주도 함께하기 OFF',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 8,
              children: [
                TextButton(onPressed: null, child: Text('일정 변경안')),
                TextButton(onPressed: null, child: Text('내 캐릭터 변경')),
                TextButton(onPressed: null, child: Text('레이드 완료')),
              ],
            ),
          ],
        ),
        if (m.loading) const LinearProgressIndicator(minHeight: 2),
        TextButton(
          onPressed: () {
            widget.onCreateAnother();
            context.push('/recruitments/create');
          },
          child: const Text('새 모집 만들기'),
        ),
      ],
    );
  }

  Widget _member(Map<String, dynamic> member, bool groupLinked) {
    final c = member['character'] as Map?;
    final display = c?['display'] as Map?;
    final name = display?['character_name'] as String? ?? '캐릭터 미확인';
    final role = c?['selected_role'] == 'support' ? '서포터' : '딜러';
    final leader = member['room_role'] == 'leader';
    final comparison = member['comparison'] as Map?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name${member['is_me'] == true ? ' · 나' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$role${leader ? ' · 공대장' : ''}${display?['class_name'] == null ? '' : ' · ${display!['class_name']}'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (comparison != null)
                  Text(
                    '전투력 ${DisplayNumberFormatter.whole(comparison['actual'])}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (member['status'] == 'needs_review')
                  const Text(
                    '캐릭터 상태 확인 필요',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
              ],
            ),
          ),
          if (groupLinked)
            RecruitmentBadge(member['group_member'] == true ? '그룹원' : '비그룹'),
        ],
      ),
    );
  }

  String _time(DateTime utc) {
    final kst = utc.toUtc().add(const Duration(hours: 9));
    const days = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};
    return '${days[kst.weekday]} ${kst.month}.${kst.day} ${minuteClock(kst.hour * 60 + kst.minute)}';
  }
}
