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

  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  );

  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  });
}
