import '../../domain/entities/party_application_command.dart';

class PartyApplicationWritePlan {
  const PartyApplicationWritePlan._();

  static Map<String, Object?> create({
    required PartyApplyCommand command,
    required String playerId,
    required String characterName,
    required String className,
    required double itemLevel,
    required Object serverTimestamp,
  }) => {
    'schemaVersion': 1,
    'recruitmentId': command.recruitmentId,
    'applicantPlayerId': playerId,
    'cycleKey': command.cycleKey,
    'characterId': command.characterId,
    'characterNameSnapshot': characterName,
    'classNameSnapshot': className,
    'requestedRole': command.requestedRole.name,
    'submittedBuildSnapshot': {
      'itemLevel': itemLevel,
      'combatPower': command.combatPower,
      ...?command.gemValidation?.toFields(),
    },
    'status': 'pending',
    'resolutionReason': null,
    'approvalCount': 0,
    'rejectionCount': 0,
    'revision': 1,
    'createdAt': serverTimestamp,
    'decidedAt': null,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> reapply({
    required PartyApplyCommand command,
    required String characterName,
    required String className,
    required double itemLevel,
    required int nextRevision,
    required Object serverTimestamp,
  }) => {
    'cycleKey': command.cycleKey,
    'characterId': command.characterId,
    'characterNameSnapshot': characterName,
    'classNameSnapshot': className,
    'requestedRole': command.requestedRole.name,
    'submittedBuildSnapshot': {
      'itemLevel': itemLevel,
      'combatPower': command.combatPower,
      ...?command.gemValidation?.toFields(),
    },
    'status': 'pending',
    'resolutionReason': null,
    'approvalCount': 0,
    'revision': nextRevision,
    'decidedAt': null,
    'updatedAt': serverTimestamp,
  };

  static Map<String, Object?> withdraw({
    required int nextRevision,
    required Object serverTimestamp,
  }) => {
    'status': 'withdrawn',
    'resolutionReason': 'withdrawnByApplicant',
    'revision': nextRevision,
    'decidedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };
}
