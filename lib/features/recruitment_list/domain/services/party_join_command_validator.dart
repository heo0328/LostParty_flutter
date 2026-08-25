import '../entities/party_join_command.dart';

class PartyJoinCommandValidator {
  const PartyJoinCommandValidator();

  PartyJoinFailure? validateDirectJoin(PartyDirectJoinCommand command) =>
      _invalidId(command.recruitmentId) ||
              _invalidId(command.characterId) ||
              command.cycleKey.trim().isEmpty ||
              command.expectedRecruitmentRevision < 1
          ? PartyJoinFailure.invalidRequest
          : null;

  PartyJoinFailure? validateDecision(PartyDecideApplicationCommand command) =>
      _invalidId(command.recruitmentId) ||
              _invalidId(command.applicantPlayerId) ||
              command.expectedApplicationRevision < 1 ||
              command.expectedRecruitmentRevision < 1
          ? PartyJoinFailure.invalidRequest
          : null;

  bool _invalidId(String value) => value.trim().isEmpty || value.contains('/');
}
