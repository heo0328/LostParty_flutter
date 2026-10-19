import 'server_account_verification.dart';
import 'server_registration_api.dart';
import 'ownership_wire.dart';

class OwnershipContext {
  OwnershipContext.fromJson(Object? value) {
    final j = ownershipObject(value, {
      'relation',
      'notice_code',
      'observed_at',
      'can_start_claim',
      'blocked_reason',
    });
    relation = ownershipChoice(j['relation'], {
      'self',
      'other',
      'unverified',
      'unresolved',
    });
    noticeCode = ownershipNullableChoice(j['notice_code'], {
      'OTHER_OWNER_VERIFIED',
    });
    observedAt = ownershipTime(j['observed_at']);
    ownershipRequire(j['can_start_claim'] is bool);
    canStartClaim = j['can_start_claim'] as bool;
    blockedReason = ownershipNullableChoice(j['blocked_reason'], {
      'ALREADY_VERIFIED',
      'IDENTITY_UNRESOLVED',
      'DISPUTE_ALREADY_ACTIVE',
      'DISPUTE_CAPACITY_REACHED',
    });
    ownershipRequire(canStartClaim == (blockedReason == null));
    ownershipRequire((relation == 'other') == (noticeCode != null));
    if (relation == 'self') {
      ownershipRequire(blockedReason == 'ALREADY_VERIFIED');
    }
    if (relation == 'unresolved') {
      ownershipRequire(blockedReason == 'IDENTITY_UNRESOLVED');
    }
  }
  late final String relation;
  late final String? noticeCode, blockedReason;
  late final DateTime observedAt;
  late final bool canStartClaim;
}

class OwnershipPreview {
  OwnershipPreview.fromJson(Object? value) {
    final j = ownershipObject(value, {
      'preview',
      'ownership_context',
      'server_now',
    });
    preview = ServerRegistrationPreview.fromJson(
      j['preview'] as Map<String, dynamic>,
    );
    context = OwnershipContext.fromJson(j['ownership_context']);
    serverNow = ownershipTime(j['server_now']);
    if (context.relation != 'self') {
      ownershipRequire(preview.characters.every((c) => c.combatPower == null));
    }
  }
  late final ServerRegistrationPreview preview;
  late final OwnershipContext context;
  late final DateTime serverNow;
}

