import '../../../../shared/diagnostics/load_timing.dart';
import '../../domain/services/account_detail_access.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import '../../data/mappers/character_build_analysis_mapper.dart';
import '../../data/repositories/scoped_role_repository.dart';
import '../../data/repositories/scoped_settings_repository.dart';
import '../../data/scoped_account_runtime.dart';
import '../../data/representative_client.dart';
import '../../data/scoped_character_management_gateway.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/character_build_analysis.dart';
import '../../domain/entities/character_build_role.dart';
import '../../domain/role_summary.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/services/scoped_account_presentation.dart';
import '../../domain/services/character_usage_level_policy.dart';
import 'scoped_startup_refresh_controller.dart';

class MemberCharacterState {
  const MemberCharacterState(
    this.ref,
    this.observation, {
    this.preferences,
    this.dealer,
    this.support,
    this.failure,
    this.cached = true,
  });
  final ScopedCharacterRef ref;
  final CacheCharacterObservation observation;
  final ScopedSettingsState? preferences;
  final ScopedRoleState? dealer, support;
  final String? failure;
  final bool cached;
  ScopedRoleState? role(CharacterBuildRole role) =>
      role == CharacterBuildRole.dealer ? dealer : support;
  MemberCharacterState withPreferences(ScopedSettingsState value) =>
      MemberCharacterState(
        ref,
        observation,
        preferences: value,
        dealer: dealer,
        support: support,
        cached: cached,
      );
  MemberCharacterState withRole(
    CharacterBuildRole role,
    ScopedRoleState? value,
  ) => MemberCharacterState(
    ref,
    observation,
    preferences: preferences,
    dealer: role == CharacterBuildRole.dealer ? value : dealer,
    support: role == CharacterBuildRole.support ? value : support,
    cached: cached,
  );
}

class MemberAccountSection {
  MemberAccountSection(
    this.registration,
    Iterable<MemberCharacterState> characters, {
    this.presentation,
    this.cached = true,
    this.failure,
  }) : characters = List.unmodifiable(characters);
  final CacheRegistrationSnapshot registration;
  final List<MemberCharacterState> characters;
  final ScopedSettingsState? presentation;
  final bool cached;
  final String? failure;
  bool get displayReady =>
      presentation != null &&
      characters
          .where(
            (c) =>
                registration.settings.activityIds.contains(c.ref.characterId),
          )
          .every((c) => c.preferences != null);
  List<MemberCharacterState> get ordered {
    if (characters.isEmpty) return characters;
    final projected = projectScopedAccountPresentation(
      items: characters
          .map(
            (c) => ScopedPresentationItem(
              c.ref,
              c.observation,
              PreferenceValues(
                visible: true,
                displayOrder: c.preferences?.preferences.displayOrder,
              ),
              itemLevel: double.tryParse(
                '${(jsonDecode(c.observation.profileJson) as Map)['item_level']}',
              ),
            ),
          )
          .toList(),
      scope: characters.first.ref.scope,
      accountId: registration.accountId!,
      representativeId: registration.settings.representativeId,
      visibleCount: 200,
    );
    return projected
        .map((p) => characters.firstWhere((c) => c.ref == p.ref))
        .toList();
  }

  List<MemberCharacterState> get visible => ordered
      .where(
        (c) =>
            registration.settings.activityIds.contains(c.ref.characterId) &&
            (c.preferences?.preferences.visible ?? true),
      )
      .take(presentation?.visibleCount ?? 200)
      .toList();
}

class RepresentativeChoice {
  RepresentativeChoice(
    this.registration,
    this.character,
    this.before,
    this.session,
  );
  final ScopedRegistrationRef registration;
  final ScopedCharacterRef character;
  final RepresentativeState before;
  final AccountReadScope session;
}

/// App-owned member state. Cache is display-only; each write gets a fresh plan.
class MemberAccountViewModel extends ChangeNotifier {
  MemberAccountViewModel({
    required this.runtime,
    required this.runner,
    required this.catalog,
    required this.gateChanges,
    required this.commandPending,
  }) {
    _session = (
      runtime.session.userId,
      runtime.session.generation,
      runtime.session.isAuthenticated,
    );
    runtime.session.addListener(_sessionChanged);
    runner.addListener(_runnerChanged);
    gateChanges.addListener(_gateChanged);
  }
  final ScopedAccountRuntime runtime;
  final ScopedStartupRefreshController runner;
  final GameCatalogRepository catalog;
  final Listenable gateChanges;
  final bool Function() commandPending;
  late (String?, int, bool) _session;
  bool _disposed = false,
      _activated = false,
      _refreshAfter = false,
      _wasRunnerBusy = false,
      _wasGate = false;
  bool _initialDisplayReady = false;
  bool get initialDisplayReady => _initialDisplayReady;
  int _epoch = 0;
  Future<void>? _flight;
  final Map<String, Future<void>> _writes = {};
  final Map<String, ScopedCharacterManagementGateway> _initializers = {};
  final Map<String, RepresentativeState> _representatives = {};
  final Map<String, RepresentativeCommand> _representativePending = {};
  final Map<String, DateTime> _representativeRetryAt = {};
  final Map<String, String> _representativeFailures = {};
  Timer? _representativeTimer;
  RepresentativeChoice? _representativeDialog;
  bool openRepresentativeDialog(RepresentativeChoice choice) {
    if (_representativeDialog != null) return false;
    _representativeDialog = choice;
    return true;
  }

