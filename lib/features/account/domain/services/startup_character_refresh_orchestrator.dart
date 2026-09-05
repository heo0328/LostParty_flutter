import 'dart:async';

import '../entities/character_auto_refresh_result.dart';
import '../entities/local_game_account.dart';
import '../repositories/account_repository.dart';
import '../repositories/nice_group_auto_refresh_settings_repository.dart';
import 'character_auto_refresh_coordinator.dart';
import 'nice_group_policy.dart';
import 'startup_character_refresh_eligibility_policy.dart';

enum StartupCharacterRefreshPhase { idle, running, completed }

class StartupCharacterRefreshState {
  const StartupCharacterRefreshState({
    required this.phase,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
  });

  const StartupCharacterRefreshState.idle()
    : this(
        phase: StartupCharacterRefreshPhase.idle,
        totalCount: 0,
        completedCount: 0,
        failedCount: 0,
      );

  final StartupCharacterRefreshPhase phase;
  final int totalCount;
  final int completedCount;
  final int failedCount;

  bool get isRunning => phase == StartupCharacterRefreshPhase.running;
}

class StartupCharacterRefreshItemResult {
  const StartupCharacterRefreshItemResult({
    required this.character,
    this.result,
    this.error,
  });

  final LocalAccountCharacter character;
  final CharacterAutoRefreshResult? result;
  final Object? error;

  bool get isSuccess => error == null && result?.canProceed == true;
}

class StartupCharacterRefreshReport {
  const StartupCharacterRefreshReport({
    required this.items,
    this.fatalError,
  });

  final List<StartupCharacterRefreshItemResult> items;
  final Object? fatalError;

  int get totalCount => items.length;
  int get completedCount => items.length;
  int get failedCount =>
      items.where((item) => !item.isSuccess).length + (fatalError == null ? 0 : 1);
}

abstract interface class StartupCharacterRefreshRunner {
  StartupCharacterRefreshState get state;
  Stream<StartupCharacterRefreshState> get states;
  Future<StartupCharacterRefreshReport> runOnce();
  Future<void> dispose();
}

class StartupCharacterRefreshOrchestrator
    implements StartupCharacterRefreshRunner {
  StartupCharacterRefreshOrchestrator({
    required String playerId,
    required AccountRepository accountRepository,
    required NiceGroupAutoRefreshSettingsRepository
    niceGroupAutoRefreshSettingsRepository,
    required CharacterAutoRefreshGateway refreshGateway,
    StartupCharacterRefreshEligibilityPolicy eligibilityPolicy =
        const StartupCharacterRefreshEligibilityPolicy(),
    NiceGroupPolicy niceGroupPolicy = const NiceGroupPolicy(),
  }) : _playerId = playerId.trim(),
       _accountRepository = accountRepository,
       _niceGroupAutoRefreshSettingsRepository =
           niceGroupAutoRefreshSettingsRepository,
       _refreshGateway = refreshGateway,
       _eligibilityPolicy = eligibilityPolicy,
       _niceGroupPolicy = niceGroupPolicy;

  final String _playerId;
  final AccountRepository _accountRepository;
  final NiceGroupAutoRefreshSettingsRepository
  _niceGroupAutoRefreshSettingsRepository;
  final CharacterAutoRefreshGateway _refreshGateway;
  final StartupCharacterRefreshEligibilityPolicy _eligibilityPolicy;
  final NiceGroupPolicy _niceGroupPolicy;

  final StreamController<StartupCharacterRefreshState> _stateController =
      StreamController<StartupCharacterRefreshState>.broadcast(sync: true);
  StartupCharacterRefreshState _state =
      const StartupCharacterRefreshState.idle();
  Future<StartupCharacterRefreshReport>? _runFuture;

  @override
  StartupCharacterRefreshState get state => _state;

  @override
  Stream<StartupCharacterRefreshState> get states => _stateController.stream;

  @override
  Future<StartupCharacterRefreshReport> runOnce() =>
      _runFuture ??= _run();

  Future<StartupCharacterRefreshReport> _run() async {
    if (_playerId.isEmpty) {
      return _complete(const StartupCharacterRefreshReport(items: []));
    }

    try {
      final accounts = await _accountRepository.loadAccounts();
      final eligible = _eligibilityPolicy.eligibleCharacters(accounts);
      final niceGroupClassNames = _niceGroupPolicy.evaluate(accounts).classNames;
      final hasEligibleNiceGroupCharacter = eligible.any(
        (character) => niceGroupClassNames.contains(_classKey(character)),
      );
      final niceGroupRefreshEnabled = hasEligibleNiceGroupCharacter
          ? await _loadNiceGroupRefreshEnabled()
          : false;

      _emit(
        StartupCharacterRefreshState(
          phase: StartupCharacterRefreshPhase.running,
          totalCount: eligible.length,
          completedCount: 0,
          failedCount: 0,
        ),
      );

      var completedCount = 0;
      var failedCount = 0;
      final items = await Future.wait([
        for (final character in eligible)
          _refresh(
            character,
            excludedFromAutoRefresh:
                niceGroupClassNames.contains(_classKey(character)) &&
                !niceGroupRefreshEnabled,
          ).then((item) {
            completedCount++;
            if (!item.isSuccess) failedCount++;
            _emit(
              StartupCharacterRefreshState(
                phase: StartupCharacterRefreshPhase.running,
                totalCount: eligible.length,
                completedCount: completedCount,
                failedCount: failedCount,
              ),
            );
            return item;
          }),
      ]);
      return _complete(StartupCharacterRefreshReport(items: items));
    } on Object catch (error) {
      return _complete(
        StartupCharacterRefreshReport(items: const [], fatalError: error),
      );
    }
  }

  Future<bool> _loadNiceGroupRefreshEnabled() async {
    try {
      return await _niceGroupAutoRefreshSettingsRepository.loadEnabled(
        playerId: _playerId,
      );
    } on Object {
      return false;
    }
  }

  Future<StartupCharacterRefreshItemResult> _refresh(
    LocalAccountCharacter character, {
    required bool excludedFromAutoRefresh,
  }) async {
    try {
      final result = await _refreshGateway.prefetch(
        CharacterAutoRefreshRequest(
          characterId: character.id,
          characterName: character.characterName,
          generation: 0,
          expectedRole: character.preferredRole,
          excludedFromAutoRefresh: excludedFromAutoRefresh,
        ),
      );
      return StartupCharacterRefreshItemResult(
        character: character,
        result: result,
      );
    } on Object catch (error) {
      return StartupCharacterRefreshItemResult(
        character: character,
        error: error,
      );
    }
  }

  StartupCharacterRefreshReport _complete(
    StartupCharacterRefreshReport report,
  ) {
    _emit(
      StartupCharacterRefreshState(
        phase: StartupCharacterRefreshPhase.completed,
        totalCount: report.totalCount,
        completedCount: report.completedCount,
        failedCount: report.failedCount,
      ),
    );
    return report;
  }

  String _classKey(LocalAccountCharacter character) =>
      character.characterClassName.trim().toLowerCase();

  void _emit(StartupCharacterRefreshState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  @override
  Future<void> dispose() => _stateController.close();
}
