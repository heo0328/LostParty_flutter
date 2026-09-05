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

abstract interface class ManualCharacterRefreshRunner {
  StartupCharacterRefreshState get state;
  Stream<StartupCharacterRefreshState> get states;
  Future<StartupCharacterRefreshReport> runManualExcludingNiceGroup();
}

class StartupCharacterRefreshOrchestrator
    implements StartupCharacterRefreshRunner, ManualCharacterRefreshRunner {
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
  Future<StartupCharacterRefreshReport>? _activeRunFuture;

  @override
  StartupCharacterRefreshState get state => _state;

  @override
  Stream<StartupCharacterRefreshState> get states => _stateController.stream;

  @override
  Future<StartupCharacterRefreshReport> runOnce() =>
      _runFuture ??= _runShared(excludeNiceGroup: false, force: false);

  @override
  Future<StartupCharacterRefreshReport> runManualExcludingNiceGroup() =>
      _runShared(excludeNiceGroup: true, force: true);

  Future<StartupCharacterRefreshReport> _runShared({
    required bool excludeNiceGroup,
    required bool force,
  }) {
    final active = _activeRunFuture;
    if (active != null) return active;
    late final Future<StartupCharacterRefreshReport> future;
    future = _run(excludeNiceGroup: excludeNiceGroup, force: force).whenComplete(
      () {
        if (identical(_activeRunFuture, future)) _activeRunFuture = null;
      },
    );
    return _activeRunFuture = future;
  }

  Future<StartupCharacterRefreshReport> _run({
    required bool excludeNiceGroup,
    required bool force,
  }) async {
    if (_playerId.isEmpty) {
      return _complete(const StartupCharacterRefreshReport(items: []));
    }

    try {
      final accounts = await _accountRepository.loadAccounts();
      final eligible = _eligibilityPolicy.eligibleCharacters(accounts);
      final niceGroupClassNames = _niceGroupPolicy.evaluate(accounts).classNames;
      final targets = excludeNiceGroup
          ? eligible
                .where(
                  (character) =>
                      !niceGroupClassNames.contains(_classKey(character)),
                )
                .toList(growable: false)
          : eligible;
      final hasEligibleNiceGroupCharacter = targets.any(
        (character) => niceGroupClassNames.contains(_classKey(character)),
      );
      final niceGroupRefreshEnabled = !excludeNiceGroup &&
              hasEligibleNiceGroupCharacter
          ? await _loadNiceGroupRefreshEnabled()
          : false;

      _emit(
        StartupCharacterRefreshState(
          phase: StartupCharacterRefreshPhase.running,
          totalCount: targets.length,
          completedCount: 0,
          failedCount: 0,
        ),
      );

      var completedCount = 0;
      var failedCount = 0;
      final items = await Future.wait([
        for (final character in targets)
          _refresh(
            character,
            force: force,
            excludedFromAutoRefresh:
                niceGroupClassNames.contains(_classKey(character)) &&
                !niceGroupRefreshEnabled,
          ).then((item) {
            completedCount++;
            if (!item.isSuccess) failedCount++;
            _emit(
              StartupCharacterRefreshState(
                phase: StartupCharacterRefreshPhase.running,
                totalCount: targets.length,
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
    required bool force,
  }) async {
    try {
      final result = await _refreshGateway.prefetch(
        CharacterAutoRefreshRequest(
          characterId: character.id,
          characterName: character.characterName,
          generation: 0,
          expectedRole: character.preferredRole,
          excludedFromAutoRefresh: excludedFromAutoRefresh,
          force: force,
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
