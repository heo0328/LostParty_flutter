import '../domain/account_read_session.dart';
import '../domain/entities/character_build_role.dart';
import '../domain/scoped_cache_models.dart';
import 'mappers/scoped_role_build_mapper.dart';
import 'repositories/scoped_role_repository.dart';
import 'role_summary_client.dart';

class RoleSyncResult {
  const RoleSyncResult(this.state, [this.failure]);
  final ScopedRoleState? state;
  final AccountReadException? failure;
}

/// Explicit sync only; no timers, auto armory, UI or legacy writer.
class ScopedRoleSync {
  ScopedRoleSync(this.client, this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final RoleSummaryClient client;
  final ScopedRoleRepository store;
  final DateTime Function() now;
  final Map<Object, Future<RoleSyncResult>> _flights = {};

  Future<ScopedRolePlan> prepare(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref, {
    void Function()? guard,
  }) async {
    guard?.call();
    final profile = await client.get(ref);
    guard?.call();
    return store.observe(registration, ref, profile, guard: guard);
  }

  Future<ScopedRoleState> save(
    ScopedRolePlan plan,
    ScopedRoleBuildDraft draft, {
    void Function()? guard,
  }) => store.save(plan, draft, guard: guard);
  Future<ScopedRoleState> read(
    ScopedRolePlan plan,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => store.read(plan, role, guard: guard);
  Future<ScopedRoleState> useServer(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref,
    CharacterBuildRole role, {
    void Function()? guard,
  }) async {
    final plan = await prepare(registration, ref, guard: guard);
    return store.useServer(plan, role, now().toUtc(), guard: guard);
  }

  Future<RoleSyncResult> sync(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref,
    CharacterBuildRole role, {
    void Function()? guard,
  }) {
    final scope = accountReadScope(client.api.session);
    final key = (
      ref.scope,
      scope.generation,
      ref.accountId,
      ref.characterId,
      role,
    );
    if (_flights[key] case final flight?) return flight;
    late final Future<RoleSyncResult> flight;
    flight = _sync(registration, ref, role, guard).whenComplete(() {
      if (identical(_flights[key], flight)) _flights.remove(key);
    });
    _flights[key] = flight;
    return flight;
  }

  Future<RoleSyncResult> _sync(
    ScopedRegistrationRef registration,
    ScopedCharacterRef ref,
    CharacterBuildRole role,
    void Function()? guard,
  ) async {
    final captured = accountReadScope(client.api.session);
    void current() {
      client.requireScope(ref, captured);
      guard?.call();
    }

    ScopedRolePlan plan;
    try {
      plan = await prepare(registration, ref, guard: current);
    } on AccountReadException catch (error) {
      current();
      return RoleSyncResult(null, error);
    }
    var command = await store.materialize(plan, role, guard: current);
    if (command == null) {
      return RoleSyncResult(await store.read(plan, role, guard: current));
    }
    final time = now().toUtc();
    final sent = command.firstSentAt;
    if (sent != null &&
        (time.isBefore(sent) ||
            time.difference(sent) >= const Duration(hours: 24))) {
      await store.fail(
        plan,
        command,
        'review',
        'IDEMPOTENCY_REVIEW_REQUIRED',
        guard: current,
      );
    } else if (sent == null &&
        command.body['expected_version'] != plan.profile.role(role).version) {
      await store.fail(
        plan,
        command,
        'conflict',
        'REVISION_CONFLICT',
        guard: current,
      );
    } else if (command.body['expected_lifecycle_revision'] !=
            plan.profile.lifecycleRevision ||
        plan.profile.lifecycleState != 'active') {
      await store.fail(
        plan,
        command,
        'blocked',
        'REVISION_CONFLICT',
        guard: current,
      );
    } else if ((command.state == 'ready' || command.state == 'retry') &&
        (command.retryAt == null || !time.isBefore(command.retryAt!))) {
      command = await store.markSent(plan, command, time, guard: current);
      try {
        final ack = await client.put(ref, role, command.id, command.body);
        current();
        await store.acknowledge(plan, command, ack, guard: current);
      } on AccountReadException catch (error) {
        current();
        final receivedAt = now().toUtc();
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
          plan,
          command,
          state,
          error.code,
          retryAt:
              error.retryAt ??
              (error.retryAfter == null
                  ? null
                  : receivedAt.add(error.retryAfter!)),
          guard: current,
        );
        return RoleSyncResult(
          await store.read(plan, role, guard: current),
          error,
        );
      }
      // Historical ACK confirms only that immutable command, not current GET.
      try {
        plan = await prepare(registration, ref, guard: current);
      } on AccountReadException catch (error) {
        current();
        return RoleSyncResult(
          await store.read(plan, role, guard: current),
          error,
        );
      }
    }
    return RoleSyncResult(await store.read(plan, role, guard: current));
  }
}
