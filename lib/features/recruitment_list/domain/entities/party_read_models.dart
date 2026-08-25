import 'recruitment_aggregate.dart';
import 'recruitment_application.dart';
import 'party_recruitment.dart';

class PartyReadSnapshot<T> {
  const PartyReadSnapshot({required this.items, required this.isFromCache});

  final List<T> items;
  final bool isFromCache;
}

class ActiveRaidSummary {
  const ActiveRaidSummary({
    required this.id,
    required this.title,
    required this.leaderPlayerId,
    required this.metadata,
    required this.currentCycleKey,
    required this.memberCount,
    required this.maxMemberCount,
    required this.revision,
    required this.updatedAt,
    required this.isOwnedByCurrentPlayer,
    this.raidStartAt,
  });

  final String id;
  final String title;
  final String leaderPlayerId;
  final RecruitmentMetadata metadata;
  final String currentCycleKey;
  final int memberCount;
  final int maxMemberCount;
  final int revision;
  final DateTime updatedAt;
  final bool isOwnedByCurrentPlayer;
  final DateTime? raidStartAt;
}

class PartyApplicationSummary {
  const PartyApplicationSummary({
    required this.recruitmentId,
    required this.applicantPlayerId,
    required this.cycleKey,
    required this.characterId,
    required this.characterName,
    required this.className,
    required this.requestedRole,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolutionReason,
    this.decidedAt,
  });

  final String recruitmentId;
  final String applicantPlayerId;
  final String cycleKey;
  final String characterId;
  final String characterName;
  final String className;
  final PartyRole requestedRole;
  final RecruitmentApplicationStatus status;
  final String? resolutionReason;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final DateTime updatedAt;
}
