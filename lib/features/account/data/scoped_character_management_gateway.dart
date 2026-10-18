import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/account_read_session.dart';
import '../domain/entities/local_game_account.dart';
import '../domain/repositories/character_management_gateway.dart';
import '../domain/role_summary.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_models.dart';
import '../domain/services/nice_group_policy.dart';
import 'local/scoped_command_key.dart';
import 'scoped_account_runtime.dart';

/// App-owned editor session; retains an uncertain command across page re-entry.
/// No local account DB writes, ownership seeding or provider calls.
class ScopedCharacterManagementGateway extends ChangeNotifier
    implements CharacterManagementGateway {
  ScopedCharacterManagementGateway(
    this.runtime,
    this.registrationId, {
    required this.otherWorkPending,
  }) {
    runtime.session.addListener(_sessionChanged);
  }
  final ScopedAccountRuntime runtime;
  final String registrationId;
  final bool Function() otherWorkPending;
  AccountReadScope? _session;
  StorageScope? _scope;
  CacheRegistrationSnapshot? _registration;
  final Map<int, CacheCharacterObservation> _characters = {};
  Map<String, dynamic>? _body;
  String? _key;
  DateTime? _retryAt;
  bool _acknowledged = false, _busy = false, _disposed = false;
  int _ticket = 0;
  CharacterManagementSnapshot? _loaded;
  ScopedMemberRoster? _confirmedRoster;
  int? _confirmedGeneration;
  ScopedMemberRoster? get confirmedRoster =>
      current &&
          !pending &&
          !busy &&
          _confirmedGeneration == runtime.readGeneration
      ? _confirmedRoster
      : null;
  int? _pendingCount;
  List<int>? _pendingOrder;
  @override
  bool get busy => _busy;
  @override
  bool get pending => _body != null;
  @override
  bool get current =>
      !_disposed &&
      runtime.canRead &&
      _session != null &&
      _session == accountReadScope(runtime.session) &&
      _scope == runtime.scope &&
      _registration != null;

  void _sessionChanged() {
    if (_session != null &&
        (!runtime.canRead || _session != accountReadScope(runtime.session))) {
      _ticket++;
      _registration = null;
      _loaded = null;
      _characters.clear();
      _body = null;
      _key = null;
      _pendingOrder = null;
      _pendingCount = null;
      _acknowledged = false;
      _retryAt = null;
      if (!_disposed) notifyListeners();
    }
  }

  void _guard(int ticket, AccountReadScope member, StorageScope scope) {
    if (_disposed || ticket != _ticket) {
      throw const AccountReadException('STALE_READ');
    }
    runtime.requireCurrent(member, scope);
  }

  @override
  Future<CharacterManagementSnapshot> load() => _load();

  Future<CharacterManagementSnapshot> _load({
    bool fresh = false,
    ScopedMemberRoster? confirmedRoster,
    bool cachedSettings = false,
  }) async {
    if (_busy) throw const AccountReadException('REQUEST_IN_PROGRESS');
    if (!fresh && pending && current && _loaded != null) return _loaded!;
    final ticket = _ticket,
        member = accountReadScope(runtime.session),
        scope = runtime.scope;
    void guard() => _guard(ticket, member, scope);
    final roster =
        confirmedRoster ?? await runtime.loadMemberRoster(guard: guard);
    guard();
    final reg = roster.registrations
        .where((r) => r.registrationId == registrationId)
        .firstOrNull;
    if (reg?.ownershipStatus != 'owned' ||
        reg?.accountId == null ||
        reg?.ownershipRevision == null) {
      throw const AccountReadException('OWNERSHIP_REQUIRED');
    }
    final snapshot = roster.rosters
        .where((r) => r.registration.registrationId == registrationId)
        .firstOrNull;
    if (snapshot == null || !snapshot.registration.sameStructure(reg!)) {
      throw const AccountReadException('INVALID_PREPARATION');
    }
    final ref = runtime.reference(registrationId);
    var presentation = cachedSettings
        ? await runtime.readCachedPersonalSettings(ref, guard: guard)
        : null;
    if (presentation == null) {
      final plan = await runtime.preparePersonalSettings(ref, guard: guard);
      presentation = await runtime.readPersonalSettings(plan, guard: guard);
    }
    final characters = <LocalAccountCharacter>[];
    final mapping = <int, CacheCharacterObservation>{};
    final usable = <int>{};
    // Stable inside this editor only; UUID is the sole server identity.
    final ordered = snapshot.characters.toList()
      ..sort((a, b) => a.characterId.compareTo(b.characterId));
    for (var i = 0; i < ordered.length; i++) {
      final row = ordered[i], id = i + 1;
      final profile = jsonDecode(row.profileJson) as Map<String, dynamic>;
      final character = ScopedCharacterRef(
        scope,
        accountId: row.accountId,
        characterId: row.characterId,
      );
      var pref = cachedSettings
          ? await runtime.readCachedPersonalSettings(
              ref,
              character: character,
              guard: guard,
            )
          : null;
      if (pref == null) {
        final p = await runtime.preparePersonalSettings(
          ref,
          character: character,
          guard: guard,
        );
        pref = await runtime.readPersonalSettings(p, guard: guard);
      }
      final values = pref.preferences;
      final level = double.tryParse('${profile['item_level']}');
      if (_usable(row)) usable.add(id);
      mapping[id] = row;
      characters.add(
        LocalAccountCharacter(
          id: id,
          serverCharacterId: row.characterId,
          serverName: row.serverName,
          characterName: row.characterName,
          characterLevel: profile['character_level'] as int,
          characterClassName: profile['class_name'] as String,
          itemLevel: level,
          combatPower: double.tryParse('${profile['combat_power']}'),
          isVisible: values.visible,
          displayOrder: values.displayOrder,
          preferredRole: values.preferredRole,
          isRosterMissing: row.lifecycleState != 'active',
        ),
      );
    }
    guard();
    final ids = {for (final c in characters) c.serverCharacterId: c.id};
    final selected = {
      for (final id in reg.settings.activityIds)
        if (ids[id] != null) ids[id]!,
    };
    if (selected.length != reg.settings.activityIds.length ||
        (reg.settings.representativeId != null &&
            ids[reg.settings.representativeId] == null)) {
      throw const AccountReadException('CHARACTER_UNUSABLE');
    }
    final account = LocalGameAccount(
      id: 1,
      label: reg.label,
      isMain: reg.isMain,
      lookupCharacterName: '',
      representativeCharacterId: ids[reg.settings.representativeId],
      displayLimit: presentation.visibleCount,
      characters: characters,
    );
    _session = member;
    _scope = scope;
    _registration = reg;
    _characters
      ..clear()
      ..addAll(mapping);
    // NiceGroup classification includes all owned rosters, not only this editor.
    final niceAccounts = [
      for (final r in roster.rosters)
        LocalGameAccount(
          id: 0,
          label: '',
          isMain: false,
          lookupCharacterName: '',
          representativeCharacterId: null,
          displayLimit: 1,
          characters: [
            for (final c in r.characters)
              LocalAccountCharacter(
                id: 0,
                serverName: c.serverName,
                characterName: c.characterName,
                characterLevel: 0,
                characterClassName:
                    (jsonDecode(c.profileJson) as Map)['class_name'] as String,
                itemLevel: double.tryParse(
                  '${(jsonDecode(c.profileJson) as Map)['item_level']}',
                ),
                combatPower: null,
                isVisible: true,
                displayOrder: null,
              ),
          ],
        ),
    ];
    _confirmedRoster = roster;
    _confirmedGeneration = runtime.readGeneration;
    return _loaded = CharacterManagementSnapshot(
      account: account,
      initialSelectionRequired: reg.settings.state == 'unconfigured',
      selectedIds: selected,
      usableIds: usable,
      hasNiceGroup: !const NiceGroupPolicy().evaluate(niceAccounts).isEmpty,
    );
  }

  bool _usable(CacheCharacterObservation row) {
    final p = jsonDecode(row.profileJson) as Map;
    final level = double.tryParse('${p['item_level']}');
    return level != null &&
        level.isFinite &&
        level >= 0 &&
        row.usable == true &&
        row.lifecycleState == 'active' &&
        p['roster_status'] == 'confirmed';
  }

  @override
  Future<CharacterManagementSnapshot> save({
    required List<int> selectedIds,
    required int representativeId,
    required int displayLimit,
    bool initializeSelection = false,
    bool saveDisplayOrder = true,
  }) async {
    if (!current) throw const AccountReadException('STALE_READ');
    if (_busy || otherWorkPending()) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    final ticket = _ticket, member = _session!, scope = _scope!;
    void guard() => _guard(ticket, member, scope);
    final lock = Object();
    runtime.lockCharacterSettings(lock);
    _busy = true;
    notifyListeners();
    ScopedMemberRoster? confirmed;
    try {
      if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) {
        throw AccountReadException('REQUEST_IN_PROGRESS', retryAt: _retryAt);
      }
      if (!pending) {
        if (initializeSelection &&
            _registration!.settings.state != 'unconfigured') {
          throw const AccountReadException('REVISION_CONFLICT');
        }
        if (selectedIds.isEmpty ||
            selectedIds.length != selectedIds.toSet().length ||
            !selectedIds.contains(representativeId) ||
            !selectedIds.every(
              (id) => _characters[id] != null && _usable(_characters[id]!),
            )) {
          throw const AccountReadException('CHARACTER_UNUSABLE');
        }
        final reg = _registration!;
        final fresh = await runtime.loadMemberRoster(guard: guard);
        final actual = fresh.registrations
            .where((r) => r.registrationId == registrationId)
            .firstOrNull;
        if (actual == null || !reg.sameStructure(actual)) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
        final rows = fresh.rosters
            .where((r) => r.registration.registrationId == registrationId)
            .expand((r) => r.characters)
            .toList();
        if (!selectedIds.every(
          (id) => rows.any(
            (c) => c.characterId == _characters[id]!.characterId && _usable(c),
          ),
        )) {
          throw const AccountReadException('CHARACTER_UNUSABLE');
        }
        _body = Map.unmodifiable({
          'activity_character_ids': selectedIds
              .map((id) => _characters[id]!.characterId)
              .toList(growable: false),
          'representative_character_id':
              _characters[representativeId]!.characterId,
          'expected_settings_version': reg.settings.version,
          'expected_ownership_revision': reg.ownershipRevision,
          'expected_roster_revision': reg.rosterRevision,
        });
        _pendingOrder = initializeSelection || !saveDisplayOrder
            ? []
            : List.of(selectedIds);
        _pendingCount = displayLimit;
        _key = newScopedCommandKey();
      }
      guard();
      if (!_acknowledged) {
        final response = await runtime.api.request(
          '/v1/me/game-accounts/$registrationId/character-settings',
          method: 'PUT',
          body: _body,
          idempotencyKey: _key,
        );
        guard();
        final value = ServerCharacterSettings.fromJson(response!);
        roleCheck(
          value.ownershipRevision == _body!['expected_ownership_revision'] &&
              value.settingsVersion >=
                  (_body!['expected_settings_version'] as int) &&
              value.settingsVersion <=
                  (_body!['expected_settings_version'] as int) + 1 &&
              value.representativeCharacterId ==
                  _body!['representative_character_id'] &&
              setEquals(
                value.activityCharacterIds.toSet(),
                (_body!['activity_character_ids'] as List)
                    .cast<String>()
                    .toSet(),
              ),
        );
        _acknowledged = true;
        runtime.invalidateReads();
      }
      // A replay ACK is historical. Only a new complete read supplies UI values.
      final fresh = await runtime.loadMemberRoster(guard: guard);
      confirmed = fresh;
      final reg = fresh.registrations
          .where((r) => r.registrationId == registrationId)
          .firstOrNull;
      if (reg == null ||
          reg.ownershipStatus != 'owned' ||
          reg.accountId != _registration!.accountId ||
          reg.ownershipRevision != _registration!.ownershipRevision) {
        throw const AccountReadException('OWNERSHIP_REQUIRED');
      }
      if (reg.settings.version !=
                  (_body!['expected_settings_version'] as int) &&
              reg.settings.version !=
                  (_body!['expected_settings_version'] as int) + 1 ||
          reg.settings.representativeId !=
              _body!['representative_character_id'] ||
          !setEquals(
            reg.settings.activityIds.toSet(),
            (_body!['activity_character_ids'] as List).cast<String>().toSet(),
          )) {
        _clearPending();
        throw const AccountReadException('REVISION_CONFLICT');
      }
      final ref = runtime.reference(registrationId);
      // Preferences keep their own existing durable outbox and current values.
      for (var i = 0; i < _pendingOrder!.length; i++) {
        final row = _characters[_pendingOrder![i]]!;
        final c = ScopedCharacterRef(
          scope,
          accountId: row.accountId,
          characterId: row.characterId,
        );
        final plan = await runtime.preparePersonalSettings(
          ref,
          character: c,
          guard: guard,
        );
        final before = await runtime.readPersonalSettings(plan, guard: guard);
        final old = before.preferences;
        if (old.displayOrder == i && !before.hasPending) {
          continue;
        }
        if (old.displayOrder != i) {
          await runtime.saveCharacterPreferences(
            plan,
            PreferenceValues(
              preferredRole: old.preferredRole,
              visible: old.visible,
              displayOrder: i,
            ),
            guard: guard,
          );
        }
        final synced = await runtime.syncPersonalSettings(
          ref,
          character: c,
          guard: guard,
        );
        if (synced.failure != null) {
          throw AccountReadException(synced.failure!.code);
        }
      }
      final plan = await runtime.preparePersonalSettings(ref, guard: guard);
      final old = await runtime.readPersonalSettings(plan, guard: guard);
      if (old.visibleCount != _pendingCount) {
        await runtime.saveAccountPresentation(
          plan,
          _pendingCount!,
          guard: guard,
        );
      }
      if (old.visibleCount != _pendingCount || old.hasPending) {
        final synced = await runtime.syncPersonalSettings(ref, guard: guard);
        if (synced.failure != null) {
          throw AccountReadException(synced.failure!.code);
        }
      }
    } catch (e) {
      guard();
      if (e is AccountReadException) {
        if (e.retryAt != null || e.retryAfter != null) {
          _retryAt = e.retryAt ?? DateTime.now().add(e.retryAfter!);
        }
        // REQUEST_IN_PROGRESS/transport/invalid response are not failed writes.
        if (!_acknowledged &&
            {
              'OWNERSHIP_REQUIRED',
              'CHARACTER_UNUSABLE',
              'REVISION_CONFLICT',
              'REGISTRATION_NOT_FOUND',
              'REGISTRATION_CHANGED',
              'IDEMPOTENCY_EXPIRED',
            }.contains(e.code)) {
          _clearPending();
        }
      }
      rethrow;
    } finally {
      _busy = false;
      runtime.unlockCharacterSettings(lock);
      if (!_disposed) notifyListeners();
    }
    guard();
    final value = await _load(
      fresh: true,
      confirmedRoster: confirmed,
      cachedSettings: true,
    );
    guard();
    _clearPending();
    return value;
  }

  void _clearPending() {
    _body = null;
    _key = null;
    _pendingOrder = null;
    _pendingCount = null;
    _retryAt = null;
    _acknowledged = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    runtime.session.removeListener(_sessionChanged);
    super.dispose();
  }
}
