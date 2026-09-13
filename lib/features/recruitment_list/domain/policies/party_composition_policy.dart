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

class PartySlot {
  const PartySlot({required this.partyIndex, required this.slotIndex});

  final int partyIndex;
  final int slotIndex;

  String get documentId => '${partyIndex}_$slotIndex';

  @override
  bool operator ==(Object other) =>
      other is PartySlot &&
      other.partyIndex == partyIndex &&
      other.slotIndex == slotIndex;

  @override
  int get hashCode => Object.hash(partyIndex, slotIndex);
}

class OccupiedPartyMember {
  const OccupiedPartyMember({
    required this.id,
    required this.className,
    required this.role,
    required this.partyIndex,
    this.slotIndex,
    this.joinedAt,
    this.isLeader = false,
  });

  final String id;
  final String className;
  final PartyRole role;
  final int partyIndex;
  final int? slotIndex;
  final DateTime? joinedAt;
  final bool isLeader;

  PartyCompositionMember toCompositionMember() =>
      PartyCompositionMember(id: id, className: className, role: role);
}

class PartySlotDecision {
  const PartySlotDecision._({
    required this.canJoin,
    required this.slot,
    required this.occupancy,
    required this.failure,
  });

  const PartySlotDecision.accepted({
    required PartySlot slot,
    required Map<String, PartySlot> occupancy,
  }) : this._(
         canJoin: true,
         slot: slot,
         occupancy: occupancy,
         failure: PartyCompositionFailure.none,
       );

  const PartySlotDecision.rejected(PartyCompositionFailure failure)
    : this._(canJoin: false, slot: null, occupancy: const {}, failure: failure);

  final bool canJoin;
  final PartySlot? slot;
  final Map<String, PartySlot> occupancy;
  final PartyCompositionFailure failure;
}

enum PartyReplacementDisposition {
  inPlace,
  moveToEmpty,
  inPlaceNeedsRebalance,
  rejected,
}

class PartyReplacementPlan {
  const PartyReplacementPlan._({
    required this.disposition,
    required this.failure,
    this.destination,
    this.suggestedSwapMemberIds = const [],
  });

  const PartyReplacementPlan.inPlace()
    : this._(
        disposition: PartyReplacementDisposition.inPlace,
        failure: PartyCompositionFailure.none,
      );

  const PartyReplacementPlan.moveToEmpty(PartySlot destination)
    : this._(
        disposition: PartyReplacementDisposition.moveToEmpty,
        destination: destination,
        failure: PartyCompositionFailure.none,
      );

  const PartyReplacementPlan.inPlaceNeedsRebalance(
    List<String> suggestedSwapMemberIds,
  ) : this._(
        disposition: PartyReplacementDisposition.inPlaceNeedsRebalance,
        suggestedSwapMemberIds: suggestedSwapMemberIds,
        failure: PartyCompositionFailure.none,
      );

  const PartyReplacementPlan.rejected(PartyCompositionFailure failure)
    : this._(
        disposition: PartyReplacementDisposition.rejected,
        failure: failure,
      );

  final PartyReplacementDisposition disposition;
  final PartyCompositionFailure failure;
  final PartySlot? destination;
  final List<String> suggestedSwapMemberIds;

  bool get canChange => disposition != PartyReplacementDisposition.rejected;
  bool get needsRebalance =>
      disposition == PartyReplacementDisposition.inPlaceNeedsRebalance;
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

  Map<String, PartySlot> resolveOccupancy(List<OccupiedPartyMember> members) {
    final occupancy = <String, PartySlot>{};
    final used = <PartySlot>{};
    final pending = <OccupiedPartyMember>[];

    for (final member in members) {
      final slotIndex = member.slotIndex;
      if (slotIndex == null || !_isValidSlot(member.partyIndex, slotIndex)) {
        pending.add(member);
        continue;
      }
      final slot = PartySlot(
        partyIndex: member.partyIndex,
        slotIndex: slotIndex,
      );
      if (used.contains(slot) || occupancy.containsKey(member.id)) {
        pending.add(member);
        continue;
      }
      occupancy[member.id] = slot;
      used.add(slot);
    }

    final remaining = [...pending]..sort(_comparePending);
    for (final member in remaining) {
      if (occupancy.containsKey(member.id)) continue;
      final seen = <PartySlot>{};
      for (final slot in _fillOrder(member)) {
        if (!seen.add(slot) || !_isValidSlot(slot.partyIndex, slot.slotIndex)) {
          continue;
        }
        if (used.contains(slot)) continue;
        occupancy[member.id] = slot;
        used.add(slot);
        break;
      }
    }
    return Map.unmodifiable(occupancy);
  }

