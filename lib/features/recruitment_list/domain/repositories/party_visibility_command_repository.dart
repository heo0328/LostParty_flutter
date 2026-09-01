import '../entities/party_visibility_command.dart';

abstract interface class PartyVisibilityCommandRepository {
  Future<PartyVisibilityResult> setVisibility(PartyVisibilityCommand command);
}
