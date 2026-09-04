import 'dart:async';

import '../entities/character_auto_refresh_result.dart';
import '../entities/character_build_analysis.dart';
import '../entities/character_build_catalog_detection.dart';
import '../entities/character_build_draft.dart';
import '../entities/character_build_snapshot.dart';
import '../repositories/account_repository.dart';

enum CharacterRefreshPriority { prefetch, command }

class CharacterAutoRefreshRequest {
  const CharacterAutoRefreshRequest({
    required this.characterId,
    required this.characterName,
    required this.generation,
    this.expectedRole,
    this.excludedFromAutoRefresh = false,
    this.force = false,
  });

  final int characterId;
  final String characterName;
  final int generation;
  final CharacterBuildRole? expectedRole;
  final bool excludedFromAutoRefresh;
  final bool force;
}

class CharacterAutoRefreshCoordinator {
  CharacterAutoRefreshCoordinator({
    required AccountRepository accountRepository,
    DateTime Function()? clock,
    this.successTtl = const Duration(minutes: 5),
    this.maxConcurrentRequests = 3,
  }) : _accountRepository = accountRepository,
       _clock = clock ?? DateTime.now {
    if (maxConcurrentRequests < 1) {
      throw ArgumentError.value(maxConcurrentRequests, 'maxConcurrentRequests');
    }
  }

  final AccountRepository _accountRepository;
  final DateTime Function() _clock;
  final Duration successTtl;
  final int maxConcurrentRequests;

  final Map<int, _RefreshJob> _jobs = {};
  final Map<int, _FreshResult> _freshResults = {};
  final List<_RefreshJob> _commandQueue = [];
  final List<_RefreshJob> _prefetchQueue = [];
  int _running = 0;

  Future<CharacterAutoRefreshResult> prefetch(
    CharacterAutoRefreshRequest request,
  ) => _schedule(request, CharacterRefreshPriority.prefetch);

  Future<CharacterAutoRefreshResult> ensureFresh(
    CharacterAutoRefreshRequest request,
  ) => _schedule(request, CharacterRefreshPriority.command);

  void invalidate(int characterId) => _freshResults.remove(characterId);

  Future<CharacterAutoRefreshResult> _schedule(
    CharacterAutoRefreshRequest request,
    CharacterRefreshPriority priority,
  ) async {
    if (request.excludedFromAutoRefresh) {
      return _excludedResult(request);
    }
    final cached = _freshResults[request.characterId];
    if (!request.force &&
        cached != null &&
        _clock().difference(cached.completedAt) < successTtl) {
      return CharacterAutoRefreshResult(
        status: CharacterAutoRefreshStatus.cached,
        characterId: request.characterId,
        generation: request.generation,
        snapshot: cached.result.snapshot,
        detectedRole: cached.result.detectedRole,
        expectedRoleChanged:
            request.expectedRole != null &&
            request.expectedRole != cached.result.detectedRole,
        message: null,
      );
    }

    final existing = _jobs[request.characterId];
    if (existing != null) {
      if (priority == CharacterRefreshPriority.command) {
        existing.request = request;
        if (!existing.started) {
          _prefetchQueue.remove(existing);
          if (!_commandQueue.contains(existing)) _commandQueue.add(existing);
        }
      }
      return (await existing.completer.future).forRequest(
        generation: request.generation,
        expectedRole: request.expectedRole,
      );
    }

    final job = _RefreshJob(request);
    _jobs[request.characterId] = job;
    (priority == CharacterRefreshPriority.command
            ? _commandQueue
            : _prefetchQueue)
        .add(job);
    _drain();
    return (await job.completer.future).forRequest(
      generation: request.generation,
      expectedRole: request.expectedRole,
    );
  }

  void _drain() {
    while (_running < maxConcurrentRequests &&
        (_commandQueue.isNotEmpty || _prefetchQueue.isNotEmpty)) {
      final job = _commandQueue.isNotEmpty
          ? _commandQueue.removeAt(0)
          : _prefetchQueue.removeAt(0);
      job.started = true;
      _running++;
      _run(job)
          .then((result) {
            job.completer.complete(result);
          }, onError: job.completer.completeError)
          .whenComplete(() {
            _jobs.remove(job.request.characterId);
            _running--;
            _drain();
          });
    }
  }

