import 'dart:async';
import 'account_bootstrap.dart';

import 'package:dio/dio.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_models.dart';
import '../domain/server_account_read_repository.dart';
import 'backend_account_read_api.dart';
import 'local/scoped_account_cache_database.dart';
import 'repositories/scoped_character_cache_repository.dart';
import 'server_character_lifecycle_client.dart';
import '../domain/entities/character_build_role.dart';
import 'mappers/scoped_role_build_mapper.dart';
import 'repositories/scoped_role_repository.dart';
import 'role_summary_client.dart';
import 'scoped_role_sync.dart';
import '../domain/role_summary.dart';
import 'personal_settings_client.dart';
import 'repositories/scoped_settings_repository.dart';
import 'scoped_settings_sync.dart';

typedef ScopedCacheDatabaseFactory =
    FutureOr<ScopedAccountCacheDatabase> Function();

/// Explicit factory only. Constructing a runtime/controller never opens a DB.
ScopedAccountCacheDatabase openScopedAccountCacheDatabase() =>
    ScopedAccountCacheDatabase(driftDatabase(name: 'lost_party_server_cache'));

class ScopedRegistrationRead {
  ScopedRegistrationRead(this.metadata, this.cached);
  final List<ServerAccountRegistration> metadata;
  final List<CacheRegistrationSnapshot> cached;
}

class ScopedMemberRoster {
  ScopedMemberRoster(
    Iterable<CacheRegistrationSnapshot> registrations,
    Iterable<CacheRosterSnapshot> rosters,
  ) : registrations = List.unmodifiable(registrations),
      rosters = List.unmodifiable(rosters);
  final List<CacheRegistrationSnapshot> registrations;
  final List<CacheRosterSnapshot> rosters;
}

class ScopedPersonalData {
  const ScopedPersonalData(this.preferences, this.dealer, this.support);
  final ScopedSettingsState preferences;
  final ScopedRoleState dealer, support;
}

/// The app owns this object and closes it after disposing its consumers.
/// Neither the injected authentication session nor the HTTP client is owned.
class ScopedAccountRuntime {
  ScopedAccountRuntime({
    required this.api,
    required ServerAccountReadRepository registrations,
    required this.databaseFactory,
    this.enabled = false,
    this.allowHttp = false,
    this.ownsDatabase = true,
    this.bootstrapEnabled = false,
  }) : baseUrl = api.dio.options.baseUrl {
    _validateEnvironment();
    _client = ServerCharacterLifecycleClient(api, registrations: registrations);
  }
  final DioBackendAccountReadApi api;
  final ScopedCacheDatabaseFactory databaseFactory;
  final String baseUrl;
  final bool enabled, allowHttp, ownsDatabase;
  final bool bootstrapEnabled;
  AppliedAccountBootstrap? _bootstrap;
  AppliedAccountBootstrap? get bootstrap {
    final value = _bootstrap;
    return canRead &&
            value?.scope == scope &&
            value?.sessionGeneration == session.generation &&
            value?.generation == readGeneration
        ? value
        : null;
  }

  late final ServerCharacterLifecycleClient _client;
  ScopedAccountCacheDatabase? _database;
  ScopedCharacterCacheRepository? _cache;
  ScopedRoleSync? _roles;
  ScopedSettingsSync? _settings;
  Future<ScopedCharacterCacheRepository>? _opening;
  final Set<Future<dynamic>> _active = {};
  bool _disposed = false;
  int _readGeneration = 0;
  int get readGeneration => _readGeneration;
  // Shared by the existing management editor and quick representative writes.
  Object? _characterSettingsOwner;
  bool get characterSettingsBusy => _characterSettingsOwner != null;
  void lockCharacterSettings(Object owner) {
    if (_characterSettingsOwner != null) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    _characterSettingsOwner = owner;
  }

  void unlockCharacterSettings(Object owner) {
    if (identical(_characterSettingsOwner, owner)) {
      _characterSettingsOwner = null;
    }
  }

  Future<void>? _closing;
  final Map<Object, Future<ScopedMemberRoster>> _memberRosters = {};

