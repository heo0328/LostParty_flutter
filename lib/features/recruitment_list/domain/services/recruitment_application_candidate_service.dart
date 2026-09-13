import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/entities/weekly_raid_claim.dart';
import '../../../account/domain/repositories/weekly_raid_claim_repository.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../entities/party_recruitment.dart';
import '../entities/active_raid_assignment.dart';
import '../entities/recruitment_aggregate.dart';
import '../entities/recruitment_application.dart';
import '../policies/participation_conflict_policy.dart';
import '../policies/party_composition_policy.dart';
import '../policies/weekly_raid_reset_policy.dart';
import '../repositories/active_raid_assignment_repository.dart';
import '../repositories/recruitment_state_repository.dart';
import '../repositories/weekly_raid_clear_repository.dart';
import 'recruitment_runtime.dart';
import 'candidate_participation_status.dart';
import 'raid_activity_character_source.dart';

export 'candidate_participation_status.dart';

class RecruitmentApplicationCandidate {
  const RecruitmentApplicationCandidate({
    required this.characterId,
    required this.accountId,
    required this.accountLabel,
    required this.className,
    required this.role,
    required this.itemLevel,
    required this.combatPower,
    required this.rejectionReasons,
    this.isPreferred = false,
    this.participationStatuses = const [],
  });

  final String characterId;
  final int accountId;
  final String accountLabel;
  final String className;
  final PartyRole role;
  final double? itemLevel;
  final double? combatPower;
  final List<String> rejectionReasons;
  final bool isPreferred;
  final List<CandidateParticipationStatus> participationStatuses;

  bool get canApply => rejectionReasons.isEmpty;
}

