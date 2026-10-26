import 'dart:convert';
import 'beta/beta_contract.dart';
import 'beta/beta_read.dart';
import '../../account/domain/account_read_session.dart';
import '../../account/domain/member_raid_models.dart';
import '../../account/domain/role_summary.dart';
import '../../account/domain/server_registration_api.dart';
import '../domain/backend_recruitment.dart';
import 'admission_candidates.dart' show AdmissionPowerComparison;
import 'backend_recruitment_repository.dart';
import 'cycle_read_repository.dart';
import 'cycle_schedule.dart' show scheduleStable;

const applicationDisplayProfile = 'application-display-1';
Object? _freeze(Object? v) => v is Map
    ? Map<String, dynamic>.unmodifiable(
        v.map((k, v) => MapEntry(k as String, _freeze(v))),
      )
    : v is List
    ? List<Object?>.unmodifiable(v.map(_freeze))
    : v;
Map<String, dynamic> _snapshot(Map<String, dynamic> raw) {
  final encoded = jsonEncode(raw);
  if (utf8.encode(encoded).length > 1024 * 1024) {
    throw const AccountReadException('RESPONSE_TOO_LARGE', status: 413);
  }
  return _freeze(jsonDecode(encoded)) as Map<String, dynamic>;
}

int _version(Object? v) {
  roleCheck(v is int && v > 0 && v <= 2147483647);
  return v as int;
}

class ApplicationAnalysis {
  ApplicationAnalysis(Map<String, dynamic> raw) : wire = _snapshot(raw) {
    roleShape(wire, 'version saved_at analyzed_at integrity_status issues');
    _version(wire['version']);
    roleUtc(wire['saved_at']);
    roleUtc(wire['analyzed_at']);
    roleCheck(
      {
        'clean',
        'review',
        'error',
        'unavailable',
      }.contains(wire['integrity_status']),
    );
    final values = raidList(wire['issues']);
    roleCheck(values.length <= 20);
    issues = List.unmodifiable(
      values.map((v) => AnalysisIssue.fromJson(roleMap(v))),
    );
  }
  final Map<String, dynamic> wire;
  late final List<AnalysisIssue> issues;
}

/// Validates the agreed display extension without changing legacy/write DTOs.
class ApplicationItemLevel {
  ApplicationItemLevel.fromDisplay(Map<String, dynamic> display) {
    roleCheck(
      [
        'item_level',
        'item_level_source',
        'item_level_fetched_at',
      ].every(display.containsKey),
    );
    final raw = display['item_level'];
    roleCheck(
      raw == null ||
          raw is String &&
              raw.length <= 64 &&
              RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(raw),
    );
    roleCheck(
      {
        'application_snapshot',
        'current_saved',
        'unavailable',
      }.contains(display['item_level_source']),
    );
    value = raw as String?;
    source = display['item_level_source'] as String;
    final stamp = display['item_level_fetched_at'];
    fetchedAt = stamp == null ? null : roleUtc(stamp);
    roleCheck(
      source == 'unavailable'
          ? value == null && fetchedAt == null
          : value != null,
    );
  }
  late final String? value;
  late final String source;
  late final DateTime? fetchedAt;

  String get label => switch (source) {
    'unavailable' => '아이템 레벨 조회 불가',
    'current_saved' => '아이템 레벨 $value · 현재 저장 정보',
    _ => '아이템 레벨 $value',
  };
}

