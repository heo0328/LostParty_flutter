import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/account_read_session.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/server_combat_power.dart';
import '../../domain/services/character_usage_level_policy.dart';
import 'server_registration_view_model.dart';

/// Private display cache. It never writes local characters or build snapshots.
class ServerCombatPowerViewModel extends ChangeNotifier {
  ServerCombatPowerViewModel(this.reads, this.writes, this.session) {
    session.addListener(_onSession);
    writes.addListener(_changed);
    _onSession();
  }
  final ServerAccountReadRepository reads;
  final ServerRegistrationViewModel writes;
  final AccountReadSession session;
  List<ServerAccountRegistration> registrations = const [];
  final Map<String, ServerAccountRoster> _rosters = {};
  AccountReadException? failure;
  bool loading = false, _disposed = false;
  int _ticket = 0;
  (String?, int, bool)? _sessionKey;
  bool get canRefresh =>
      session.isAuthenticated &&
      !loading &&
      writes.canWrite &&
      _sessionKey ==
          (session.userId, session.generation, session.isAuthenticated);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onSession() {
    final key = (session.userId, session.generation, session.isAuthenticated);
    if (key == _sessionKey) return;
    _sessionKey = key;
    _ticket++;
    registrations = const [];
    _rosters.clear();
    failure = null;
    loading = false;
    notifyListeners();
    if (session.isAuthenticated) unawaited(reload(shareInFlight: true));
  }

  bool _valid(int ticket) =>
      !_disposed && ticket == _ticket && session.isAuthenticated;

  Future<void> reload({bool shareInFlight = false}) async {
    if (loading || !session.isAuthenticated || _disposed) return;
    final ticket = ++_ticket;
    loading = true;
    failure = null;
    registrations = const [];
    _rosters.clear();
    notifyListeners();
    try {
      final accounts = await reads.loadRegistrations(
        shareInFlight: shareInFlight,
      );
      final rosters = <String, ServerAccountRoster>{};
      for (final account in accounts) {
        if (!_valid(ticket)) {
          return;
        }
        rosters[account.registrationId] = await reads.loadCharacters(
          account.registrationId,
        );
      }
      if (_valid(ticket)) {
        registrations = accounts;
        _rosters.addAll(rosters);
      }
    } on AccountReadException catch (e) {
      if (_valid(ticket)) failure = e;
    } catch (_) {
      if (_valid(ticket)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
    } finally {
      if (_valid(ticket)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void store(String registrationId, ServerAccountRoster roster) {
    if (_disposed || !session.isAuthenticated) return;
    _rosters[registrationId] = roster;
    notifyListeners();
  }

  ServerPowerObservation? powerFor(LocalAccountCharacter character) {
    if (!session.isAuthenticated ||
        _sessionKey !=
            (session.userId, session.generation, session.isAuthenticated)) {
      return null;
    }
    ServerPowerObservation? latest;
    for (final roster in _rosters.values) {
      for (final row in roster.characters) {
        if (row.serverName != character.serverName ||
            row.characterName != character.characterName) {
          continue;
        }
        final observed = row.power;
        final time = observed.checkedAt ?? observed.fetchedAt;
        final oldTime = latest?.checkedAt ?? latest?.fetchedAt;
        if (latest == null ||
            (time != null && (oldTime == null || time.isAfter(oldTime)))) {
          latest = observed;
        }
      }
    }
    return latest;
  }

  double? displayPowerFor(
    LocalAccountCharacter character,
    double? roleSnapshot,
  ) => character.preferredRole != null
      ? roleSnapshot
      : powerFor(character)?.value ?? character.combatPower;

  static List<Map<String, String>> targets(
    Iterable<ServerAccountCharacter> rows,
  ) {
    const policy = CharacterUsageLevelPolicy();
    final eligible = rows
        .where(
          (c) =>
              !['missing', 'suspect'].contains(c.rosterStatus) &&
              policy.isInUsageRange(double.tryParse(c.itemLevel ?? '')),
        )
        .toList();
    // Unobserved/deferred characters precede cached characters on the next tap.
    eligible.sort((a, b) {
      int rank(ServerAccountCharacter c) => c.power.status == 'unknown'
          ? 0
          : c.power.stale
          ? 1
          : 2;
      final order = rank(a).compareTo(rank(b));
      return order != 0
          ? order
          : '${a.serverName}\u0000${a.characterName}'.compareTo(
              '${b.serverName}\u0000${b.characterName}',
            );
    });
    return eligible
        .take(20)
        .map(
          (c) => {
            'server_name': c.serverName,
            'character_name': c.characterName,
          },
        )
        .toList();
  }

  Future<void> refreshLocalCharacters(
    Iterable<LocalAccountCharacter> characters,
  ) async {
    if (!canRefresh) return;
    final wanted = characters
        .map((c) => (c.serverName, c.characterName))
        .toSet();
    for (final account in registrations) {
      final roster = _rosters[account.registrationId];
      if (roster == null) continue;
      final selected = targets(
        roster.characters.where(
          (c) => wanted.contains((c.serverName, c.characterName)),
        ),
      );
      if (selected.isEmpty) continue;
      await writes.refreshPower(account, selected);
      if (!_disposed && session.isAuthenticated && !writes.hasPending) {
        await reload();
      }
      return;
    }
    failure = const AccountReadException('NO_REGISTERED_POWER_TARGET');
    notifyListeners();
  }

  Future<void> refreshServerRoster(
    String registrationId,
    Iterable<ServerAccountCharacter> rows,
  ) async {
    if (!canRefresh) return;
    final key = _sessionKey;
    if (!registrations.any((a) => a.registrationId == registrationId)) {
      await reload();
    }
    if (_disposed || key != _sessionKey || !canRefresh) return;
    final selected = targets(rows);
    for (final account in registrations) {
      if (account.registrationId == registrationId && selected.isNotEmpty) {
        await writes.refreshPower(account, selected);
        return;
      }
    }
    failure = const AccountReadException('NO_REGISTERED_POWER_TARGET');
    notifyListeners();
  }

  Future<void> retry() async {
    await writes.retry();
    if (!_disposed && session.isAuthenticated && !writes.hasPending) {
      await reload();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    session.removeListener(_onSession);
    writes.removeListener(_changed);
    super.dispose();
  }
}
