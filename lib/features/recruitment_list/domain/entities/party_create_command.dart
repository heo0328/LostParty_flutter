import '../policies/approval_policy.dart';
import '../policies/party_composition_policy.dart';
import '../../../../shared/character_build/build_integrity_snapshot.dart';
import '../../../../shared/character_build/party_gem_validation_snapshot.dart';
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
    this.leaderGemValidation,
    this.leaderBuildIntegrity,
    this.groupId,
    this.visibility = RecruitmentVisibility.public,
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
  final PartyGemValidationSnapshot? leaderGemValidation;
  final BuildIntegritySnapshot? leaderBuildIntegrity;
  final ApprovalPolicy approvalPolicy;
  final RecruitmentPartyRules compositionRules;
  final String cycleKey;

  /// 일반 레이드는 null. 그룹 레이드는 가입한 그룹 하나.
  final String? groupId;

  /// `public` 또는 `group`. 그룹 전용은 `group`이며 groupId가 필요하다.
  final String visibility;
}

enum PartyCreateFailure {
  unauthenticated,
  playerBindingMissing,
  serverDataMissing,
  ownershipLost,
  invalidCharacter,
  weeklyRaidCompleted,
  participationConflict,
  idConflict,
  notGroupMember,
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

class RecruitmentVisibility {
  const RecruitmentVisibility._();

  static const public = 'public';
  static const group = 'group';

  static bool isValid(String value) => value == public || value == group;
}
