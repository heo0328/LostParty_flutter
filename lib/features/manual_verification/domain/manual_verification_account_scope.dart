import 'entities/manual_verification_request.dart';

bool isSameManualVerificationAccount({
  required ManualVerificationRequest request,
  required int localAccountId,
  required String? serverGameAccountId,
  required Set<String> rosterIdentityKeys,
}) {
  if (request.localAccountId == localAccountId) return true;
  final storedAccountId = request.targetGameAccountId ?? request.serverGameAccountId;
  if (serverGameAccountId != null &&
      storedAccountId != null &&
      storedAccountId == serverGameAccountId) {
    return true;
  }
  return rosterIdentityKeys.contains(request.targetIdentityKey);
}
