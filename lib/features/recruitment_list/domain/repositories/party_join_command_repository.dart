import '../entities/party_join_command.dart';

abstract interface class PartyJoinCommandRepository {
  Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command);
  Future<PartyJoinResult> approve(PartyDecideApplicationCommand command);
  Future<PartyJoinResult> reject(PartyDecideApplicationCommand command);
}
