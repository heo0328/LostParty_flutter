import '../entities/account_recovery_status.dart';

abstract class AccountRecoveryRepository {
  Future<AccountRecoveryStatus> loadStatus();

  Future<AccountRecoveryLinkResult> linkGoogle();
}
