import 'dart:convert';
import '../../../account/domain/role_summary.dart';
import '../../../account/domain/member_raid_models.dart';
import 'beta_contract.dart';

enum RecruitmentCommandOwner { creation, participation, presets }

enum RecruitmentCommandState { pending, acknowledged, needsReview }

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
    this.state = RecruitmentCommandState.pending,
    this.rawAck,
    this.contractMode = RecruitmentContractMode.betaWire2,
    this.expectedStatus = 200,
  }) : rawQuery = jsonEncode(query),
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
      rawAck = j['raw_ack'] as String?,
      contractMode = RecruitmentContractMode.values.byName(
        j['contract_mode'] as String,
      ),
      expectedStatus = j['expected_status'] as int {
    roleShape(
      j,
      'version owner operation method path raw_query target_cycles raw_body key created_at attempted_at state raw_ack contract_mode expected_status',
    );
    roleCheck(j['version'] == 1);
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
  final DateTime? attemptedAt;
  final RecruitmentCommandState state;
  final String? rawAck;
  final RecruitmentContractMode contractMode;
  final int expectedStatus;
  Map<String, dynamic> get query =>
      betaFreeze(jsonDecode(rawQuery)) as Map<String, dynamic>;
  bool expired(DateTime now) =>
      !now.isBefore(createdAt.add(const Duration(hours: 24)));
  void _validate() {
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
    'version': 1,
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
      ..remove('raw_ack');
    return jsonEncode(original(this)) == jsonEncode(original(other));
  }

  RecruitmentCommand transition({
    DateTime? attemptedAt,
    RecruitmentCommandState? state,
    String? rawAck,
  }) => RecruitmentCommand._({
    ...toJson(),
    if (attemptedAt != null) 'attempted_at': attemptedAt.toIso8601String(),
    if (state != null) 'state': state.name,
    'raw_ack': rawAck ?? this.rawAck,
  });
}
