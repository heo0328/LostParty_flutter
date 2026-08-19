import 'package:flutter/foundation.dart';

import '../../../../shared/lost_ark_api/client/lost_ark_api_exception.dart';
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
  bool _isRefreshing = false;
  CharacterBuildRole? _selectedRole;
  List<CharacterBuildSnapshot> _snapshots = const [];
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get supportsMultipleRoles =>
      _supportClasses.contains(character.characterClassName);
  CharacterBuildRole? get selectedRole => _selectedRole;
  List<CharacterBuildSnapshot> get snapshots => _snapshots;
  String? get errorMessage => _errorMessage;

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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectRole(CharacterBuildRole role) {
    if (!supportsMultipleRoles && role != CharacterBuildRole.dealer) {
      return;
    }
    _selectedRole = role;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshSelectedRole() async {
    final role = _selectedRole;
    if (role == null || _isRefreshing) {
      return;
    }
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _accountRepository.refreshCharacterBuildSnapshot(
        characterId: character.id,
        characterName: character.characterName,
        role: role,
      );
      _snapshots = await _accountRepository.loadCharacterBuildSnapshots(
        character.id,
      );
    } on LostArkApiException catch (error) {
      _errorMessage = _messageFor(error.type);
    } catch (_) {
      _errorMessage = '세팅 데이터를 저장하지 못했습니다.';
    } finally {
      _isRefreshing = false;
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
