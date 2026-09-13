import '../../../account/domain/entities/character_build_snapshot.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../account/domain/repositories/activity_characters_repository.dart';
import '../../../account/domain/entities/weekly_raid_claim.dart';
import '../../../account/domain/repositories/weekly_raid_claim_repository.dart';
import '../../../account/domain/services/gem_validation_snapshot_mapper.dart';
import '../../../account/domain/services/build_integrity_snapshot_mapper.dart';
import 'package:lost_party/shared/character_build/build_integrity_snapshot.dart';
import 'package:lost_party/shared/character_build/party_gem_validation_snapshot.dart';
import '../entities/active_raid_assignment.dart';
import '../entities/party_recruitment.dart';
import '../policies/participation_conflict_policy.dart';
import '../policies/party_composition_policy.dart';
import '../policies/weekly_raid_reset_policy.dart';
import '../repositories/active_raid_assignment_repository.dart';
import '../repositories/recruitment_state_repository.dart';
import '../repositories/weekly_raid_clear_repository.dart';
import 'candidate_participation_status.dart';
import 'raid_activity_character_source.dart';
import 'recruitment_runtime.dart';

class RecruitmentLeaderRoleOption {
  const RecruitmentLeaderRoleOption({
    required this.role,
    required this.itemLevel,
    required this.combatPower,
    required this.rejectionReasons,
    this.gemValidation,
    this.buildIntegrity,
  });

  final PartyRole role;
  final double? itemLevel;
  final double? combatPower;
  final List<String> rejectionReasons;
  final PartyGemValidationSnapshot? gemValidation;
  final BuildIntegritySnapshot? buildIntegrity;

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

  List<PartyRole> get selectableRoles => roles
      .where((option) => option.canSelect)
      .map((option) => option.role)
      .toList(growable: false);

  PartyRole resolveSelectedRole({
    PartyRole? current,
    bool Function(RecruitmentLeaderRoleOption option)? usable,
  }) {
    bool matches(RecruitmentLeaderRoleOption option) =>
        usable?.call(option) ?? option.canSelect;
    final usableRoles = roles.where(matches);
    if (current != null &&
        usableRoles.any((option) => option.role == current)) {
      return current;
    }
    return usableRoles.firstOrNull?.role ??
        selectableRoles.firstOrNull ??
        current ??
        PartyRole.dealer;
  }
}

class RecruitmentLeaderCandidateQuery {
  const RecruitmentLeaderCandidateQuery({
    required this.raidId,
    required this.difficultyId,
    required this.minItemLevel,
    required this.startAt,
    required this.maxPlayHours,
    this.partyRules,
    this.occupiedMembers = const [],
    this.replacingMemberId,
    this.allowPositionChanges = false,
  });

  final String raidId;
  final String difficultyId;
  final int minItemLevel;
  final DateTime startAt;
  final int? maxPlayHours;

  /// 신청·참가 후보 구성 판정용. 모집 생성 후보에서는 null이다.
  final RecruitmentPartyRules? partyRules;

  /// 현재 확정 membership. [partyRules]가 있을 때만 사용한다.
  final List<OccupiedPartyMember> occupiedMembers;

  /// 캐릭터 변경 시 교체 대상 PlayerId. 신청·즉시 가입에서는 null이다.
  final String? replacingMemberId;
  final bool allowPositionChanges;
}