class ApplicationDisplayItem {
  final String? applicationMemo;
  ApplicationDisplayItem(
    Map<String, dynamic> raw,
    String room,
    String target,
    int generation, {
    this.applicationMemo,
  }) : wire = _snapshot(raw) {
    if (applicationMemo != null) ApplicationMemo(applicationMemo!);
    roleShape(
      wire,
      'application_id room_id revision state created_at expires_at ended_at character_id selected_role display admission_origin target_cycle_key target_generation comparison analysis display_reason',
    );
    final base = {...wire}
      ..remove('comparison')
      ..remove('analysis')
      ..remove('display_reason');
    row = CycleOwnRow(base, target, true);
    roleCheck(
      row.roomId == room &&
          wire['target_cycle_key'] == target &&
          _version(wire['target_generation']) == generation,
    );
    _version(wire['revision']);
    roleUtc(wire['created_at']);
    for (final key in ['expires_at', 'ended_at']) {
      if (wire[key] != null) roleUtc(wire[key]);
    }
    final display = roleMap(wire['display']);
    roleCheck(display.values.every((v) => v == null || v is String));
    itemLevel = ApplicationItemLevel.fromDisplay(display);
    final origin = roleMap(wire['admission_origin']);
    roleShape(origin, 'scope group_id');
    roleCheck({'public', 'group'}.contains(origin['scope']));
    if (origin['group_id'] != null) roleId(origin['group_id']);
    final role = wire['selected_role'];
    roleCheck(role == 'dealer' || role == 'support');
    comparison = wire['comparison'] == null
        ? null
        : AdmissionPowerComparison(
            roleMap(wire['comparison']),
            role as String,
          ).wire;
    analysis = wire['analysis'] == null
        ? null
        : ApplicationAnalysis(roleMap(wire['analysis']));
    final reason = wire['display_reason'];
    roleCheck(
      {
        null,
        'APPLICATION_CONTEXT_CHANGED',
        'CHARACTER_DATA_UNAVAILABLE',
      }.contains(reason),
    );
    roleCheck(
      reason == null
          ? comparison != null
          : comparison == null && analysis == null,
    );
    roleCheck(itemLevel.source != 'current_saved' || reason == null);
    if (comparison case final p?) {
      roleCheck(
        raidList(p['current_issues']).length <= 20 &&
            raidList(p['success_issues']).length <= 20,
      );
      final a = analysis;
      roleCheck(
        a == null
            ? raidList(p['current_issues']).isEmpty
            : a.wire['version'] == p['current_summary_version'] &&
                  scheduleStable(a.wire['issues']) ==
                      scheduleStable(p['current_issues']),
      );
      roleCheck(
        p['actual'] == null
            ? p['success_summary_version'] == null &&
                  p['observed_at'] == null &&
                  p['success_saved_at'] == null &&
                  raidList(p['success_issues']).isEmpty
            : p['success_summary_version'] != null &&
                  p['observed_at'] != null &&
                  p['success_saved_at'] != null,
      );
    }
  }
  final Map<String, dynamic> wire;
  late final CycleOwnRow row;
  late final Map<String, dynamic>? comparison;
  late final ApplicationAnalysis? analysis;
  late final ApplicationItemLevel itemLevel;
  String get status {
    if (wire['display_reason'] == 'APPLICATION_CONTEXT_CHANGED') {
      return '신청 당시 소유 정보가 변경되어 확인이 필요합니다.';
    }
    if (wire['display_reason'] != null) return '캐릭터 정보를 확인할 수 없습니다.';
    final a = analysis;
    if (a == null) return '분석 정보 없음';
    final label = switch (a.wire['integrity_status']) {
      'clean' => '세팅 이상 없음',
      'review' => '분석 확인 필요',
      'error' => '분석 오류',
      _ => '분석 정보 확인 불가',
    };
    final errors = a.issues.where((v) => v.severity == 'error').length;
    final warnings = a.issues.where((v) => v.severity == 'warning').length;
    final codes = [
      if (errors > 0) '오류 $errors건',
      if (warnings > 0) '경고 $warnings건',
    ].join(' · ');
    return '$label${codes.isEmpty ? '' : ' · $codes'}${comparison?['actual'] != null && a.wire['version'] != comparison?['success_summary_version'] ? '\n전투력은 마지막 성공 정보입니다.' : ''}';
  }

  bool get warning =>
      wire['display_reason'] != null ||
      (analysis != null && analysis!.wire['integrity_status'] != 'clean');
}

class ApplicationDisplayPage {
  ApplicationDisplayPage(
    Map<String, dynamic> raw,
    String room,
    String target, {
    Map<String, String?> memos = const {},
  }) : wire = _snapshot(raw) {
    roleShape(wire, 'scope data');
    scope = roleMap(wire['scope']);
    CycleReadScope(scope, target);
    roleId(scope['room_cycle_id']);
    _version(scope['target_revision']);
    final generation = _version(scope['target_generation']);
    final data = roleMap(wire['data']);
    roleShape(data, 'items applications_revision next_cursor evaluated_at');
    revision = _version(data['applications_revision']);
    roleCheck(roleUtc(data['evaluated_at']) == roleUtc(scope['server_now']));
    items = List.unmodifiable(
      raidList(data['items']).map(
        (v) => ApplicationDisplayItem(
          roleMap(v),
          room,
          target,
          generation,
          applicationMemo: memos[v['application_id']],
        ),
      ),
    );
    roleCheck(
      items.length <= 20 &&
          items.every((v) => v.row.state == 'pending') &&
          items.map((v) => v.row.id).toSet().length == items.length,
    );
    cursor = data['next_cursor'] as String?;
    roleCheck(
      cursor == null ||
          cursor!.isNotEmpty && cursor!.length <= 2048 && items.isNotEmpty,
    );
  }
  final Map<String, dynamic> wire;
  late final Map<String, dynamic> scope;
  late final int revision;
  late final List<ApplicationDisplayItem> items;
  late final String? cursor;
  String get identity => scheduleStable({
    'scope': {...scope}
      ..remove('server_now')
      ..remove('target_revision'),
    'revision': revision,
  });
}

