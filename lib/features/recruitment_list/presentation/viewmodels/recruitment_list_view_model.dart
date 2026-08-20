import 'package:flutter/foundation.dart';

import '../../data/datasources/local_recruitment_list_data_source.dart';
import '../../data/repositories/recruitment_list_repository_impl.dart';
import '../../domain/entities/party_recruitment.dart';
import '../../domain/repositories/recruitment_list_repository.dart';

class RecruitmentListViewModel extends ChangeNotifier {
  final RecruitmentListRepository _repository;

  RecruitmentListViewModel({required RecruitmentListRepository repository})
    : _repository = repository;

  factory RecruitmentListViewModel.local() {
    return RecruitmentListViewModel(
      repository: RecruitmentListRepositoryImpl(
        localDataSource: LocalRecruitmentListDataSource(),
      ),
    );
  }

  List<PartyRecruitment> _recruitments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PartyRecruitment> get recruitments => _recruitments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadRecruitments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recruitments = await _repository.getRecruitments();
    } catch (_) {
      _errorMessage = 'Failed to load recruitments.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
