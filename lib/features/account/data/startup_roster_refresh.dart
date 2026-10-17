import 'package:flutter/foundation.dart';

import '../../../shared/lost_ark_api/client/api_cooldown.dart';
import '../domain/account_read_session.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/scoped_startup_refresh.dart';
import '../domain/server_registration_api.dart';
import 'local/scoped_command_key.dart';
import 'scoped_account_runtime.dart';

class _RosterCommand {
  _RosterCommand(this.before) : key = newScopedCommandKey();
  final CacheRegistrationSnapshot before;
  final String key;
  DateTime? firstSentAt, retryAt;
  ServerRegistrationRefresh? ack;
}

/// One app-lifetime preparation per member/registration/ownership lifetime.
/// A successful provider write is not repeated by detail or prepare retries.
class StartupRosterRefresh extends ChangeNotifier {
  StartupRosterRefresh(this.runtime, this.cooldown);
  final ScopedAccountRuntime runtime;
  final ApiCooldown cooldown;
  final _commands = <(StorageScope, String, String, int), _RosterCommand>{};
  final _progress = <StorageScope, List<RosterRefreshProgress>>{};
  List<RosterRefreshProgress> get progress => runtime.canRead
      ? List.unmodifiable(_progress[runtime.scope] ?? [])
      : const [];

  Future<void> prepare({
    required void Function() guard,
    required void Function() onApplied,
  }) async {
    guard();
    final scope = runtime.scope;
    final registrations = await runtime.refreshRegistrations(guard: guard);
    guard();
    final owned = registrations.cached
        .where((r) => r.ownershipStatus == 'owned')
        .toList();
    final rows = <RosterRefreshProgress>[
      for (final r in owned)
        RosterRefreshProgress(
          r.registrationId,
          r.label.isEmpty ? (r.isMain ? '본계정' : '부계정') : r.label,
          RosterRefreshPhase.queued,
        ),
    ];
    void update(
      int i,
      RosterRefreshPhase phase, {
      ServerRegistrationRefresh? ack,
      String? code,
    }) {
      guard();
      rows[i] = RosterRefreshProgress(
        rows[i].registrationId,
        rows[i].label,
        phase,
        added: ack?.addedCount ?? 0,
        suspect: ack?.suspectCount ?? 0,
        code: code,
      );
      _progress[scope] = List.of(rows);
      notifyListeners();
    }

    _progress[scope] = rows;
    notifyListeners();
    AccountReadException? failure;
    for (var i = 0; i < owned.length; i++) {
      guard();
      final reg = owned[i];
      if (reg.accountId == null || reg.ownershipRevision == null) {
        throw const AccountReadException('OWNERSHIP_REQUIRED');
      }
      final identity = (
        scope,
        reg.registrationId,
        reg.accountId!,
        reg.ownershipRevision!,
      );
      final command = _commands.putIfAbsent(
        identity,
        () => _RosterCommand(reg),
      );
      if (command.ack case final ack?) {
        if (reg.version < ack.registration.version ||
            reg.rosterRevision < ack.registration.rosterRevision!) {
          throw const AccountReadException('REVISION_REGRESSION');
        }
        update(i, RosterRefreshPhase.updated, ack: ack);
        continue;
      }
      try {
        if (cooldown.active ||
            (command.retryAt != null &&
                cooldown.now().isBefore(command.retryAt!))) {
          throw AccountReadException('RATE_LIMITED', retryAt: command.retryAt);
        }
        if (command.firstSentAt != null &&
            cooldown.now().difference(command.firstSentAt!) >=
                const Duration(hours: 24)) {
          throw const AccountReadException('IDEMPOTENCY_EXPIRED');
        }
        update(i, RosterRefreshPhase.refreshing);
        command.firstSentAt ??= cooldown.now();
        final json = await runtime.api.request(
          '/v1/me/game-accounts/${reg.registrationId}/refresh',
          method: 'POST',
          body: const {},
          idempotencyKey: command.key,
        );
        guard();
        final ack = ServerRegistrationRefresh.fromJson(json!);
        final r = ack.registration, before = command.before;
        if (r.registrationId != before.registrationId ||
            r.gameAccountId != before.accountId ||
            r.ownershipStatus != 'owned' ||
            r.ownershipRevision != before.ownershipRevision ||
            r.version <= before.version ||
            r.rosterRevision == null ||
            r.rosterRevision! <= before.rosterRevision ||
            ack.requiresRefresh != (ack.suspectCount > 0)) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        command.ack = ack;
        onApplied();
        guard();
        update(i, RosterRefreshPhase.updated, ack: ack);
      } catch (e) {
        guard();
        final error = e is AccountReadException
            ? e
            : const AccountReadException('INVALID_RESPONSE');
        if (error.retryAt != null ||
            error.retryAfter != null ||
            error.status == 429) {
          command.retryAt =
              error.retryAt ??
              cooldown.now().add(
                error.retryAfter ?? const Duration(seconds: 60),
              );
          cooldown.observe(command.retryAt!);
        }
        update(i, RosterRefreshPhase.failed, code: error.code);
        failure ??= error;
        // These are definitive preconditions, not a lease/network ambiguity.
        // A later explicit preparation may use a new command after correction.
        if ({
          'OWNERSHIP_REQUIRED',
          'REGISTRATION_NOT_FOUND',
          'REVISION_CONFLICT',
          'KEY_VERSION_CONFLICT',
        }.contains(error.code)) {
          _commands.remove(identity);
        }
        if (cooldown.active ||
            {'UNAUTHENTICATED', 'KEY_NOT_READY'}.contains(error.code)) {
          break;
        }
      }
    }
    guard();
    if (failure != null) throw failure;
  }
}
