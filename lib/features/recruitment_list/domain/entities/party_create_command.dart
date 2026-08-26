import '../policies/approval_policy.dart';
import '../policies/party_composition_policy.dart';
import 'party_recruitment.dart';
import 'recruitment_aggregate.dart';

class PartyCreateCommand {
  const PartyCreateCommand({
    required this.recruitmentId,
    required this.title,
    required this.metadata,
    required this.leaderCharacterId,
    required this.leaderCharacterName,
    required this.leaderClassName,
    required this.leaderRole,
    required this.leaderItemLevel,
    required this.approvalPolicy,
    required this.compositionRules,
    required this.cycleKey,
    this.leaderCombatPower,
  });

  final String recruitmentId;
  final String title;
  final RecruitmentMetadata metadata;
  final String leaderCharacterId;
  final String leaderCharacterName;
  final String leaderClassName;
  final PartyRole leaderRole;
  final double leaderItemLevel;
  final double? leaderCombatPower;
  final ApprovalPolicy approvalPolicy;
  final RecruitmentPartyRules compositionRules;
  final String cycleKey;
}

enum PartyCreateFailure {
  unauthenticated,
  playerBindingMissing,
  ownershipLost,
  invalidCharacter,
  weeklyRaidCompleted,
  participationConflict,
  idConflict,
  permissionDenied,
  temporarilyUnavailable,
  invalidRequest,
  unknown,
}

class PartyCreateResult {
  const PartyCreateResult.success(this.recruitmentId) : failure = null;

  const PartyCreateResult.failure(this.failure) : recruitmentId = null;

  final String? recruitmentId;
  final PartyCreateFailure? failure;

  bool get isSuccess => failure == null;
}
