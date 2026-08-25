import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../entities/active_raid_assignment.dart';
import '../entities/party_recruitment.dart';
import '../policies/participation_conflict_policy.dart';
import '../policies/weekly_raid_reset_policy.dart';
import '../repositories/active_raid_assignment_repository.dart';
import '../repositories/recruitment_state_repository.dart';
import '../repositories/weekly_raid_clear_repository.dart';
import 'candidate_participation_status.dart';
import 'recruitment_runtime.dart';

class RecruitmentLeaderRoleOption {
  const RecruitmentLeaderRoleOption({
    required this.role,
    required this.itemLevel,
    required this.combatPower,
    required this.rejectionReasons,
  });

  final PartyRole role;
  final double? itemLevel;
  final double? combatPower;
  final List<String> rejectionReasons;

  bool get canSelect => rejectionReasons.isEmpty;
}

class RecruitmentLeaderCandidate {
  const RecruitmentLeaderCandidate({
    required this.characterId,
    required this.localCharacterId,
    required this.accountId,
    required this.accountLabel,
    required this.isMainAccount,
    required this.isRepresentative,
    required this.serverName,
    required this.className,
    required this.roles,
    required this.participationStatuses,
    required this.rejectionReasons,
    this.serverCharacterId,
  });

  final String characterId;
  final String? serverCharacterId;
  final int localCharacterId;
  final int accountId;
  final String accountLabel;
  final bool isMainAccount;
  final bool isRepresentative;
  final String serverName;
  final String className;
  final List<RecruitmentLeaderRoleOption> roles;
  final List<CandidateParticipationStatus> participationStatuses;
  final List<String> rejectionReasons;

  bool get canSelect =>
      rejectionReasons.isEmpty && roles.any((option) => option.canSelect);

  RecruitmentLeaderRoleOption? optionFor(PartyRole role) =>
      roles.where((option) => option.role == role).firstOrNull;
}

class RecruitmentLeaderCandidateQuery {
  const RecruitmentLeaderCandidateQuery({
    required this.raidId,
    required this.difficultyId,
    required this.minItemLevel,
    required this.startAt,
    required this.maxPlayHours,
  });

  final String raidId;
  final String difficultyId;
  final int minItemLevel;
  final DateTime startAt;
  final int? maxPlayHours;
}

