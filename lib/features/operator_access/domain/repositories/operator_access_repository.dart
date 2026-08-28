import '../entities/operator_user.dart';

abstract interface class OperatorAccessRepository {
  Future<bool> isCurrentPlayerOperator();

  Future<List<OperatorUserSummary>> loadUsers({int limit = 50});

  Future<OperatorUserDetail?> loadUserDetail(String playerId);
}
