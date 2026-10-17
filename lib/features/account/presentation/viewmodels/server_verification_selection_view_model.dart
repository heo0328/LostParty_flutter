import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/account_read_session.dart';
import '../../domain/policies/account_label_policy.dart';
import '../../domain/server_account_models.dart';
import '../../domain/server_account_read_repository.dart';
import '../../domain/server_account_verification.dart';
import '../../domain/services/roster_character_order.dart';

/// Owns a complete saved roster for selection, independently of activity filters.
class ServerVerificationSelectionViewModel extends ChangeNotifier {
  ServerVerificationSelectionViewModel(
    this.repository,
    this.session, {
    String? initialRegistrationId,
  }) : _selectedId = initialRegistrationId {
    _scope = (session.userId, session.generation);
    session.addListener(_onSession);
    unawaited(load());
  }

  final ServerAccountReadRepository repository;
  final AccountReadSession session;
  late (String?, int) _scope;
  int _ticket = 0;
  bool _disposed = false;
  String? _selectedId;
  List<ServerAccountRegistration> registrations = const [];
  ServerAccountRegistration? registration;
  ServerAccountRoster? roster;
  VerificationTarget? target;
  AccountReadException? failure;
  bool loading = false, loaded = false, checking = false;

  String? get registrationId => _selectedId;
  List<ServerAccountCharacter> get characters => rosterByItemLevel(
    roster?.characters ?? const <ServerAccountCharacter>[],
    (c) => c.itemLevel,
  );
  bool get canStart =>
      !loading &&
      !checking &&
      loaded &&
      registration != null &&
      canVerify(registration!) &&
      target != null;
  bool canVerify(ServerAccountRegistration account) =>
      account.ownershipStatus != 'owned';
  String displayLabelFor(ServerAccountRegistration account) =>
      AccountLabelPolicy.serverLabels(registrations)[account.registrationId]!;

  void _onSession() {
    final next = (session.userId, session.generation);
    if (_scope == next && session.isAuthenticated) return;
    _scope = next;
    _ticket++;
    _selectedId = null;
    registrations = const [];
    registration = null;
    roster = null;
    target = null;
    failure = null;
    loading = loaded = checking = false;
    notifyListeners();
    if (session.isAuthenticated) unawaited(load());
  }

  bool _valid(int ticket) =>
      !_disposed &&
      ticket == _ticket &&
      session.isAuthenticated &&
      _scope == (session.userId, session.generation);

  Future<void> select(String? id) async {
    _selectedId = id;
    await load();
  }

  void choose(VerificationTarget? value) {
    if (loading || checking || !loaded || roster == null) return;
    if (value != null &&
        !roster!.characters.any(
          (c) =>
              c.serverName == value.serverName &&
              c.characterName == value.characterName,
        )) {
      return;
    }
    target = value;
    notifyListeners();
  }

  void invalidate() {
    _ticket++;
    registration = null;
    roster = null;
    target = null;
    loading = loaded = checking = false;
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || !session.isAuthenticated) return;
    final ticket = ++_ticket, id = _selectedId;
    checking = false;
    loading = true;
    loaded = false;
    registration = null;
    roster = null;
    target = null;
    failure = null;
    notifyListeners();
    try {
      final items = await repository.loadRegistrations();
      if (!_valid(ticket)) return;
      registrations = items;
      if (id != null) {
        final matches = items.where((a) => a.registrationId == id);
        if (matches.isEmpty) {
          _selectedId = null;
          throw const AccountReadException(
            'REGISTRATION_NOT_FOUND',
            status: 404,
          );
        }
        final selected = matches.single;
        if (!canVerify(selected)) {
          _selectedId = null;
          loaded = true;
          return;
        }
        final result = await repository.loadCharacters(id);
        if (!_valid(ticket)) return;
        // A version change after this read is rejected by start's expected version.
        registration = selected;
        roster = result;
      }
      loaded = true;
    } on AccountReadException catch (error) {
      if (_valid(ticket)) failure = error;
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

  /// UI preflight only; the server must also enforce current ownership on start.
  Future<bool> checkStart({String? characterName}) async {
    if (_disposed || loading || checking || !session.isAuthenticated) {
      return false;
    }
    final ticket = ++_ticket;
    checking = true;
    failure = null;
    notifyListeners();
    try {
      final items = await repository.loadRegistrations();
      if (!_valid(ticket)) return false;
      registrations = items;
      if (characterName != null) {
        final name = characterName.trim();
        if (name.isEmpty) throw const AccountReadException('INVALID_REQUEST');
        for (final owned in items.where((a) => !canVerify(a))) {
          final current = await repository.loadCharacters(owned.registrationId);
          if (!_valid(ticket)) return false;
          if (current.ownershipStatus != 'owned') {
            throw const AccountReadException('REVISION_CONFLICT');
          }
          if (current.characters.any((c) => c.characterName == name)) {
            throw const AccountReadException('ALREADY_VERIFIED');
          }
        }
      } else {
        final matches = items.where((a) => a.registrationId == _selectedId);
        if (matches.isEmpty) {
          throw const AccountReadException('REGISTRATION_NOT_FOUND');
        }
        final current = matches.single;
        if (!canVerify(current)) {
          throw const AccountReadException('ALREADY_VERIFIED');
        }
        if (registration == null || current.version != registration!.version) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
      }
      return true;
    } on AccountReadException catch (error) {
      if (_valid(ticket)) {
        failure = error;
        if (characterName == null) {
          registration = null;
          roster = null;
          target = null;
          loaded = false;
          if (error.code == 'ALREADY_VERIFIED') _selectedId = null;
        }
      }
      return false;
    } catch (_) {
      if (_valid(ticket)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
      return false;
    } finally {
      if (_valid(ticket)) {
        checking = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    session.removeListener(_onSession);
    super.dispose();
  }
}
