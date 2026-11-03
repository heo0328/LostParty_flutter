import 'dart:async';
import 'role_batch_client.dart';
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

typedef RoleUploadPlan = ({ScopedRolePlan plan, CharacterBuildRole role});
typedef RolePlanResult = ({
  ScopedRolePlan? plan,
  AccountReadException? failure,
});

/// Explicit sync only; no timers, auto armory, UI or legacy writer.
class ScopedRoleSync {
  ScopedRoleSync(this.client, this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final RoleSummaryClient client;
  final ScopedRoleRepository store;
  final DateTime Function() now;
  final Map<Object, Future<RoleSyncResult>> _flights = {};

  Object _key(ScopedCharacterRef ref, CharacterBuildRole role) => (
    ref.scope,
    accountReadScope(client.api.session).generation,
    ref.accountId,
    ref.characterId,
    role,
  );

  Future<Map<String, RolePlanResult>> prepareBatch(
    List<(ScopedRegistrationRef, ScopedCharacterRef)> refs,
    void Function() current,
  ) async {
    current();
    final profiles = await RoleBatchClient(
      client,
    ).profiles(refs.map((e) => e.$2).toList());
    current();
    final result = <String, RolePlanResult>{};
    for (final (registration, ref) in refs) {
      current();
      final value = profiles[ref.characterId]!;
      if (value.failure != null) {
        result[ref.characterId] = (plan: null, failure: value.failure);
        continue;
      }
      try {
        final plan = await store.observe(
          registration,
          ref,
          value.profile!,
          guard: current,
        );
        result[ref.characterId] = (plan: plan, failure: null);
      } on ScopedCacheException catch (error) {
        current();
        result[ref.characterId] = (
          plan: null,
          failure: AccountReadException(error.code),
        );
      }
    }
    return result;
  }

  /// Reserves the same per-resource flights used by single-character sync.
  Future<Map<RoleUploadKey, RoleSyncResult>> syncBatch(
    List<RoleUploadPlan> uploads,
    void Function() current,
  ) {
    current();
    final keys = <RoleUploadKey>{};
    for (final upload in uploads) {
      if (!keys.add((upload.plan.ref.characterId, upload.role))) {
        throw const AccountReadException('INVALID_REQUEST');
      }
    }
    final owned = <RoleUploadPlan>[];
    final waiting = <RoleUploadKey, Future<RoleSyncResult>>{};
    final completion = Completer<Map<RoleUploadKey, RoleSyncResult>>();
    for (final upload in uploads) {
      final ref = upload.plan.ref, key = _key(upload.plan.ref, upload.role);
      final resource = (ref.characterId, upload.role);
      final previous = _flights[key];
      if (previous != null) {
        waiting[resource] = previous;
        continue;
      }
      owned.add(upload);
      final flight = completion.future.then((r) => r[resource]!);
      _flights[key] = flight;
      unawaited(
        flight.then<void>(
          (_) {
            if (identical(_flights[key], flight)) _flights.remove(key);
          },
          onError: (Object _, StackTrace _) {
            if (identical(_flights[key], flight)) _flights.remove(key);
          },
        ),
      );
    }
    return () async {
      try {
        final results = await _syncBatchOwned(owned, current);
        completion.complete(results);
        for (final entry in waiting.entries) {
          results[entry.key] = await entry.value;
          current();
        }
        return results;
      } catch (error, stack) {
        if (!completion.isCompleted) completion.completeError(error, stack);
        rethrow;
      }
    }();
  }

  Future<Map<RoleUploadKey, RoleSyncResult>> _syncBatchOwned(
    List<RoleUploadPlan> uploads,
    void Function() current,
  ) async {
    final results = <RoleUploadKey, RoleSyncResult>{};
    final ready = <String, (ScopedRolePlan, ScopedRoleCommand)>{};
    final writes = <RoleBatchWrite>[];
    for (final upload in uploads) {
      current();
      final plan = upload.plan, role = upload.role;
      final key = (plan.ref.characterId, role);
      try {
        final command = await readyCommand(plan, role, current);
        if (command == null) {
          results[key] = RoleSyncResult(
            await store.read(plan, role, guard: current),
          );
          continue;
        }
        try {
          writes.add(RoleBatchWrite(plan.ref, role, command.id, command.body));
          ready[command.id] = (plan, command);
        } on AccountReadException catch (error) {
          results[key] = await recordFailure(plan, command, error, current);
        } on FormatException {
          results[key] = await recordFailure(
            plan,
            command,
            const AccountReadException('INVALID_REQUEST', status: 400),
            current,
          );
        }
      } on ScopedCacheException catch (error) {
        current();
        results[key] = RoleSyncResult(null, AccountReadException(error.code));
      }
    }
    for (final chunk in RoleBatchClient.chunks(writes)) {
      current();
      final sentWrites = <RoleBatchWrite>[];
      for (final write in chunk) {
        final (plan, command) = ready[write.commandId]!;
        try {
          final sent = await store.markSent(
            plan,
            command,
            now().toUtc(),
            guard: current,
          );
          ready[write.commandId] = (plan, sent);
          sentWrites.add(write);
        } on ScopedCacheException catch (error) {
          current();
          results[write.key] = RoleSyncResult(
            null,
            AccountReadException(error.code),
          );
        }
      }
      if (sentWrites.isEmpty) continue;
      Map<String, RoleBatchResult>? response;
      AccountReadException? transportFailure;
      try {
        response = await RoleBatchClient(client).put(sentWrites);
      } on AccountReadException catch (error) {
        current();
        transportFailure = error;
      }
      current();
      for (final write in sentWrites) {
        final (plan, command) = ready[write.commandId]!;
        try {
          final value = response?[command.id];
          final error = transportFailure ?? value?.failure;
          if (error != null) {
            results[write.key] = await recordFailure(
              plan,
              command,
              error,
              current,
            );
          } else {
            await store.acknowledge(plan, command, value!.ack!, guard: current);
            results[write.key] = RoleSyncResult(
              await store.read(plan, command.role, guard: current),
            );
          }
        } on ScopedCacheException catch (error) {
          // Keep other acknowledged items even if this item's local ACK fails.
          current();
          results[write.key] = RoleSyncResult(
            null,
            AccountReadException(error.code),
          );
        }
      }
    }
    return results;
  }

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
    final key = _key(ref, role);
    if (_flights[key] case final flight?) return flight;
    late final Future<RoleSyncResult> flight;
    flight = _sync(registration, ref, role, guard).whenComplete(() {
      if (identical(_flights[key], flight)) _flights.remove(key);
    });
    _flights[key] = flight;
    return flight;
  }

