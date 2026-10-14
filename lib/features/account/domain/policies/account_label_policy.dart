/// Names describe display position; account identifiers remain unchanged.
class AccountLabelPolicy {
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
