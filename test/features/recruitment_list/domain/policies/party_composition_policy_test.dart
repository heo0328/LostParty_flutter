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
