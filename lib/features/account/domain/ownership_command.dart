import 'account_read_session.dart';
import 'scoped_cache_models.dart';
import 'server_account_verification.dart';
import 'ownership_wire.dart';

enum OwnershipOperation {
  startClaim,
  confirm,
  cancelProof,
  startDefense,
  cancelDispute,
  settle,
}

class OwnershipDefenseSelection {
  OwnershipDefenseSelection({
    required String registrationId,
    required String characterId,
    required int registrationVersion,
    required int ownershipRevision,
    required int rosterRevision,
    required int lifecycleRevision,
  }) : json = ownershipFreeze({
         'registration_id': verificationUuid(registrationId),
         'character_id': verificationUuid(characterId),
         'expected_registration_version': ownershipVersion(registrationVersion),
         'expected_ownership_revision': ownershipVersion(ownershipRevision),
         'expected_roster_revision': ownershipVersion(rosterRevision),
         'expected_lifecycle_revision': ownershipVersion(lifecycleRevision),
       });
  final Map<String, dynamic> json;
}

/// Original wire payload + durable member/environment identity. Session binding
/// is ephemeral and must be renewed explicitly when restoring for the same member.
class OwnershipCommand {
  OwnershipCommand._(
    AccountReadSession session,
    this.storageScope,
    this.operation,
    String key,
    DateTime createdAt,
    Map<String, dynamic> payload, {
    String? targetId,
  }) : sessionScope = accountReadScope(session),
       idempotencyKey = verificationUuid(key),
       createdAt = createdAt.toUtc(),
       targetId = targetId == null ? null : verificationUuid(targetId),
       body = ownershipFreeze(payload) {
    ownershipRequire(sessionScope.userId == storageScope.userId);
    ownershipRequire(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(idempotencyKey),
    );
  }

  factory OwnershipCommand.claim(
    AccountReadSession session,
    StorageScope scope, {
    required String key,
    required DateTime createdAt,
    String? characterName,
    String? registrationId,
    int? registrationVersion,
    VerificationTarget? target,
  }) {
    final direct = characterName != null;
    ownershipRequire(
      direct
          ? registrationId == null &&
                registrationVersion == null &&
                target == null
          : registrationId != null &&
                registrationVersion != null &&
                target != null,
    );
    return OwnershipCommand._(
      session,
      scope,
      OwnershipOperation.startClaim,
      key,
      createdAt,
      direct
          ? {
              'source': 'direct_input',
              'character_name': ownershipName(characterName),
            }
          : {
              'source': 'registration',
              'registration_id': verificationUuid(registrationId),
              'expected_registration_version': ownershipVersion(
                registrationVersion,
              ),
              'target_character': target!.toJson(),
            },
    );
  }

  factory OwnershipCommand.defense(
    AccountReadSession session,
    StorageScope scope, {
    required String key,
    required DateTime createdAt,
    required String disputeId,
    required int disputeVersion,
    required OwnershipDefenseSelection selection,
  }) => OwnershipCommand._(
    session,
    scope,
    OwnershipOperation.startDefense,
    key,
    createdAt,
    {
      'expected_dispute_version': ownershipVersion(disputeVersion),
      'selection': selection.json,
    },
    targetId: disputeId,
  );

  factory OwnershipCommand.versioned(
    AccountReadSession session,
    StorageScope scope, {
    required OwnershipOperation operation,
    required String key,
    required DateTime createdAt,
    required String id,
    required int version,
  }) {
    ownershipRequire(
      {
        OwnershipOperation.confirm,
        OwnershipOperation.cancelProof,
        OwnershipOperation.cancelDispute,
        OwnershipOperation.settle,
      }.contains(operation),
    );
    return OwnershipCommand._(session, scope, operation, key, createdAt, {
      'expected_version': ownershipVersion(version),
    }, targetId: id);
  }

