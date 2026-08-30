import '../entities/group_request_character.dart';

const groupCharacterSearchPageSize = 20;

/// 계약 §6·§12.6. 초대 대상은 active Character의 정확한 이름 한 건만 조회한다.
/// prefix 검색과 전체 스캔은 사용하지 않는다.
abstract interface class GroupCharacterSearchRepository {
  Future<List<GroupRequestCharacter>> searchActiveCharactersByExactName(
    String characterName, {
    int limit,
  });
}
