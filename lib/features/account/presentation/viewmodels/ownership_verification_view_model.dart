import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/backend_auth_models.dart';
import '../../domain/account_read_session.dart';
import '../../domain/ownership_command.dart';
import '../../domain/ownership_verification_models.dart';
import '../../domain/server_character_lifecycle.dart';
import '../../domain/server_account_verification.dart';
import '../../domain/services/roster_character_order.dart';
import 'ownership_dispute_controller.dart';

/// Page-owned selection only; all durable commands belong to the app controller.
class OwnershipVerificationViewModel extends ChangeNotifier {
  OwnershipVerificationViewModel(this.controller) {
    _scope = _identity;
    controller.addListener(_changed);
  }
  final OwnershipDisputeController controller;
  AccountReadSession get session => controller.session;
  (String?, int, Object?) get _identity =>
      (session.userId, session.generation, controller.scope);
  late (String?, int, Object?) _scope;
  bool _disposed = false, busy = false;
  int _ticket = 0;
  AccountReadException? failure;
  OwnershipPreview? preview;
  String? previewName, defenseDisputeId;
  LifecycleCharacterPage? defenseRoster;
  List<LifecycleCharacter> defenseCharacters = const [];
  LifecycleCharacter? defenseCharacter;
  bool get ready => !busy && !controller.commandBusy && controller.signedIn;
  bool _valid(int ticket) =>
      !_disposed && ticket == _ticket && _scope == _identity;
  void _changed() {
    if (_scope != _identity) {
      _scope = _identity;
      _ticket++;
      busy = false;
      preview = null;
      previewName = null;
      defenseDisputeId = null;
      defenseRoster = null;
      defenseCharacters = const [];
      defenseCharacter = null;
      failure = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> run(Future<void> Function() action) async {
    if (!ready) return;
    final ticket = ++_ticket;
    busy = true;
    failure = null;
    notifyListeners();
    try {
      await action();
    } on AccountReadException catch (e) {
      if (_valid(ticket)) failure = e;
    } catch (_) {
      if (_valid(ticket)) {
        failure = const AccountReadException('INVALID_RESPONSE');
      }
    } finally {
      if (_valid(ticket)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clearPreview() {
    if (busy) return;
    preview = null;
    previewName = null;
    failure = null;
    notifyListeners();
  }

  Future<void> inspect(String name) => run(() async {
    final ticket = _ticket;
    final value = await controller.preview(name.trim());
    if (!_valid(ticket)) return;
    preview = value;
    previewName = name.trim();
  });
  String _key() {
    final bytes = base64Url
        .decode(base64Url.normalize(newAuthSecret()))
        .sublist(0, 16);
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> startClaim({
    String? registrationId,
    int? version,
    VerificationTarget? target,
  }) => run(() async {
    if (preview?.context.canStartClaim != true ||
        previewName == null ||
        (target != null &&
            (target.characterName != previewName ||
                !preview!.preview.characters.any(
                  (c) =>
                      c.characterName == target.characterName &&
                      c.serverName == target.serverName,
                )))) {
      throw const AccountReadException('CURRENT_READ_REQUIRED');
    }
    await controller.execute(
      OwnershipCommand.claim(
        session,
        controller.scope!,
        key: _key(),
        createdAt: controller.now(),
        characterName: registrationId == null ? previewName : null,
        registrationId: registrationId,
        registrationVersion: version,
        target: target,
      ),
    );
  });
  Future<void> act(OwnershipOperation operation, String id, int version) => run(
    () => controller.execute(
      OwnershipCommand.versioned(
        session,
        controller.scope!,
        operation: operation,
        key: _key(),
        createdAt: controller.now(),
        id: id,
        version: version,
      ),
    ),
  );

  Future<void> prepareDefense(String id) => run(() async {
    final ticket = _ticket;
    defenseDisputeId = null;
    defenseRoster = null;
    defenseCharacters = const [];
    defenseCharacter = null;
    await controller.selectDispute(id);
    if (!_valid(ticket)) return;
    final dispute = controller.selectedDispute;
    if (dispute == null ||
        !controller.disputeIsCurrent(id) ||
        !dispute.allowedActions.contains('start_defense') ||
        controller.defenseRemaining(id) == Duration.zero) {
      throw const AccountReadException('CURRENT_READ_REQUIRED');
    }
    final registrationId = dispute.myRegistrationId;
    if (registrationId == null) {
      throw const AccountReadException('REGISTRATION_NOT_FOUND');
    }
    LifecycleCharacterPage? first;
    final items = <LifecycleCharacter>[],
        ids = <String>{},
        cursors = <String>{};
    String? cursor;
    do {
      final page = await controller.defenseCharacters(registrationId, cursor);
      if (!_valid(ticket)) return;
      first ??= page;
      if (page.registrationId != registrationId ||
          page.ownershipStatus != 'owned' ||
          !first.sameStructure(page)) {
        throw const AccountReadException('CURSOR_STALE');
      }
      for (final item in page.items) {
        if (item.characterId == null || !ids.add(item.characterId!)) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        items.add(item);
      }
      if (items.length > 200) {
        throw const AccountReadException('INVALID_RESPONSE');
      }
      cursor = page.nextCursor;
      if (cursor != null && (page.items.isEmpty || !cursors.add(cursor))) {
        throw const AccountReadException('CURSOR_STALE');
      }
    } while (cursor != null);
    if (!_valid(ticket)) return;
    defenseDisputeId = id;
    defenseRoster = first;
    defenseCharacters = rosterByItemLevel(
      items.where((c) => c.usable).toList(),
      (c) => c.wire['item_level'] as String?,
    );
  });
  void chooseDefense(String? id) {
    if (!ready) return;
    defenseCharacter = defenseCharacters
        .where((c) => c.characterId == id)
        .firstOrNull;
    notifyListeners();
  }

  Future<void> startDefense() => run(() async {
    final roster = defenseRoster, character = defenseCharacter;
    final dispute = controller.selectedDispute;
    if (roster == null ||
        character == null ||
        dispute?.id != defenseDisputeId) {
      throw const AccountReadException('CURRENT_READ_REQUIRED');
    }
    await controller.execute(
      OwnershipCommand.defense(
        session,
        controller.scope!,
        key: _key(),
        createdAt: controller.now(),
        disputeId: dispute!.id,
        disputeVersion: dispute.version,
        selection: OwnershipDefenseSelection(
          registrationId: roster.registrationId,
          characterId: character.characterId!,
          registrationVersion: roster.version,
          ownershipRevision: roster.ownershipRevision!,
          rosterRevision: roster.rosterRevision,
          lifecycleRevision: character.lifecycleRevision!,
        ),
      ),
    );
    defenseDisputeId = null;
    defenseCharacter = null;
  });
  @override
  void dispose() {
    _disposed = true;
    _ticket++;
    controller.removeListener(_changed);
    super.dispose();
  }
}