class RecruitmentLeaderCandidateService {
  const RecruitmentLeaderCandidateService({
    required this.accountRepository,
    required this.weeklyClearRepository,
    required this.session,
    required this.clock,
    required this.assignmentRepository,
    this.assignmentLookup,
    required this.recruitmentRepository,
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
  final ActiveRaidAssignmentRepository assignmentRepository;
  final ActiveRaidAssignmentLookup? assignmentLookup;
  final RecruitmentStateRepository recruitmentRepository;
  final WeeklyRaidClaimRepository? weeklyRaidClaimRepository;
  final String? claimPlayerId;
  final ActivityCharactersRepository? activityCharactersRepository;
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
    final serverClaims = await _loadServerClaims(weekKey);
    final activityCharacterIds = await loadRaidActivityCharacterIds(
      repository: activityCharactersRepository,
      playerId: claimPlayerId,
    );
    final candidates = <RecruitmentLeaderCandidate>[];
    final seenCharacters = <String>{};

    for (final account in accounts) {
      if (account.hasLostOwnership) continue;
      for (final character in raidCandidateCharacters(
        account,
        activityCharacterIds,
      )) {
        final key =
            '${character.serverName.trim().toLowerCase()}::${character.characterName.trim().toLowerCase()}';
        if (!seenCharacters.add(key)) continue;
        final serverCharacterId = character.serverCharacterId;
        final hasServerAssignmentForSameRaid =
            serverCharacterId != null &&
            assignmentLookup != null &&
            await assignmentLookup!.blocksCandidate(
              playerId: userId,
              characterId: serverCharacterId,
              raidId: query.raidId,
              cycleKey: weekKey,
            );
        final snapshots = await accountRepository.loadCharacterBuildSnapshots(
          character.id,
        );
        final roles = <RecruitmentLeaderRoleOption>[];
        final partyRules = query.partyRules;
        final compositionPolicy = partyRules == null
            ? null
            : PartyCompositionPolicy(partyRules);
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
          if (compositionPolicy != null) {
            final compositionFailure = _compositionFailure(
              policy: compositionPolicy,
              userId: userId,
              className: character.characterClassName,
              role: role,
              occupiedMembers: query.occupiedMembers,
              replacingMemberId: query.replacingMemberId,
              allowPositionChanges: query.allowPositionChanges,
            );
            if (compositionFailure != null) {
              reasons.add(_compositionReason(compositionFailure));
            }
          }
          roles.add(
            RecruitmentLeaderRoleOption(
              role: role,
              itemLevel: itemLevel,
              combatPower: snapshot.combatPower ?? character.combatPower,
              rejectionReasons: List.unmodifiable(reasons),
              gemValidation: _gemValidationFor(snapshot),
              buildIntegrity: buildIntegritySnapshotFromBuild(snapshot),
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
        final hasServerClaim =
            character.serverCharacterId != null &&
            serverClaims.any(
              (claim) =>
                  claim.characterId == character.serverCharacterId &&
                  claim.raidId == query.raidId,
            );
        if (hasServerClaim) {
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
        if (hasServerAssignmentForSameRaid) {
          statuses.add(
            const CandidateParticipationStatus(
              type: CandidateParticipationStatusType.activeSameRaid,
            ),
          );
          rejectionReasons.add('동일 레이드 참가 중');
        }
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

  PartyGemValidationSnapshot? _gemValidationFor(
    CharacterBuildSnapshot snapshot,
  ) => gemValidationSnapshotFromBuild(snapshot);

  PartyCompositionFailure? _compositionFailure({
    required PartyCompositionPolicy policy,
    required String userId,
    required String className,
    required PartyRole role,
    required List<OccupiedPartyMember> occupiedMembers,
    required String? replacingMemberId,
    required bool allowPositionChanges,
  }) {
    if (replacingMemberId != null) {
      if (!allowPositionChanges) {
        return policy.failureForInPlaceReplacement(
          replaceMemberId: replacingMemberId,
          className: className,
          role: role,
          existing: occupiedMembers,
        );
      }
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

  Future<List<WeeklyRaidClaim>> _loadServerClaims(String cycleKey) async {
    final repository = weeklyRaidClaimRepository;
    final playerId = claimPlayerId;
    if (repository == null || playerId == null) return const [];
    return repository
        .watchCurrentCycleClaims(playerId: playerId, cycleKey: cycleKey)
        .first;
  }
}
