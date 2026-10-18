import '../domain/member_raid_models.dart';
import '../domain/personal_settings.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_models.dart';
import '../domain/server_character_lifecycle.dart';
import 'representative_client.dart';

/// Backend 8d03e962: one complete read snapshot, never a write permission.
class AccountBootstrap {
  AccountBootstrap.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'server_now complete registrations weekly_states');
    serverNow = roleUtc(json['server_now']);
    roleCheck(json['complete'] == true);
    final values = raidList(json['registrations']);
    roleCheck(values.length <= 20);
    registrations = List.unmodifiable(
      values.map((v) => BootstrapRegistration(roleMap(v))),
    );
    roleCheck(
      registrations.map((r) => r.snapshot.registrationId).toSet().length ==
          registrations.length,
    );
    roleCheck(registrations.where((r) => r.snapshot.isMain).length <= 1);
    final accounts = registrations
        .map((r) => r.snapshot.accountId)
        .whereType<String>()
        .toList();
    roleCheck(accounts.toSet().length == accounts.length);
    weekly = MemberWeeklyBatch.fromJson(roleMap(json['weekly_states']));
    roleCheck(
      weekly.cycleKey == weekly.cycle.key &&
          weekly.cycle.serverTime == serverNow,
    );
    final profiles = {
      for (final r in registrations)
        for (final p in r.profiles) p.characterId: p,
    };
    final keys = <String>{};
    for (final entry in weekly.entries) {
      final p = profiles[entry.characterId];
      roleCheck(
        p != null && entry.cycleKey == weekly.cycleKey && keys.add(entry.key),
      );
      roleCheck(
        entry.ownershipRevision == p!.ownershipRevision &&
            entry.lifecycleRevision == p.lifecycleRevision,
      );
    }
  }
  late final DateTime serverNow;
  late final List<BootstrapRegistration> registrations;
  late final MemberWeeklyBatch weekly;
}

class BootstrapRegistration {
  BootstrapRegistration(Map<String, dynamic> json) {
    roleShape(
      json,
      'registration characters representative presentation personal_profiles unavailable_characters',
    );
    final raw = roleMap(json['registration']);
    registration = ServerAccountRegistration.fromJson(raw);
    characters = LifecycleCharacterPage.fromJson(
      roleMap(json['characters']),
      maximumItems: 200,
    );
    roleCheck(characters.nextCursor == null);
    snapshot = characters.registration(registration.label, characters.items);
    roleCheck(
      snapshot.registrationId == registration.registrationId &&
          snapshot.accountId == registration.gameAccountId &&
          snapshot.version == registration.version &&
          snapshot.isMain == registration.isMain &&
          snapshot.ownershipStatus == registration.ownershipStatus &&
          snapshot.ownershipRevision == registration.ownershipRevision &&
          snapshot.rosterRevision ==
              (registration.rosterRevision ?? registration.version) &&
          sameLifecycleSettings(
            characters.settingsWire,
            roleMap(raw['settings']),
          ),
    );
    final ids = <String>{}, names = <(String, String)>{};
    for (final c in characters.items) {
      roleCheck(names.add((c.serverName, c.characterName)));
      if (c.characterId != null) roleCheck(ids.add(c.characterId!));
    }
    profiles = List.unmodifiable(
      raidList(
        json['personal_profiles'],
      ).map((p) => PersonalProfile.fromJson(roleMap(p))),
    );
    unavailable = {};
    for (final v in raidList(json['unavailable_characters'])) {
      final value = roleMap(v);
      roleShape(value, 'character_id code');
      final id = roleId(value['character_id']);
      roleCheck(
        {'CHARACTER_UNUSABLE', 'IDENTITY_CONFLICT'}.contains(value['code']) &&
            !unavailable.containsKey(id),
      );
      unavailable[id] = value['code'] as String;
    }
    representative = json['representative'] == null
        ? null
        : RepresentativeState.fromJson(roleMap(json['representative']));
    presentation = json['presentation'] == null
        ? null
        : AccountPresentation.fromJson(roleMap(json['presentation']));
    if (snapshot.ownershipStatus != 'owned') {
      roleCheck(
        representative == null &&
            presentation == null &&
            profiles.isEmpty &&
            unavailable.isEmpty,
      );
      return;
    }
    roleCheck(
      representative?.matches(snapshot) == true && presentation != null,
    );
    roleCheck(
      presentation!.registrationId == snapshot.registrationId &&
          presentation!.accountId == snapshot.accountId &&
          presentation!.ownershipRevision == snapshot.ownershipRevision &&
          presentation!.registrationVersion == snapshot.version,
    );
    final expected = snapshot.settings.activityIds.toSet();
    for (final p in profiles) {
      final c = characters.items
          .where((c) => c.characterId == p.characterId)
          .firstOrNull;
      roleCheck(
        expected.remove(p.characterId) &&
            c != null &&
            p.accountId == snapshot.accountId &&
            p.ownershipRevision == snapshot.ownershipRevision &&
            p.lifecycleRevision == c.lifecycleRevision &&
            p.lifecycleState == c.lifecycleState &&
            c.blockedReason != 'IDENTITY_CONFLICT',
      );
    }
    for (final id in unavailable.keys) {
      roleCheck(expected.remove(id));
      final c = characters.items.where((c) => c.characterId == id).firstOrNull;
      roleCheck(c == null || !c.usable);
    }
    roleCheck(expected.isEmpty);
  }
  late final ServerAccountRegistration registration;
  late final LifecycleCharacterPage characters;
  late final CacheRegistrationSnapshot snapshot;
  late final RepresentativeState? representative;
  late final AccountPresentation? presentation;
  late final List<PersonalProfile> profiles;
  late final Map<String, String> unavailable;
}

class AppliedAccountBootstrap {
  const AppliedAccountBootstrap(
    this.data,
    this.scope,
    this.sessionGeneration,
    this.generation,
    this.receivedAt,
  );
  final AccountBootstrap data;
  final StorageScope scope;
  final int sessionGeneration, generation;
  final DateTime receivedAt;
}
