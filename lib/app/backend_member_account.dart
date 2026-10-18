import 'dart:async';

import 'package:flutter/foundation.dart';
import '../features/account/data/member_raid_client.dart';
import '../features/account/data/member_weekly_store.dart';
import '../features/account/presentation/viewmodels/member_weekly_view_model.dart';

import '../features/account/data/datasources/lost_ark_character_remote_data_source.dart';
import '../features/account/data/scoped_startup_refresh_source.dart';
import '../features/account/presentation/viewmodels/member_account_view_model.dart';
import '../features/account/presentation/viewmodels/member_lostark_key.dart';
import '../features/account/presentation/viewmodels/member_settings_view_model.dart';
import '../features/account/presentation/viewmodels/scoped_startup_refresh_controller.dart';
import '../shared/game_catalog/domain/repositories/game_catalog_repository.dart';
import '../shared/lost_ark_api/client/api_cooldown.dart';
import 'backend_account_lifecycle.dart';

/// App owns member list + runner; pages/shell only subscribe. No DB ownership.
class BackendMemberAccount {
  BackendMemberAccount({
    required BackendAccountLifecycle lifecycle,
    this.automaticRefreshEnabled = BackendAccountLifecycle.configuredEnabled,
    required MemberSettingsViewModel settings,
    required MemberLostArkKey key,
    required LostArkCharacterRemoteDataSource remote,
    required GameCatalogRepository catalog,
    required ApiCooldown cooldown,
    MemberWeeklyStore? weeklyStore,
  }) {
    final gate = lifecycle.model!, runtime = lifecycle.runtime!;
    final changes = Listenable.merge([settings, key, gate]);
    bool pending() => gate.commandInProgress || gate.loading;
    source = RuntimeStartupRefreshSource(
      runtime: runtime,
      remote: remote,
      catalog: catalog,
      cooldown: cooldown,
      changes: changes,
      readAccess: () {
        final settingsReady =
            settings.signedIn &&
            settings.value != null &&
            !settings.busy &&
            !settings.hasPending &&
            settings.failure == null;
        final keyReady =
            key.signedIn &&
            key.localReady &&
            key.value?.configured == true &&
            !key.busy &&
            !key.hasPending &&
            key.failure == null;
        return ScopedRefreshAccess(
          niceGroupEnabled: settingsReady ? settings.value!.enabled : null,
          settingsVersion: settingsReady ? settings.value!.version : null,
          keyVersion: keyReady ? key.value!.version : null,
          accountChangesPending: pending() || runtime.characterSettingsBusy,
        );
      },
    );
    runner = ScopedStartupRefreshController(
      source,
      canStartAutomatically: _automaticPresentationReady,
    );
    model = MemberAccountViewModel(
      runtime: runtime,
      runner: runner,
      catalog: catalog,
      gateChanges: gate,
      commandPending: pending,
    );
    if (weeklyStore != null) {
      weekly = MemberWeeklyViewModel(
        model: model,
        client: MemberRaidClient(runtime.api),
        store: weeklyStore,
      );
    }
  }
  final bool automaticRefreshEnabled;
  late final RuntimeStartupRefreshSource source;
  late final ScopedStartupRefreshController runner;
  late final MemberAccountViewModel model;
  MemberWeeklyViewModel? weekly;
  bool _disposed = false, _initialized = false, _automaticInitialized = false;
  bool _displayWasReady = false;
  void initialize() {
    if (_disposed || _initialized) return;
    _initialized = true;
    weekly?.initialize();
    model.initialize();
    if (automaticRefreshEnabled) {
      model.addListener(_startAutomaticWhenDisplayReady);
      weekly?.addListener(_startAutomaticWhenDisplayReady);
      _startAutomaticWhenDisplayReady();
    }
  }

  bool _automaticPresentationReady() =>
      model.initialDisplayReady &&
      !model.loading &&
      (model.failure != null || weekly?.initialDisplaySettled != false);

  void _startAutomaticWhenDisplayReady() {
    if (_disposed) return;
    final ready = _automaticPresentationReady();
    final becameReady = ready && !_displayWasReady;
    _displayWasReady = ready;
    if (!ready) return;
    if (!_automaticInitialized) {
      _automaticInitialized = true;
      runner.initialize();
    } else if (becameReady && !runner.consumed && !runner.isBusy) {
      unawaited(runner.startIfReady());
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    model.removeListener(_startAutomaticWhenDisplayReady);
    weekly?.removeListener(_startAutomaticWhenDisplayReady);
    weekly?.dispose();
    model.dispose();
    runner.dispose();
    source.dispose();
  }
}
