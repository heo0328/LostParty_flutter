import 'package:flutter/foundation.dart';

import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/repositories/recruitment_state_repository.dart';

class RecruitmentListViewModel extends ChangeNotifier {
  RecruitmentListViewModel({required RecruitmentStateRepository repository})
    : _repository = repository {
    if (repository case final Listenable listenable) {
      listenable.addListener(_onRepositoryChanged);
    }
  }
  final RecruitmentStateRepository _repository;
  List<PublicRecruitmentSummary> _recruitments = const [];
  bool _isLoading = false;
  String? _errorMessage;
  List<PublicRecruitmentSummary> get recruitments => _recruitments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  void _onRepositoryChanged() => loadRecruitments();

  @override
  void dispose() {
    if (_repository case final Listenable listenable) {
      listenable.removeListener(_onRepositoryChanged);
    }
    super.dispose();
  }

  Future<void> loadRecruitments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _recruitments = await _repository.getPublicRecruitments();
    } catch (_) {
      _errorMessage = '모집 목록을 불러오지 못했습니다.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
