import '../entities/party_create_command.dart';

abstract class PartyCreateRepository {
  Future<PartyCreateResult> create(PartyCreateCommand command);
}
