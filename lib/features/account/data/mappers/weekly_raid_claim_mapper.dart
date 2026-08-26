import '../../domain/entities/weekly_raid_claim.dart';
import '../dtos/weekly_raid_claim_dto.dart';
import 'weekly_raid_claim_document_id.dart';

class WeeklyRaidClaimMapper {
  const WeeklyRaidClaimMapper({required this.toDateTime});

  final DateTime Function(Object? value) toDateTime;

  WeeklyRaidClaim map(WeeklyRaidClaimDto dto, {required String documentId}) {
    if (dto.schemaVersion != 1 ||
        documentId.trim().isEmpty ||
        dto.playerId.trim().isEmpty ||
        dto.characterId.trim().isEmpty ||
        dto.raidId.trim().isEmpty ||
        dto.cycleKey.trim().isEmpty ||
        dto.difficultyId.trim().isEmpty) {
      throw const FormatException('Invalid weekly raid claim.');
    }
    try {
      if (documentId !=
          WeeklyRaidClaimDocumentId.create(
            cycleKey: dto.cycleKey,
            characterId: dto.characterId,
            raidId: dto.raidId,
          )) {
        throw const FormatException('Weekly raid claim path mismatch.');
      }
    } on ArgumentError {
      throw const FormatException('Invalid weekly raid claim identity.');
    }
    final source = switch (dto.source) {
      'manual' => WeeklyRaidClaimSource.manual,
      'partyMember' => WeeklyRaidClaimSource.partyMember,
      'partyOwner' => WeeklyRaidClaimSource.partyOwner,
      _ => throw const FormatException('Invalid weekly raid claim source.'),
    };
    return WeeklyRaidClaim(
      id: documentId,
      playerId: dto.playerId,
      characterId: dto.characterId,
      raidId: dto.raidId,
      cycleKey: dto.cycleKey,
      difficultyId: dto.difficultyId,
      source: source,
      sourceRecruitmentId: dto.sourceRecruitmentId,
      sourceCompletionRevision: dto.sourceCompletionRevision,
      completedAt: toDateTime(dto.completedAt).toUtc(),
      updatedAt: toDateTime(dto.updatedAt).toUtc(),
      cycleStartedAt: toDateTime(dto.cycleStartedAt).toUtc(),
      cycleEndsAt: toDateTime(dto.cycleEndsAt).toUtc(),
    );
  }
}
