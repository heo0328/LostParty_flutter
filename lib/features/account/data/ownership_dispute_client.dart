import '../domain/account_read_session.dart';
import '../domain/ownership_command.dart';
import '../domain/ownership_verification_models.dart';
import '../domain/ownership_wire.dart';
import '../domain/scoped_cache_models.dart';
import '../domain/server_account_verification.dart';
import '../domain/server_registration_api.dart';
import 'ownership_command_store.dart';

/// Historical command acknowledgement, never a current ownership grant.
class OwnershipAcknowledgement {
  const OwnershipAcknowledgement.proof(OwnershipVerification value)
    : proof = value,
      dispute = null;
  const OwnershipAcknowledgement.dispute(OwnershipDispute value)
    : dispute = value,
      proof = null;
  final OwnershipVerification? proof;
  final OwnershipDispute? dispute;
  String get id => proof?.id ?? dispute!.id;
}

class OwnershipDisputeClient {
  OwnershipDisputeClient(
    this.api,
    this.session,
    this.scope,
    this.commands, {
    DateTime Function()? now,
    this.environmentIsCurrent,
  }) : now = now ?? DateTime.now;
  final BackendRegistrationApi api;
  final AccountReadSession session;
  final StorageScope scope;
  final OwnershipCommandStore commands;
  final DateTime Function() now;
  final bool Function()? environmentIsCurrent;
  final Set<String> _inFlight = {};

  AccountReadScope _binding() {
    if (environmentIsCurrent?.call() == false) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
    final binding = accountReadScope(session);
    if (binding.userId != scope.userId) {
      throw const AccountReadException('SESSION_CHANGED');
    }
    return binding;
  }

  void _requireBinding(AccountReadScope binding) {
    requireAccountReadScope(session, binding);
    _binding();
  }