  AccountReadSession get session => api.session;
  bool get disposed => _disposed;
  bool get canRead => !_disposed && enabled && session.isAuthenticated;
  StorageScope get scope => StorageScope(
    baseUrl: baseUrl,
    userId: accountReadScope(session).userId,
    allowHttp: allowHttp,
  );
  ScopedRegistrationRef reference(String id) =>
      ScopedRegistrationRef(scope, id);

  void _validateEnvironment() {
    try {
      StorageScope(
        baseUrl: baseUrl,
        userId: '00000000-0000-4000-8000-000000000000',
        allowHttp: allowHttp,
      );
      // Dio collapses repeated slashes. Do not silently call another base path.
      final uri = Uri.parse(baseUrl);
      final prefix = uri.path.endsWith('/')
          ? uri.path.substring(0, uri.path.length - 1)
          : uri.path;
      for (final path in [
        '/v1/me/game-accounts',
        '/v2/me/game-accounts/00000000-0000-4000-8000-000000000000/characters',
        '/v2/me/character-retirements',
      ]) {
        final expected = uri.replace(path: '$prefix$path');
        final actual = RequestOptions(baseUrl: baseUrl, path: path).uri;
        if (uri.path.contains('//') || actual != expected) {
          throw const AccountReadException('INVALID_ENVIRONMENT');
        }
      }
    } on ScopedCacheException {
      throw const AccountReadException('INVALID_ENVIRONMENT');
    } on FormatException {
      throw const AccountReadException('INVALID_ENVIRONMENT');
    }
  }

  void requireCurrent(
    AccountReadScope sessionScope,
    StorageScope storageScope,
  ) {
    if (_disposed) throw const AccountReadException('DISPOSED');
    if (!enabled) throw const AccountReadException('FEATURE_DISABLED');
    requireAccountReadScope(session, sessionScope);
    if (api.dio.options.baseUrl != baseUrl || scope != storageScope) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
  }

  Future<T> _track<T>(Future<T> Function() action) {
    final future = Future<T>.sync(action);
    _active.add(future);
    future.then<void>(
      (_) => _active.remove(future),
      onError: (Object _, StackTrace _) {
        _active.remove(future);
      },
    );
    return future;
  }

