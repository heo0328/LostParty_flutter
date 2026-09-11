/// Character 최소 표시 문서에 저장하는 Build 무결성 요약.
///
/// schemaVersion 1. 알 수 없는 값·깨진 맵은 [tryFromFields]가 null을 반환한다.
enum BuildIntegrityStatus {
  clean,
  review,
  error,
  unavailable,
}

/// 고정 우선순위 순서의 이슈 코드. 직렬화 문자열과 동일하다.
enum BuildIntegrityIssueCode {
  foreignClassGem,
  sameClassGemUnverified,
  gemUnavailable,
  arkGridMinimum,
  arkGridCondition,
}

enum BuildIntegrityRole {
  dealer,
  support,
}

class BuildIntegritySnapshot {
  static const int schemaVersion = 1;

  const BuildIntegritySnapshot({
    required this.status,
    required this.issueCodes,
    required this.role,
    required this.checkedAt,
    required this.catalogVersion,
  });

  final BuildIntegrityStatus status;
  final List<BuildIntegrityIssueCode> issueCodes;
  final BuildIntegrityRole role;
  final DateTime checkedAt;
  final String? catalogVersion;

  bool get isClean => status == BuildIntegrityStatus.clean;

  /// 활동 Character 목록용 표시 라벨. 우선순위는 상태·코드 순이다.
  List<String> get displayLabels {
    switch (status) {
      case BuildIntegrityStatus.clean:
        return const <String>[];
      case BuildIntegrityStatus.unavailable:
        return const <String>['확인 불가'];
      case BuildIntegrityStatus.review:
        if (issueCodes.contains(BuildIntegrityIssueCode.sameClassGemUnverified)) {
          return const <String>['보석 확인 필요'];
        }
        if (issueCodes.contains(BuildIntegrityIssueCode.gemUnavailable)) {
          return const <String>['보석 정보 없음'];
        }
        return const <String>['확인 필요'];
      case BuildIntegrityStatus.error:
        final labels = <String>[];
        final hasGemError = issueCodes.any(
          (code) =>
              code == BuildIntegrityIssueCode.foreignClassGem ||
              code == BuildIntegrityIssueCode.sameClassGemUnverified ||
              code == BuildIntegrityIssueCode.gemUnavailable,
        );
        final hasArkGridError = issueCodes.any(
          (code) =>
              code == BuildIntegrityIssueCode.arkGridMinimum ||
              code == BuildIntegrityIssueCode.arkGridCondition,
        );
        if (hasGemError) {
          labels.add('보석');
        }
        if (hasArkGridError) {
          labels.add('아크그리드');
        }
        return labels.isEmpty ? const <String>['오류'] : labels;
    }
  }

  Map<String, Object?> toFields() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'status': status.name,
      'issueCodes': issueCodes.map((code) => code.name).toList(growable: false),
      'role': role.name,
      'checkedAt': checkedAt.toUtc(),
      'catalogVersion': catalogVersion,
    };
  }

  static BuildIntegritySnapshot? tryFromFields(
    Object? raw, {
    DateTime? Function(Object? value)? parseDate,
  }) {
    if (raw is! Map) {
      return null;
    }

    try {
      final map = Map<Object?, Object?>.from(raw);
      final schema = map['schemaVersion'];
      if (schema is! int || schema != schemaVersion) {
        return null;
      }

      final status = _parseStatus(map['status']);
      final role = _parseRole(map['role']);
      final checkedAt = parseDate != null
          ? parseDate(map['checkedAt'])
          : _parseCheckedAt(map['checkedAt']);
      if (status == null || role == null || checkedAt == null) {
        return null;
      }

      final issueCodes = _parseIssueCodes(map['issueCodes']);
      if (issueCodes == null) {
        return null;
      }

      final catalogRaw = map['catalogVersion'];
      final String? catalogVersion;
      if (catalogRaw == null) {
        catalogVersion = null;
      } else if (catalogRaw is String) {
        catalogVersion = catalogRaw;
      } else {
        return null;
      }

      return BuildIntegritySnapshot(
        status: status,
        issueCodes: issueCodes,
        role: role,
        checkedAt: checkedAt,
        catalogVersion: catalogVersion,
      );
    } catch (_) {
      return null;
    }
  }

  bool hasSameValues(BuildIntegritySnapshot other) {
    if (status != other.status ||
        role != other.role ||
        catalogVersion != other.catalogVersion ||
        !checkedAt.isAtSameMomentAs(other.checkedAt) ||
        issueCodes.length != other.issueCodes.length) {
      return false;
    }
    for (var i = 0; i < issueCodes.length; i++) {
      if (issueCodes[i] != other.issueCodes[i]) {
        return false;
      }
    }
    return true;
  }

  static BuildIntegrityStatus? _parseStatus(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in BuildIntegrityStatus.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  static BuildIntegrityRole? _parseRole(Object? raw) {
    if (raw is! String) {
      return null;
    }
    for (final value in BuildIntegrityRole.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }

  static DateTime? _parseCheckedAt(Object? raw) {
    if (raw is DateTime) {
      return raw.toUtc();
    }
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  static List<BuildIntegrityIssueCode>? _parseIssueCodes(Object? raw) {
    if (raw is! List) {
      return null;
    }
    final codes = <BuildIntegrityIssueCode>[];
    final seen = <BuildIntegrityIssueCode>{};
    for (final entry in raw) {
      if (entry is! String) {
        return null;
      }
      final code = _parseIssueCode(entry);
      if (code == null) {
        return null;
      }
      if (seen.add(code)) {
        codes.add(code);
      }
    }
    return List<BuildIntegrityIssueCode>.unmodifiable(codes);
  }

  static BuildIntegrityIssueCode? _parseIssueCode(String raw) {
    for (final value in BuildIntegrityIssueCode.values) {
      if (value.name == raw) {
        return value;
      }
    }
    return null;
  }
}
