class ServerPowerObservation {
  ServerPowerObservation.fromJson(Map<String, dynamic> json) {
    serverName = _text(json['server_name']);
    characterName = _text(json['character_name']);
    final raw = json['combat_power'];
    if (raw != null &&
        (raw is! String ||
            double.tryParse(raw) == null ||
            !double.parse(raw).isFinite ||
            double.parse(raw) < 0)) {
      throw const FormatException('Invalid power.');
    }
    combatPower = raw as String?;
    fetchedAt = _time(json['power_fetched_at']);
    checkedAt = _time(json['power_checked_at']);
    if (json['power_stale'] is! bool) {
      throw const FormatException('Invalid stale.');
    }
    stale = json['power_stale'] as bool;
    status = _text(json['power_status']);
    if (!['unknown', 'available', 'unavailable', 'failed'].contains(status)) {
      throw const FormatException('Invalid power status.');
    }
    reason = _reason(json['power_reason']);
  }
  late final String serverName, characterName, status;
  late final String? combatPower, reason;
  late final DateTime? fetchedAt, checkedAt;
  late final bool stale;
  (String, String) get identity => (serverName, characterName);
  double? get value => combatPower == null ? null : double.parse(combatPower!);
  String get displayState => switch (status) {
    'failed' => combatPower == null ? '조회 실패' : '조회 실패 · 이전 값',
    'unavailable' => '서버 전투력 미제공',
    'unknown' => '서버 전투력 미조회',
    _ => stale ? '최근 확인 필요' : '서버 확인',
  };
}

class ServerPowerResult {
  ServerPowerResult.fromJson(Map<String, dynamic> json) {
    const keys = {
      'server_name',
      'character_name',
      'combat_power',
      'power_fetched_at',
      'power_checked_at',
      'power_stale',
      'power_status',
      'power_reason',
      'status',
      'reason',
      'retry_after_seconds',
      'retry_at',
    };
    if (json.length != keys.length || !keys.every(json.containsKey)) {
      throw const FormatException('Invalid power result.');
    }
    power = ServerPowerObservation.fromJson(json);
    status = _text(json['status']);
    if (![
      'updated',
      'cached',
      'unavailable',
      'failed',
      'skipped',
      'deferred',
    ].contains(status)) {
      throw const FormatException('Invalid result status.');
    }
    reason = _reason(json['reason']);
    final seconds = json['retry_after_seconds'];
    retryAt = _time(json['retry_at']);
    if ((seconds == null) != (retryAt == null) ||
        (seconds != null && (seconds is! int || seconds < 1)) ||
        ({'RATE_LIMITED', 'UPSTREAM_RATE_LIMITED'}.contains(reason) &&
            retryAt == null) ||
        (!{'RATE_LIMITED', 'UPSTREAM_RATE_LIMITED'}.contains(reason) &&
            retryAt != null)) {
      throw const FormatException('Invalid retry metadata');
    }
    retryAfter = seconds == null ? null : Duration(seconds: seconds as int);
  }
  late final ServerPowerObservation power;
  late final String status;
  late final Duration? retryAfter;
  late final DateTime? retryAt;
  late final String? reason;

  static List<ServerPowerResult> decode(
    Map<String, dynamic> json,
    List<Map<String, String>> targets,
  ) {
    if (json.length != 1 || json['items'] is! List) {
      throw const FormatException('Invalid power response.');
    }
    final result = (json['items'] as List)
        .map((item) => ServerPowerResult.fromJson(item as Map<String, dynamic>))
        .toList();
    final ids = targets
        .map((t) => (t['server_name']!, t['character_name']!))
        .toSet()
        .toList();
    if (result.length != ids.length || result.length > 20) {
      throw const FormatException('Invalid power targets.');
    }
    for (var i = 0; i < ids.length; i++) {
      if (result[i].power.identity != ids[i]) {
        throw const FormatException('Unexpected power target.');
      }
    }
    return List.unmodifiable(result);
  }
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty || value.runes.length > 64) {
    throw const FormatException('Invalid power text.');
  }
  return value;
}

String? _reason(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'^[A-Z][A-Z0-9_]{0,79}$').hasMatch(value)) {
    throw const FormatException('Invalid power reason.');
  }
  return value;
}

DateTime? _time(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw const FormatException('Invalid power time.');
  }
  return DateTime.parse(value).toUtc();
}
