import '../../../recruitment_list/domain/entities/party_event.dart';

enum PartyEventReadFailureType {
  unauthenticated,
  playerBindingMissing,
  permissionDenied,
  unavailable,
  contract,
  unknown,
}

class PartyEventReadException implements Exception {
  const PartyEventReadException(this.type);

  final PartyEventReadFailureType type;
}

/// 현재 Player의 자기 이벤트만 읽는다. UI·unread·Drift와 연결하지 않는다.
abstract class PartyEventReadRepository {
  /// [occurredAt] 내림차순으로 최근 [limit]개를 일회 조회한다.
  Future<List<PartyEvent>> loadRecentEvents({
    required String playerId,
    int limit = 20,
  });
}