  void closeRepresentativeDialog(RepresentativeChoice choice) {
    if (identical(_representativeDialog, choice)) _representativeDialog = null;
  }

  String? representativeTarget(String id) =>
      _representativePending[id]?.characterId;
  RepresentativeState? representative(String id) => _representatives[id];
  bool representativePending(String id) =>
      _representativePending.containsKey(id);
  String? representativeFailure(String id) => _representativeFailures[id];
  int representativeRetrySeconds(String id) {
    final until = _representativeRetryAt[id];
    return until == null
        ? 0
        : (until.difference(runner.source.cooldown.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, 86400);
  }

  List<MemberAccountSection> _sections = [];
  List<MemberAccountSection> get sections => List.unmodifiable(_sections);
  bool loading = false;
  bool restoring = false;
  int _backgroundEpoch = 0;
  String? failure;
  DateTime? _restoreRetryAt;
  Timer? _restoreRetryTimer;
  int get restoreRetrySeconds => _restoreRetryAt == null
      ? 0
      : (_restoreRetryAt!
                    .difference(runner.source.cooldown.now())
                    .inMilliseconds /
                1000)
            .ceil()
            .clamp(0, 86400);
  bool get canRefresh =>
      signedIn &&
      !loading &&
      !runner.isBusy &&
      !commandPending() &&
      restoreRetrySeconds == 0;
  void _observeReadFailure(Object error) {
    LoadTiming.failure();
    if (error is! AccountReadException || error.status != 429) return;
    final until =
        error.retryAt ??
        runner.source.cooldown.now().add(
          error.retryAfter ?? const Duration(seconds: 60),
        );
    if (_restoreRetryAt == null || until.isAfter(_restoreRetryAt!)) {
      _restoreRetryAt = until;
    }
    _restoreRetryTimer?.cancel();
    _restoreRetryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || restoreRetrySeconds == 0) timer.cancel();
      if (!_disposed) _emit();
    });
  }

  bool get signedIn => !_disposed && runtime.canRead;
  bool get canEdit =>
      signedIn &&
      !runtime.characterSettingsBusy &&
      !loading &&
      !runner.isBusy &&
      !commandPending() &&
      !_writes.keys.any(
        (key) =>
            key.startsWith('representative:') || key.startsWith('display:'),
      ) &&
      !runner.source.cooldown.active;
  bool busy(String key) => _writes.containsKey(key);
  bool get managementBlocked =>
      loading ||
      runner.isBusy ||
      commandPending() ||
      _writes.isNotEmpty ||
      _representativePending.isNotEmpty;
  MemberCharacterState? character(ScopedCharacterRef ref) => _sections
      .where((s) => s.registration.accountId == ref.accountId)
      .expand((s) => s.characters)
      .where(
        (c) => c.ref.characterId == ref.characterId && c.ref.scope == ref.scope,
      )
      .firstOrNull;
  bool detailsAvailable(ScopedCharacterRef ref) {
    if (!signedIn ||
        loading ||
        failure != null ||
        commandPending() ||
        ref.scope != runtime.scope) {
      return false;
    }
    final section = _sections
        .where((s) => s.registration.accountId == ref.accountId)
        .firstOrNull;
    return section != null &&
        !section.cached &&
        hasAccountDetailAccess(
          ownershipStatus: section.registration.ownershipStatus,
          accountId: section.registration.accountId,
          ownershipRevision: section.registration.ownershipRevision,
        ) &&
        section.characters.any(
          (c) =>
              c.ref.characterId == ref.characterId &&
              c.observation.lifecycleState == 'active' &&
              c.observation.usable == true,
        );
  }

  void _emit() {
    if (!_disposed) LoadTiming.listeners(notifyListeners);
  }

  void initialize() {
    if (_activated || _disposed) return;
    _activated = true;
    unawaited(refresh());
  }

  void _sessionChanged() {
    final next = (
      runtime.session.userId,
      runtime.session.generation,
      runtime.session.isAuthenticated,
    );
    if (next == _session) return;
    _session = next;
    _initialDisplayReady = false;
    _epoch++;
    _backgroundEpoch++;
    restoring = false;
    _flight = null;
    _writes.clear();
    _representatives.clear();
    _representativePending.clear();
    _representativeRetryAt.clear();
    _representativeFailures.clear();
    _representativeTimer?.cancel();
    _representativeTimer = null;
    _representativeDialog = null;
    _restoreRetryAt = null;
    _restoreRetryTimer?.cancel();
    _sections = [];
    loading = false;
    failure = null;
    _refreshAfter = false;
    _emit();
    if (_activated && signedIn) unawaited(refresh());
  }

  void _gateChanged() {
    final pending = commandPending();
    if (pending && !_wasGate) {
      _epoch++;
      _flight = null;
      loading = false;
    }
    if (!pending && _wasGate && _activated && signedIn) unawaited(refresh());
    _wasGate = pending;
    _emit();
  }

  void _runnerChanged() {
    final busy = runner.isBusy;
    if (!busy && _wasRunnerBusy && runner.consumed && signedIn) {
      if (_flight != null) {
        _refreshAfter = true;
      } else {
        unawaited(refresh());
      }
    }
    _wasRunnerBusy = busy;
    _emit();
  }

  String _code(Object e) => e is AccountReadException
      ? e.code
      : e is ScopedCacheException
      ? e.code
      : 'RESTORE_FAILED';
  void Function() _guard(
    int epoch,
    AccountReadScope member,
    StorageScope scope,
    int generation,
  ) => () {
    if (_disposed || epoch != _epoch || commandPending()) {
      throw const AccountReadException('STALE_READ');
    }
    runtime.requireCurrent(member, scope);
    if (runtime.readGeneration != generation) {
      throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
    }
  };
  Future<List<MemberCharacterState>> _restoreRows(
    CacheRegistrationSnapshot reg,
    List<MemberCharacterState> rows, {
    required void Function() guard,
    required bool active,
  }) async {
    final result = List<MemberCharacterState>.of(rows);
    final indices = [
      for (var i = 0; i < rows.length; i++)
        if (reg.settings.activityIds.contains(rows[i].ref.characterId) ==
            active)
          i,
    ];
    final registration = runtime.reference(reg.registrationId);
    for (var offset = 0; offset < indices.length; offset += 3) {
      guard();
      if (restoreRetrySeconds > 0) break;
      await Future.wait(
        indices.skip(offset).take(3).map((i) async {
          final row = rows[i];
          try {
            guard();
            final fresh = await runtime.restoreCharacterPersonalData(
              registration,
              row.ref,
              guard: guard,
            );
            guard();
            result[i] = MemberCharacterState(
              row.ref,
              row.observation,
              preferences: fresh.preferences,
              dealer: fresh.dealer,
              support: fresh.support,
              cached: false,
            );
          } catch (e) {
            guard();
            _observeReadFailure(e);
            result[i] = MemberCharacterState(
              row.ref,
              row.observation,
              preferences: row.preferences,
              dealer: row.dealer,
              support: row.support,
              failure: _code(e),
              cached: row.cached,
            );
          }
        }),
      );
    }
    guard();
    return result;
  }

  Future<List<MemberAccountSection>> _readSections(
    List<CacheRegistrationSnapshot> regs, {
    required bool server,
    bool activeCacheOnly = false,
    ScopedMemberRoster? confirmedRoster,
    required void Function() guard,
  }) async {
    final result = <MemberAccountSection>[];
    for (final reg in regs) {
      guard();
      final ref = runtime.reference(reg.registrationId);
      if (server &&
          restoreRetrySeconds == 0 &&
          reg.isMain &&
          reg.ownershipStatus == 'owned') {
        try {
          final value = await RepresentativeClient(
            runtime.api,
          ).get(ref, guard: guard);
          guard();
          if (!value.matches(reg)) {
            throw const AccountReadException('REVISION_CONFLICT');
          }
          _representatives[reg.registrationId] = value;
          final pending = _representativePending[reg.registrationId];
          if (pending != null &&
              (value.settingsVersion > pending.before.settingsVersion ||
                  value.registrationVersion !=
                      pending.before.registrationVersion ||
                  value.ownershipRevision != pending.before.ownershipRevision ||
                  value.rosterRevision != pending.before.rosterRevision)) {
            _representativePending.remove(reg.registrationId);
            _representativeRetryAt.remove(reg.registrationId);
          }
          _representativeFailures.remove(reg.registrationId);
        } catch (e) {
          guard();
          _observeReadFailure(e);
          _representativeFailures[reg.registrationId] = _code(e);
        }
      }
      final view = await LoadTiming.local(
        LocalLoadWork.roster,
        () => runtime.readRoster(ref, guard: guard),
      );
      final proof = confirmedRoster?.rosters
          .where((r) => r.registration.registrationId == reg.registrationId)
          .firstOrNull;
      final confirmedCache =
          view != null &&
          proof != null &&
          view.registration.sameStructure(proof.registration) &&
          view.characters.length == proof.characters.length &&
          view.characters.every(
            (c) => proof.characters.any(
              (p) =>
                  p.characterId == c.characterId &&
                  p.lifecycleRevision == c.lifecycleRevision &&
                  p.lifecycleState == c.lifecycleState &&
                  p.usable == c.usable &&
                  p.profileJson == c.profileJson,
            ),
          );
      var presentation = await LoadTiming.local(
        LocalLoadWork.presentation,
        () => runtime.readCachedPersonalSettings(ref, guard: guard),
      );
      String? accountFailure;
      if (server &&
          restoreRetrySeconds == 0 &&
          reg.ownershipStatus == 'owned') {
        try {
          final p = await runtime.preparePersonalSettings(ref, guard: guard);
          presentation = await runtime.readPersonalSettings(p, guard: guard);
        } catch (e) {
          guard();
          _observeReadFailure(e);
          accountFailure = _code(e);
        }
      }
      final rows = <MemberCharacterState>[];
      for (final c in view?.characters ?? <CacheCharacterObservation>[]) {
        final character = ScopedCharacterRef(
          runtime.scope,
          accountId: c.accountId,
          characterId: c.characterId,
        );
        if (activeCacheOnly &&
            !reg.settings.activityIds.contains(c.characterId)) {
          rows.add(MemberCharacterState(character, c, cached: true));
          continue;
        }
        final prefs = await LoadTiming.local(
          LocalLoadWork.preferences,
          () => runtime.readCachedPersonalSettings(
            ref,
            character: character,
            guard: guard,
          ),
        );
        final dealer = await LoadTiming.local(
          LocalLoadWork.dealer,
          () => runtime.readCachedRoleBuild(
            ref,
            character,
            CharacterBuildRole.dealer,
            guard: guard,
          ),
        );
        final support = await LoadTiming.local(
          LocalLoadWork.support,
          () => runtime.readCachedRoleBuild(
            ref,
            character,
            CharacterBuildRole.support,
            guard: guard,
          ),
        );
        var row = MemberCharacterState(
          character,
          c,
          preferences: prefs,
          dealer: dealer,
          support: support,
          cached: !(confirmedCache || view?.validated == true),
        );
        rows.add(row);
      }
      result.add(
        MemberAccountSection(
          reg,
          server
              ? await _restoreRows(reg, rows, guard: guard, active: true)
              : rows,
          presentation: presentation,
          cached: !(server || confirmedCache || view?.validated == true),
          failure: accountFailure,
        ),
      );
    }
    guard();
    return result;
  }

  /// The management gateway has already fetched and validated the saved roster.
  /// Reuse those receipts/settings instead of restoring every server profile again.
  Future<void> restoreAfterManagement(
    ScopedCharacterManagementGateway gateway,
  ) async {
    _backgroundEpoch++;
    final registrationId = gateway.registrationId;
    if (!identical(gateway.runtime, runtime)) return;
    final proof = gateway.confirmedRoster;
    if (!signedIn || commandPending()) return;
    final member = accountReadScope(runtime.session), scope = runtime.scope;
    final guard = _guard(_epoch, member, scope, runtime.readGeneration);
    try {
      final regs = await runtime.readRegistrations(guard: guard);
      final reg = regs
          .where((r) => r.registrationId == registrationId)
          .firstOrNull;
      if (reg?.ownershipStatus == 'owned' && reg!.isMain) {
        final value = await RepresentativeClient(
          runtime.api,
        ).get(runtime.reference(registrationId), guard: guard);
        guard();
        if (!value.matches(reg)) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
        _representatives[registrationId] = value;
        _representativeFailures.remove(registrationId);
      }
      _sections = await _readSections(
        regs,
        server: false,
        confirmedRoster: proof,
        guard: guard,
      );
      guard();
      failure = null;
      _emit();
    } catch (e) {
      if (!_disposed &&
          signedIn &&
          accountReadScope(runtime.session) == member) {
        failure = _code(e);
        _emit();
      }
    }
  }

  Future<void> refresh() {
    if (_writes.keys.any((key) => key.startsWith('representative:'))) {
      return Future.value();
    }
    if (!signedIn || commandPending() || restoreRetrySeconds > 0) {
      return Future.value();
    }
    if (_flight case final pending?) return pending;
    final epoch = _epoch,
        member = accountReadScope(runtime.session),
        scope = runtime.scope,
        initialGeneration = runtime.readGeneration;
    var generation = initialGeneration;
    void guard() => _guard(epoch, member, scope, generation)();
    loading = true;
    restoring = true;
    failure = null;
    late final Future<void> flight;
    flight =
        Future<void>(
          () => LoadTiming.run(LoadStage.accountRefresh, () async {
            try {
              await LoadTiming.run(LoadStage.displayReady, () async {
                if (_sections.isEmpty) {
                  await LoadTiming.run(LoadStage.initialCache, () async {
                    final cached = await LoadTiming.local(
                      LocalLoadWork.registrations,
                      () => runtime.readRegistrations(guard: guard),
                    );
                    _sections = await _readSections(
                      cached,
                      server: false,
                      activeCacheOnly: true,
                      guard: guard,
                    );
                    guard();
                    _initialDisplayReady = true;
                    _emit();
                  });
                }
                if (!_initialDisplayReady) {
                  guard();
                  _initialDisplayReady = true;
                  _emit();
                }
                var roster = await LoadTiming.run(
                  LoadStage.roster,
                  () => runtime.loadMemberRoster(guard: guard),
                );
                await LoadTiming.run(LoadStage.initialSelection, () async {
                  for (final reg in roster.registrations) {
                    if (reg.ownershipStatus != 'owned' ||
                        (reg.settings.state != 'unconfigured' &&
                            _initializers[reg.registrationId]?.pending !=
                                true)) {
                      continue;
                    }
                    final gateway = _initializers.putIfAbsent(
                      reg.registrationId,
                      () => ScopedCharacterManagementGateway(
                        runtime,
                        reg.registrationId,
                        otherWorkPending: () =>
                            commandPending() || runner.isBusy,
                      ),
                    );
                    final snapshot = await gateway.load();
                    guard();
                    if (!snapshot.initialSelectionRequired &&
                        !gateway.pending) {
                      continue;
                    }
                    final candidates =
                        snapshot.account.characters
                            .where(
                              (c) =>
                                  snapshot.usableIds.contains(c.id) &&
                                  const CharacterUsageLevelPolicy()
                                      .isInUsageRange(c.itemLevel),
                            )
                            .toList()
                          ..sort(
                            (a, b) => b.itemLevel!.compareTo(a.itemLevel!),
                          );
                    if (candidates.isEmpty) continue;
                    try {
                      await gateway.save(
                        selectedIds: candidates.map((c) => c.id).toList(),
                        representativeId: candidates.first.id,
                        displayLimit: candidates.length.clamp(1, 200),
                        initializeSelection: true,
                      );
                    } finally {
                      generation = runtime.readGeneration;
                    }
                    guard();
                    roster = await runtime.loadMemberRoster(guard: guard);
                  }
                });
                _sections = await LoadTiming.run(
                  LoadStage.displayCache,
                  () => _readSections(
                    roster.registrations,
                    server: false,
                    guard: guard,
                  ),
                );
                _emit();
                _sections = await LoadTiming.run(
                  LoadStage.activeRestore,
                  () => _readSections(
                    roster.registrations,
                    server: true,
                    guard: guard,
                  ),
                );
                loading = false;
                _emit();
              });
              final backgroundEpoch = ++_backgroundEpoch;
              void backgroundGuard() {
                guard();
                if (backgroundEpoch != _backgroundEpoch ||
                    _writes.isNotEmpty ||
                    runtime.characterSettingsBusy) {
                  throw const AccountReadException('STALE_READ');
                }
              }

              // Inactive results update only their cache. Never replace an editing
              // screen or active row from this older snapshot.
              await LoadTiming.run(LoadStage.inactiveRestore, () async {
                for (final section in _sections.toList()) {
                  if (section.cached ||
                      section.registration.ownershipStatus != 'owned') {
                    continue;
                  }
                  await _restoreRows(
                    section.registration,
                    section.characters,
                    guard: backgroundGuard,
                    active: false,
                  );
                }
              });
            } catch (e) {
              LoadTiming.failure();
              if (!_disposed && epoch == _epoch) {
                final code = _code(e);
                if (loading ||
                    !{
                      'STALE_READ',
                      'ACCOUNT_OBSERVATION_CHANGED',
                    }.contains(code)) {
                  _observeReadFailure(e);
                  failure = code;
                }
              }
            } finally {
              if (!_disposed && epoch == _epoch) {
                restoring = false;
                loading = false;
                _emit();
              }
            }
          }, root: true),
        ).whenComplete(() {
          if (!identical(_flight, flight)) return;
          _flight = null;
          if (_refreshAfter) {
            _refreshAfter = false;
            unawaited(refresh());
          }
        });
    _flight = flight;
    _emit();
    return flight;
  }

  RepresentativeChoice? representativeChoice(
    ScopedRegistrationRef reg,
    ScopedCharacterRef ref,
  ) {
    if (!canEdit ||
        _writes.isNotEmpty ||
        representativePending(reg.registrationId) ||
        _representativeFailures.containsKey(reg.registrationId) ||
        representativeRetrySeconds(reg.registrationId) > 0 ||
        reg.scope != runtime.scope ||
        ref.scope != runtime.scope) {
      return null;
    }
    final section = _sections
        .where((s) => s.registration.registrationId == reg.registrationId)
        .firstOrNull;
    final value = _representatives[reg.registrationId], row = character(ref);
    if (section == null ||
        section.cached ||
        !section.displayReady ||
        !section.visible.any((c) => c.ref.characterId == ref.characterId) ||
        !section.registration.isMain ||
        section.registration.ownershipStatus != 'owned' ||
        section.registration.accountId != ref.accountId ||
        value == null ||
        !value.matches(section.registration) ||
        value.characterId == ref.characterId ||
        !section.registration.settings.activityIds.contains(ref.characterId) ||
        row == null ||
        row.observation.lifecycleState != 'active' ||
        !_representativeEligible(row.observation) ||
        row.observation.usable != true) {
      return null;
    }
    return RepresentativeChoice(
      reg,
      ref,
      value,
      accountReadScope(runtime.session),
    );
  }

  Future<void> changeRepresentative(RepresentativeChoice choice) async {
    if (!signedIn || accountReadScope(runtime.session) != choice.session) {
      return;
    }
    final current = representativeChoice(choice.registration, choice.character);
    if (current == null || !identical(current.before, choice.before)) return;
    final id = choice.registration.registrationId;
    await _write('representative:$id', (guard) async {
      final lock = Object();
      runtime.lockCharacterSettings(lock);
      try {
        final roster = await runtime.loadMemberRoster(guard: guard);
        guard();
        final reg = roster.registrations
            .where((r) => r.registrationId == id)
            .firstOrNull;
        final row = roster.rosters
            .where((r) => r.registration.registrationId == id)
            .expand((r) => r.characters)
            .where((c) => c.characterId == choice.character.characterId)
            .firstOrNull;
        if (reg == null ||
            !choice.before.matches(reg) ||
            !reg.isMain ||
            reg.ownershipStatus != 'owned' ||
            !reg.settings.activityIds.contains(choice.character.characterId) ||
            row?.accountId != choice.character.accountId ||
            (row != null && !_representativeEligible(row)) ||
            row?.usable != true ||
            row?.lifecycleState != 'active') {
          _representatives.remove(id);
          throw const AccountReadException('REVISION_CONFLICT');
        }
        final command = RepresentativeCommand(
          choice.before,
          choice.character.characterId,
        );
        _representativePending[id] = command;
        await _sendRepresentative(choice.registration, command, guard);
      } finally {
        runtime.unlockCharacterSettings(lock);
      }
    });
    if (signedIn &&
        accountReadScope(runtime.session) == choice.session &&
        !representativePending(id)) {
      await refresh();
    }
  }

  bool _representativeEligible(CacheCharacterObservation row) {
    final profile = jsonDecode(row.profileJson) as Map;
    final level = double.tryParse('${profile['item_level']}');
    return row.usable == true &&
        row.lifecycleState == 'active' &&
        profile['roster_status'] == 'confirmed' &&
        level != null &&
        level.isFinite &&
        level >= 0;
  }

  Future<void> _sendRepresentative(
    ScopedRegistrationRef reg,
    RepresentativeCommand command,
    void Function() guard,
  ) async {
    final id = reg.registrationId;
    try {
      await RepresentativeClient(runtime.api).put(reg, command, guard: guard);
      guard();
      // Replay acknowledgements are historical: display only a subsequent GET.
      await RepresentativeClient(runtime.api).get(reg, guard: guard);
      guard();
      _representativePending.remove(id);
      _representativeRetryAt.remove(id);
      _representatives.remove(id);
    } catch (e) {
      guard();
      final definitive =
          e is AccountReadException &&
          {400, 403, 404, 409, 422}.contains(e.status) &&
          e.code != 'REQUEST_IN_PROGRESS';
      if (definitive) {
        _representativePending.remove(id);
        _representatives.remove(id);
      }
      if (e is AccountReadException &&
          (e.retryAt != null || e.retryAfter != null)) {
        _representativeRetryAt[id] =
            e.retryAt ?? runner.source.cooldown.now().add(e.retryAfter!);
        _representativeTimer ??= Timer.periodic(const Duration(seconds: 1), (
          _,
        ) {
          if (_representativeRetryAt.keys.every(
            (key) => representativeRetrySeconds(key) == 0,
          )) {
            _representativeTimer?.cancel();
            _representativeTimer = null;
          }
          _emit();
        });
      }
      _representativeFailures[id] = definitive
          ? _code(e)
          : 'REPRESENTATIVE_UNCERTAIN';
      rethrow;
    }
  }

  Future<void> retryRepresentative(ScopedRegistrationRef reg) async {
    if (!canEdit ||
        _writes.isNotEmpty ||
        reg.scope != runtime.scope ||
        representativeRetrySeconds(reg.registrationId) > 0) {
      return;
    }
    final command = _representativePending[reg.registrationId];
    if (command == null) return;
    final member = accountReadScope(runtime.session);
    await _write(
      'representative:${reg.registrationId}',
      (guard) => _sendRepresentative(reg, command, guard),
    );
    if (signedIn &&
        accountReadScope(runtime.session) == member &&
        !representativePending(reg.registrationId)) {
      await refresh();
    }
  }

  void _setCharacter(ScopedCharacterRef ref, MemberCharacterState row) {
    _sections = _sections
        .map(
          (s) => s.registration.accountId != ref.accountId
              ? s
              : MemberAccountSection(
                  s.registration,
                  s.characters.map(
                    (c) => c.ref.characterId == ref.characterId ? row : c,
                  ),
                  presentation: s.presentation,
                  cached: s.cached,
                  failure: s.failure,
                ),
        )
        .toList();
    _emit();
  }

  void _setPresentation(String registration, ScopedSettingsState value) {
    _sections = _sections
        .map(
          (s) => s.registration.registrationId != registration
              ? s
              : MemberAccountSection(
                  s.registration,
                  s.characters,
                  presentation: value,
                  cached: s.cached,
                ),
        )
        .toList();
    _emit();
  }

  Future<void> _write(
    String key,
    Future<void> Function(void Function()) action,
  ) {
    if (!canEdit) return Future.value();
    _backgroundEpoch++;
    if (_writes[key] case final active?) return active;
    final epoch = _epoch,
        member = accountReadScope(runtime.session),
        scope = runtime.scope,
        generation = runtime.readGeneration;
    final guard = _guard(epoch, member, scope, generation);
    failure = null;
    late final Future<void> flight;
    flight =
        Future<void>(() async {
          try {
            await action(guard);
          } catch (e) {
            if (!_disposed && epoch == _epoch) failure = _code(e);
          }
        }).whenComplete(() {
          if (identical(_writes[key], flight)) _writes.remove(key);
          _emit();
        });
    _writes[key] = flight;
    _emit();
    return flight;
  }

  Future<void> saveDisplaySettings(
    ScopedRegistrationRef reg,
    Map<String, PreferenceValues> values,
  ) => _write('display:${reg.registrationId}', (guard) async {
    cacheRequire(reg.scope == runtime.scope, 'SCOPE_CHANGED');
    for (final entry in values.entries) {
      guard();
      final section = sections.firstWhere(
        (s) => s.registration.registrationId == reg.registrationId,
      );
      final row = section.characters.firstWhere(
        (c) => c.ref.characterId == entry.key,
      );
      cacheRequire(
        section.registration.settings.activityIds.contains(entry.key),
        'CHARACTER_UNUSABLE',
      );
      final old = row.preferences!.preferences;
      if (old.preferredRole == entry.value.preferredRole &&
          old.visible == entry.value.visible &&
          old.displayOrder == entry.value.displayOrder) {
        continue;
      }
      final plan = await runtime.preparePersonalSettings(
        reg,
        character: row.ref,
        guard: guard,
      );
      final local = await runtime.saveCharacterPreferences(
        plan,
        entry.value,
        guard: guard,
      );
      guard();
      _setCharacter(row.ref, character(row.ref)!.withPreferences(local));
      final synced = await runtime.syncPersonalSettings(
        reg,
        character: row.ref,
        guard: guard,
      );
      guard();
      if (synced.state != null) {
        _setCharacter(
          row.ref,
          character(row.ref)!.withPreferences(synced.state!),
        );
      }
      if (synced.failure != null) {
        throw AccountReadException(synced.failure!.code);
      }
    }
  });

  Future<void> savePreferences(
    ScopedRegistrationRef reg,
    ScopedCharacterRef ref,
    PreferenceValues values,
  ) => _write('prefs:${ref.characterId}', (guard) async {
    cacheRequire(
      reg.scope == runtime.scope && ref.scope == runtime.scope,
      'SCOPE_CHANGED',
    );
    final p = await runtime.preparePersonalSettings(
      reg,
      character: ref,
      guard: guard,
    );
    final local = await runtime.saveCharacterPreferences(
      p,
      values,
      guard: guard,
    );
    guard();
    _setCharacter(ref, character(ref)!.withPreferences(local));
    final synced = await runtime.syncPersonalSettings(
      reg,
      character: ref,
      guard: guard,
    );
    guard();
    if (synced.state != null) {
      _setCharacter(ref, character(ref)!.withPreferences(synced.state!));
    }
    if (synced.failure != null) failure = synced.failure!.code;
  });
  Future<void> saveCount(ScopedRegistrationRef reg, int count) =>
      _write('count:${reg.registrationId}', (guard) async {
        cacheRequire(reg.scope == runtime.scope, 'SCOPE_CHANGED');
        final p = await runtime.preparePersonalSettings(reg, guard: guard);
        final local = await runtime.saveAccountPresentation(
          p,
          count,
          guard: guard,
        );
        guard();
        _setPresentation(reg.registrationId, local);
        final synced = await runtime.syncPersonalSettings(reg, guard: guard);
        guard();
        if (synced.state != null) {
          _setPresentation(reg.registrationId, synced.state!);
        }
        if (synced.failure != null) failure = synced.failure!.code;
      });
  Future<void> resolveSettings(
    ScopedRegistrationRef reg, {
    ScopedCharacterRef? ref,
    bool useServer = false,
  }) => _write(
    ref == null ? 'count:${reg.registrationId}' : 'prefs:${ref.characterId}',
    (guard) async {
      cacheRequire(
        reg.scope == runtime.scope &&
            (ref == null || ref.scope == runtime.scope),
        'SCOPE_CHANGED',
      );
      ScopedSettingsState? value;
      if (useServer) {
        value = await runtime.useServerPersonalSettings(
          reg,
          character: ref,
          guard: guard,
        );
      } else {
        final r = await runtime.syncPersonalSettings(
          reg,
          character: ref,
          guard: guard,
        );
        value = r.state;
        if (r.failure != null) failure = r.failure!.code;
      }
      guard();
      if (value != null) {
        if (ref == null) {
          _setPresentation(reg.registrationId, value);
        } else {
          _setCharacter(ref, character(ref)!.withPreferences(value));
        }
      }
    },
  );
  Future<void> resolveRole(
    ScopedRegistrationRef reg,
    ScopedCharacterRef ref,
    CharacterBuildRole role, {
    bool useServer = false,
  }) => _write('role:${ref.characterId}:${role.name}', (guard) async {
    cacheRequire(
      reg.scope == runtime.scope && ref.scope == runtime.scope,
      'SCOPE_CHANGED',
    );
    ScopedRoleState? value;
    if (useServer) {
      value = await runtime.useServerRoleBuild(reg, ref, role, guard: guard);
    } else {
      final r = await runtime.syncRoleBuild(reg, ref, role, guard: guard);
      value = r.state;
      if (r.failure != null) failure = r.failure!.code;
    }
    guard();
    if (value != null) {
      _setCharacter(ref, character(ref)!.withRole(role, value));
      if (!value.hasPending) runner.serverResolved(ref, role);
    }
  });
  Future<CharacterBuildAnalysis?> analysis(
    ScopedCharacterRef ref,
    CharacterBuildRole role,
  ) async {
    if (!detailsAvailable(ref)) return null;
    final row = character(ref), state = character(ref)?.role(role);
    if (row == null || state?.rawMatchesDisplay != true) return null;
    final member = accountReadScope(runtime.session),
        scope = runtime.scope,
        epoch = _epoch;
    final gameCatalog = await catalog.loadCatalog();
    runtime.requireCurrent(member, scope);
    if (epoch != _epoch || _disposed) {
      throw const AccountReadException('STALE_READ');
    }
    if (!detailsAvailable(ref)) return null;
    return const CharacterBuildAnalysisMapper().fromJson(
      jsonDecode(state!.rawJson!) as Map<String, dynamic>,
      catalog: gameCatalog,
    );
  }

  @override
  void dispose() {
    for (final gateway in _initializers.values) {
      gateway.dispose();
    }
    _initializers.clear();
    if (_disposed) return;
    _disposed = true;
    _representativeTimer?.cancel();
    _restoreRetryTimer?.cancel();
    _epoch++;
    runtime.session.removeListener(_sessionChanged);
    runner.removeListener(_runnerChanged);
    gateChanges.removeListener(_gateChanged);
    super.dispose();
  }
}
