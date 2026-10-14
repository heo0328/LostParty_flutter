import '../server_account_models.dart';

/// Names describe display position; account identifiers remain unchanged.
class AccountLabelPolicy {
  /// Input must be the complete list in the server's stable GET order.
  static Map<String, String> serverLabels(
    Iterable<ServerAccountRegistration> accounts,
  ) {
    var subAccountNumber = 0;
    return Map.unmodifiable({
      for (final account in accounts)
        account.registrationId: display(
          customLabel: account.label,
          isMain: account.isMain,
          subAccountNumber: account.isMain ? 0 : ++subAccountNumber,
        ),
    });
  }

  static String display({
    required String? customLabel,
    required bool isMain,
    required int subAccountNumber,
  }) {
    if (customLabel != null && customLabel.trim().isNotEmpty) {
      return customLabel;
    }
    return isMain ? '메인 계정' : '부계정 $subAccountNumber';
  }
}
