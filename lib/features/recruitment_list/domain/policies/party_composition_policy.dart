import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../entities/party_recruitment.dart';

class RecruitmentPartyRules {
  const RecruitmentPartyRules({
    required this.partyCount,
    required this.membersPerParty,
    required this.supportsPerParty,
    required this.maxDealersPerClassPerParty,
  });

  factory RecruitmentPartyRules.fromRaid(RaidDefinition raid) {
    if (raid.partySize % raid.partyCount != 0 ||
        raid.requiredSupportCount % raid.partyCount != 0 ||
        raid.maxDealerCountPerClass % raid.partyCount != 0) {
      throw ArgumentError('레이드 파티 기준을 파티별로 균등하게 나눌 수 없습니다.');
    }

    return RecruitmentPartyRules(
      partyCount: raid.partyCount,
      membersPerParty: raid.partySize ~/ raid.partyCount,
      supportsPerParty: raid.requiredSupportCount ~/ raid.partyCount,
      maxDealersPerClassPerParty:
          raid.maxDealerCountPerClass ~/ raid.partyCount,
    );
  }

  final int partyCount;
  final int membersPerParty;
  final int supportsPerParty;
  final int maxDealersPerClassPerParty;

  int get totalMembers => partyCount * membersPerParty;
  int get totalSupports => partyCount * supportsPerParty;
  int get totalDealers => totalMembers - totalSupports;
  int get dealersPerParty => membersPerParty - supportsPerParty;
}

class PartyCompositionMember {
  const PartyCompositionMember({
    required this.id,
    required this.className,
    required this.role,
  });

  final String id;
  final String className;
  final PartyRole role;
}

enum PartyCompositionFailure {
  none,
  duplicateMember,
  partyFull,
  dealerSlotsFull,
  supportSlotsFull,
  duplicateDealerClass,
  noValidPlacement,
}

class PartyCompositionDecision {
  const PartyCompositionDecision._({
    required this.canJoin,
    required this.assignments,
    required this.failure,
  });

  const PartyCompositionDecision.accepted(Map<String, int> assignments)
    : this._(
        canJoin: true,
        assignments: assignments,
        failure: PartyCompositionFailure.none,
      );

  const PartyCompositionDecision.rejected(PartyCompositionFailure failure)
    : this._(canJoin: false, assignments: const {}, failure: failure);

  final bool canJoin;
  final Map<String, int> assignments;
  final PartyCompositionFailure failure;
}

class PartyCompositionPolicy {
  const PartyCompositionPolicy(this.rules);

  final RecruitmentPartyRules rules;

  PartyCompositionDecision arrange(List<PartyCompositionMember> members) {
    if (members.map((member) => member.id).toSet().length != members.length) {
      return const PartyCompositionDecision.rejected(
        PartyCompositionFailure.duplicateMember,
      );
    }
    if (members.length > rules.totalMembers) {
      return const PartyCompositionDecision.rejected(
        PartyCompositionFailure.partyFull,
      );
    }

    final supportCount = members
        .where((member) => member.role == PartyRole.support)
        .length;
    final dealerCount = members.length - supportCount;
    if (supportCount > rules.totalSupports) {
      return const PartyCompositionDecision.rejected(
        PartyCompositionFailure.supportSlotsFull,
      );
    }
    if (dealerCount > rules.totalDealers) {
      return const PartyCompositionDecision.rejected(
        PartyCompositionFailure.dealerSlotsFull,
      );
    }

    final parties = List.generate(
      rules.partyCount,
      (_) => <PartyCompositionMember>[],
    );
    final assignments = <String, int>{};
    final orderedMembers = [...members]
      ..sort((left, right) {
        if (left.role != right.role) {
          return left.role == PartyRole.support ? -1 : 1;
        }
        return left.className.compareTo(right.className);
      });

    if (_place(orderedMembers, 0, parties, assignments)) {
      return PartyCompositionDecision.accepted(Map.unmodifiable(assignments));
    }

    final hasDuplicateDealerClass = _hasDealerClassOverTotalLimit(members);
    return PartyCompositionDecision.rejected(
      hasDuplicateDealerClass
          ? PartyCompositionFailure.duplicateDealerClass
          : PartyCompositionFailure.noValidPlacement,
    );
  }

  bool _place(
    List<PartyCompositionMember> members,
    int memberIndex,
    List<List<PartyCompositionMember>> parties,
    Map<String, int> assignments,
  ) {
    if (memberIndex == members.length) return true;

    final member = members[memberIndex];
    for (var partyIndex = 0; partyIndex < parties.length; partyIndex++) {
      final party = parties[partyIndex];
      if (!_canPlace(member, party)) continue;

      party.add(member);
      assignments[member.id] = partyIndex;
      if (_place(members, memberIndex + 1, parties, assignments)) return true;
      assignments.remove(member.id);
      party.removeLast();
    }
    return false;
  }

  bool _canPlace(
    PartyCompositionMember member,
    List<PartyCompositionMember> party,
  ) {
    if (party.length >= rules.membersPerParty) return false;

    final sameRole = party.where((item) => item.role == member.role);
    if (member.role == PartyRole.support) {
      return sameRole.length < rules.supportsPerParty;
    }

    if (sameRole.length >= rules.dealersPerParty) return false;
    final sameClassDealers = sameRole.where(
      (item) => item.className == member.className,
    );
    return sameClassDealers.length < rules.maxDealersPerClassPerParty;
  }

  bool _hasDealerClassOverTotalLimit(List<PartyCompositionMember> members) {
    final counts = <String, int>{};
    for (final member in members.where(
      (member) => member.role == PartyRole.dealer,
    )) {
      counts.update(member.className, (count) => count + 1, ifAbsent: () => 1);
    }
    final totalLimit = rules.partyCount * rules.maxDealersPerClassPerParty;
    return counts.values.any((count) => count > totalLimit);
  }
}
