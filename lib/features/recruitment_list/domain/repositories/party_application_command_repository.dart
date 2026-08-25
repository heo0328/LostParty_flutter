import '../entities/party_application_command.dart';

abstract class PartyApplicationCommandRepository {
  Future<PartyApplicationCommandResult> apply(PartyApplyCommand command);
  Future<PartyApplicationCommandResult> withdraw(PartyWithdrawApplicationCommand command);
}