  PartySlotDecision assignEmptySlot({
    required OccupiedPartyMember joining,
    required List<OccupiedPartyMember> existing,
  }) {
    if (existing.any((member) => member.id == joining.id)) {
      return const PartySlotDecision.rejected(
        PartyCompositionFailure.duplicateMember,
      );
    }
    if (existing.length + 1 > rules.totalMembers) {
      return const PartySlotDecision.rejected(
        PartyCompositionFailure.partyFull,
      );
    }

    final allMembers = [
      ...existing.map((member) => member.toCompositionMember()),
      joining.toCompositionMember(),
    ];
    final supportCount = allMembers
        .where((member) => member.role == PartyRole.support)
        .length;
    final dealerCount = allMembers.length - supportCount;
    if (supportCount > rules.totalSupports) {
      return const PartySlotDecision.rejected(
        PartyCompositionFailure.supportSlotsFull,
      );
    }
    if (dealerCount > rules.totalDealers) {
      return const PartySlotDecision.rejected(
        PartyCompositionFailure.dealerSlotsFull,
      );
    }

    final occupancy = resolveOccupancy(existing);
    final parties = List.generate(
      rules.partyCount,
      (_) => <PartyCompositionMember>[],
    );
    final existingById = {for (final member in existing) member.id: member};
    for (final entry in occupancy.entries) {
      final member = existingById[entry.key];
      if (member == null) continue;
      parties[entry.value.partyIndex].add(member.toCompositionMember());
    }

    final joiner = joining.toCompositionMember();
    for (final slot in _allSlots()) {
      if (occupancy.values.contains(slot)) continue;
      if (!_canPlace(joiner, parties[slot.partyIndex])) continue;
      return PartySlotDecision.accepted(slot: slot, occupancy: occupancy);
    }

    return PartySlotDecision.rejected(
      _hasDealerClassOverTotalLimit(allMembers)
          ? PartyCompositionFailure.duplicateDealerClass
          : PartyCompositionFailure.noValidPlacement,
    );
  }

  /// 캐릭터 변경처럼 기존 partyIndex·slotIndex를 유지한 채 직업·역할만 바꿀 때 사용한다.
  PartyCompositionFailure? failureForInPlaceReplacement({
    required String replaceMemberId,
    required String className,
    required PartyRole role,
    required List<OccupiedPartyMember> existing,
  }) {
    OccupiedPartyMember? target;
    for (final member in existing) {
      if (member.id == replaceMemberId) {
        target = member;
        break;
      }
    }
    if (target == null) return PartyCompositionFailure.noValidPlacement;

    var supportCount = 0;
    var dealerCount = 0;
    var sameClassDealerCount = 0;
    for (final member in existing) {
      if (member.partyIndex != target.partyIndex) continue;
      final effectiveRole = member.id == replaceMemberId ? role : member.role;
      final effectiveClass = member.id == replaceMemberId
          ? className
          : member.className;
      if (effectiveRole == PartyRole.support) {
        supportCount++;
        continue;
      }
      dealerCount++;
      if (effectiveClass == className) sameClassDealerCount++;
    }
    if (supportCount > rules.supportsPerParty) {
      return PartyCompositionFailure.supportSlotsFull;
    }
    if (dealerCount > rules.dealersPerParty) {
      return PartyCompositionFailure.dealerSlotsFull;
    }
    if (role == PartyRole.support) return null;
    if (sameClassDealerCount > rules.maxDealersPerClassPerParty) {
      return PartyCompositionFailure.duplicateDealerClass;
    }
    return null;
  }

  /// 캐릭터 변경 시 전체 공대를 재배치하지 않고 확정된 우선순서로 배치를 계획한다.
  PartyReplacementPlan planReplacement({
    required String replaceMemberId,
    required String className,
    required PartyRole role,
    required List<OccupiedPartyMember> existing,
  }) {
    final target = existing
        .where((member) => member.id == replaceMemberId)
        .firstOrNull;
    if (target == null) {
      return const PartyReplacementPlan.rejected(
        PartyCompositionFailure.noValidPlacement,
      );
    }

    final occupancy = resolveOccupancy(existing);
    final targetSlot = occupancy[replaceMemberId];
    if (targetSlot == null) {
      return const PartyReplacementPlan.rejected(
        PartyCompositionFailure.noValidPlacement,
      );
    }
    final effective = [
      for (final member in existing)
        member.id == replaceMemberId
            ? OccupiedPartyMember(
                id: member.id,
                className: className,
                role: role,
                partyIndex: targetSlot.partyIndex,
                slotIndex: targetSlot.slotIndex,
                joinedAt: member.joinedAt,
                isLeader: member.isLeader,
              )
            : OccupiedPartyMember(
                id: member.id,
                className: member.className,
                role: member.role,
                partyIndex:
                    occupancy[member.id]?.partyIndex ?? member.partyIndex,
                slotIndex: occupancy[member.id]?.slotIndex ?? member.slotIndex,
                joinedAt: member.joinedAt,
                isLeader: member.isLeader,
              ),
    ];

    final inPlaceFailure = _failureForArrangement(effective);
    if (inPlaceFailure == null) return const PartyReplacementPlan.inPlace();

    if (!target.isLeader) {
      final used = occupancy.values.toSet();
      for (final slot in _allSlots()) {
        if (used.contains(slot)) continue;
        final moved = [
          for (final member in effective)
            member.id == replaceMemberId ? _atSlot(member, slot) : member,
        ];
        if (_failureForArrangement(moved) == null) {
          return PartyReplacementPlan.moveToEmpty(slot);
        }
      }
    }

    for (var leftIndex = 0; leftIndex < effective.length; leftIndex++) {
      final left = effective[leftIndex];
      if (left.isLeader) continue;
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < effective.length;
        rightIndex++
      ) {
        final right = effective[rightIndex];
        if (right.isLeader || left.partyIndex == right.partyIndex) continue;
        final swapped = [...effective];
        swapped[leftIndex] = _atSlot(
          left,
          PartySlot(partyIndex: right.partyIndex, slotIndex: right.slotIndex!),
        );
        swapped[rightIndex] = _atSlot(
          right,
          PartySlot(partyIndex: left.partyIndex, slotIndex: left.slotIndex!),
        );
        if (_failureForArrangement(swapped) == null) {
          return PartyReplacementPlan.inPlaceNeedsRebalance([
            left.id,
            right.id,
          ]);
        }
      }
    }