class OwnershipVerification {
  OwnershipVerification.fromJson(Object? value) {
    final j = ownershipObject(value, {
      'verification_id',
      'version',
      'purpose',
      'source',
      'source_registration_id',
      'equipment_status',
      'ownership_outcome',
      'ownership_context',
      'target',
      'required_slots',
      'created_at',
      'equipment_expires_at',
      'server_now',
      'ended_at',
      'result_code',
      'dispute_id',
      'registration_id',
      'allowed_actions',
    });
    id = verificationUuid(j['verification_id']);
    version = ownershipVersion(j['version']);
    purpose = ownershipChoice(j['purpose'], {'claim', 'defense'});
    source = ownershipChoice(j['source'], {
      'direct_input',
      'registration',
      'dispute_defense',
    });
    sourceRegistrationId = ownershipNullableId(j['source_registration_id']);
    equipmentStatus = ownershipChoice(j['equipment_status'], {
      'pending',
      'passed',
      'expired',
      'cancelled',
      'invalidated',
    });
    outcome = ownershipChoice(j['ownership_outcome'], {
      'none',
      'verified',
      'dispute_opened',
      'defended',
      'blocked',
    });
    context = OwnershipContext.fromJson(j['ownership_context']);
    target = ownershipTarget(j['target']);
    requiredSlots = ownershipStrings(
      j['required_slots'],
      (s) => ownershipChoice(s, {'무기', '투구', '어깨', '상의', '하의', '장갑'}),
      min: 1,
      max: 3,
    );
    createdAt = ownershipTime(j['created_at']);
    equipmentExpiresAt = ownershipTime(j['equipment_expires_at']);
    serverNow = ownershipTime(j['server_now']);
    endedAt = ownershipNullableTime(j['ended_at']);
    resultCode = ownershipNullableChoice(j['result_code'], {
      'REQUIRED_EQUIPMENT_PRESENT',
      'NON_REQUIRED_EQUIPMENT_CHANGED',
      'PROVIDER_EVIDENCE_PENDING',
      'ROSTER_EVIDENCE_PENDING',
      'VERIFIED',
      'DISPUTE_OPENED',
      'OWNER_DEFENDED',
      'DISPUTE_CAPACITY_REACHED',
      'DISPUTE_ALREADY_ACTIVE',
      'REVISION_CONFLICT',
      'IDENTITY_CONFLICT',
      'LOSTARK_KEY_CHANGED',
      'PARENT_DISPUTE_ENDED',
      'DEFENSE_WINDOW_CLOSED',
      'VERIFICATION_EXPIRED',
      'VERIFICATION_CANCELLED',
    });
    disputeId = ownershipNullableId(j['dispute_id']);
    registrationId = ownershipNullableId(j['registration_id']);
    allowedActions = ownershipStrings(
      j['allowed_actions'],
      (a) => ownershipChoice(a, {
        'confirm',
        'cancel',
        'view_dispute',
        'open_registration',
      }),
    );
    ownershipRequire(
      equipmentExpiresAt.isAfter(createdAt) &&
          equipmentExpiresAt.difference(createdAt) <=
              const Duration(minutes: 10),
    );
    ownershipRequire((equipmentStatus == 'pending') == (endedAt == null));
    if (endedAt != null) {
      ownershipRequire(!endedAt!.isBefore(createdAt));
    }
    if (purpose == 'defense') {
      ownershipRequire(
        source == 'dispute_defense' &&
            sourceRegistrationId != null &&
            registrationId != null &&
            disputeId != null,
      );
    } else {
      ownershipRequire(source != 'dispute_defense');
      ownershipRequire(
        (source == 'registration') == (sourceRegistrationId != null),
      );
      if (sourceRegistrationId != null) {
        ownershipRequire(registrationId == sourceRegistrationId);
      }
    }
    final validResult = switch (equipmentStatus) {
      'pending' =>
        outcome == 'none' &&
            {
              null,
              'REQUIRED_EQUIPMENT_PRESENT',
              'NON_REQUIRED_EQUIPMENT_CHANGED',
              'PROVIDER_EVIDENCE_PENDING',
              'ROSTER_EVIDENCE_PENDING',
            }.contains(resultCode),
      'passed' => switch (outcome) {
        'verified' =>
          purpose == 'claim' &&
              resultCode == 'VERIFIED' &&
              registrationId != null &&
              disputeId == null,
        'dispute_opened' =>
          purpose == 'claim' &&
              resultCode == 'DISPUTE_OPENED' &&
              disputeId != null,
        'defended' => purpose == 'defense' && resultCode == 'OWNER_DEFENDED',
        'blocked' =>
          purpose == 'claim' &&
              {
                'DISPUTE_CAPACITY_REACHED',
                'DISPUTE_ALREADY_ACTIVE',
              }.contains(resultCode) &&
              disputeId == null,
        _ => false,
      },
      'invalidated' =>
        outcome == 'blocked' &&
            {
              'REVISION_CONFLICT',
              'IDENTITY_CONFLICT',
              'LOSTARK_KEY_CHANGED',
              'PARENT_DISPUTE_ENDED',
              'DEFENSE_WINDOW_CLOSED',
            }.contains(resultCode),
      'expired' => outcome == 'none' && resultCode == 'VERIFICATION_EXPIRED',
      'cancelled' =>
        outcome == 'none' && resultCode == 'VERIFICATION_CANCELLED',
      _ => false,
    };
    ownershipRequire(validResult);
    if (purpose == 'claim' && outcome != 'dispute_opened') {
      ownershipRequire(disputeId == null);
    }
    if (source == 'direct_input' && outcome != 'verified') {
      ownershipRequire(registrationId == null);
    }
    if (allowedActions.contains('confirm') ||
        allowedActions.contains('cancel')) {
      ownershipRequire(
        equipmentStatus == 'pending' && equipmentExpiresAt.isAfter(serverNow),
      );
    }
    if (allowedActions.contains('view_dispute')) {
      ownershipRequire(disputeId != null);
    }
    if (allowedActions.contains('open_registration')) {
      ownershipRequire(outcome == 'verified' && registrationId != null);
    }
  }
  late final String id, purpose, source, equipmentStatus, outcome;
  late final int version;
  late final String? sourceRegistrationId,
      resultCode,
      disputeId,
      registrationId;
  late final OwnershipContext context;
  late final VerificationTarget target;
  late final List<String> requiredSlots, allowedActions;
  late final DateTime createdAt, equipmentExpiresAt, serverNow;
  late final DateTime? endedAt;
}

