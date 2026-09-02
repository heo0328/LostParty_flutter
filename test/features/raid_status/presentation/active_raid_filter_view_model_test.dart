import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/raid_status/data/repositories/drift_raid_status_filter_store.dart';
import 'package:lost_party/features/raid_status/domain/entities/raid_status_filter_selection.dart';
import 'package:lost_party/features/raid_status/presentation/viewmodels/active_raid_filter_view_model.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';
import 'package:lost_party/shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';

void main() {
  ActiveRaidSummary raid({
    required String id,
    String raidId = 'act4',
    String difficultyId = 'normal',
    String? groupId,
  }) => ActiveRaidSummary(
    id: id,
    title: id,
    leaderPlayerId: 'player-1',
    metadata: RecruitmentMetadata(
      catalogVersion: 'test',
      raidId: raidId,
      difficultyId: difficultyId,
      raidName: raidId,
      difficultyName: difficultyId,
      difficultyAlias: difficultyId,
      gateCount: 2,
      minItemLevel: 1680,
      minCombatPower: null,
      experienceLevel: null,
      maxPlayHours: null,
    ),
    currentCycleKey: '2026-08-19',
    memberCount: 1,
    maxMemberCount: 8,
    revision: 1,
    updatedAt: DateTime.utc(2026, 8, 20),
    isOwnedByCurrentPlayer: true,
    groupId: groupId,
  );

  test('원본과 필터 결과를 나누고 공개 조건을 로컬 적용한다', () async {
    final store = MemoryRaidStatusFilterStore();
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(id: 'public'),
            raid(id: 'group', groupId: 'group-1', raidId: 'serca'),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: store,
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.originalItems, hasLength(2));
    expect(viewModel.state.items, hasLength(2));
    expect(viewModel.state.countLabel, '2개');

    await viewModel.setSelection(
      RaidStatusFilterSelection.unrestricted.toggleGroup(),
    );
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(store.values['player-1']?.includeGroup, isFalse);
  });

  test('저장된 필터를 복원하고 카탈로그에 없는 선택은 제거한다', () async {
    final store = MemoryRaidStatusFilterStore({
      'player-1': const RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'act4', 'retired'},
        difficultyIds: {'normal', 'legacy'},
      ),
    });
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () => Stream.value(
        PartyReadSnapshot(
          items: [
            raid(id: 'public'),
            raid(id: 'serca', raidId: 'serca', difficultyId: 'hard'),
          ],
          isFromCache: false,
        ),
      ),
      playerId: 'player-1',
      filterStore: store,
      catalogRepository: _CatalogRepository(),
    )..start();
    addTearDown(viewModel.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.selection.raidIds, {'act4'});
    expect(viewModel.state.selection.difficultyIds, {'normal'});
    expect(viewModel.state.items.map((item) => item.id), ['public']);
    expect(viewModel.state.barLabel, '레이드 필터: 4막 · 노말');
  });

  test('칩 변경은 원본 스트림을 다시 구독하지 않는다', () async {
    var starts = 0;
    final controller =
        StreamController<PartyReadSnapshot<ActiveRaidSummary>>.broadcast();
    addTearDown(controller.close);
    final viewModel = ActiveRaidFilterViewModel(
      streamFactory: () {
        starts += 1;
        return controller.stream;
      },
      playerId: 'player-1',
      filterStore: MemoryRaidStatusFilterStore(),
    )..start();
    addTearDown(viewModel.dispose);

    controller.add(
      PartyReadSnapshot(items: [raid(id: 'public')], isFromCache: false),
    );
    await Future<void>.delayed(Duration.zero);
    await viewModel.setSelection(
      const RaidStatusFilterSelection(
        includePublic: true,
        includeGroup: true,
        raidIds: {'missing'},
      ),
    );

    expect(starts, 1);
    expect(viewModel.state.isEmptyFiltered, isTrue);
    expect(viewModel.state.originalItems, hasLength(1));
  });
}

class _CatalogRepository implements RaidCatalogRepository {
  @override
  Future<RaidCatalog> loadCatalog() async => RaidCatalog(
    schemaVersion: 1,
    catalogVersion: 'test',
    updatedAt: DateTime.utc(2026, 8, 20),
    raids: const [
      RaidDefinition(
        raidId: 'act4',
        officialName: '4막',
        displayName: '4막',
        aliases: [],
        partySize: 8,
        partyCount: 2,
        requiredSupportCount: 2,
        maxDealerCountPerClass: 2,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'normal',
            name: '노말',
            displayAlias: '노말',
            displayOrder: 1,
            minItemLevel: 1680,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1700,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
      RaidDefinition(
        raidId: 'serca',
        officialName: '세르카',
        displayName: '세르카',
        aliases: [],
        partySize: 4,
        partyCount: 1,
        requiredSupportCount: 1,
        maxDealerCountPerClass: 1,
        gateCount: 2,
        isActive: true,
        difficulties: [
          RaidDifficultyDefinition(
            difficultyId: 'hard',
            name: '하드',
            displayAlias: '하드',
            displayOrder: 2,
            minItemLevel: 1730,
            clearGold: 0,
            boundGold: 0,
            isActive: true,
          ),
        ],
      ),
    ],
  );
}
