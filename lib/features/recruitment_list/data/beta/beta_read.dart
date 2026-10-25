import '../../../account/domain/server_registration_api.dart';
import '../../../account/domain/role_summary.dart';
import 'beta_contract.dart';

class BetaDecoded<T> {
  const BetaDecoded(this.value, this.metadata);
  final T value;
  final Map<String, dynamic>? metadata;
}

Future<BetaDecoded<T>> readRecruitment<T>({
  required BackendRegistrationApi api,
  required RecruitmentContractMode mode,
  required String path,
  required T Function(Map<String, dynamic>) parse,
  Map<String, dynamic> query = const {},
  String method = 'GET',
  Map<String, dynamic>? body,
}) async {
  final contract = BetaContract(mode: mode);
  final q = contract.query(method, path, query);
  if (mode == RecruitmentContractMode.betaWire2) {
    contract.validateRequest(method, path, q, body);
  }
  final raw = (await api.request(
    path,
    method: method,
    query: q.isEmpty ? null : q,
    body: body,
  ))!;
  if (mode == RecruitmentContractMode.legacy) {
    return BetaDecoded(parse(raw), null);
  }
  final result = BetaResponse.parse(
    method: method,
    path: path,
    status: 200,
    json: raw,
    parseLegacy: parse,
  );
  return BetaDecoded(result.value, roleMap(result.metadata['data']));
}

Map<String, dynamic>? betaDisplayData(Map<String, dynamic>? raw) => raw == null
    ? null
    : betaFreeze({
            'beta_schedule': raw['beta_schedule'],
            if (raw.containsKey('recruitment_identity'))
              'recruitment_identity': raw['recruitment_identity'],
          })
          as Map<String, dynamic>;

String betaScheduleLabel(Map<String, dynamic> data) {
  final s = data['beta_schedule'];
  if (s == null) return '일정 정보 없음';
  return switch (s['coordination_state']) {
    'base_committed' => '직접 지정',
    'coordinating' => '더 이른 시간 조율 중',
    'early_confirmed' => '자동 조율로 확정',
    'base_confirmed' => '기본 시간으로 확정',
    'proposal_confirmed' => '제안 시간으로 확정',
    'deadline_pending' => '출발 시간 확인 중',
    'needs_review' => '일정 확인 필요',
    'ended' => '종료',
    _ => throw const FormatException('Invalid schedule state'),
  };
}

DateTime? betaEffectiveStart(Map<String, dynamic>? data) =>
    data?['beta_schedule'] == null
    ? null
    : roleUtc(data!['beta_schedule']['effective_starts_at']);

String betaDepartureText(Map<String, dynamic> data) {
  final instant = betaEffectiveStart(data);
  final label = betaScheduleLabel(data);
  return instant == null
      ? label
      : '${instant.add(const Duration(hours: 9)).toIso8601String().substring(5, 16).replaceAll('T', ' ')} · $label';
}
