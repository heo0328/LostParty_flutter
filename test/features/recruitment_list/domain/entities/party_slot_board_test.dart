import 'package:flutter_test/flutter_test.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_recruitment.dart';

void main() {
  test('정원 전체 슬롯을 만들고 점유·빈자리·미정 멤버를 구분한다', () {
    const occupied = PartyMemberDisplay(
      playerId: 'player-leader',
      characterName: '리더',
      className: '블레이드',
      role: PartyRole.dealer,
      partyIndex: 0,
      slotIndex: 0,
    );
    const unassigned = PartyMemberDisplay(
      playerId: 'player-old',
      characterName: '이전멤버',
      className: '바드',
      role: PartyRole.support,
      partyIndex: 1,
    );

    final board = PartySlotBoard.fromMembers(
      members: const [occupied, unassigned],
      membersPerParty: 4,
      maxMemberCount: 8,
    );

    expect(board.partyCount, 2);
    expect(board.cells, hasLength(8));
    expect(board.cells.first.isLeaderSeat, isTrue);
    expect(board.cells.first.member?.characterName, '리더');
    expect(
      board.cells.where((cell) => cell.isOccupied),
      hasLength(1),
    );
    expect(board.unassignedMembers.single.characterName, '이전멤버');
    expect(board.cellsForParty(1).every((cell) => !cell.isOccupied), isTrue);
  });

  test('저장된 자리는 다른 멤버를 당기지 않는다', () {
    const lateJoin = PartyMemberDisplay(
      playerId: 'player-late',
      characterName: '후발',
      className: '워로드',
      role: PartyRole.dealer,
      partyIndex: 0,
      slotIndex: 3,
    );

    final board = PartySlotBoard.fromMembers(
      members: const [lateJoin],
      membersPerParty: 4,
      maxMemberCount: 4,
    );

    expect(board.partyCount, 1);
    expect(board.cells[0].member, isNull);
    expect(board.cells[3].member?.characterName, '후발');
  });
}
