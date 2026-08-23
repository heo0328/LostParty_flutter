import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
import '../../domain/entities/character_build_draft.dart';
import '../../domain/entities/character_build_snapshot.dart';
import '../../domain/entities/local_game_account.dart';
import '../../domain/repositories/account_repository.dart';

class CharacterDetailViewModel extends ChangeNotifier {
  CharacterDetailViewModel({
    required this.character,
    required AccountRepository accountRepository,
  }) : _accountRepository = accountRepository,
       _selectedRole = _supportClasses.contains(character.characterClassName)
           ? null
           : CharacterBuildRole.dealer;

  static const _supportClasses = {'바드', '발키리', '도화가', '홀리나이트'};

  final LocalAccountCharacter character;
  final AccountRepository _accountRepository;

  bool _isLoading = false;
  bool _isFetchingDraft = false;
  bool _isCommittingDraft = false;
  CharacterBuildRole? _selectedRole;
  CharacterBuildDraft? _draft;
  CharacterBuildRole? _draftRole;
  List<CharacterBuildSnapshot> _snapshots = const [];
  CharacterBuildRole? _preferredRole;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isFetchingDraft => _isFetchingDraft;
  bool get isCommittingDraft => _isCommittingDraft;
  bool get supportsMultipleRoles =>
      _supportClasses.contains(character.characterClassName);
  CharacterBuildRole? get selectedRole => _selectedRole;
  CharacterBuildDraft? get draft => _draft;
  CharacterBuildRole? get draftRole => _draftRole;
  List<CharacterBuildSnapshot> get snapshots => _snapshots;
  String? get errorMessage => _errorMessage;
  CharacterBuildRole? get preferredRole => _preferredRole;
  bool get canSelectPreferredRole =>
      _snapshots.any((item) => item.role == CharacterBuildRole.dealer) &&
      _snapshots.any((item) => item.role == CharacterBuildRole.support);

  CharacterBuildSnapshot? get selectedSnapshot {
    final role = _selectedRole;
    if (role == null) {
      return null;
    }
    for (final snapshot in _snapshots) {
      if (snapshot.role == role) {
        return snapshot;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _snapshots = await _accountRepository.loadCharacterBuildSnapshots(
        character.id,
      );
      _preferredRole = character.preferredRole;
      if (_preferredRole == null && canSelectPreferredRole) {
        _preferredRole = CharacterBuildRole.support;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPreferredRole(CharacterBuildRole role) async {
    if (!canSelectPreferredRole || _preferredRole == role) return;
    await _accountRepository.setPreferredCharacterRole(
      characterId: character.id,
      role: role,
    );
    _preferredRole = role;
    notifyListeners();
  }

  void selectRole(CharacterBuildRole role) {
    if (!supportsMultipleRoles && role != CharacterBuildRole.dealer) {
      return;
    }
    _selectedRole = role;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> requestBuildDraft() async {
    final role = _selectedRole;
    if (role == null || _isFetchingDraft || _isCommittingDraft) {
      return;
    }
    _isFetchingDraft = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _draft = await _accountRepository.createCharacterBuildDraft(
        characterId: character.id,
        characterName: character.characterName,
      );
      _draftRole = role;
    } on LostArkApiException catch (error) {
      _errorMessage = _messageFor(error.type);
    } catch (_) {
      _errorMessage = '세팅 데이터를 조회하지 못했습니다.';
    } finally {
      _isFetchingDraft = false;
      notifyListeners();
    }
  }

  void selectDraftRole(CharacterBuildRole role) {
    if (_draft == null || _isCommittingDraft) {
      return;
    }
    if (!supportsMultipleRoles && role != CharacterBuildRole.dealer) {
      return;
    }
    _draftRole = role;
    _errorMessage = null;
    notifyListeners();
  }

  void cancelDraft() {
    if (_isCommittingDraft) {
      return;
    }
    _draft = null;
    _draftRole = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> commitDraft() async {
    final currentDraft = _draft;
    final role = _draftRole;
    if (currentDraft == null || role == null || _isCommittingDraft) {
      return false;
    }
    _isCommittingDraft = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _accountRepository.commitCharacterBuildDraft(
        draft: currentDraft,
        role: role,
      );
      _snapshots = await _accountRepository.loadCharacterBuildSnapshots(
        character.id,
      );
      _selectedRole = role;
      if (_preferredRole == null && canSelectPreferredRole) {
        await _accountRepository.setPreferredCharacterRole(
          characterId: character.id,
          role: role,
        );
        _preferredRole = role;
      }
      _draft = null;
      _draftRole = null;
      return true;
    } on LostArkApiException catch (error) {
      _errorMessage = _messageFor(error.type);
      return false;
    } catch (_) {
      _errorMessage = '세팅 데이터를 저장하지 못했습니다.';
      return false;
    } finally {
      _isCommittingDraft = false;
      notifyListeners();
    }
  }

  String _messageFor(LostArkApiErrorType type) {
    return switch (type) {
      LostArkApiErrorType.missingToken => 'API 토큰이 등록되어 있지 않습니다.',
      LostArkApiErrorType.unauthorized => 'API 토큰을 확인해 주세요.',
      LostArkApiErrorType.notFound => '캐릭터 상세 정보를 찾을 수 없습니다.',
      LostArkApiErrorType.rateLimited => 'API 호출 제한에 도달했습니다. 잠시 후 다시 시도해 주세요.',
      LostArkApiErrorType.timeout => 'API 요청 시간이 초과되었습니다.',
      LostArkApiErrorType.server => 'Lost Ark API 서버 오류가 발생했습니다.',
      LostArkApiErrorType.invalidResponse => '상세 데이터 형식을 확인할 수 없습니다.',
      LostArkApiErrorType.network => '네트워크 연결을 확인해 주세요.',
      LostArkApiErrorType.cancelled => 'API 요청이 취소되었습니다.',
      LostArkApiErrorType.unknown => '알 수 없는 API 오류가 발생했습니다.',
    };
  }
}
