import '../../domain/entities/party_read_models.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../dto/party_read_document_dto.dart';

class PartyReadContractException implements Exception {
  const PartyReadContractException(this.message);

  final String message;

  @override
  String toString() => 'PartyReadContractException: $message';
}

class PartyReadDocumentMapper {
  const PartyReadDocumentMapper({required this.toDateTime});

  final DateTime Function(Object? value) toDateTime;

  PublicRecruitmentSummary toPublicRecruitment(
    PartyReadDocumentDto document,
  ) {
    final data = document.data;
    _requireSchema(data);
    return PublicRecruitmentSummary(
      id: document.id,
      title: _string(data, 'title'),
      leaderUserId: _string(data, 'leaderPlayerId'),
      metadata: _metadata(data),
      memberCount: _integer(data, 'memberCount'),
      maxMemberCount: _integer(data, 'maxMemberCount'),
      isRecruiting:
          _string(data, 'status') == 'active' &&
          _boolean(data, 'manualRecruitmentEnabled') &&
          _boolean(data, 'hasAvailableSlot'),
      revision: _integer(data, 'revision'),
      updatedAt: _date(data, 'updatedAt'),
      currentCycleKey: _string(data, 'currentCycleKey'),
    );
  }

  ActiveRaidSummary toActiveRaid(
    PartyReadDocumentDto document, {
    required String currentPlayerId,
  }) {
    final data = document.data;
    _requireSchema(data);
    final leaderPlayerId = _string(data, 'leaderPlayerId');
    return ActiveRaidSummary(
      id: document.id,
      title: _string(data, 'title'),
      leaderPlayerId: leaderPlayerId,
      metadata: _metadata(data),
      currentCycleKey: _string(data, 'currentCycleKey'),
      memberCount: _integer(data, 'memberCount'),
      maxMemberCount: _integer(data, 'maxMemberCount'),
      revision: _integer(data, 'revision'),
      updatedAt: _date(data, 'updatedAt'),
      raidStartAt: _nullableDate(data, 'raidStartAt'),
      isOwnedByCurrentPlayer: leaderPlayerId == currentPlayerId,
    );
  }

  PartyApplicationSummary toApplication(PartyReadDocumentDto document) {
    final data = document.data;
    _requireSchema(data);
    return PartyApplicationSummary(
      recruitmentId: _string(data, 'recruitmentId'),
      applicantPlayerId: _string(data, 'applicantPlayerId'),
      cycleKey: _string(data, 'cycleKey'),
      characterId: _string(data, 'characterId'),
      characterName: _string(data, 'characterNameSnapshot'),
      className: _string(data, 'classNameSnapshot'),
      requestedRole: _enumValue(
        PartyRole.values,
        _string(data, 'requestedRole'),
        'requestedRole',
      ),
      status: _enumValue(
        RecruitmentApplicationStatus.values,
        _string(data, 'status'),
        'status',
      ),
      revision: _integer(data, 'revision'),
      resolutionReason: _nullableString(data, 'resolutionReason'),
      createdAt: _date(data, 'createdAt'),
      decidedAt: _nullableDate(data, 'decidedAt'),
      updatedAt: _date(data, 'updatedAt'),
    );
  }

  RecruitmentMetadata _metadata(Map<String, Object?> data) =>
      RecruitmentMetadata(
        catalogVersion: _string(data, 'raidCatalogVersion'),
        raidId: _string(data, 'raidId'),
        difficultyId: _string(data, 'difficultyId'),
        raidName: _string(data, 'raidNameSnapshot'),
        difficultyName: _string(data, 'difficultyNameSnapshot'),
        difficultyAlias: _string(data, 'difficultyAliasSnapshot'),
        gateCount: _integer(data, 'gateCount'),
        minItemLevel: _integer(data, 'minItemLevel'),
        minCombatPower: _nullableInteger(data, 'minCombatPower'),
        experienceLevel: _nullableEnumValue(
          ExperienceLevel.values,
          _nullableString(data, 'experienceLevel'),
          'experienceLevel',
        ),
        maxPlayHours: _nullableInteger(data, 'maxPlayHours'),
        raidStartAt: _nullableDate(data, 'raidStartAt'),
      );

  void _requireSchema(Map<String, Object?> data) {
    if (_integer(data, 'schemaVersion') != 1) {
      throw const PartyReadContractException('Unsupported schemaVersion.');
    }
  }

  String _string(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is String && value.trim().isNotEmpty) return value;
    throw PartyReadContractException('$field must be a non-empty string.');
  }

  String? _nullableString(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) return value;
    throw PartyReadContractException('$field must be null or a string.');
  }

  int _integer(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is int) return value;
    throw PartyReadContractException('$field must be an integer.');
  }

  int? _nullableInteger(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value == null) return null;
    if (value is int) return value;
    throw PartyReadContractException('$field must be null or an integer.');
  }

  bool _boolean(Map<String, Object?> data, String field) {
    final value = data[field];
    if (value is bool) return value;
    throw PartyReadContractException('$field must be a boolean.');
  }

  DateTime _date(Map<String, Object?> data, String field) {
    try {
      return toDateTime(data[field]).toUtc();
    } catch (_) {
      throw PartyReadContractException('$field must be a timestamp.');
    }
  }

  DateTime? _nullableDate(Map<String, Object?> data, String field) {
    if (data[field] == null) return null;
    return _date(data, field);
  }

  T _enumValue<T extends Enum>(
    List<T> values,
    String name,
    String field,
  ) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw PartyReadContractException('$field has an unknown value: $name.');
  }

  T? _nullableEnumValue<T extends Enum>(
    List<T> values,
    String? name,
    String field,
  ) => name == null ? null : _enumValue(values, name, field);
}