class OwnershipDispute {
  OwnershipDispute.fromJson(Object? value) {
    final j = ownershipObject(value, {
      'dispute_id',
      'version',
      'viewer_role',
      'state',
      'phase',
      'target',
      'started_at',
      'defense_deadline',
      'server_now',
      'defense_available_until',
      'resolved_at',
      'reason_code',
      'next_retry_at',
      'my_registration_id',
      'my_active_verification_ids',
      'allowed_actions',
    });
    id = verificationUuid(j['dispute_id']);
    version = ownershipVersion(j['version']);
    viewerRole = ownershipChoice(j['viewer_role'], {'challenger', 'owner'});
    state = ownershipChoice(j['state'], {
      'defending',
      'defended',
      'transferred',
      'cancelled',
      'invalidated',
      'review_required',
    });
    phase = ownershipChoice(j['phase'], {
      'awaiting_defense',
      'settlement_due',
      'retrying_settlement',
      'finished',
      'review_required',
    });
    target = ownershipTarget(j['target']);
    startedAt = ownershipTime(j['started_at']);
    defenseDeadline = ownershipTime(j['defense_deadline']);
    serverNow = ownershipTime(j['server_now']);
    defenseAvailableUntil = ownershipNullableTime(j['defense_available_until']);
    resolvedAt = ownershipNullableTime(j['resolved_at']);
    reasonCode = ownershipNullableChoice(j['reason_code'], {
      'OWNER_DEFENDED',
      'OWNERSHIP_TRANSFERRED',
      'CHALLENGER_CANCELLED',
      'OWNER_CHANGED',
      'TARGET_CHANGED',
      'PARTY_IMPACT_REVIEW_REQUIRED',
      'REGISTRATION_REMOVED',
      'REGISTRATION_CONFLICT',
      'REGISTRATION_LIMIT',
      'UPSTREAM_UNAVAILABLE',
      'LOSTARK_KEY_NOT_CONFIGURED',
      'LOSTARK_KEY_REJECTED',
      'WAITING_FOR_EARLIER_DISPUTE',
      'MEMBER_UNAVAILABLE',
    });
    nextRetryAt = ownershipNullableTime(j['next_retry_at']);
    myRegistrationId = ownershipNullableId(j['my_registration_id']);
    myActiveVerificationIds = ownershipStrings(
      j['my_active_verification_ids'],
      verificationUuid,
    );
    allowedActions = ownershipStrings(
      j['allowed_actions'],
      (a) => ownershipChoice(a, {
        'cancel_dispute',
        'start_defense',
        'view_my_verifications',
        'request_settlement',
        'open_registration',
      }),
    );
    ownershipRequire(
      defenseDeadline.difference(startedAt) == const Duration(hours: 24),
    );
    if (state == 'defending') {
      ownershipRequire(resolvedAt == null);
      if (serverNow.isBefore(defenseDeadline)) {
        ownershipRequire(phase == 'awaiting_defense');
      } else {
        ownershipRequire(
          phase ==
              (reasonCode != null && nextRetryAt != null
                  ? 'retrying_settlement'
                  : 'settlement_due'),
        );
      }
    } else if (state == 'review_required') {
      ownershipRequire(
        phase == 'review_required' && resolvedAt == null && reasonCode != null,
      );
    } else {
      ownershipRequire(
        phase == 'finished' &&
            resolvedAt != null &&
            reasonCode != null &&
            nextRetryAt == null &&
            defenseAvailableUntil == null,
      );
    }
    if (defenseAvailableUntil != null) {
      ownershipRequire(!defenseAvailableUntil!.isAfter(defenseDeadline));
    }
    if (allowedActions.contains('start_defense')) {
      ownershipRequire(
        viewerRole == 'owner' &&
            {'defending', 'review_required'}.contains(state) &&
            defenseAvailableUntil != null &&
            defenseAvailableUntil!.isAfter(serverNow),
      );
    }
    if (allowedActions.contains('cancel_dispute')) {
      ownershipRequire(
        viewerRole == 'challenger' &&
            (state == 'review_required' ||
                (state == 'defending' && serverNow.isBefore(defenseDeadline))),
      );
    }
    if (allowedActions.contains('request_settlement')) {
      ownershipRequire(
        state == 'defending' && !serverNow.isBefore(defenseDeadline),
      );
    }
    if (allowedActions.contains('view_my_verifications')) {
      ownershipRequire(myActiveVerificationIds.isNotEmpty);
    }
    if (allowedActions.contains('open_registration')) {
      ownershipRequire(myRegistrationId != null);
    }
  }
  late final String id, viewerRole, state, phase;
  late final int version;
  late final VerificationTarget target;
  late final DateTime startedAt, defenseDeadline, serverNow;
  late final DateTime? defenseAvailableUntil, resolvedAt, nextRetryAt;
  late final String? reasonCode, myRegistrationId;
  late final List<String> myActiveVerificationIds, allowedActions;
}

/// One server page only: no partial-page merging or CURSOR_STALE retry here.
class OwnershipPage<T> {
  OwnershipPage.fromJson(
    Object? value,
    T Function(Object?) decode,
    String Function(T) id, {
    int limit = 100,
  }) {
    final j = ownershipObject(value, {
      'items',
      'next_cursor',
      'feed_revision',
      'server_now',
    });
    ownershipRequire(
      j['items'] is List && (j['items'] as List).length <= limit,
    );
    items = List.unmodifiable((j['items'] as List).map(decode));
    ownershipRequire(items.map(id).toSet().length == items.length);
    nextCursor = ownershipCursor(j['next_cursor']);
    feedRevision = ownershipVersion(j['feed_revision']);
    serverNow = ownershipTime(j['server_now']);
    ownershipRequire(nextCursor == null || items.isNotEmpty);
  }
  late final List<T> items;
  late final String? nextCursor;
  late final int feedRevision;
  late final DateTime serverNow;
}

String? ownershipCursor(Object? value) {
  if (value == null) return null;
  ownershipRequire(value is String && value.isNotEmpty && value.length <= 2048);
  return value as String;
}
