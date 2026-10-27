import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../account/domain/scoped_cache_models.dart';
import '../../../account/presentation/viewmodels/member_account_view_model.dart';
import '../../data/cycle_read_repository.dart';

/// Display-only projection. Account names never replace historical snapshots.
Map<String, String> scopedParticipationNames(
  Iterable<MemberCharacterState> characters,
  StorageScope scope,
) => {
  for (final c in characters)
    if (c.ref.scope == scope &&
        c.ref.characterId == c.observation.characterId &&
        c.ref.accountId == c.observation.accountId &&
        c.observation.characterName.trim().isNotEmpty)
      c.ref.characterId: c.observation.characterName,
};

class CycleOwnCardInfo {
  CycleOwnCardInfo._(this.role, this.characters, this.raids);
  final String role;
  final List<String> characters, raids;

  static bool supports(CycleOwnRow row) =>
      row.isActiveParticipation &&
      row.participationState == 'participating' &&
      row.card != null &&
      row.profile?.content != null &&
      {'participant', 'retained'}.contains(row.profile!.mode) &&
      row.profile!.recovery['state'] == 'none' &&
      {'leader', 'member'}.contains(row.profile!.viewer['role']);

  static CycleOwnCardInfo? fromRow(
    CycleOwnRow row,
    Map<String, String> names,
    RaidCatalog? catalog,
  ) {
    if (!supports(row)) return null;
    final p = row.profile!, card = row.card!;
    final leader = p.viewer['role'] == 'leader';
    final role = card.capacity == 4
        ? (leader ? '파티장' : '파티원')
        : (leader ? '공대장' : '공대원');
    final ids = <String>{};
    for (final a in p.content!['assignments'] as List) {
      if (a['target_cycle_key'] == p.target['target_cycle_key'] &&
          a['cycle_member_id'] == p.viewer['cycle_member_id'] &&
          a['state'] == 'active' &&
          card.items.any(
            (i) =>
                i['item_id'] == a['item_id'] && i['round_id'] == a['round_id'],
          )) {
        ids.add((a['character_id'] as String).toLowerCase());
      }
    }
    return CycleOwnCardInfo._(
      role,
      List.unmodifiable([
        if (ids.isEmpty) '캐릭터명 확인 실패',
        for (final id in ids) names[id] ?? '캐릭터명 확인 실패',
      ]),
      List.unmodifiable([
        for (final item in card.items) raidLabel(item, catalog),
      ]),
    );
  }

  static String raidLabel(Map<String, dynamic> item, RaidCatalog? catalog) {
    final raid = catalog?.raids
        .where((r) => r.raidId == item['raid_id'])
        .firstOrNull;
    final difficulty = raid?.difficulties
        .where((d) => d.difficultyId == item['difficulty_id'])
        .firstOrNull;
    return '${raid?.displayName ?? item['raid_id']} · '
        '${difficulty?.name ?? item['difficulty_id']}';
  }
}
