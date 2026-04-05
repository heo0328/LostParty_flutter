import '../../domain/entities/party_recruitment.dart';
import '../../domain/repositories/recruitment_list_repository.dart';
import '../datasources/local_recruitment_list_data_source.dart';

class RecruitmentListRepositoryImpl implements RecruitmentListRepository {
  final LocalRecruitmentListDataSource localDataSource;

  RecruitmentListRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<List<PartyRecruitment>> getRecruitments() {
    return localDataSource.fetchRecruitments();
  }
}