    return PartyReplacementPlan.rejected(inPlaceFailure);
  }

  OccupiedPartyMember _atSlot(OccupiedPartyMember member, PartySlot slot) =>
      OccupiedPartyMember(
        id: member.id,
        className: member.className,
        role: member.role,
        partyIndex: slot.partyIndex,
        slotIndex: slot.slotIndex,
        joinedAt: member.joinedAt,
        isLeader: member.isLeader,
      );

  PartyCompositionFailure? _failureForArrangement(
    List<OccupiedPartyMember> members,
  ) {
    for (var partyIndex = 0; partyIndex < rules.partyCount; partyIndex++) {
      final party = members.where((member) => member.partyIndex == partyIndex);
      final supports = party
          .where((member) => member.role == PartyRole.support)
          .length;
      final dealers = party.length - supports;
      if (supports > rules.supportsPerParty) {
        return PartyCompositionFailure.supportSlotsFull;
      }
      if (dealers > rules.dealersPerParty) {
        return PartyCompositionFailure.dealerSlotsFull;
      }
      final dealerClasses = <String, int>{};
      for (final member in party.where(
        (member) => member.role == PartyRole.dealer,
      )) {
        dealerClasses.update(
          member.className,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (dealerClasses.values.any(
        (count) => count > rules.maxDealersPerClassPerParty,
      )) {
        return PartyCompositionFailure.duplicateDealerClass;
      }
    }
    return null;
  }

  PartyCompositionFailure? failureForArrangement(
    List<OccupiedPartyMember> members,
  ) => _failureForArrangement(members);

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

  bool _isValidSlot(int partyIndex, int slotIndex) =>
      partyIndex >= 0 &&
      partyIndex < rules.partyCount &&
      slotIndex >= 0 &&
      slotIndex < rules.membersPerParty;

  int _preferredParty(OccupiedPartyMember member) {
    if (member.isLeader) return 0;
    if (member.partyIndex < 0 || member.partyIndex >= rules.partyCount) {
      return 0;
    }
    return member.partyIndex;
  }

  Iterable<PartySlot> _allSlots() sync* {
    for (var partyIndex = 0; partyIndex < rules.partyCount; partyIndex++) {
      for (var slotIndex = 0; slotIndex < rules.membersPerParty; slotIndex++) {
        yield PartySlot(partyIndex: partyIndex, slotIndex: slotIndex);
      }
    }
  }

  Iterable<PartySlot> _fillOrder(OccupiedPartyMember member) sync* {
    if (member.isLeader) {
      yield const PartySlot(partyIndex: 0, slotIndex: 0);
    }
    final preferred = _preferredParty(member);
    for (var slotIndex = 0; slotIndex < rules.membersPerParty; slotIndex++) {
      yield PartySlot(partyIndex: preferred, slotIndex: slotIndex);
    }
    yield* _allSlots();
  }

  int _comparePending(OccupiedPartyMember left, OccupiedPartyMember right) {
    if (left.isLeader != right.isLeader) {
      return left.isLeader ? -1 : 1;
    }
    final leftJoinedAt = left.joinedAt;
    final rightJoinedAt = right.joinedAt;
    if (leftJoinedAt != null && rightJoinedAt != null) {
      final byJoinedAt = leftJoinedAt.compareTo(rightJoinedAt);
      if (byJoinedAt != 0) return byJoinedAt;
    } else if (leftJoinedAt != null) {
      return -1;
    } else if (rightJoinedAt != null) {
      return 1;
    }
    return left.id.compareTo(right.id);
  }
}
