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
  gemSlotCount,
  foreignClassGem,
  unmatchedSkillGem,
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
  static const int schemaVersion = 2;

  const BuildIntegritySnapshot({
    required this.status,
    required this.issueCodes,
    required this.role,
    required this.checkedAt,
    required this.catalogVersion,
    this.storedSchemaVersion = schemaVersion,
  });

  final BuildIntegrityStatus status;
  final List<BuildIntegrityIssueCode> issueCodes;
  final BuildIntegrityRole role;
  final DateTime checkedAt;
  final String? catalogVersion;
  /// 읽은 과거 Snapshot 의미를 보존한다. 새 Snapshot은 항상 v2다.
  final int storedSchemaVersion;

  bool get isClean => status == BuildIntegrityStatus.clean;

  List<BuildIntegrityDisplayItem> get displayItems {
    switch (status) {
      case BuildIntegrityStatus.clean:
        return const <BuildIntegrityDisplayItem>[];
      case BuildIntegrityStatus.unavailable:
        return const [BuildIntegrityDisplayItem('확인 불가', isError: false)];
      case BuildIntegrityStatus.review:
        if (issueCodes.contains(BuildIntegrityIssueCode.sameClassGemUnverified)) {
          return const [BuildIntegrityDisplayItem('보석 확인 필요', isError: false)];
        }
        if (issueCodes.contains(BuildIntegrityIssueCode.gemUnavailable)) {
          return const [BuildIntegrityDisplayItem('보석 정보 확인 불가', isError: false)];
        }
        return const [BuildIntegrityDisplayItem('확인 필요', isError: false)];
      case BuildIntegrityStatus.error:
        final items = <BuildIntegrityDisplayItem>[];
        final hasGemError = issueCodes.any(
          (code) =>
              code == BuildIntegrityIssueCode.gemSlotCount ||
              code == BuildIntegrityIssueCode.foreignClassGem ||
              code == BuildIntegrityIssueCode.unmatchedSkillGem ||
              code == BuildIntegrityIssueCode.sameClassGemUnverified ||
              code == BuildIntegrityIssueCode.gemUnavailable,
        );
        final hasArkGridError = issueCodes.any(
          (code) =>
              code == BuildIntegrityIssueCode.arkGridMinimum ||
              code == BuildIntegrityIssueCode.arkGridCondition,
        );
        if (hasGemError) {
          items.add(const BuildIntegrityDisplayItem('보석 오류', isError: true));
        }
        if (hasArkGridError) {
          items.add(const BuildIntegrityDisplayItem('아크그리드 오류', isError: true));
        }
        if (issueCodes.contains(BuildIntegrityIssueCode.gemUnavailable)) {
          items.add(const BuildIntegrityDisplayItem('보석 정보 확인 불가', isError: false));
        }
        return items.isEmpty
            ? const [BuildIntegrityDisplayItem('오류', isError: true)]
            : items;
    }
  }

  List<String> get displayLabels =>
      displayItems.map((item) => item.label).toList(growable: false);

  Map<String, Object?> toFields() {
    return <String, Object?>{
      'schemaVersion': storedSchemaVersion,
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
      if (schema is! int || (schema != 1 && schema != schemaVersion)) {
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
      if (schema == 1 &&
          issueCodes.any(
            (code) =>
                code == BuildIntegrityIssueCode.gemSlotCount ||
                code == BuildIntegrityIssueCode.unmatchedSkillGem,
          )) {
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
        storedSchemaVersion: schema,
      );
    } catch (_) {
      return null;
    }
  }

  bool hasSameValues(BuildIntegritySnapshot other) {
    if (storedSchemaVersion != other.storedSchemaVersion ||
        status != other.status ||
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

class BuildIntegrityDisplayItem {
  const BuildIntegrityDisplayItem(this.label, {required this.isError});

  final String label;
  final bool isError;
}
