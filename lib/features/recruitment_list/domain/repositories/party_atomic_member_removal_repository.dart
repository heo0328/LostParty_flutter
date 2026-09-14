import '../entities/party_atomic_command.dart';
import '../entities/party_membership_command.dart';

abstract interface class PartyAtomicMemberRemovalRepository {
  Future<PartyMembershipResult> remove(
    PartyRemoveMemberCommand command,
    PartyAtomicMemberRemovalType type,
  );
}
