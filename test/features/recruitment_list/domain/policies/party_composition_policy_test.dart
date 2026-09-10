import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';
import 'package:lost_party/features/recruitment_list/domain/policies/party_composition_policy.dart';
import 'package:lost_party/shared/raid_catalog/domain/entities/raid_catalog.dart';

void main() {
  group('RecruitmentPartyRules', () {
    test('4인과 8인 카탈로그 기준을 파티별 규칙으로 변환한다', () {
      final fourPlayerRules = RecruitmentPartyRules.fromRaid(
        _raid(partySize: 4),
      );
      final eightPlayerRules = RecruitmentPartyRules.fromRaid(
        _raid(
          partySize: 8,
          partyCount: 2,
          requiredSupportCount: 2,
          maxDealerCountPerClass: 2,
        ),
      );

      expect(fourPlayerRules.dealersPerParty, 3);
      expect(fourPlayerRules.supportsPerParty, 1);
      expect(eightPlayerRules.partyCount, 2);
      expect(eightPlayerRules.dealersPerParty, 3);
      expect(eightPlayerRules.supportsPerParty, 1);
      expect(eightPlayerRules.maxDealersPerClassPerParty, 1);
    });
  });

  group('PartyCompositionPolicy', () {
    test('4인은 딜러 3명과 서포터 1명을 배치한다', () {
      final decision = _fourPlayerPolicy.arrange([
        _member('d1', '발키리'),
        _member('d2', '바드'),
        _member('d3', '블레이드'),
        _member('s1', '발키리', role: PartyRole.support),
      ]);

      expect(decision.canJoin, isTrue);
      expect(decision.assignments.values.toSet(), {0});
    });

    test('같은 직업의 딜러와 서포터는 함께 배치한다', () {
      final decision = _fourPlayerPolicy.arrange([
        _member('dealer', '발키리'),
        _member('support', '발키리', role: PartyRole.support),
      ]);

      expect(decision.canJoin, isTrue);
    });

    test('4인 파티의 동일 직업 딜러 중복은 거절한다', () {
      final decision = _fourPlayerPolicy.arrange([
        _member('d1', '발키리'),
        _member('d2', '발키리'),
      ]);

      expect(decision.canJoin, isFalse);
      expect(decision.failure, PartyCompositionFailure.duplicateDealerClass);
    });

    test('8인은 같은 직업 딜러 2명을 서로 다른 파티에 배치한다', () {
      final decision = _eightPlayerPolicy.arrange([
        _member('d1', '발키리'),
        _member('d2', '발키리'),
      ]);

      expect(decision.canJoin, isTrue);
      expect(decision.assignments['d1'], isNot(decision.assignments['d2']));
    });

    test('8인의 같은 직업 딜러 3명은 거절한다', () {
      final decision = _eightPlayerPolicy.arrange([
        _member('d1', '발키리'),
        _member('d2', '발키리'),
        _member('d3', '발키리'),
      ]);

      expect(decision.canJoin, isFalse);
      expect(decision.failure, PartyCompositionFailure.duplicateDealerClass);
    });

    test('8인에서 이미 같은 직업 딜러 2명이면 세 번째 가입을 거절한다', () {
      final decision = _eightPlayerPolicy.assignEmptySlot(
        joining: _occupied('d3', '발키리'),
        existing: [
          _occupied('d1', '발키리', partyIndex: 0, slotIndex: 0, isLeader: true),
          _occupied('d2', '발키리', partyIndex: 1, slotIndex: 0),
        ],
      );

      expect(decision.canJoin, isFalse);
      expect(decision.failure, PartyCompositionFailure.duplicateDealerClass);
    });

    test('8인은 서포터 2명을 각각 다른 파티에 배치한다', () {
      final decision = _eightPlayerPolicy.arrange([
        _member('s1', '바드', role: PartyRole.support),
        _member('s2', '발키리', role: PartyRole.support),
      ]);

      expect(decision.canJoin, isTrue);
      expect(decision.assignments['s1'], isNot(decision.assignments['s2']));
    });

    test('역할별 자리와 전체 정원을 넘으면 거절한다', () {
      final supports = List.generate(
        2,
        (index) => _member('s$index', '바드$index', role: PartyRole.support),
      );
      final tooManyMembers = List.generate(
        5,
        (index) => _member('d$index', '직업$index'),
      );

      expect(
        _fourPlayerPolicy.arrange(supports).failure,
        PartyCompositionFailure.supportSlotsFull,
      );
      expect(
        _fourPlayerPolicy.arrange(tooManyMembers).failure,
        PartyCompositionFailure.partyFull,
      );
    });

    test('동일한 멤버 ID는 중복 신청으로 거절한다', () {
      final decision = _fourPlayerPolicy.arrange([
        _member('same', '바드'),
        _member('same', '블레이드'),
      ]);

      expect(decision.failure, PartyCompositionFailure.duplicateMember);
    });
  });

  group('PartyCompositionPolicy 고정 슬롯', () {
    test('기존 멤버 자리를 유지하고 빈 슬롯만 배정한다', () {
      final existing = [
        _occupied(
          'leader',
          '블레이드',
          partyIndex: 0,
          slotIndex: 0,
          isLeader: true,
        ),
        _occupied('d2', '소서리스', partyIndex: 0, slotIndex: 2),
      ];

      final occupancy = _fourPlayerPolicy.resolveOccupancy(existing);
      expect(occupancy['leader'], const PartySlot(partyIndex: 0, slotIndex: 0));
      expect(occupancy['d2'], const PartySlot(partyIndex: 0, slotIndex: 2));

      final decision = _fourPlayerPolicy.assignEmptySlot(
        joining: _occupied('s1', '바드', role: PartyRole.support),
        existing: existing,
      );

      expect(decision.canJoin, isTrue);
      expect(decision.slot, const PartySlot(partyIndex: 0, slotIndex: 1));
      expect(
        decision.occupancy['d2'],
        const PartySlot(partyIndex: 0, slotIndex: 2),
      );
    });

    test('slotIndex가 없는 기존 멤버는 리더·가입 시각·ID 순으로 자리를 채운다', () {
      final occupancy = _fourPlayerPolicy.resolveOccupancy([
        _occupied('member-b', '소서리스', joinedAt: DateTime.utc(2026, 8, 26, 10)),
        _occupied(
          'leader',
          '블레이드',
          isLeader: true,
          joinedAt: DateTime.utc(2026, 8, 26, 9),
        ),
        _occupied(
          'member-a',
          '바드',
          role: PartyRole.support,
          joinedAt: DateTime.utc(2026, 8, 26, 10),
        ),
      ]);

      expect(occupancy['leader'], const PartySlot(partyIndex: 0, slotIndex: 0));
      expect(
        occupancy['member-a'],
        const PartySlot(partyIndex: 0, slotIndex: 1),
      );
      expect(
        occupancy['member-b'],
        const PartySlot(partyIndex: 0, slotIndex: 2),
      );
    });

    test('가입 시각이 같으면 문서 순서가 아니라 playerId로 자리를 정한다', () {
      final joinedAt = DateTime.utc(2026, 8, 26, 12);
      final occupancy = _fourPlayerPolicy.resolveOccupancy([
        _occupied('zeta', '소서리스', joinedAt: joinedAt),
        _occupied(
          'leader',
          '블레이드',
          isLeader: true,
          joinedAt: DateTime.utc(2026, 8, 26, 11),
        ),
        _occupied('alpha', '워로드', joinedAt: joinedAt),
      ]);

      expect(occupancy['alpha'], const PartySlot(partyIndex: 0, slotIndex: 1));
      expect(occupancy['zeta'], const PartySlot(partyIndex: 0, slotIndex: 2));
    });

    test('8인에서 같은 직업 딜러는 다른 파티의 빈 슬롯으로 보낸다', () {
      final decision = _eightPlayerPolicy.assignEmptySlot(
        joining: _occupied('d2', '발키리'),
        existing: [
          _occupied('d1', '발키리', partyIndex: 0, slotIndex: 0, isLeader: true),
        ],
      );

      expect(decision.canJoin, isTrue);
      expect(decision.slot, const PartySlot(partyIndex: 1, slotIndex: 0));
      expect(
        decision.occupancy['d1'],
        const PartySlot(partyIndex: 0, slotIndex: 0),
      );
    });

    test('8인에서 파티 번호를 유지하고 넘치는 인원만 다른 파티로 보낸다', () {
      final occupancy = _eightPlayerPolicy.resolveOccupancy([
        _occupied('leader', '블레이드', isLeader: true),
        _occupied('a', '워로드', joinedAt: DateTime.utc(2026, 8, 26, 1)),
        _occupied('b', '소서리스', joinedAt: DateTime.utc(2026, 8, 26, 2)),
        _occupied('c', '기공사', joinedAt: DateTime.utc(2026, 8, 26, 3)),
        _occupied(
          'd',
          '바드',
          role: PartyRole.support,
          joinedAt: DateTime.utc(2026, 8, 26, 4),
        ),
      ]);

      expect(occupancy['leader']!.partyIndex, 0);
      expect(occupancy['leader']!.slotIndex, 0);
      expect(
        {
          occupancy['a'],
          occupancy['b'],
          occupancy['c'],
        }.every((slot) => slot?.partyIndex == 0),
        isTrue,
      );
      expect(occupancy['d'], const PartySlot(partyIndex: 1, slotIndex: 0));
    });

    test('이미 있는 파티의 저장 자리는 당기지 않는다', () {
      final occupancy = _eightPlayerPolicy.resolveOccupancy([
        _occupied(
          'leader',
          '블레이드',
          partyIndex: 0,
          slotIndex: 0,
          isLeader: true,
        ),
        _occupied('late', '바드', role: PartyRole.support, partyIndex: 1),
      ]);

      expect(occupancy['late'], const PartySlot(partyIndex: 1, slotIndex: 0));
    });

    test('slotIndex가 없는 리더 방에서는 신규 가입이 공대장 자리를 쓰지 않는다', () {
      final decision = _fourPlayerPolicy.assignEmptySlot(
        joining: _occupied('member', '소서리스'),
        existing: [_occupied('leader', '블레이드', isLeader: true)],
      );

      expect(decision.canJoin, isTrue);
      expect(decision.slot, const PartySlot(partyIndex: 0, slotIndex: 1));
      expect(
        decision.occupancy['leader'],
        const PartySlot(partyIndex: 0, slotIndex: 0),
      );
    });

    test('역할 정원을 넘기면 기존 자리를 바꾸지 않고 거절한다', () {
      final existing = [
        _occupied(
          'leader',
          '바드',
          role: PartyRole.support,
          partyIndex: 0,
          slotIndex: 0,
          isLeader: true,
        ),
      ];
      final decision = _fourPlayerPolicy.assignEmptySlot(
        joining: _occupied('s2', '도화가', role: PartyRole.support),
        existing: existing,
      );

      expect(decision.canJoin, isFalse);
      expect(decision.failure, PartyCompositionFailure.supportSlotsFull);
      expect(
        _fourPlayerPolicy.resolveOccupancy(existing)['leader'],
        const PartySlot(partyIndex: 0, slotIndex: 0),
      );
    });
  });

  group('PartyCompositionPolicy 자리 유지 교체', () {
    test('같은 파티의 동일 딜러 직업 교체는 거절한다', () {
      final failure = _fourPlayerPolicy.failureForInPlaceReplacement(
        replaceMemberId: 'member',
        className: '발키리',
        role: PartyRole.dealer,
        existing: [
          _occupied(
            'leader',
            '발키리',
            partyIndex: 0,
            slotIndex: 0,
            isLeader: true,
          ),
          _occupied('member', '소서리스', partyIndex: 0, slotIndex: 1),
        ],
      );

      expect(failure, PartyCompositionFailure.duplicateDealerClass);
    });

    test('다른 파티에 같은 딜러 직업이 있어도 자리 유지 교체는 허용한다', () {
      final failure = _eightPlayerPolicy.failureForInPlaceReplacement(
        replaceMemberId: 'member',
        className: '발키리',
        role: PartyRole.dealer,
        existing: [
          _occupied(
            'leader',
            '발키리',
            partyIndex: 0,
            slotIndex: 0,
            isLeader: true,
          ),
          _occupied('member', '소서리스', partyIndex: 1, slotIndex: 0),
        ],
      );

      expect(failure, isNull);
    });
  });
}

