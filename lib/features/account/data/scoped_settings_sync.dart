import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import 'personal_settings_client.dart';
import 'repositories/scoped_settings_repository.dart';

class SettingsSyncResult {
  const SettingsSyncResult(this.state, [this.failure]);
  final ScopedSettingsState? state;
  final AccountReadException? failure;
}

/// Explicit P2 operations only. No timers, armory reads or UI side effects.
class ScopedSettingsSync {
  ScopedSettingsSync(this.client, this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final PersonalSettingsClient client;
  final ScopedSettingsRepository store;
  final DateTime Function() now;
  final Map<Object, Future<SettingsSyncResult>> _flights = {};

  Future<ScopedSettingsPlan> prepare(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) async {
    guard?.call();
    if (character != null) {
      final profile = await client.profile(character);
      guard?.call();
      return store.observe(
        registration,
        profile: profile,
        character: character,
        guard: guard,
      );
    }
    final presentation = await client.presentation(registration);
    guard?.call();
    return store.observe(
      registration,
      presentation: presentation,
      guard: guard,
    );
  }

  Future<ScopedSettingsState> useServer(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) async => store.useServer(
    await prepare(registration, character: character, guard: guard),
    now().toUtc(),
    guard: guard,
  );

  Future<SettingsSyncResult> sync(
    ScopedRegistrationRef registration, {
    ScopedCharacterRef? character,
    void Function()? guard,
  }) {
    final session = accountReadScope(client.api.session);
    final key = (
      registration.scope,
      session.generation,
      registration.registrationId,
      character?.characterId,
    );
    if (_flights[key] case final active?) return active;
    late final Future<SettingsSyncResult> flight;
    flight = _sync(registration, character, guard).whenComplete(() {
      if (identical(_flights[key], flight)) _flights.remove(key);
    });
    return _flights[key] = flight;
  }

  Future<SettingsSyncResult> _sync(
    ScopedRegistrationRef registration,
    ScopedCharacterRef? character,
    void Function()? guard,
  ) async {
    final session = accountReadScope(client.api.session);
    void current() {
      client.roles.requireStorageScope(registration.scope, session);
      guard?.call();
    }

    ScopedSettingsPlan p;
    try {
      p = await prepare(registration, character: character, guard: current);
    } on AccountReadException catch (error) {
      current();
      return SettingsSyncResult(null, error);
    }
    var c = await store.materialize(p, guard: current);
    if (c == null) {
      return SettingsSyncResult(await store.read(p, guard: current));
    }
    final time = now().toUtc(), sent = c.firstSentAt;
    if (c.registrationId != registration.registrationId) {
      await store.fail(p, c, 'blocked', 'REGISTRATION_CHANGED', guard: current);
    } else if (sent != null &&
        (time.isBefore(sent) ||
            time.difference(sent) >= const Duration(hours: 24))) {
      await store.fail(
        p,
        c,
        'review',
        'IDEMPOTENCY_REVIEW_REQUIRED',
        guard: current,
      );
    } else if (p.kind == SettingKind.preferences &&
        (p.lifecycleState != 'active' ||
            c.body['expected_lifecycle_revision'] != p.lifecycleRevision)) {
      await store.fail(p, c, 'blocked', 'REVISION_CONFLICT', guard: current);
    } else if (sent == null &&
        (c.body['expected_version'] != p.server['version'] ||
            (p.kind == SettingKind.presentation &&
                c.body['expected_registration_version'] !=
                    p.server['registration_version']))) {
      await store.fail(p, c, 'conflict', 'REVISION_CONFLICT', guard: current);
    } else if ((c.state == 'ready' || c.state == 'retry') &&
        (c.retryAt == null || !time.isBefore(c.retryAt!))) {
      c = await store.markSent(p, c, time, guard: current);
      current();
      try {
        final Map<String, dynamic> server;
        if (character != null) {
          server = (await client.putPreferences(
            character,
            c.id,
            c.body,
          )).toJson();
        } else {
          final ack = await client.putPresentation(registration, c.id, c.body);
          if (ack.accountId != p.accountId) {
            throw const AccountReadException('INVALID_RESPONSE');
          }
          server = ack.toJson();
        }
        current();
        await store.acknowledge(p, c, server, guard: current);
      } on AccountReadException catch (error) {
        current();
        final retry =
            error.status == null ||
            error.status! >= 500 ||
            error.status == 429 ||
            error.code == 'REQUEST_IN_PROGRESS';
        final state = retry
            ? 'retry'
            : {'REVISION_CONFLICT', 'IDENTITY_CONFLICT'}.contains(error.code)
            ? 'conflict'
            : {
                'IDEMPOTENCY_CONFLICT',
                'IDEMPOTENCY_EXPIRED',
              }.contains(error.code)
            ? 'review'
            : 'blocked';
        await store.fail(
          p,
          c,
          state,
          error.code,
          retryAt:
              error.retryAt ??
              (error.retryAfter == null
                  ? null
                  : now().toUtc().add(error.retryAfter!)),
          guard: current,
        );
        return SettingsSyncResult(await store.read(p, guard: current), error);
      }
      // ACK confirms one immutable command. Refresh the present server state.
      try {
        p = await prepare(registration, character: character, guard: current);
      } on AccountReadException catch (error) {
        current();
        return SettingsSyncResult(await store.read(p, guard: current), error);
      }
    }
    return SettingsSyncResult(await store.read(p, guard: current));
  }
}
