import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/validation/raid_catalog_validator.dart';
import 'role_summary.dart';

String raidIdentifier(Object? value) {
  roleCheck(value is String && RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value));
  return value as String;
}

String raidCycleKey(Object? value) {
  roleCheck(value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value));
  final date = DateTime.parse('${value}T00:00:00Z');
  roleCheck(
    date.toIso8601String().substring(0, 10) == value &&
        date.weekday == DateTime.wednesday,
  );
  return value as String;
}

String raidText(Object? value) {
  roleCheck(value is String && value.isNotEmpty);
  return value as String;
}

bool raidBool(Object? value) {
  roleCheck(value is bool);
  return value as bool;
}

int raidNonnegative(Object? value) {
  roleCheck(value is int && value >= 0);
  return value as int;
}

List<dynamic> raidList(Object? value) {
  roleCheck(value is List);
  return value as List;
}

class MemberRaidCycle {
  MemberRaidCycle.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'server_time cycle_key starts_at ends_at timezone');
    serverTime = roleUtc(json['server_time']);
    startsAt = roleUtc(json['starts_at']);
    endsAt = roleUtc(json['ends_at']);
    key = raidCycleKey(json['cycle_key']);
    roleCheck(
      json['timezone'] == 'Asia/Seoul' &&
          !serverTime.isBefore(startsAt) &&
          serverTime.isBefore(endsAt) &&
          endsAt.difference(startsAt) == const Duration(days: 7),
    );
    final expected = DateTime.parse(
      '${key}T06:00:00Z',
    ).subtract(const Duration(hours: 9));
    roleCheck(expected == startsAt);
  }
  late final DateTime serverTime, startsAt, endsAt;
  late final String key;
}

RaidCatalog memberRaidCatalog(Map<String, dynamic> json) {
  roleShape(json, 'schema_version catalog_version updated_at raids');
  roleCheck(json['schema_version'] == 2 && json['schema_version'] is int);
  final version = raidText(json['catalog_version']);
  roleCheck(version.length <= 64);
  final raids = <RaidDefinition>[];
  final orders = <int>{};
  for (final raw in raidList(json['raids'])) {
    final r = roleMap(raw);
    roleShape(
      r,
      'raid_id official_name display_name aliases display_order party_size party_count required_support_count max_dealer_count_per_class gate_count is_active difficulties',
    );
    roleCheck(orders.add(rolePositive(r['display_order'])));
    final diffs = <RaidDifficultyDefinition>[];
    for (final rawDiff in raidList(r['difficulties'])) {
      final d = roleMap(rawDiff);
      roleShape(
        d,
        'difficulty_id name display_alias display_order min_item_level clear_gold bound_gold is_active',
      );
      final level = raidText(d['min_item_level']);
      roleCheck(RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(level));
      final parsed = double.parse(level);
      roleCheck(parsed.isFinite && parsed >= 1);
      diffs.add(
        RaidDifficultyDefinition(
          difficultyId: raidIdentifier(d['difficulty_id']),
          name: raidText(d['name']),
          displayAlias: raidText(d['display_alias']),
          displayOrder: rolePositive(d['display_order']),
          minItemLevel: parsed.floor(),
          exactMinItemLevel: level,
          clearGold: raidNonnegative(d['clear_gold']),
          boundGold: raidNonnegative(d['bound_gold']),
          isActive: raidBool(d['is_active']),
        ),
      );
    }
    diffs.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final size = rolePositive(r['party_size']);
    roleCheck(size == 4 || size == 8);
    raids.add(
      RaidDefinition(
        raidId: raidIdentifier(r['raid_id']),
        officialName: raidText(r['official_name']),
        displayName: raidText(r['display_name']),
        aliases: List.unmodifiable(
          raidList(r['aliases']).map((v) {
            roleCheck(v is String);
            return v as String;
          }),
        ),
        partySize: size,
        partyCount: rolePositive(r['party_count']),
        requiredSupportCount: rolePositive(r['required_support_count']),
        maxDealerCountPerClass: rolePositive(r['max_dealer_count_per_class']),
        gateCount: rolePositive(r['gate_count']),
        isActive: raidBool(r['is_active']),
        difficulties: List.unmodifiable(diffs),
      ),
    );
  }
  final catalog = RaidCatalog(
    schemaVersion: 2,
    catalogVersion: version,
    updatedAt: roleUtc(json['updated_at']),
    raids: List.unmodifiable(raids),
  );
  roleCheck(const RaidCatalogValidator().validate(catalog).isEmpty);
  return catalog;
}

