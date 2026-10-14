import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/account_read_session.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/policies/account_label_policy.dart';

/// Owns only a private read snapshot, never the local account database.
class ServerAccountReadViewModel extends ChangeNotifier {
  ServerAccountReadViewModel(
    this.repository,
    this.session, {
    this.registrationId,
  }) {
    session.addListener(_onSession);
    _onSession();
  }
  final ServerAccountReadRepository repository;
  final AccountReadSession session;
  final String? registrationId;
  List<ServerAccountRegistration> registrations = const [];
  ServerAccountRoster? roster;
  AccountReadException? failure;
  bool loading = false;
  bool loaded = false;
  bool _disposed = false;
  int _request = 0;
  (String?, int, bool)? _sessionKey;
  bool get canRead => session.isAuthenticated;
  String displayLabelFor(ServerAccountRegistration account) =>
      AccountLabelPolicy.serverLabels(registrations)[account.registrationId]!;

  void _onSession() {
    final key = (session.userId, session.generation, session.isAuthenticated);
    if (key == _sessionKey) return;
    _sessionKey = key;
    _request++;
    registrations = const [];
    roster = null;
    failure = null;
    loaded = false;
    loading = false;
    notifyListeners();
    if (canRead) unawaited(load());
  }

  Future<void> load() async {
    if (_disposed || loading || !canRead) return;
    final ticket = ++_request;
    final key = _sessionKey;
    loading = true;
    failure = null;
    // Hide old private state while replacing it; never display partial results.
    registrations = const [];
    roster = null;
    loaded = false;
    notifyListeners();
    try {
      final id = registrationId;
      if (id == null) {
        final result = await repository.loadRegistrations();
        if (_valid(ticket, key)) registrations = result;
      } else {
        final result = await repository.loadCharacters(id);
        if (_valid(ticket, key)) roster = result;
      }
      if (_valid(ticket, key)) loaded = true;
    } on AccountReadException catch (error) {
      if (_valid(ticket, key)) failure = error;
    } catch (_) {
      if (_valid(ticket, key)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
    } finally {
      if (_valid(ticket, key)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _valid(int ticket, (String?, int, bool)? key) =>
      !_disposed && ticket == _request && key == _sessionKey && canRead;

  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.removeListener(_onSession);
    super.dispose();
  }
}