class OwnApplicationStatus {
  OwnApplicationStatus(Map<String, dynamic> raw, DateTime serverNow)
    : wire = _snapshot(raw) {
    roleShape(wire, 'application_id revision state expires_at');
    roleId(wire['application_id']);
    _version(wire['revision']);
    roleCheck(
      {
        'pending',
        'accepted',
        'rejected',
        'withdrawn',
        'expired',
        'cancelled',
      }.contains(wire['state']),
    );
    final expires = roleUtc(wire['expires_at']);
    roleCheck(wire['state'] != 'pending' || expires.isAfter(serverNow));
    roleCheck(wire['state'] != 'expired' || !expires.isAfter(serverNow));
  }
  final Map<String, dynamic> wire;
  bool get pending => wire['state'] == 'pending';
}

class ApplicationDisplayDetail {
  ApplicationDisplayDetail({required this.detail, required this.application});
  factory ApplicationDisplayDetail.fromJson(
    Map<String, dynamic> raw,
    String room,
    String target,
  ) {
    final wire = _snapshot(raw);
    roleShape(wire, 'scope data');
    final scope = roleMap(wire['scope']), data = roleMap(wire['data']);
    roleCheck(data.containsKey('my_application'));
    final app = data['my_application'] == null
        ? null
        : OwnApplicationStatus(
            roleMap(data['my_application']),
            roleUtc(scope['server_now']),
          );
    final detail = BackendRecruitmentRepository.parseCycleDetail(
      {
        'scope': scope,
        'data': {...data}..remove('my_application'),
      },
      room,
      target,
    );
    return ApplicationDisplayDetail(detail: detail, application: app);
  }
  final BackendRecruitmentDetail detail;
  final OwnApplicationStatus? application;
}

abstract interface class ApplicationDisplayGateway {
  Future<ApplicationDisplayDetail> applicationDisplayDetail(
    String room,
    String target, {
    bool includeCoordinationWait = false,
  });
}

abstract interface class ApplicationDisplayListGateway {
  Future<ApplicationDisplayPage> applicationDisplayPage(
    String room,
    String target, {
    String? cursor,
  });
}

class ApplicationDisplayReader
    implements ApplicationDisplayGateway, ApplicationDisplayListGateway {
  ApplicationDisplayReader(
    this.api, {
    this.contractMode = RecruitmentContractMode.legacy,
  });
  final RecruitmentContractMode contractMode;
  final BackendRegistrationApi api;
  Future<T> _read<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const AccountReadException('INVALID_RESPONSE');
    } on TypeError {
      throw const AccountReadException('INVALID_RESPONSE');
    }
  }

  @override
  Future<ApplicationDisplayDetail> applicationDisplayDetail(
    String room,
    String target, {
    bool includeCoordinationWait = false,
  }) => _read(() async {
    roleId(room);
    raidCycleKey(target);
    final result = await readRecruitment(
      api: api,
      mode: contractMode,
      path: '/v2/raid-rooms/$room/detail',
      query: {
        'target_cycle_key': target,
        'reader_profile': applicationDisplayProfile,
        if (includeCoordinationWait &&
            contractMode == RecruitmentContractMode.betaWire2)
          'include_coordination_wait': 'true',
      },
      parse: (raw) => ApplicationDisplayDetail.fromJson(raw, room, target),
    );
    final schedule = result.metadata?['beta_schedule'];
    if (includeCoordinationWait &&
        contractMode == RecruitmentContractMode.betaWire2 &&
        schedule != null) {
      roleCheck(schedule is Map && schedule.containsKey('coordination_wait'));
    }
    result.value.detail.betaData = betaDisplayData(result.metadata);
    return result.value;
  });
  @override
  Future<ApplicationDisplayPage> applicationDisplayPage(
    String room,
    String target, {
    String? cursor,
  }) => _read(() async {
    roleId(room);
    raidCycleKey(target);
    final result = await readRecruitment(
      api: api,
      mode: contractMode,
      path: '/v2/raid-rooms/$room/applications',
      query: {
        'target_cycle_key': target,
        'reader_profile': applicationDisplayProfile,
        'state': 'pending',
        'limit': 20,
        'cursor': ?cursor,
      },
      parse: (raw) => raw,
    );
    return ApplicationDisplayPage(
      result.value,
      room,
      target,
      memos: {
        for (final row in result.metadata?['items'] as List? ?? const [])
          row['application_id'] as String: row['application_memo'] as String?,
      },
    );
  });
}