class RecruitmentApplicationCandidateService {
  const RecruitmentApplicationCandidateService({
    required this.accountRepository,
    required this.weeklyClearRepository,
    required this.session,
    required this.clock,
    this.assignmentRepository,
    this.assignmentLookup,
    this.recruitmentRepository,
    this.weeklyRaidClaimRepository,
    this.claimPlayerId,
    this.activityCharactersRepository,
    this.conflictPolicy = const ParticipationConflictPolicy(),
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final AccountRepository accountRepository;
  final WeeklyRaidClearRepository weeklyClearRepository;
  final UserSession session;
  final RecruitmentClock clock;
  final ActiveRaidAssignmentRepository? assignmentRepository;
  final ActiveRaidAssignmentLookup? assignmentLookup;
  final RecruitmentStateRepository? recruitmentRepository;
  final WeeklyRaidClaimRepository? weeklyRaidClaimRepository;
  final String? claimPlayerId;
  final ActivityCharactersRepository? activityCharactersRepository;
  final ParticipationConflictPolicy conflictPolicy;
  final WeeklyRaidResetPolicy resetPolicy;

  Future<List<RecruitmentApplicationCandidate>> load(
    RecruitmentAggregate aggregate,
  ) => _load(aggregate);

  Future<List<RecruitmentApplicationCandidate>> loadForCharacterChange(
    RecruitmentAggregate aggregate,
  ) {
    final userId = session.currentUserId;
    final member = userId == null
        ? null
        : aggregate.state.members
              .where((member) => member.userId == userId)
              .firstOrNull;
    if (member == null) return Future.value(const []);
    return _load(aggregate, replacingMember: member);
  }

  Future<List<RecruitmentApplicationCandidate>> _load(
    RecruitmentAggregate aggregate, {
    RecruitmentPartyMember? replacingMember,
  }) async {
    final accounts = await accountRepository.loadAccounts();
    final userId = session.currentUserId;
    if (accounts.isEmpty || userId == null) return const [];
    final weekKey = resetPolicy.weekFor(clock.now()).key;
    final serverClaims = await _loadServerClaims(weekKey);
    final activityCharacterIds = await loadRaidActivityCharacterIds(
      repository: activityCharactersRepository,
      playerId: claimPlayerId,
    );
    final activeAssignments =
        await assignmentRepository?.getByUser(userId) ?? const [];
    final candidates = <RecruitmentApplicationCandidate>[];
    final seenCharacters = <String>{};
    for (final account in accounts) {
      if (account.hasLostOwnership) continue;
      for (final character in raidCandidateCharacters(
        account,
        activityCharacterIds,
      )) {
        final characterKey =
            '${character.serverName.trim().toLowerCase()}::${character.characterName.trim().toLowerCase()}';
        if (!seenCharacters.add(characterKey)) continue;
        final serverCharacterId = character.serverCharacterId;
        final hasServerAssignmentForSameRaid =
            serverCharacterId != null &&
            assignmentLookup != null &&
            await assignmentLookup!.blocksCandidate(
              playerId: userId,
              characterId: serverCharacterId,
              raidId: aggregate.metadata.raidId,
              cycleKey: weekKey,
            );
        final snapshots = await accountRepository.loadCharacterBuildSnapshots(
          character.id,
        );
        for (final snapshot in snapshots) {
          final role = switch (snapshot.role) {
            CharacterBuildRole.dealer => PartyRole.dealer,
            CharacterBuildRole.support => PartyRole.support,
          };
          if (replacingMember != null &&
              character.characterName == replacingMember.characterId &&
              role == replacingMember.role) {
            continue;
          }
          final reasons = <String>[];
          final statuses = <CandidateParticipationStatus>[];
          final itemLevel = snapshot.itemLevel ?? character.itemLevel;
          final combatPower = snapshot.combatPower ?? character.combatPower;
          if (itemLevel == null ||
              itemLevel < aggregate.metadata.minItemLevel) {
            reasons.add(
              '입장 레벨 ${DisplayNumberFormatter.integer(aggregate.metadata.minItemLevel)} 미달',
            );
          }
          final minimumCombatPower = aggregate.metadata.minCombatPower;
          if (minimumCombatPower != null &&
              (combatPower == null || combatPower < minimumCombatPower)) {
            reasons.add(
              '최소 전투력 ${DisplayNumberFormatter.integer(minimumCombatPower)} 미달',
            );
          }
          final hasServerClaim =
              character.serverCharacterId != null &&
              serverClaims.any(
                (claim) =>
                    claim.characterId == character.serverCharacterId &&
                    claim.raidId == aggregate.metadata.raidId,
              );
          if (hasServerClaim) {
            reasons.add('이번 주 동일 레이드 완료');
            statuses.add(
              const CandidateParticipationStatus(
                type: CandidateParticipationStatusType.weeklyRaidClear,
              ),
            );
          }
          final pendingCount = await recruitmentRepository
              ?.countPendingApplications(
                applicantUserId: userId,
                characterId: character.characterName,
                raidId: aggregate.metadata.raidId,
              );
          if (pendingCount != null && pendingCount > 0) {
            statuses.add(
              CandidateParticipationStatus(
                type: CandidateParticipationStatusType.pendingSameRaid,
                count: pendingCount,
              ),
            );
          }
          final startAt = aggregate.metadata.raidStartAt ?? aggregate.createdAt;
          final maxPlayHours = aggregate.metadata.maxPlayHours;
          final participationDecision = conflictPolicy.evaluate(
            proposed: ActiveRaidAssignment(
              userId: userId,
              characterId: character.characterName,
              raidId: aggregate.metadata.raidId,
              difficultyId: aggregate.metadata.difficultyId,
              recruitmentId: aggregate.id,
              schedule: RaidParticipationSchedule(
                startAt: startAt,
                expectedEndAt: maxPlayHours == null
                    ? null
                    : startAt.add(Duration(hours: maxPlayHours)),
              ),
            ),
            activeAssignments: replacingMember == null
                ? activeAssignments
                : activeAssignments
                      .where(
                        (assignment) =>
                            assignment.recruitmentId != aggregate.id,
                      )
                      .toList(growable: false),
          );
          if (hasServerAssignmentForSameRaid) {
            statuses.add(
              const CandidateParticipationStatus(
                type: CandidateParticipationStatusType.activeSameRaid,
              ),
            );
            reasons.add('동일 레이드 참가 중');
          }
          for (final conflict in participationDecision.conflicts) {
            final statusType = switch (conflict.type) {
              ParticipationConflictType.sameCharacterAndRaid =>
                CandidateParticipationStatusType.activeSameRaid,
              ParticipationConflictType.overlappingSchedule =>
                CandidateParticipationStatusType.overlappingSchedule,
              ParticipationConflictType.uncertainSchedule =>
                CandidateParticipationStatusType.uncertainSchedule,
              ParticipationConflictType.sameUserInRecruitment =>
                CandidateParticipationStatusType.overlappingSchedule,
            };
            if (statuses.any((status) => status.type == statusType)) continue;
            statuses.add(CandidateParticipationStatus(type: statusType));
            final reason = switch (statusType) {
              CandidateParticipationStatusType.activeSameRaid => '동일 레이드 참가 중',
              CandidateParticipationStatusType.overlappingSchedule =>
                '동시간대 다른 파티 참가 중',
              CandidateParticipationStatusType.uncertainSchedule =>
                '참가 일정 확인 필요',
              _ => null,
            };
            if (reason != null && !reasons.contains(reason)) {
              reasons.add(reason);
            }
          }
          final occupiedMembers = [
            for (final member in aggregate.state.members)
              OccupiedPartyMember(
                id: member.userId,
                className: member.className,
                role: member.role,
                partyIndex: member.partyIndex,
                isLeader: member.userId == aggregate.state.leaderUserId,
              ),
          ];
          final compositionFailure = _compositionFailure(
            policy: aggregate.state.compositionPolicy,
            userId: userId,
            className: character.characterClassName,
            role: role,
            occupiedMembers: occupiedMembers,
            replacingMemberId: replacingMember?.userId,
          );
          if (compositionFailure != null) {
            reasons.add(_compositionReason(compositionFailure));
          }
          candidates.add(
            RecruitmentApplicationCandidate(
              characterId: character.characterName,
              accountId: account.id,
              accountLabel: account.label,
              className: character.characterClassName,
              role: role,
              itemLevel: itemLevel,
              combatPower: combatPower,
              rejectionReasons: List.unmodifiable(reasons),
              isPreferred: snapshot.role == character.preferredRole,
              participationStatuses: List.unmodifiable(statuses),
            ),
          );
        }
      }
    }
    candidates.sort((left, right) {
      if (left.characterId == right.characterId &&
          left.isPreferred != right.isPreferred) {
        return left.isPreferred ? -1 : 1;
      }
      return 0;
    });
    return candidates;
  }

  Future<List<WeeklyRaidClaim>> _loadServerClaims(String cycleKey) async {
    final repository = weeklyRaidClaimRepository;
    final playerId = claimPlayerId;
    if (repository == null || playerId == null) return const [];
    return repository
        .watchCurrentCycleClaims(playerId: playerId, cycleKey: cycleKey)
        .first;
  }

  PartyCompositionFailure? _compositionFailure({
    required PartyCompositionPolicy policy,
    required String userId,
    required String className,
    required PartyRole role,
    required List<OccupiedPartyMember> occupiedMembers,
    required String? replacingMemberId,
  }) {
    if (replacingMemberId != null) {
      final plan = policy.planReplacement(
        replaceMemberId: replacingMemberId,
        className: className,
        role: role,
        existing: occupiedMembers,
      );
      return plan.canChange ? null : plan.failure;
    }
    final placement = policy.assignEmptySlot(
      joining: OccupiedPartyMember(
        id: userId,
        className: className,
        role: role,
        partyIndex: 0,
      ),
      existing: occupiedMembers,
    );
    if (placement.canJoin) return null;
    return placement.failure;
  }

  String _compositionReason(PartyCompositionFailure failure) =>
      switch (failure) {
        PartyCompositionFailure.dealerSlotsFull ||
        PartyCompositionFailure.supportSlotsFull => '해당 역할 자리가 없습니다.',
        PartyCompositionFailure.duplicateDealerClass => '동일 딜러 직업 자리가 없습니다.',
        PartyCompositionFailure.partyFull => '파티 정원이 가득 찼습니다.',
        _ => '현재 파티 구성에 배치할 수 없습니다.',
      };
}
