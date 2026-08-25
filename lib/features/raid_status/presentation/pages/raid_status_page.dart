import 'package:flutter/material.dart';

class RaidStatusPage extends StatelessWidget {
  const RaidStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('레이드 현황'),
          bottom: const TabBar(
            tabs: [
              Tab(key: ValueKey('activeRaidsTab'), text: '진행 중'),
              Tab(key: ValueKey('pendingRaidsTab'), text: '신청 중'),
              Tab(key: ValueKey('raidHistoryTab'), text: '완료 기록'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RaidStatusEmptyView(
              key: ValueKey('activeRaidsPage'),
              icon: Icons.event_available_outlined,
              title: '진행 중인 레이드가 없습니다.',
              description: '생성하거나 가입이 확정된 레이드가 여기에 표시됩니다.',
            ),
            _RaidStatusEmptyView(
              key: ValueKey('pendingRaidsPage'),
              icon: Icons.hourglass_empty_outlined,
              title: '신청 중인 레이드가 없습니다.',
              description: '승인 대기 신청과 처리 결과가 여기에 표시됩니다.',
            ),
            _RaidStatusEmptyView(
              key: ValueKey('raidHistoryPage'),
              icon: Icons.history_outlined,
              title: '완료 기록이 없습니다.',
              description: '이번 주 완료와 지난 회차 기록이 여기에 표시됩니다.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RaidStatusEmptyView extends StatelessWidget {
  const _RaidStatusEmptyView({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
