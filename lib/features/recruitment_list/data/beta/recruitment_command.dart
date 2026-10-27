import 'dart:convert';
import '../../../account/domain/role_summary.dart';
import '../../../account/domain/member_raid_models.dart';
import 'beta_contract.dart';
import 'participation_command_evidence.dart';

enum RecruitmentCommandOwner { creation, participation, presets }

enum RecruitmentCommandState { pending, acknowledged, needsReview, rejected }

/// Exact wire bytes and query are retained independently of mutable UI drafts.
/// Authentication and in-memory preview objects must never enter this envelope.
class RecruitmentCommand {
  RecruitmentCommand({
    required this.owner,
    required this.operation,
    required this.method,
    required this.path,
    required Map<String, dynamic> query,
    required List<String> targetCycles,
    required this.rawBody,
    required this.key,
    required this.createdAt,
    this.attemptedAt,
    this.retryNotBefore,
    this.state = RecruitmentCommandState.pending,
    this.rawAck,
    this.contractMode = RecruitmentContractMode.betaWire2,
    this.expectedStatus = 200,
    this.version = 1,
    Map<String, dynamic>? validationSnapshot,
    Map<String, dynamic>? rejection,
  }) : rawQuery = jsonEncode(query),
       validationSnapshot =
           betaFreeze(validationSnapshot) as Map<String, dynamic>?,
       rejection = betaFreeze(rejection) as Map<String, dynamic>?,
       targetCycles = List.unmodifiable(targetCycles) {
    _validate();
  }
  RecruitmentCommand._(Map<String, dynamic> j)
    : owner = RecruitmentCommandOwner.values.byName(j['owner'] as String),
      operation = j['operation'] as String,
      method = j['method'] as String,
      path = j['path'] as String,
      rawQuery = j['raw_query'] as String,
      targetCycles = List<String>.unmodifiable(
        (j['target_cycles'] as List).cast<String>(),
      ),
      rawBody = j['raw_body'] as String,
      key = j['key'] as String,
      createdAt = roleUtc(j['created_at']),
      attemptedAt = j['attempted_at'] == null
          ? null
          : roleUtc(j['attempted_at']),
      state = RecruitmentCommandState.values.byName(j['state'] as String),
      retryNotBefore = j['retry_not_before'] == null
          ? null
          : roleUtc(j['retry_not_before']),
      rawAck = j['raw_ack'] as String?,
      contractMode = RecruitmentContractMode.values.byName(
        j['contract_mode'] as String,
      ),
      expectedStatus = j['expected_status'] as int,
      version = j['version'] as int,
      validationSnapshot =
          betaFreeze(j['validation_snapshot']) as Map<String, dynamic>?,
      rejection = betaFreeze(j['rejection']) as Map<String, dynamic>? {
    roleShape(
      j,
      'version owner operation method path raw_query target_cycles raw_body key created_at attempted_at state raw_ack contract_mode expected_status${version >= 2 ? ' validation_snapshot rejection' : ''}${version == 3 ? ' retry_not_before' : ''}',
    );
    roleCheck(version == 1 || version == 2 || version == 3);
    _validate();
  }
  factory RecruitmentCommand.decode(String source) {
    try {
      return RecruitmentCommand._(roleMap(jsonDecode(source)));
    } on FormatException {
      rethrow;
    } on ArgumentError {
      throw const FormatException('Corrupt recruitment journal');
    } on TypeError {
      throw const FormatException('Corrupt recruitment journal');
    }
  }
  final RecruitmentCommandOwner owner;
  final String operation, method, path, rawQuery, rawBody, key;
  final List<String> targetCycles;
  final DateTime createdAt;
  final DateTime? attemptedAt, retryNotBefore;
  final RecruitmentCommandState state;
  final String? rawAck;
  final RecruitmentContractMode contractMode;
  final int expectedStatus;
  final int version;
  final Map<String, dynamic>? validationSnapshot, rejection;
  Map<String, dynamic> get query =>
      betaFreeze(jsonDecode(rawQuery)) as Map<String, dynamic>;
  bool expired(DateTime now) =>
      !now.isBefore(createdAt.add(const Duration(hours: 24)));
  void _validate() {
    roleCheck(version == 1 || version == 2 || version == 3);
    roleCheck(
      version >= 2 || (validationSnapshot == null && rejection == null),
    );
    roleCheck(
      (state == RecruitmentCommandState.rejected) == (rejection != null),
    );
    if (rejection != null) {
      roleShape(rejection!, 'status code');
      roleCheck(
        definiteRecruitmentRejection(rejection!['status'], rejection!['code']),
      );
    }
    roleCheck(retryNotBefore == null || retryNotBefore!.isUtc);
    roleId(key);
    roleCheck(
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(key),
    );
    roleCheck(
      createdAt.isUtc &&
          (attemptedAt == null ||
              (attemptedAt!.isUtc && !attemptedAt!.isBefore(createdAt))),
    );
    roleCheck(
      utf8.encode(rawBody).length <= 32768 &&
          utf8.encode(rawQuery).length <= 65536,
    );
    roleCheck(
      targetCycles.length <= 2 &&
          targetCycles.toSet().length == targetCycles.length,
    );
    for (final t in targetCycles) {
      raidCycleKey(t);
    }
    final contract = BetaContract(mode: contractMode);
    final op = contract.operation(method, path);
    roleCheck(operation == op['id'] && method != 'GET');
    roleCheck(roleMap(op['responses']).containsKey('$expectedStatus'));
    roleCheck(
      path.startsWith('/v2/') &&
          !path.contains('?') &&
          !path.contains('#') &&
          !path.contains('..'),
    );
    final preset = path == '/v2/me/application-message-presets';
    roleCheck(
      preset
          ? owner == RecruitmentCommandOwner.presets && targetCycles.isEmpty
          : owner != RecruitmentCommandOwner.presets && targetCycles.isNotEmpty,
    );
    roleCheck(
      owner != RecruitmentCommandOwner.creation || path == '/v2/raid-rooms',
    );
    roleCheck(
      path != '/v2/raid-rooms' || owner == RecruitmentCommandOwner.creation,
    );
    final body = roleMap(jsonDecode(rawBody));
    roleCheck(
      version == 3
          ? owner == RecruitmentCommandOwner.participation
          : retryNotBefore == null,
    );
    if (version == 3 && validationSnapshot != null) {
      ParticipationCommandEvidence(validationSnapshot!).bind(
        method,
        path,
        rawQuery,
        rawBody,
        key,
        expectedStatus,
        targetCycles,
      );
    }
    if (validationSnapshot != null && version != 3) {
      roleCheck(version == 2 && owner == RecruitmentCommandOwner.creation);
      final e = validationSnapshot!;
      roleShape(e, 'room_id target_cycle_key effect created_cycles');
      roleId(e['room_id']);
      roleCheck(e['target_cycle_key'] == body['target_cycle_key']);
      roleCheck(
        e['effect'] ==
            (body['continuation']['enabled'] == true
                ? 'target_and_next'
                : 'target_only'),
      );
      final rows = raidList(e['created_cycles']);
      roleCheck(rows.length == targetCycles.length);
      final keys = <String>{}, ids = <String>{};
      for (final raw in rows) {
        final p = roleMap(raw);
        roleShape(
          p,
          'target_cycle_key room_cycle_id generation target_revision',
        );
        roleCheck(
          keys.add(raidCycleKey(p['target_cycle_key'])) &&
              ids.add(roleId(p['room_cycle_id'])),
        );
        roleCheck(
          rolePositive(p['generation']) <= 2147483647 &&
              rolePositive(p['target_revision']) <= 2147483647,
        );
      }
      roleCheck(keys.containsAll(targetCycles));
    }
    for (final field in ['target_cycle_key', 'view_cycle_key']) {
      if (body[field] != null) roleCheck(targetCycles.contains(body[field]));
      if (query[field] != null) roleCheck(targetCycles.contains(query[field]));
    }
    if (body['beta_schedule_targets'] case final List targets) {
      final actual = targets.map((v) => roleMap(v)['target_cycle_key']).toSet();
      roleCheck(
        actual.length == targetCycles.length &&
            actual.containsAll(targetCycles),
      );
    }
    if (contractMode == RecruitmentContractMode.betaWire2) {
      contract.validateRequest(method, path, query, jsonDecode(rawBody));
    } else {
      roleCheck(!query.containsKey('contract_profile'));
      roleMap(jsonDecode(rawBody));
    }
    roleCheck(
      (state == RecruitmentCommandState.acknowledged) == (rawAck != null),
    );
    if (rawAck != null) {
      roleCheck(utf8.encode(rawAck!).length <= 262144);
      final ack = roleMap(jsonDecode(rawAck!));
      if (contractMode == RecruitmentContractMode.betaWire2) {
        contract.validateResponse(method, path, expectedStatus, ack);
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    if (version >= 2) 'validation_snapshot': validationSnapshot,
    if (version == 3) 'retry_not_before': retryNotBefore?.toIso8601String(),
    if (version >= 2) 'rejection': rejection,
    'owner': owner.name,
    'operation': operation,
    'method': method,
    'path': path,
    'raw_query': rawQuery,
    'target_cycles': targetCycles,
    'raw_body': rawBody,
    'key': key,
    'created_at': createdAt.toIso8601String(),
    'attempted_at': attemptedAt?.toIso8601String(),
    'state': state.name,
    'raw_ack': rawAck,
    'contract_mode': contractMode.name,
    'expected_status': expectedStatus,
  };
  String encode() => jsonEncode(toJson());
  bool sameOriginal(RecruitmentCommand other) {
    Map<String, dynamic> original(RecruitmentCommand c) => c.toJson()
      ..remove('attempted_at')
      ..remove('state')
      ..remove('raw_ack')
      ..remove('retry_not_before');
    // A validated rejection resolves the request; it does not alter its recipe.
    final a = original(this)..remove('rejection'),
        b = original(other)..remove('rejection');
    return jsonEncode(a) == jsonEncode(b);
  }

  RecruitmentCommand transition({
    DateTime? attemptedAt,
    DateTime? retryNotBefore,
    RecruitmentCommandState? state,
    String? rawAck,
    Map<String, dynamic>? rejection,
  }) => RecruitmentCommand._({
    ...toJson(),
    if (version == 3)
      'retry_not_before': (retryNotBefore ?? this.retryNotBefore)
          ?.toIso8601String(),
    if (attemptedAt != null) 'attempted_at': attemptedAt.toIso8601String(),
    if (state != null) 'state': state.name,
    'raw_ack': rawAck ?? this.rawAck,
    if (version >= 2) 'rejection': rejection ?? this.rejection,
  });
}

/// Closed set of known no-create outcomes. Unknown errors stay unresolved.
bool definiteRecruitmentRejection(Object? status, Object? code) =>
    const {400, 403, 404, 409, 413}.contains(status) &&
    const {
      'INVALID_REQUEST',
      'ROOM_COMPOSITION_CONFLICT',
      'APPLICATION_MEMO_TOO_LONG',
      'APPLICATION_PRESET_LIMIT_EXCEEDED',
      'PERMISSION_DENIED',
      'NOT_FOUND',
      'PAYLOAD_TOO_LARGE',
      'SELECTION_CONTEXT_CHANGED',
      'TARGET_CYCLE_OUT_OF_RANGE',
      'RAID_ITEM_LEVEL_REQUIRED',
      'CHARACTER_ALREADY_PARTICIPATING',
      'RAID_ALREADY_COMPLETED',
      'GROUP_ACCESS_REQUIRED',
      'CLIENT_UPGRADE_REQUIRED',
      'CONTEXT_EXPIRED',
      'CHARACTER_NOT_ELIGIBLE',
      'CONTEXT_INVALID',
      'REQUEST_TOO_LARGE',
      'COMMAND_CONTEXT_EXPIRED',
      'REVISION_CONFLICT',
      'CYCLE_CHANGED',
      'CATALOG_VERSION_CONFLICT',
      'RECRUITMENT_CLOSED',
      'START_BEFORE_FLOOR',
      'INVALID_START_TIME',
      'SCHEDULE_BEFORE_FLOOR',
      'SCHEDULE_IN_PAST',
      'MAINTENANCE_WINDOW',
      'SESSION_DURATION_EXCEEDED',
      'WEEKLY_ALREADY_PARTICIPATING',
      'WEEKLY_OCCUPANCY_CHANGED',
      'WEEKLY_ALREADY_COMPLETED',
      'RAID_WEEKLY_COMPLETED',
      'WEEKLY_COMPLETED',
      'COMBAT_POWER_REQUIRED',
      'ROLE_NOT_SUPPORTED',
      'CHARACTER_DATA_UNAVAILABLE',
      'MEMBER_RAID_LIMIT_REACHED',
      'GROUP_MEMBERSHIP_REQUIRED',
      'OWNERSHIP_REQUIRED',
      'CHARACTER_NOT_ACTIVE',
      'ROOM_RESTRICTED',
      'GROUP_CAPACITY_EXCEEDED',
      'MEMBER_GROUP_LIMIT_EXCEEDED',
    }.contains(code);
