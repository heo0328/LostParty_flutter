import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/auth/api_token_store.dart';
import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_summary.dart';
import '../../domain/repositories/account_repository.dart';

class MyAccountViewModel extends ChangeNotifier {
  MyAccountViewModel({
    required ApiTokenStore apiTokenStore,
    required AccountRepository accountRepository,
  }) : _apiTokenStore = apiTokenStore,
       _accountRepository = accountRepository;

  final ApiTokenStore _apiTokenStore;
  final AccountRepository _accountRepository;

  bool _isLoadingTokenStatus = false;
  bool _isFetchingCharacters = false;
  bool _hasApiToken = false;
  bool _hasFetchedCharacters = false;
  List<CharacterSummary> _characters = const [];
  LostArkApiErrorType? _errorType;

  bool get isLoadingTokenStatus => _isLoadingTokenStatus;
  bool get isFetchingCharacters => _isFetchingCharacters;
  bool get hasApiToken => _hasApiToken;
  bool get hasFetchedCharacters => _hasFetchedCharacters;
  List<CharacterSummary> get characters => _characters;
  LostArkApiErrorType? get errorType => _errorType;

  Future<void> loadTokenStatus() async {
    _isLoadingTokenStatus = true;
    notifyListeners();

    _hasApiToken = await _apiTokenStore.read() != null;
    _isLoadingTokenStatus = false;
    notifyListeners();
  }

  Future<void> fetchCharacters(String characterName) async {
    _isFetchingCharacters = true;
    _errorType = null;
    notifyListeners();

    try {
      _characters = await _accountRepository.fetchCharacters(characterName);
      _hasFetchedCharacters = true;
    } on LostArkApiException catch (error) {
      _errorType = error.type;
      _hasFetchedCharacters = false;
    } finally {
      _isFetchingCharacters = false;
    }

    notifyListeners();
  }
}