class MemberWeeklyEntry {
  MemberWeeklyEntry.fromJson(Map<String, dynamic> json)
    : wire = Map.unmodifiable(json) {
    roleShape(
      json,
      'character_id raid_id cycle_key revision ownership_revision lifecycle_revision state completion_sources participation can_mark_completed can_clear_manual_completion mark_blocked_reason',
    );
    characterId = roleId(json['character_id']);
    raidId = raidIdentifier(json['raid_id']);
    cycleKey = raidCycleKey(json['cycle_key']);
    revision = rolePositive(json['revision']);
    ownershipRevision = rolePositive(json['ownership_revision']);
    lifecycleRevision = rolePositive(json['lifecycle_revision']);
    state = raidText(json['state']);
    roleCheck({'incomplete', 'participating', 'completed'}.contains(state));
    canMark = raidBool(json['can_mark_completed']);
    canClear = raidBool(json['can_clear_manual_completion']);
    final sources = <String>{};
    for (final raw in raidList(json['completion_sources'])) {
      final source = roleMap(raw);
      roleShape(source, 'source completed_at difficulty_id party_id');
      final kind = raidText(source['source']);
      roleCheck({'manual', 'party'}.contains(kind) && sources.add(kind));
      roleUtc(source['completed_at']);
      if (source['difficulty_id'] != null) {
        raidIdentifier(source['difficulty_id']);
      }
      if (source['party_id'] != null) roleId(source['party_id']);
      roleCheck(kind != 'manual' || source['party_id'] == null);
    }
    manual = sources.contains('manual');
    party = sources.contains('party');
    final participation = json['participation'];
    if (participation != null) {
      final p = roleMap(participation);
      roleShape(p, 'party_id difficulty_id joined_at');
      roleId(p['party_id']);
      raidIdentifier(p['difficulty_id']);
      roleUtc(p['joined_at']);
    }
    participating = participation != null;
    reason = json['mark_blocked_reason'] as String?;
    roleCheck(
      reason == null ||
          {
            'CURRENT_CYCLE_REQUIRED',
            'RAID_INACTIVE',
            'CHARACTER_UNUSABLE',
            'PARTICIPATION_CONFIRMATION_REQUIRED',
          }.contains(reason),
    );
    roleCheck(
      state ==
          (sources.isNotEmpty
              ? 'completed'
              : participating
              ? 'participating'
              : 'incomplete'),
    );
    roleCheck(
      !(participating && sources.isNotEmpty) &&
          (!canClear || manual) &&
          (canMark == (reason == null)),
    );
  }
  final Map<String, dynamic> wire;
  late final String characterId, raidId, cycleKey, state;
  late final String? reason;
  late final int revision, ownershipRevision, lifecycleRevision;
  late final bool canMark, canClear, manual, party, participating;
  bool get completed => state == 'completed';
  String get key => '$characterId:$raidId';
}

class MemberWeeklyBatch {
  MemberWeeklyBatch.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'current_cycle cycle_key catalog_version entries');
    cycle = MemberRaidCycle.fromJson(roleMap(json['current_cycle']));
    cycleKey = raidCycleKey(json['cycle_key']);
    catalogVersion = raidText(json['catalog_version']);
    entries = List.unmodifiable(
      raidList(
        json['entries'],
      ).map((v) => MemberWeeklyEntry.fromJson(roleMap(v))),
    );
  }
  late final MemberRaidCycle cycle;
  late final String cycleKey, catalogVersion;
  late final List<MemberWeeklyEntry> entries;
}
