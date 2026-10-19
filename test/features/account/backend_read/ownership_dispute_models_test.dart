import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/account/domain/ownership_verification_models.dart';
import 'ownership_dispute_fixtures.dart';

void main() {
  test(
    'pinned executable contract has 11 operations and exact response fields',
    () {
      final spec =
          jsonDecode(
                File(
                  'docs/backend-migration/contracts/issue15-7ba6297-v2.openapi.json',
                ).readAsStringSync(),
              )
              as Map;
      expect(
        (spec['paths'] as Map).values.fold<int>(
          0,
          (n, p) => n + (p as Map).length,
        ),
        11,
      );
      final schemas = spec['components']['schemas'] as Map;
      for (final pair in [
        ('VerificationV2', proofJson()),
        ('DisputeOut', disputeJson()),
        ('PreviewV2', previewJson()),
        ('VerificationPage', pageJson([])),
      ]) {
        expect(
          pair.$2.keys.toSet(),
          (schemas[pair.$1]['required'] as List).toSet(),
        );
      }
    },
  );

  test(
    'strict required nullable fields and unknown fields in all V2 envelopes',
    () {
      final cases = <(Map<String, dynamic>, Object Function(Object?))>[
        (proofJson(), OwnershipVerification.fromJson),
        (disputeJson(), OwnershipDispute.fromJson),
        (previewJson(), OwnershipPreview.fromJson),
        (contextJson(), OwnershipContext.fromJson),
        (
          pageJson([]),
          (v) => OwnershipPage<OwnershipVerification>.fromJson(
            v,
            OwnershipVerification.fromJson,
            (p) => p.id,
          ),
        ),
      ];
      for (final (wire, decode) in cases) {
        for (final field in wire.keys) {
          expect(
            () => decode({...wire}..remove(field)),
            throwsFormatException,
            reason: field,
          );
        }
        expect(() => decode({...wire, 'unknown': 1}), throwsFormatException);
      }
    },
  );

  test(
    'unknown enums, non-strict versions, malformed UUID/time, duplicated actions/slots fail closed',
    () {
      for (final change in <Map<String, dynamic>>[
        {'version': true},
        {'version': 1.0},
        {'version': 0},
        {'purpose': 'future'},
        {'equipment_status': 'verified'},
        {'ownership_outcome': 'success'},
        {'result_code': 'FUTURE'},
        {'verification_id': '../id'},
        {'registration_id': 12},
        {'server_now': '2026-02-30T01:00:00Z'},
        {'created_at': '2026-10-19T01:00:00'},
        {
          'required_slots': ['장갑', '장갑'],
        },
        {'required_slots': []},
        {
          'required_slots': ['목걸이'],
        },
        {
          'allowed_actions': ['confirm', 'confirm'],
        },
        {
          'allowed_actions': ['delete'],
        },
        {
          'target': {...targetJson(), 'character_id': charId},
        },
      ]) {
        expect(
          () => OwnershipVerification.fromJson({...proofJson(), ...change}),
          throwsFormatException,
          reason: '$change',
        );
      }
    },
  );

  test('ownership notice and eligibility combinations are coherent', () {
    for (final change in [
      {'relation': 'self'},
      {'relation': 'unresolved'},
      {'can_start_claim': false},
      {'notice_code': null},
      {'blocked_reason': 'ALREADY_VERIFIED'},
    ]) {
      expect(
        () => OwnershipContext.fromJson({...contextJson(), ...change}),
        throwsFormatException,
      );
    }
    final self = OwnershipContext.fromJson({
      ...contextJson(),
      'relation': 'self',
      'notice_code': null,
      'can_start_claim': false,
      'blocked_reason': 'ALREADY_VERIFIED',
    });
    expect(self.canStartClaim, false);
  });

  test(
    'equipment passed / dispute opened is distinct from verified and immutable',
    () {
      final wire = proofJson()
        ..addAll({
          'equipment_status': 'passed',
          'ownership_outcome': 'dispute_opened',
          'result_code': 'DISPUTE_OPENED',
          'ended_at': wireNow,
          'dispute_id': disputeId,
          'allowed_actions': ['view_dispute'],
        });
      final value = OwnershipVerification.fromJson(wire);
      expect(value.outcome, 'dispute_opened');
      expect(value.registrationId, isNull);
      expect(() => value.allowedActions.add('confirm'), throwsUnsupportedError);
      (wire['required_slots'] as List).clear();
      expect(value.requiredSlots, ['장갑']);
      expect(
        () => OwnershipVerification.fromJson({
          ...wire,
          'required_slots': ['장갑'],
          'ownership_outcome': 'verified',
        }),
        throwsFormatException,
      );
    },
  );

  test('all terminal proof outcomes and invalid combinations', () {
    final outcomes = [
      {
        'equipment_status': 'passed',
        'ownership_outcome': 'verified',
        'result_code': 'VERIFIED',
        'registration_id': regId,
      },
      {
        'equipment_status': 'passed',
        'ownership_outcome': 'blocked',
        'result_code': 'DISPUTE_CAPACITY_REACHED',
      },
      {
        'equipment_status': 'invalidated',
        'ownership_outcome': 'blocked',
        'result_code': 'LOSTARK_KEY_CHANGED',
      },
      {
        'equipment_status': 'expired',
        'ownership_outcome': 'none',
        'result_code': 'VERIFICATION_EXPIRED',
      },
      {
        'equipment_status': 'cancelled',
        'ownership_outcome': 'none',
        'result_code': 'VERIFICATION_CANCELLED',
      },
    ];
    for (final terminal in outcomes) {
      final wire = {
        ...proofJson(),
        ...terminal,
        'ended_at': wireNow,
        'allowed_actions': <String>[],
      };
      expect(
        OwnershipVerification.fromJson(wire).equipmentStatus,
        terminal['equipment_status'],
      );
      expect(
        () => OwnershipVerification.fromJson({...wire, 'ended_at': null}),
        throwsFormatException,
      );
      expect(
        () => OwnershipVerification.fromJson({
          ...wire,
          'allowed_actions': ['confirm'],
        }),
        throwsFormatException,
      );
    }
    final defended = {
      ...proofJson(defense: true),
      'equipment_status': 'passed',
      'ownership_outcome': 'defended',
      'result_code': 'OWNER_DEFENDED',
      'ended_at': wireNow,
      'allowed_actions': ['view_dispute'],
    };
    expect(OwnershipVerification.fromJson(defended).outcome, 'defended');
    expect(
      () => OwnershipVerification.fromJson({...defended, 'dispute_id': null}),
      throwsFormatException,
    );
  });

  test('dispute deadline, role/action and terminal phase boundaries', () {
    expect(
      OwnershipDispute.fromJson(disputeJson(role: 'owner')).allowedActions,
      ['start_defense'],
    );
    final due = OwnershipDispute.fromJson(disputeJson(due: true));
    expect(due.state, 'defending');
    expect(due.phase, 'settlement_due');
    for (final change in [
      {'viewer_role': 'future'},
      {'version': true},
      {'phase': 'finished'},
      {
        'allowed_actions': ['start_defense'],
      },
      {
        'my_active_verification_ids': [proofId, proofId],
      },
      {
        'allowed_actions': ['view_my_verifications'],
      },
      {
        'allowed_actions': ['open_registration'],
      },
      {'defense_deadline': '2026-10-21T01:00:00Z'},
    ]) {
      expect(
        () => OwnershipDispute.fromJson({...disputeJson(), ...change}),
        throwsFormatException,
      );
    }
    final finished = {
      ...disputeJson(),
      'state': 'transferred',
      'phase': 'finished',
      'resolved_at': '2026-10-20T01:00:01Z',
      'reason_code': 'OWNERSHIP_TRANSFERRED',
      'defense_available_until': null,
      'allowed_actions': <String>[],
    };
    expect(OwnershipDispute.fromJson(finished).state, 'transferred');
    expect(
      () => OwnershipDispute.fromJson({...finished, 'resolved_at': null}),
      throwsFormatException,
    );
  });

  test(
    'page rejects duplicate IDs, overflow and broken cursor, preserves empty page',
    () {
      OwnershipPage<OwnershipVerification> decode(Object? j) =>
          OwnershipPage.fromJson(
            j,
            OwnershipVerification.fromJson,
            (p) => p.id,
            limit: 1,
          );
      expect(decode(pageJson([])).items, isEmpty);
      expect(
        () => decode(pageJson([proofJson(), proofJson()])),
        throwsFormatException,
      );
      expect(() => decode(pageJson([], cursor: 'next')), throwsFormatException);
      expect(
        () => decode(pageJson([proofJson()], cursor: '')),
        throwsFormatException,
      );
      expect(() => ownershipCursor('x' * 2049), throwsFormatException);
      final value = decode(pageJson([proofJson()], cursor: 'opaque'));
      expect(value.nextCursor, 'opaque');
      expect(() => value.items.clear(), throwsUnsupportedError);
    },
  );
}
