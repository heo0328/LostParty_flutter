import 'role_batch_client.dart';
import '../domain/account_read_session.dart';
import '../domain/entities/character_build_role.dart';
import '../domain/scoped_cache_models.dart';
import 'repositories/scoped_role_repository.dart';
import 'role_summary_client.dart';

typedef RolePlanResult = ({
  ScopedRolePlan? plan,
  AccountReadException? failure,
});

/// Server projection reader. Never produces or uploads an analysis.
class ScopedRoleSync {
  ScopedRoleSync(this.client, this.store);
  final RoleSummaryClient client;
  final ScopedRoleRepository store;
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

  Future<ScopedRoleState> read(
    ScopedRolePlan plan,
    CharacterBuildRole role, {
    void Function()? guard,
  }) => store.read(plan, role, guard: guard);
  Future<ScopedRoleState> useServer(
    ScopedRegistrationRef reg,
    ScopedCharacterRef ref,
    CharacterBuildRole role, {
    void Function()? guard,
  }) async =>
      store.read(await prepare(reg, ref, guard: guard), role, guard: guard);
}