final _fourPlayerPolicy = PartyCompositionPolicy(
  RecruitmentPartyRules.fromRaid(_raid(partySize: 4)),
);

final _eightPlayerPolicy = PartyCompositionPolicy(
  RecruitmentPartyRules.fromRaid(
    _raid(
      partySize: 8,
      partyCount: 2,
      requiredSupportCount: 2,
      maxDealerCountPerClass: 2,
    ),
  ),
);

PartyCompositionMember _member(
  String id,
  String className, {
  PartyRole role = PartyRole.dealer,
}) => PartyCompositionMember(id: id, className: className, role: role);

OccupiedPartyMember _occupied(
  String id,
  String className, {
  PartyRole role = PartyRole.dealer,
  int partyIndex = 0,
  int? slotIndex,
  DateTime? joinedAt,
  bool isLeader = false,
}) => OccupiedPartyMember(
  id: id,
  className: className,
  role: role,
  partyIndex: partyIndex,
  slotIndex: slotIndex,
  joinedAt: joinedAt,
  isLeader: isLeader,
);

RaidDefinition _raid({
  required int partySize,
  int partyCount = 1,
  int requiredSupportCount = 1,
  int maxDealerCountPerClass = 1,
}) => RaidDefinition(
  raidId: 'raid',
  officialName: '레이드',
  displayName: '레이드',
  aliases: const [],
  partySize: partySize,
  partyCount: partyCount,
  requiredSupportCount: requiredSupportCount,
  maxDealerCountPerClass: maxDealerCountPerClass,
  gateCount: 2,
  isActive: true,
  difficulties: const [],
);