  Future<ScopedRoleCommand?> readyCommand(
    ScopedRolePlan plan,
    CharacterBuildRole role,
    void Function() current,
  ) async {
    final command = await store.materialize(plan, role, guard: current);
    if (command == null) return null;
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
      return command;
    }
    return null;
  }

  Future<RoleSyncResult> recordFailure(
    ScopedRolePlan plan,
    ScopedRoleCommand command,
    AccountReadException error,
    void Function() current,
  ) async {
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
        : {'IDEMPOTENCY_CONFLICT', 'IDEMPOTENCY_EXPIRED'}.contains(error.code)
        ? 'review'
        : 'blocked';
    await store.fail(
      plan,
      command,
      state,
      error.code,
      retryAt:
          error.retryAt ??
          (error.retryAfter == null ? null : receivedAt.add(error.retryAfter!)),
      guard: current,
    );
    return RoleSyncResult(
      await store.read(plan, command.role, guard: current),
      error,
    );
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
    var command = await readyCommand(plan, role, current);
    if (command != null) {
      command = await store.markSent(
        plan,
        command,
        now().toUtc(),
        guard: current,
      );
      try {
        final ack = await client.put(ref, role, command.id, command.body);
        current();
        await store.acknowledge(plan, command, ack, guard: current);
      } on AccountReadException catch (error) {
        return recordFailure(plan, command, error, current);
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
