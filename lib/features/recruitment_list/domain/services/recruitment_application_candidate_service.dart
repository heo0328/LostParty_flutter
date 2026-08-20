import '../../../account/domain/entities/character_build_role.dart';
import '../../../account/domain/repositories/account_repository.dart';
import '../../../../shared/formatters/display_number_formatter.dart';
import '../entities/party_recruitment.dart';
import '../entities/recruitment_aggregate.dart';
import '../policies/party_composition_policy.dart';
import '../policies/weekly_raid_reset_policy.dart';
import '../repositories/weekly_raid_clear_repository.dart';
import 'recruitment_runtime.dart';

class RecruitmentApplicationCandidate {
  const RecruitmentApplicationCandidate({
    required this.characterId,
    required this.className,
    required this.role,
    required this.itemLevel,
    required this.combatPower,
    required this.rejectionReasons,
  });

  final String characterId;
  final String className;
  final PartyRole role;
  final double? itemLevel;
  final double? combatPower;
  final List<String> rejectionReasons;

  bool get canApply => rejectionReasons.isEmpty;
}

class RecruitmentApplicationCandidateService {
  const RecruitmentApplicationCandidateService({
    required this.accountRepository,
    required this.weeklyClearRepository,
    required this.session,
    required this.clock,
    this.resetPolicy = const WeeklyRaidResetPolicy(),
  });

  final AccountRepository accountRepository;
  final WeeklyRaidClearRepository weeklyClearRepository;
  final UserSession session;
  final RecruitmentClock clock;
  final WeeklyRaidResetPolicy resetPolicy;

  Future<List<RecruitmentApplicationCandidate>> load(
    RecruitmentAggregate aggregate,
  ) async {
    final account = await accountRepository.loadMainAccount();
    final userId = session.currentUserId;
    if (account == null || userId == null) return const [];
    final weekKey = resetPolicy.weekFor(clock.now()).key;
    final candidates = <RecruitmentApplicationCandidate>[];
    for (final character in account.visibleCharacters) {
      final snapshots = await accountRepository.loadCharacterBuildSnapshots(
        character.id,
      );
      for (final snapshot in snapshots) {
        final role = switch (snapshot.role) {
          CharacterBuildRole.dealer => PartyRole.dealer,
          CharacterBuildRole.support => PartyRole.support,
        };
        final reasons = <String>[];
        final itemLevel = snapshot.itemLevel ?? character.itemLevel;
        final combatPower = snapshot.combatPower ?? character.combatPower;
        if (itemLevel == null || itemLevel < aggregate.metadata.minItemLevel) {
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
        }
        final composition = aggregate.state.compositionPolicy.arrange([
          ...aggregate.state.members.map(
            (member) => PartyCompositionMember(
              id: member.userId,
              className: member.className,
              role: member.role,
            ),
          ),
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
            className: character.characterClassName,
            role: role,
            itemLevel: itemLevel,
            combatPower: combatPower,
            rejectionReasons: List.unmodifiable(reasons),
          ),
        );
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