  Future<CharacterAutoRefreshResult> _run(_RefreshJob job) async {
    final fetchRequest = job.request;
    try {
      final draft = await _accountRepository.createCharacterBuildDraft(
        characterId: fetchRequest.characterId,
        characterName: fetchRequest.characterName,
      );
      final request = job.request;
      final validation = _validateDraft(draft, request.expectedRole);
      if (validation.message != null || validation.role == null) {
        return _fallbackResult(request, validation.message!);
      }
      final snapshot = await _accountRepository.commitCharacterBuildDraft(
        draft: draft,
        role: validation.role!,
      );
      final result = CharacterAutoRefreshResult(
        status: CharacterAutoRefreshStatus.refreshed,
        characterId: request.characterId,
        generation: request.generation,
        snapshot: snapshot,
        detectedRole: validation.role,
        expectedRoleChanged:
            request.expectedRole != null &&
            request.expectedRole != validation.role,
        message: null,
      );
      _freshResults[request.characterId] = _FreshResult(
        result: result,
        completedAt: _clock(),
      );
      return result;
    } on Object {
      return _fallbackResult(job.request, '캐릭터 최신 정보를 가져오지 못했습니다.');
    }
  }

  _DraftValidation _validateDraft(
    CharacterBuildDraft draft,
    CharacterBuildRole? expectedRole,
  ) {
    final analysis = draft.analysis;
    if (analysis.gemEffects.any(
      (effect) => effect.category == GemSkillCategory.unknown,
    )) {
      return const _DraftValidation(message: '확인되지 않은 보석 대상이 있습니다.');
    }
    if (analysis.arkGridConditions.any((condition) => !condition.isSatisfied)) {
      return const _DraftValidation(message: '아크그리드 발동 조건이 현재 세팅과 다릅니다.');
    }
    final detection = analysis.catalogDetection;
    if (detection == null ||
        detection.status == CharacterBuildDetectionStatus.unsupportedClass) {
      return _DraftValidation(
        role: expectedRole,
        message: expectedRole == null ? '현재 역할을 판별할 수 없습니다.' : null,
      );
    }
    if (detection.status != CharacterBuildDetectionStatus.detected ||
        detection.detectedRole == null) {
      return const _DraftValidation(message: '현재 역할을 하나로 판별할 수 없습니다.');
    }
    if (detection.matchedRelatedNodes.isEmpty) {
      return const _DraftValidation(message: '현재 역할의 4티어 노드를 확인할 수 없습니다.');
    }
    return _DraftValidation(role: detection.detectedRole);
  }

  Future<CharacterAutoRefreshResult> _excludedResult(
    CharacterAutoRefreshRequest request,
  ) async {
    final snapshot = await _existingSnapshot(request);
    return CharacterAutoRefreshResult(
      status: snapshot == null
          ? CharacterAutoRefreshStatus.blocked
          : CharacterAutoRefreshStatus.excluded,
      characterId: request.characterId,
      generation: request.generation,
      snapshot: snapshot,
      detectedRole: snapshot?.role,
      expectedRoleChanged: false,
      message: snapshot == null ? '저장된 수동 빌드 스냅샷이 없습니다.' : null,
    );
  }

  Future<CharacterAutoRefreshResult> _fallbackResult(
    CharacterAutoRefreshRequest request,
    String message,
  ) async {
    final snapshot = await _existingSnapshot(request);
    return CharacterAutoRefreshResult(
      status: snapshot == null
          ? CharacterAutoRefreshStatus.blocked
          : CharacterAutoRefreshStatus.needsConfirmation,
      characterId: request.characterId,
      generation: request.generation,
      snapshot: snapshot,
      detectedRole: snapshot?.role,
      expectedRoleChanged: false,
      message: message,
    );
  }

  Future<CharacterBuildSnapshot?> _existingSnapshot(
    CharacterAutoRefreshRequest request,
  ) async {
    final snapshots = await _accountRepository.loadCharacterBuildSnapshots(
      request.characterId,
    );
    if (request.expectedRole != null) {
      for (final snapshot in snapshots) {
        if (snapshot.role == request.expectedRole) return snapshot;
      }
      return null;
    }
    if (snapshots.isEmpty) return null;
    final sorted = List<CharacterBuildSnapshot>.of(snapshots)
      ..sort((left, right) => right.capturedAt.compareTo(left.capturedAt));
    return sorted.first;
  }
}

class _RefreshJob {
  _RefreshJob(this.request);

  CharacterAutoRefreshRequest request;
  final Completer<CharacterAutoRefreshResult> completer = Completer();
  bool started = false;
}

class _FreshResult {
  const _FreshResult({required this.result, required this.completedAt});

  final CharacterAutoRefreshResult result;
  final DateTime completedAt;
}

class _DraftValidation {
  const _DraftValidation({this.role, this.message});

  final CharacterBuildRole? role;
  final String? message;
}
