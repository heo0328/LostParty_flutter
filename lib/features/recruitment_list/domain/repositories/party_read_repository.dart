import '../entities/party_read_models.dart';
import '../entities/recruitment_aggregate.dart';

enum PartyReadFailureType { permissionDenied, unavailable, contract, unknown }

class PartyReadException implements Exception {
  const PartyReadException(this.type);

  final PartyReadFailureType type;
}

abstract class PartyReadRepository {
  Stream<PartyReadSnapshot<PublicRecruitmentSummary>> watchPublicRecruitments({
    required String cycleKey,
  });

  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  });

  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  });

  Stream<PublicRecruitmentSummary?> watchRecruitment(String recruitmentId);
}
