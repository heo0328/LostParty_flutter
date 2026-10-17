import 'account_read_session.dart';

enum ServerVerificationStatus { pending, verified, expired, cancelled }

/// Backend VerificationOut. This response never binds local account ownership.
class ServerAccountVerification {
  ServerAccountVerification.fromJson(Map<String, dynamic> json) {
    const fields = {
      'challenge_id',
      'status',
      'required_slots',
      'expires_at',
      'remaining_seconds',
      'result_code',
      'result_reference',
      'registration_id',
    };
    if (json.length != fields.length || !fields.every(json.containsKey)) {
      throw const FormatException('Invalid verification fields.');
    }
    challengeId = verificationUuid(json['challenge_id']);
    status = ServerVerificationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => throw const FormatException('Invalid verification status.'),
    );
    final slots = json['required_slots'];
    if (slots is! List || slots.any((value) => value is! String)) {
      throw const FormatException('Invalid verification slots.');
    }
    requiredSlots = List<String>.unmodifiable(slots.cast<String>());
    final expiry = json['expires_at'];
    if (expiry is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T.+(?:Z|\+00:00)$').hasMatch(expiry)) {
      throw const FormatException('Invalid verification expiry.');
    }
    expiresAt = DateTime.parse(expiry).toUtc();
    final remaining = json['remaining_seconds'];
    if (remaining is! int || remaining < 0) {
      throw const FormatException('Invalid verification remaining time.');
    }
    remainingSeconds = remaining;
    final code = json['result_code'];
    if (code != null && code is! String) {
      throw const FormatException('Invalid verification result code.');
    }
    resultCode = code as String?;
    resultReference = json['result_reference'] == null
        ? null
        : verificationUuid(json['result_reference']);
    registrationId = json['registration_id'] == null
        ? null
        : verificationUuid(json['registration_id']);
  }

  late final String challengeId;
  late final ServerVerificationStatus status;
  late final List<String> requiredSlots;
  late final DateTime expiresAt;
  late final int remainingSeconds;
  late final String? resultCode, resultReference, registrationId;
}

String verificationUuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('Invalid verification UUID.');
  }
  return value.toLowerCase();
}

class VerificationTarget {
  VerificationTarget({
    required String serverName,
    required String characterName,
  }) : serverName = _verificationName(serverName),
       characterName = _verificationName(characterName);

  final String serverName, characterName;

  Map<String, String> toJson() => Map.unmodifiable({
    'server_name': serverName,
    'character_name': characterName,
  });

  @override
  bool operator ==(Object other) =>
      other is VerificationTarget &&
      other.serverName == serverName &&
      other.characterName == characterName;

  @override
  int get hashCode => Object.hash(serverName, characterName);
}

String _verificationName(String value) {
  final name = value.trim();
  if (name.isEmpty ||
      name.runes.length > 64 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
    throw const FormatException('Invalid verification name.');
  }
  return name;
}

/// Reuse the same object after an uncertain response; do not mint a new key.
class ServerVerificationCommand {
  ServerVerificationCommand._(
    AccountReadSession session, {
    required this.path,
    required this.method,
    required String idempotencyKey,
    required Map<String, dynamic>? body,
    required this.expectedStatus,
    this.challengeId,
    this.registrationId,
  }) : scope = accountReadScope(session),
       body = body == null ? null : Map.unmodifiable(body),
       idempotencyKey = verificationUuid(idempotencyKey) {
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(this.idempotencyKey)) {
      throw const FormatException('Expected a UUIDv4 idempotency key.');
    }
  }

  factory ServerVerificationCommand.startForRegistration(
    AccountReadSession session, {
    required String registrationId,
    required String idempotencyKey,
    VerificationTarget? targetCharacter,
    int? expectedRegistrationVersion,
  }) {
    final id = verificationUuid(registrationId);
    if ((targetCharacter == null) != (expectedRegistrationVersion == null) ||
        (expectedRegistrationVersion != null &&
            expectedRegistrationVersion < 1)) {
      throw const FormatException('Expected target and registration version.');
    }
    return ServerVerificationCommand._(
      session,
      path: basePath,
      method: 'POST',
      body: {
        'source': 'registration',
        'registration_id': id,
        if (targetCharacter != null) ...{
          'target_character': targetCharacter.toJson(),
          'expected_registration_version': expectedRegistrationVersion,
        },
      },
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
      registrationId: id,
    );
  }

  factory ServerVerificationCommand.startForName(
    AccountReadSession session, {
    required String characterName,
    required String idempotencyKey,
  }) {
    final name = characterName.trim();
    if (name.isEmpty ||
        name.runes.length > 64 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw const FormatException('Invalid verification character name.');
    }
    return ServerVerificationCommand._(
      session,
      path: basePath,
      method: 'POST',
      body: {'source': 'direct_input', 'character_name': name},
      idempotencyKey: idempotencyKey,
      expectedStatus: 201,
    );
  }

  factory ServerVerificationCommand.confirm(
    AccountReadSession session, {
    required String challengeId,
    required String idempotencyKey,
  }) => ServerVerificationCommand._challenge(
    session,
    challengeId: challengeId,
    idempotencyKey: idempotencyKey,
    cancel: false,
  );

  factory ServerVerificationCommand.cancel(
    AccountReadSession session, {
    required String challengeId,
    required String idempotencyKey,
  }) => ServerVerificationCommand._challenge(
    session,
    challengeId: challengeId,
    idempotencyKey: idempotencyKey,
    cancel: true,
  );

  factory ServerVerificationCommand._challenge(
    AccountReadSession session, {
    required String challengeId,
    required String idempotencyKey,
    required bool cancel,
  }) {
    final id = verificationUuid(challengeId);
    return ServerVerificationCommand._(
      session,
      path: '$basePath/$id${cancel ? '' : '/confirm'}',
      method: cancel ? 'DELETE' : 'POST',
      body: cancel ? null : <String, dynamic>{},
      idempotencyKey: idempotencyKey,
      expectedStatus: cancel ? 204 : 200,
      challengeId: id,
    );
  }

  static const basePath = '/v1/me/game-account-verifications';
  final AccountReadScope scope;
  final String path, method, idempotencyKey;
  final Map<String, dynamic>? body;
  final int expectedStatus;
  final String? challengeId, registrationId;
}
