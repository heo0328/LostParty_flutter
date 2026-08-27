import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/data/mappers/party_complete_claim_write_plan.dart';

void main() {
  test('partyOwner Claim은 출처와 회차 revision을 저장한다', () {
    final claim = PartyCompleteClaimWritePlan.partyOwnerClaim(
      playerId: 'player-1',
      characterId: 'abcdefghijklmnopqrst',
      raidId: 'act4',
      cycleKey: '2026-08-19',
      difficultyId: 'normal',
      sourceRecruitmentId: 'recruitment-1',
      sourceCompletionRevision: 2,
      cycleStartedAt: Object(),
      cycleEndsAt: Object(),
      serverTimestamp: Object(),
    );

    expect(claim['source'], 'partyOwner');
    expect(claim['sourceRecruitmentId'], 'recruitment-1');
    expect(claim['sourceCompletionRevision'], 2);
  });

  test('membershipMatchesSnapshot은 역할과 슬롯까지 비교한다', () {
    final membership = {
      'characterId': 'abcdefghijklmnopqrst',
      'role': 'dealer',
      'partyIndex': 0,
      'slotIndex': 1,
    };
    const snapshot = {
      'playerId': 'player-1',
      'characterId': 'abcdefghijklmnopqrst',
      'role': 'dealer',
      'partyIndex': 0,
      'slotIndex': 1,
    };

    expect(
      PartyCompleteClaimWritePlan.membershipMatchesSnapshot(
        membership,
        snapshot,
      ),
      isTrue,
    );
    expect(
      PartyCompleteClaimWritePlan.membershipMatchesSnapshot(
        {...membership, 'slotIndex': 2},
        snapshot,
      ),
      isFalse,
    );
  });

  test('claimMatchesPartyComplete는 partyOwner 출처와 revision을 검증한다', () {
    expect(
      PartyCompleteClaimWritePlan.claimMatchesPartyComplete(
        claim: const {
          'source': 'partyOwner',
          'sourceRecruitmentId': 'recruitment-1',
          'sourceCompletionRevision': 1,
        },
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 1,
      ),
      isTrue,
    );
    expect(
      PartyCompleteClaimWritePlan.claimMatchesPartyComplete(
        claim: const {
          'source': 'manual',
          'sourceRecruitmentId': 'recruitment-1',
          'sourceCompletionRevision': 1,
        },
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 1,
      ),
      isFalse,
    );
  });

  test('claimWriteAction은 같은 방의 이전 partyOwner Claim을 교체한다', () {
    expect(
      PartyCompleteClaimWritePlan.claimWriteAction(
        existing: null,
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 3,
      ),
      PartyCompleteClaimWriteAction.create,
    );
    expect(
      PartyCompleteClaimWritePlan.claimWriteAction(
        existing: const {
          'source': 'partyOwner',
          'sourceRecruitmentId': 'recruitment-1',
          'sourceCompletionRevision': 1,
        },
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 3,
      ),
      PartyCompleteClaimWriteAction.replace,
    );
    expect(
      PartyCompleteClaimWritePlan.claimWriteAction(
        existing: const {
          'source': 'partyOwner',
          'sourceRecruitmentId': 'recruitment-1',
          'sourceCompletionRevision': 3.0,
        },
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 3,
      ),
      PartyCompleteClaimWriteAction.skip,
    );
    expect(
      PartyCompleteClaimWritePlan.claimWriteAction(
        existing: const {
          'source': 'manual',
          'sourceRecruitmentId': 'recruitment-1',
          'sourceCompletionRevision': 1,
        },
        recruitmentId: 'recruitment-1',
        sourceCompletionRevision: 3,
      ),
      PartyCompleteClaimWriteAction.skip,
    );
  });

  test('restoredAssignment은 join plan과 같은 점유 필드를 쓴다', () {
    final assignment = PartyCompleteClaimWritePlan.restoredAssignment(
      playerId: 'player-1',
      characterId: 'abcdefghijklmnopqrst',
      raidId: 'act4',
      recruitmentId: 'recruitment-1',
      cycleKey: '2026-08-19',
      role: 'support',
      serverTimestamp: Object(),
    );

    expect(assignment['schemaVersion'], 1);
    expect(assignment['playerId'], 'player-1');
    expect(assignment['recruitmentId'], 'recruitment-1');
    expect(assignment['cycleKey'], '2026-08-19');
    expect(assignment['role'], 'support');
  });
}