  Future<T> _read<T>(
    String path,
    T Function(Object?) decode, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String method = 'GET',
  }) async {
    final binding = _binding();
    try {
      final json = await api.request(
        path,
        method: method,
        body: body,
        query: query,
      );
      _requireBinding(binding);
      return _decode(() => decode(json));
    } on Object {
      _requireBinding(binding);
      rethrow;
    }
  }

  T _decode<T>(T Function() action) {
    try {
      return action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  Future<OwnershipPreview> preview(String name) => _read(
    '/v2/game-accounts/preview',
    OwnershipPreview.fromJson,
    method: 'POST',
    body: {'character_name': ownershipName(name)},
  );

  Future<OwnershipVerification> proof(String id) {
    final target = verificationUuid(id);
    return _read('${OwnershipCommand.proofsPath}/$target', (j) {
      final value = OwnershipVerification.fromJson(j);
      ownershipRequire(value.id == target);
      return value;
    });
  }

  Future<OwnershipDispute> dispute(String id) {
    final target = verificationUuid(id);
    return _read('${OwnershipCommand.disputesPath}/$target', (j) {
      final value = OwnershipDispute.fromJson(j);
      ownershipRequire(value.id == target);
      return value;
    });
  }

  Map<String, dynamic> _pageQuery(
    String filter,
    String value,
    Set<String> choices,
    String view,
    int limit,
    String? cursor,
  ) {
    ownershipChoice(value, choices);
    ownershipChoice(view, {'active', 'all'});
    ownershipRequire(limit >= 1 && limit <= 100);
    ownershipCursor(cursor);
    return {filter: value, 'view': view, 'limit': limit, 'cursor': ?cursor};
  }

  Future<OwnershipPage<OwnershipVerification>> proofs({
    String purpose = 'all',
    String view = 'active',
    int limit = 20,
    String? cursor,
  }) {
    final query = _pageQuery(
      'purpose',
      purpose,
      {'all', 'claim', 'defense'},
      view,
      limit,
      cursor,
    );
    return _read(OwnershipCommand.proofsPath, (j) {
      final page = OwnershipPage<OwnershipVerification>.fromJson(
        j,
        OwnershipVerification.fromJson,
        (v) => v.id,
        limit: limit,
      );
      ownershipRequire(
        page.items.every(
          (v) =>
              (purpose == 'all' || v.purpose == purpose) &&
              (view == 'all' ||
                  (v.equipmentStatus == 'pending' &&
                      v.equipmentExpiresAt.isAfter(page.serverNow))),
        ),
      );
      return page;
    }, query: query);
  }

  Future<OwnershipPage<OwnershipDispute>> disputes({
    String role = 'all',
    String view = 'active',
    int limit = 20,
    String? cursor,
  }) {
    final query = _pageQuery(
      'role',
      role,
      {'all', 'challenger', 'owner'},
      view,
      limit,
      cursor,
    );
    return _read(OwnershipCommand.disputesPath, (j) {
      final page = OwnershipPage<OwnershipDispute>.fromJson(
        j,
        OwnershipDispute.fromJson,
        (v) => v.id,
        limit: limit,
      );
      ownershipRequire(
        page.items.every(
          (v) =>
              (role == 'all' || v.viewerRole == role) &&
              (view == 'all' ||
                  {'defending', 'review_required'}.contains(v.state)),
        ),
      );
      return page;
    }, query: query);
  }

  Future<OwnershipAcknowledgement> execute(OwnershipCommand command) async {
    _binding();
    _requireBinding(command.sessionScope);
    if (scope != command.storageScope) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
    if (!_inFlight.add(command.idempotencyKey)) {
      throw const AccountReadException('REQUEST_IN_PROGRESS');
    }
    try {
      final entry = await commands.prepare(session, command);
      _requireBinding(command.sessionScope);
      if (entry.phase == OwnershipCommandPhase.awaitingCurrent) {
        throw const AccountReadException('CURRENT_READ_REQUIRED');
      }
      if (entry.phase == OwnershipCommandPhase.reconciled ||
          entry.phase == OwnershipCommandPhase.reconciliationRequired ||
          !command.replayableAt(now().toUtc())) {
        if (entry.phase == OwnershipCommandPhase.awaitingAck) {
          await commands.requireReconciliation(session, command);
        }
        throw const AccountReadException('COMMAND_RECONCILIATION_REQUIRED');
      }
      Map<String, dynamic>? json;
      try {
        json = await api.request(
          command.path,
          method: command.method,
          body: command.body,
          idempotencyKey: command.idempotencyKey,
          expectedStatus: command.expectedStatus,
        );
      } on AccountReadException catch (error) {
        _requireBinding(command.sessionScope);
        if ({
              'IDEMPOTENCY_CONFLICT',
              'IDEMPOTENCY_EXPIRED',
              'REVISION_CONFLICT',
              'IDENTITY_CONFLICT',
              'VERIFICATION_TERMINAL',
              'DISPUTE_TERMINAL',
              'DEFENSE_WINDOW_CLOSED',
              'ALREADY_VERIFIED',
            }.contains(error.code) ||
            ({400, 403, 404, 409}.contains(error.status) &&
                !{
                  'REQUEST_IN_PROGRESS',
                  'LOSTARK_KEY_NOT_CONFIGURED',
                  'LOSTARK_KEY_REJECTED',
                }.contains(error.code))) {
          await commands.requireReconciliation(session, command);
        }
        rethrow;
      }
      _requireBinding(command.sessionScope);
      final ack = _decode(() => _ack(command, json));
      await commands.acknowledge(session, command, ack.id);
      _requireBinding(command.sessionScope);
      return ack;
    } on Object {
      _requireBinding(command.sessionScope);
      rethrow;
    } finally {
      _inFlight.remove(command.idempotencyKey);
    }
  }

  OwnershipAcknowledgement _ack(OwnershipCommand c, Object? json) {
    if (!c.returnsProof) {
      final result = OwnershipDispute.fromJson(json);
      ownershipRequire(result.id == c.targetId);
      return OwnershipAcknowledgement.dispute(result);
    }
    final result = OwnershipVerification.fromJson(json);
    switch (c.operation) {
      case OwnershipOperation.startClaim:
        ownershipRequire(
          result.purpose == 'claim' && result.source == c.body['source'],
        );
        if (c.body['source'] == 'registration') {
          ownershipRequire(
            result.sourceRegistrationId == c.body['registration_id'] &&
                result.target == ownershipTarget(c.body['target_character']),
          );
        } else {
          // The server canonicalizes ASCII input case; it does not rename a proof.
          ownershipRequire(
            result.target.characterName.toLowerCase() ==
                (c.body['character_name'] as String).toLowerCase(),
          );
        }
      case OwnershipOperation.startDefense:
        final selection = c.body['selection'] as Map<String, dynamic>;
        ownershipRequire(
          result.purpose == 'defense' &&
              result.disputeId == c.targetId &&
              result.sourceRegistrationId == selection['registration_id'],
        );
      case OwnershipOperation.confirm:
      case OwnershipOperation.cancelProof:
        ownershipRequire(result.id == c.targetId);
      default:
        throw const FormatException('Invalid proof operation.');
    }
    return OwnershipAcknowledgement.proof(result);
  }

  /// ACK persistence and current GET are separate. On GET failure the journal
  /// stays awaitingCurrent and retries only GET, including settle's reservation.
  Future<OwnershipAcknowledgement> loadCurrentFor(
    OwnershipJournalEntry entry,
  ) async {
    final c = entry.command;
    _binding();
    _requireBinding(c.sessionScope);
    if (scope != c.storageScope) {
      throw const AccountReadException('ENVIRONMENT_CHANGED');
    }
    if (entry.phase != OwnershipCommandPhase.awaitingCurrent ||
        entry.responseId == null) {
      throw const AccountReadException('ACK_REQUIRED');
    }
    final current = c.returnsProof
        ? OwnershipAcknowledgement.proof(await proof(entry.responseId!))
        : OwnershipAcknowledgement.dispute(await dispute(entry.responseId!));
    _requireBinding(c.sessionScope);
    await commands.completeCurrent(session, entry);
    _requireBinding(c.sessionScope);
    return current;
  }
}