  static const proofsPath = '/v2/me/game-account-verifications';
  static const disputesPath = '/v2/me/ownership-disputes';
  final StorageScope storageScope;
  final AccountReadScope sessionScope;
  final OwnershipOperation operation;
  final String idempotencyKey;
  final DateTime createdAt;
  final String? targetId;
  final Map<String, dynamic> body;
  String get method => 'POST';
  int get expectedStatus =>
      {
        OwnershipOperation.startClaim,
        OwnershipOperation.startDefense,
      }.contains(operation)
      ? 201
      : 200;
  bool get returnsProof => {
    OwnershipOperation.startClaim,
    OwnershipOperation.startDefense,
    OwnershipOperation.confirm,
    OwnershipOperation.cancelProof,
  }.contains(operation);
  String get path => switch (operation) {
    OwnershipOperation.startClaim => proofsPath,
    OwnershipOperation.confirm => '$proofsPath/$targetId/confirm',
    OwnershipOperation.cancelProof => '$proofsPath/$targetId/cancel',
    OwnershipOperation.startDefense => '$disputesPath/$targetId/defenses',
    OwnershipOperation.cancelDispute => '$disputesPath/$targetId/cancel',
    OwnershipOperation.settle => '$disputesPath/$targetId/settle',
  };
  String get targetKey => switch (operation) {
    OwnershipOperation.startClaim =>
      body['source'] == 'registration'
          ? 'registration:${body['registration_id']}'
          : 'name:${(body['character_name'] as String).toLowerCase()}',
    OwnershipOperation.confirm ||
    OwnershipOperation.cancelProof => 'proof:$targetId',
    _ => 'dispute:$targetId',
  };

  bool replayableAt(DateTime now) =>
      !now.isBefore(createdAt) &&
      now.difference(createdAt) < const Duration(hours: 24);

  Map<String, dynamic> toJson() => {
    'environment': storageScope.environment,
    'user_id': storageScope.userId,
    'operation': operation.name,
    'key': idempotencyKey,
    'created_at': createdAt.toIso8601String(),
    'target_id': targetId,
    'method': method,
    'path': path,
    'body': body,
    'expected_status': expectedStatus,
  };

  factory OwnershipCommand.restore(
    Object? value,
    AccountReadSession session,
    StorageScope scope,
  ) {
    final j = ownershipObject(value, {
      'environment',
      'user_id',
      'operation',
      'key',
      'created_at',
      'target_id',
      'method',
      'path',
      'body',
      'expected_status',
    });
    ownershipRequire(
      j['environment'] == scope.environment && j['user_id'] == scope.userId,
    );
    final op = OwnershipOperation.values.firstWhere(
      (v) => v.name == j['operation'],
      orElse: () => throw const FormatException('Invalid ownership operation.'),
    );
    final created = ownershipTime(j['created_at']);
    final key = verificationUuid(j['key']);
    late OwnershipCommand command;
    if (op == OwnershipOperation.startClaim) {
      final raw = j['body'];
      ownershipRequire(raw is Map<String, dynamic>);
      final direct = (raw as Map<String, dynamic>)['source'] == 'direct_input';
      final b = ownershipObject(
        raw,
        direct
            ? {'source', 'character_name'}
            : {
                'source',
                'registration_id',
                'expected_registration_version',
                'target_character',
              },
      );
      ownershipRequire(direct || b['source'] == 'registration');
      command = OwnershipCommand.claim(
        session,
        scope,
        key: key,
        createdAt: created,
        characterName: direct ? ownershipName(b['character_name']) : null,
        registrationId: direct ? null : verificationUuid(b['registration_id']),
        registrationVersion: direct
            ? null
            : ownershipVersion(b['expected_registration_version']),
        target: direct ? null : ownershipTarget(b['target_character']),
      );
      ownershipRequire(j['target_id'] == null);
    } else if (op == OwnershipOperation.startDefense) {
      final b = ownershipObject(j['body'], {
        'expected_dispute_version',
        'selection',
      });
      final s = ownershipObject(b['selection'], {
        'registration_id',
        'character_id',
        'expected_registration_version',
        'expected_ownership_revision',
        'expected_roster_revision',
        'expected_lifecycle_revision',
      });
      command = OwnershipCommand.defense(
        session,
        scope,
        key: key,
        createdAt: created,
        disputeId: verificationUuid(j['target_id']),
        disputeVersion: ownershipVersion(b['expected_dispute_version']),
        selection: OwnershipDefenseSelection(
          registrationId: verificationUuid(s['registration_id']),
          characterId: verificationUuid(s['character_id']),
          registrationVersion: ownershipVersion(
            s['expected_registration_version'],
          ),
          ownershipRevision: ownershipVersion(s['expected_ownership_revision']),
          rosterRevision: ownershipVersion(s['expected_roster_revision']),
          lifecycleRevision: ownershipVersion(s['expected_lifecycle_revision']),
        ),
      );
    } else {
      final b = ownershipObject(j['body'], {'expected_version'});
      command = OwnershipCommand.versioned(
        session,
        scope,
        operation: op,
        key: key,
        createdAt: created,
        id: verificationUuid(j['target_id']),
        version: ownershipVersion(b['expected_version']),
      );
    }
    ownershipRequire(
      j['method'] == command.method &&
          j['path'] == command.path &&
          j['expected_status'] == command.expectedStatus,
    );
    return command;
  }
}
