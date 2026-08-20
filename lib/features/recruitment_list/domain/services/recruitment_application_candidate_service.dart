import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/repositories/account_repository.dart';
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

enum CandidateParticipationStatusType {
  pendingSameRaid,
  activeSameRaid,
  overlappingSchedule,
  uncertainSchedule,
  weeklyRaidClear,
}

class CandidateParticipationStatus {
  const CandidateParticipationStatus({required this.type, this.count = 1});

  final CandidateParticipationStatusType type;
  final int count;

  bool get isBlocking =>
      type != CandidateParticipationStatusType.pendingSameRaid;
}

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
    this.recruitmentRepository,
    this.conflictPolicy = const ParticipationConflictPolicy(),
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final AccountRepository accountRepository;
  final WeeklyRaidClearRepository weeklyClearRepository;
  final UserSession session;
  final RecruitmentClock clock;
  final ActiveRaidAssignmentRepository? assignmentRepository;
  final RecruitmentStateRepository? recruitmentRepository;
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
    final activeAssignments =
        await assignmentRepository?.getByUser(userId) ?? const [];
    final candidates = <RecruitmentApplicationCandidate>[];
    final seenCharacters = <String>{};
    for (final account in accounts) {
      for (final character in account.visibleCharacters) {
        final characterKey =
            '${character.serverName.trim().toLowerCase()}::${character.characterName.trim().toLowerCase()}';
        if (!seenCharacters.add(characterKey)) continue;
        final snapshots = await accountRepository.loadCharacterBuildSnapshots(
          character.id,
        );
        for (final snapshot in snapshots) {
          final role = switch (snapshot.role) {
            CharacterBuildRole.dealer => PartyRole.dealer,
            CharacterBuildRole.support => PartyRole.support,
          };
          if (replacingMember != null &&
              (character.characterName == replacingMember.characterId ||
                  role != replacingMember.role)) {
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
          if (await weeklyClearRepository.hasClear(
            userId: userId,
            characterId: character.characterName,
            raidId: aggregate.metadata.raidId,
            resetWeekKey: weekKey,
          )) {
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
          final composition = aggregate.state.compositionPolicy.arrange([
            ...aggregate.state.members.map(
              (member) => PartyCompositionMember(
                id: member.userId,
                className:
                    replacingMember != null &&
                        member.userId == replacingMember.userId
                    ? character.characterClassName
                    : member.className,
                role: member.role,
              ),
            ),
            if (replacingMember == null)
              PartyCompositionMember(
                id: userId,
                className: character.characterClassName,
                role: role,
              ),
          ]);
          if (!composition.canJoin) {
            reasons.add(_compositionReason(composition.failure));
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
              participationStatuses: List.unmodifiable(statuses),
            ),
          );
        }
      }
    }
    return candidates;
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
