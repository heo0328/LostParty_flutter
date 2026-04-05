import '../entities/party_recruitment.dart';

abstract class RecruitmentListRepository {
  Future<List<PartyRecruitment>> getRecruitments();
}