  Future<ScopedCharacterCacheRepository> _cacheConnection() {
    if (_cache case final cache?) return Future.value(cache);
    if (_opening case final pending?) return pending;
    late final Future<ScopedCharacterCacheRepository> pending;
    pending = Future<ScopedAccountCacheDatabase>.sync(databaseFactory).then((
      db,
    ) {
      _database = db;
      if (_disposed) throw const AccountReadException('DISPOSED');
      final cache = ScopedCharacterCacheRepository(
        db,
        session,
        baseUrl: baseUrl,
        allowHttp: allowHttp,
      );
      _cache = cache;
      return cache;
    });
    _opening = pending;
    pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_opening, pending)) _opening = null;
      },
    );
    return pending;
  }

  Future<T> _withCache<T>(
    Future<T> Function(ScopedCharacterCacheRepository) action, {
    void Function()? guard,
  }) {
    final sessionScope = accountReadScope(session), storageScope = scope;
    requireCurrent(sessionScope, storageScope);
    return _track(() async {
      try {
        final cache = await _cacheConnection();
        requireCurrent(sessionScope, storageScope);
        guard?.call();
        final result = await action(cache);
        requireCurrent(sessionScope, storageScope);
        guard?.call();
        return result;
      } on AccountReadException {
        rethrow;
      } on ScopedCacheException {
        rethrow;
      } catch (_) {
        throw const AccountReadException('CACHE_UNAVAILABLE');
      }
    });
  }

  void invalidateReads() {
    _bootstrap = null;
    _readGeneration++;
    _cache?.invalidateReads();
    _roles?.store.invalidate();
    _settings?.store.invalidate();
  }

  /// Explicit snapshot import. Every existing writer retains its CAS/pending fence.
  Future<AppliedAccountBootstrap> restoreBootstrap({void Function()? guard}) =>
      _withCache((cache) async {
        final member = accountReadScope(session),
            storage = scope,
            generation = readGeneration;
        void current() {
          requireCurrent(member, storage);
          if (generation != readGeneration || characterSettingsBusy) {
            throw const AccountReadException('STALE_READ');
          }
          guard?.call();
        }

        current();
        _bootstrap = null;
        final read = await cache.beginRegistrations();
        current();
        final json = await api.request('/v2/me/account-bootstrap');
        current();
        final receivedAt = DateTime.now().toUtc();
        late AccountBootstrap data;
        try {
          data = AccountBootstrap.fromJson(json!);
        } on FormatException {
          throw const AccountReadException('INVALID_RESPONSE');
        } on TypeError {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        current();
        await cache.applyRegistrations(
          read,
          data.registrations.map((r) => r.snapshot),
        );
        for (final r in data.registrations) {
          current();
          final ref = ScopedRegistrationRef(storage, r.snapshot.registrationId);
          final token = await cache.beginRoster(ref);
          current();
          await cache.applyRoster(
            token,
            CacheRosterSnapshot(r.snapshot, [
              for (final c in r.characters.items)
                if (c.characterId != null)
                  CacheCharacterObservation(
                    characterId: c.characterId!,
                    accountId: r.snapshot.accountId!,
                    serverName: c.serverName,
                    characterName: c.characterName,
                    lifecycleState: c.lifecycleState,
                    lifecycleRevision: c.lifecycleRevision,
                    usable: c.usable,
                    blockedReason: c.blockedReason,
                    profile: c.wire,
                  ),
            ]),
          );
          current();
          if (r.presentation != null) {
            await _withSettings((s) async {
              await s.store.observe(
                ref,
                presentation: r.presentation,
                guard: current,
              );
            }, guard: current);
          }
          for (final profile in r.profiles) {
            current();
            final character = ScopedCharacterRef(
              storage,
              accountId: profile.accountId,
              characterId: profile.characterId,
            );
            await _withRoles((s) async {
              await s.store.observe(ref, character, profile, guard: current);
            }, guard: current);
            await _withSettings((s) async {
              await s.store.observe(
                ref,
                profile: profile,
                character: character,
                guard: current,
              );
            }, guard: current);
          }
        }
        current();
        return _bootstrap = AppliedAccountBootstrap(
          data,
          storage,
          member.generation,
          generation,
          receivedAt,
        );
      }, guard: guard);

  /// Shared current full roster preparation. Consumers supply their own guards
  /// after the session/observation-bound flight, never another consumer's key.
  Future<ScopedMemberRoster> loadMemberRoster({void Function()? guard}) {
    final member = accountReadScope(session),
        storage = scope,
        generation = readGeneration;
    requireCurrent(member, storage);
    guard?.call();
    void current() {
      requireCurrent(member, storage);
      if (readGeneration != generation) {
        throw const AccountReadException('ACCOUNT_OBSERVATION_CHANGED');
      }
    }

    final key = (storage, member.generation, generation);
    var flight = _memberRosters[key];
    if (flight == null) {
      late final Future<ScopedMemberRoster> pending;
      pending =
          _track(() async {
            final metadata = await refreshRegistrations(
              shareInFlight: true,
              guard: current,
            );
            final snapshots = <CacheRosterSnapshot>[];
            for (final r in metadata.cached.where(
              (r) => r.ownershipStatus == 'owned',
            )) {
              final view = await refreshRoster(
                ScopedRegistrationRef(storage, r.registrationId),
                guard: current,
              );
              cacheRequire(
                view.complete &&
                    view.validated &&
                    view.registration.sameStructure(r),
                'INVALID_PREPARATION',
              );
              snapshots.add(
                CacheRosterSnapshot(view.registration, view.characters),
              );
            }
            final latest = await readRegistrations(guard: current);
            cacheRequire(
              latest.length == metadata.cached.length &&
                  latest.every(
                    (r) => metadata.cached.any((old) => old.sameStructure(r)),
                  ),
              'INVALID_PREPARATION',
            );
            for (final snapshot in snapshots) {
              final view = await readRoster(
                ScopedRegistrationRef(
                  storage,
                  snapshot.registration.registrationId,
                ),
                guard: current,
              );
              cacheRequire(
                view?.complete == true &&
                    view!.registration.sameStructure(snapshot.registration) &&
                    view.characters.length == snapshot.characters.length &&
                    view.characters.every(
                      (c) => snapshot.characters.any(
                        (old) =>
                            old.characterId == c.characterId &&
                            old.lifecycleRevision == c.lifecycleRevision &&
                            old.lifecycleState == c.lifecycleState &&
                            old.usable == c.usable &&
                            old.profileJson == c.profileJson,
                      ),
                    ),
                'INVALID_PREPARATION',
              );
            }
            current();
            return ScopedMemberRoster(latest, snapshots);
          }).whenComplete(() {
            if (identical(_memberRosters[key], pending)) {
              _memberRosters.remove(key);
            }
          });
      _memberRosters[key] = flight = pending;
    }
    final shared = flight;
    return _track(() async {
      final result = await shared;
      current();
      guard?.call();
      return result;
    });
  }

  Future<ScopedPersonalData> restoreCharacterPersonalData(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character, {
    void Function()? guard,
  }) => _withRoles((roles) async {
    final plan = await roles.prepare(registration, character, guard: guard);
    return _withSettings((settings) async {
      final prefPlan = await settings.store.observe(
        registration,
        profile: plan.profile,
        character: character,
        guard: guard,
      );
      return ScopedPersonalData(
        await settings.store.read(prefPlan, guard: guard),
        await roles.read(plan, CharacterBuildRole.dealer, guard: guard),
        await roles.read(plan, CharacterBuildRole.support, guard: guard),
      );
    }, guard: guard);
  }, guard: guard);

  Future<ScopedRoleState?> readCachedRoleBuild(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => _withRoles(
    (roles) =>
        roles.store.readCached(registration, character, role, guard: guard),
    guard: guard,
  );

  Future<T> _withSettings<T>(
    Future<T> Function(ScopedSettingsSync) action, {
    void Function()? guard,
  }) => _withCache((cache) async {
    final settings = _settings ??= ScopedSettingsSync(
      PersonalSettingsClient(api),
      ScopedSettingsRepository(cache),
    );
    return action(settings);
  }, guard: guard);
  Future<ScopedSettingsPlan> preparePersonalSettings(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) => _withSettings(
    (s) => s.prepare(registration, character: character, guard: guard),
    guard: guard,
  );
  Future<ScopedSettingsState?> readCachedPersonalSettings(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) => _withSettings(
    (s) => s.store.readCached(registration, character: character, guard: guard),
    guard: guard,
  );

  Future<ScopedSettingsState> readPersonalSettings(
    ScopedSettingsPlan plan, {
    void Function()? guard,
  }) => _withSettings((s) => s.store.read(plan, guard: guard), guard: guard);
  Future<ScopedSettingsState> saveCharacterPreferences(
    ScopedSettingsPlan plan,
    PreferenceValues values, {
    void Function()? guard,
  }) {
    cacheRequire(plan.kind == SettingKind.preferences);
    return _withSettings(
      (s) => s.store.save(plan, values.toJson(), guard: guard),
      guard: guard,
    );
  }

  Future<ScopedSettingsState> saveAccountPresentation(
    ScopedSettingsPlan plan,
    int visibleCount, {
    void Function()? guard,
  }) {
    cacheRequire(plan.kind == SettingKind.presentation);
    return _withSettings(
      (s) => s.store.save(plan, {'visible_count': visibleCount}, guard: guard),
      guard: guard,
    );
  }

  Future<SettingsSyncResult> syncPersonalSettings(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) => _withSettings(
    (s) => s.sync(registration, character: character, guard: guard),
    guard: guard,
  );
  Future<ScopedSettingsState> useServerPersonalSettings(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) => _withSettings(
    (s) => s.useServer(registration, character: character, guard: guard),
    guard: guard,
  );

  Future<T> _withRoles<T>(
    Future<T> Function(ScopedRoleSync) action, {
    void Function()? guard,
  }) => _withCache((cache) async {
    final roles = _roles ??= ScopedRoleSync(
      RoleSummaryClient(api),
      ScopedRoleRepository(cache),
    );
    return action(roles);
  }, guard: guard);

  Future<ScopedRolePlan> prepareRoleBuild(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character, {
    void Function()? guard,
  }) => _withRoles(
    (roles) => roles.prepare(registration, character, guard: guard),
    guard: guard,
  );
  Future<ScopedRoleState> saveRoleBuild(
    ScopedRolePlan plan,
    ScopedRoleBuildDraft draft, {
    void Function()? guard,
  }) => _withRoles(
    (roles) => roles.save(plan, draft, guard: guard),
    guard: guard,
  );
  Future<ScopedRoleState> readRoleBuild(
    ScopedRolePlan plan,
    CharacterBuildRole role, {
    void Function()? guard,
  }) =>
      _withRoles((roles) => roles.read(plan, role, guard: guard), guard: guard);
  Future<RoleSyncResult> syncRoleBuild(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => _withRoles(
    (roles) => roles.sync(registration, character, role, guard: guard),
    guard: guard,
  );
  Future<ScopedRoleState> useServerRoleBuild(
    ScopedRegistrationRef registration,
    ScopedCharacterRef character,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => _withRoles(
    (roles) => roles.useServer(registration, character, role, guard: guard),
    guard: guard,
  );

  Future<List<CacheRegistrationSnapshot>> readRegistrations({
    void Function()? guard,
  }) =>
      _withCache((cache) => cache.readRegistrations(cache.scope), guard: guard);

  Future<ScopedRegistrationRead> refreshRegistrations({
    bool shareInFlight = false,
    void Function()? guard,
  }) => _withCache((cache) async {
    final metadata = await _client.refreshRegistrations(
      cache,
      shareInFlight: shareInFlight,
    );
    guard?.call();
    return ScopedRegistrationRead(
      metadata,
      await cache.readRegistrations(cache.scope),
    );
  }, guard: guard);

  Future<CachedRosterView?> readRoster(
    ScopedRegistrationRef ref, {
    void Function()? guard,
  }) => _withCache((cache) => cache.readRoster(ref), guard: guard);

  Future<CachedRosterView> refreshRoster(
    ScopedRegistrationRef ref, {
    void Function()? guard,
  }) => _withCache((cache) async {
    final receipt = await _client.refreshRoster(cache, ref);
    guard?.call();
    final view = await cache.readRoster(ref, receipt: receipt);
    if (view == null) {
      throw const AccountReadException('REGISTRATION_NOT_FOUND');
    }
    // Null account preview deliberately has no canonical head or receipt.
    if (view.registration.accountId != null && !view.validated) {
      throw const AccountReadException('STALE_READ');
    }
    return view;
  }, guard: guard);

  Future<RetirementRead> readRetirements({
    RetirementContinuation? next,
    void Function()? guard,
  }) {
    final sessionScope = accountReadScope(session), storageScope = scope;
    requireCurrent(sessionScope, storageScope);
    guard?.call();
    return _track(() async {
      final page = await _client.readRetirements(next: next);
      requireCurrent(sessionScope, storageScope);
      guard?.call();
      return page;
    });
  }

  /// Logical cancellation is immediate; close waits for already tracked work.
  /// It never deletes/recreates the DB and never closes the caller's Dio/session.
  Future<void> close() {
    if (_closing case final closing?) return closing;
    _disposed = true;
    _roles?.store.dispose();
    _settings?.store.dispose();
    _client.dispose();
    _cache?.dispose();
    return _closing = _close();
  }

  Future<void> _close() async {
    await Future.wait(
      _active.toList().map(
        (f) => f.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      ),
    );
    _cache?.dispose();
    if (ownsDatabase) await _database?.close();
  }
}