class RecruitmentLeaderCandidateService {
  const RecruitmentLeaderCandidateService({
    required this.accountRepository,
    required this.weeklyClearRepository,
    required this.session,
    required this.clock,
    required this.assignmentRepository,
    required this.recruitmentRepository,
    this.conflictPolicy = const ParticipationConflictPolicy(),
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final AccountRepository accountRepository;
  final WeeklyRaidClearRepository weeklyClearRepository;
  final UserSession session;
  final RecruitmentClock clock;
  final ActiveRaidAssignmentRepository assignmentRepository;
  final RecruitmentStateRepository recruitmentRepository;
  final ParticipationConflictPolicy conflictPolicy;
  final WeeklyRaidResetPolicy resetPolicy;

  Future<List<RecruitmentLeaderCandidate>> load(
    RecruitmentLeaderCandidateQuery query,
  ) async {
    final userId = session.currentUserId;
    if (userId == null) return const [];
    final accounts = await accountRepository.loadAccounts();
    final activeAssignments = await assignmentRepository.getByUser(userId);
    final weekKey = resetPolicy.weekFor(clock.now()).key;
    final candidates = <RecruitmentLeaderCandidate>[];
    final seenCharacters = <String>{};

    for (final account in accounts) {
      if (account.hasLostOwnership) continue;
      for (final character in account.visibleCharacters) {
        final key =
            '${character.serverName.trim().toLowerCase()}::${character.characterName.trim().toLowerCase()}';
        if (!seenCharacters.add(key)) continue;
        final snapshots = await accountRepository.loadCharacterBuildSnapshots(
          character.id,
        );
        final roles = <RecruitmentLeaderRoleOption>[];
        for (final snapshot in snapshots) {
          final role = switch (snapshot.role) {
            CharacterBuildRole.dealer => PartyRole.dealer,
            CharacterBuildRole.support => PartyRole.support,
          };
          final itemLevel = snapshot.itemLevel ?? character.itemLevel;
          final reasons = <String>[];
          if (itemLevel == null || itemLevel < query.minItemLevel) {
            reasons.add('입장 레벨 ${query.minItemLevel} 미달');
          }
          roles.add(
            RecruitmentLeaderRoleOption(
              role: role,
              itemLevel: itemLevel,
              combatPower: snapshot.combatPower ?? character.combatPower,
              rejectionReasons: List.unmodifiable(reasons),
            ),
          );
        }
        roles.sort((left, right) {
          final preferred = character.preferredRole;
          if (preferred == null) return 0;
          final leftPreferred = left.role.name == preferred.name;
          final rightPreferred = right.role.name == preferred.name;
          return leftPreferred == rightPreferred
              ? 0
              : leftPreferred
              ? -1
              : 1;
        });

        final statuses = <CandidateParticipationStatus>[];
        final rejectionReasons = <String>[];
        if (roles.isEmpty) rejectionReasons.add('저장된 역할 세팅이 없습니다.');
        if (await weeklyClearRepository.hasClear(
          userId: userId,
          characterId: character.characterName,
          raidId: query.raidId,
          resetWeekKey: weekKey,
        )) {
          statuses.add(
            const CandidateParticipationStatus(
              type: CandidateParticipationStatusType.weeklyRaidClear,
            ),
          );
          rejectionReasons.add('이번 주 동일 레이드 완료');
        }
        final pendingCount = await recruitmentRepository
            .countPendingApplications(
              applicantUserId: userId,
              characterId: character.characterName,
              raidId: query.raidId,
            );
        if (pendingCount > 0) {
          statuses.add(
            CandidateParticipationStatus(
              type: CandidateParticipationStatusType.pendingSameRaid,
              count: pendingCount,
            ),
          );
        }
        final decision = conflictPolicy.evaluate(
          proposed: ActiveRaidAssignment(
            userId: userId,
            characterId: character.characterName,
            raidId: query.raidId,
            difficultyId: query.difficultyId,
            recruitmentId: 'new-recruitment-candidate',
            schedule: RaidParticipationSchedule(
              startAt: query.startAt,
              expectedEndAt: query.maxPlayHours == null
                  ? null
                  : query.startAt.add(Duration(hours: query.maxPlayHours!)),
            ),
          ),
          activeAssignments: activeAssignments,
        );
        for (final conflict in decision.conflicts) {
          final (type, reason) = switch (conflict.type) {
            ParticipationConflictType.sameCharacterAndRaid => (
              CandidateParticipationStatusType.activeSameRaid,
              '동일 레이드 참가 중',
            ),
            ParticipationConflictType.overlappingSchedule ||
            ParticipationConflictType.sameUserInRecruitment => (
              CandidateParticipationStatusType.overlappingSchedule,
              '동시간대 다른 파티 참가 중',
            ),
            ParticipationConflictType.uncertainSchedule => (
              CandidateParticipationStatusType.uncertainSchedule,
              '참가 일정 확인 필요',
            ),
          };
          if (statuses.every((status) => status.type != type)) {
            statuses.add(CandidateParticipationStatus(type: type));
          }
          if (!rejectionReasons.contains(reason)) rejectionReasons.add(reason);
        }
        candidates.add(
          RecruitmentLeaderCandidate(
            characterId: character.characterName,
            serverCharacterId: character.serverCharacterId,
            localCharacterId: character.id,
            accountId: account.id,
            accountLabel: account.label,
            isMainAccount: account.isMain,
            isRepresentative:
                account.isMain &&
                character.id == account.representativeCharacterId,
            serverName: character.serverName,
            className: character.characterClassName,
            roles: List.unmodifiable(roles),
            participationStatuses: List.unmodifiable(statuses),
            rejectionReasons: List.unmodifiable(rejectionReasons),
          ),
        );
      }
    }
    return List.unmodifiable(candidates);
  }
}
