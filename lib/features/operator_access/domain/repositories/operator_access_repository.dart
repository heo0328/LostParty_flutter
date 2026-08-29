import '../entities/operator_user.dart';
import '../entities/operator_write_readiness.dart';

abstract interface class OperatorAccessRepository {
  Future<bool> isCurrentPlayerOperator();

  Future<OperatorWriteReadiness> loadWriteReadiness();

  Future<List<OperatorUserSummary>> loadUsers({int limit = 50});

  Future<OperatorUserDetail?> loadUserDetail(String playerId);
}
