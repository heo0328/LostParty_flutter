import 'dart:async';
import 'dart:convert';
import '../../data/beta/recruitment_command_transport.dart';
import '../../data/beta/recruitment_command.dart';
import '../../data/beta/beta_creation_gateway.dart';
import '../../domain/beta_schedule_draft.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../../../shared/raid_catalog/domain/policies/raid_eligibility_policy.dart';
import '../../../account/data/local/scoped_command_key.dart';
import '../../../account/domain/account_read_session.dart';
import '../../domain/backend_recruitment.dart';
import '../../../account/domain/member_cycle_models.dart';
import '../../domain/policies/recruitment_start_policy.dart';

class _CreationCommand {
  _CreationCommand(Map<String, dynamic> body, this.createdAt, this.context)
    : encoded = jsonEncode(body),
      key = newScopedCommandKey();
  final String key, encoded;
  final DateTime createdAt;
  final RecruitmentCreationContext context;
}

/// App-owned: leaving the route does not change the draft, key or request body.
class BackendRecruitmentCreateViewModel extends ChangeNotifier {
  BackendRecruitmentCreateViewModel({
    required this.gateway,
    required this.session,
    required this.accessChanges,
    required this.hasVerifiedAccount,
    DateTime Function()? now,
    this.scopeKey,
    this.commandTransport,
    this.onActiveRoomsChanged,
  }) : now = now ?? DateTime.now {
    session.addListener(_access);
    accessChanges.addListener(_access);
    _binding = (session.userId, session.generation);
    _scopeBinding = scopeKey?.call();
    _eligible = session.isAuthenticated && hasVerifiedAccount();
  }
  final RecruitmentGateway gateway;

  /// Owned by the app; draft/UI beta wiring is a subsequent section.
  final RecruitmentCommandTransport? commandTransport;
  final void Function(String commandKey)? onActiveRoomsChanged;
  final AccountReadSession session;
  final Listenable accessChanges;
  final bool Function() hasVerifiedAccount;
  final DateTime Function() now;
  final String Function()? scopeKey;
  String? _scopeBinding;
  MemberCycles? cycles;
  DateTime? _metaReceived;
  Timer? _cycleTimer;
  bool _readingMeta = false;
  String? createdTargetKey;
  List<String> createdTargetKeys = const [];
  CycleRecruitmentGateway? get cycleGateway =>
      gateway is CycleRecruitmentGateway &&
          (gateway as CycleRecruitmentGateway).twoCycleEnabled
      ? gateway as CycleRecruitmentGateway
      : null;
  DateTime get serverNow => cycles == null || _metaReceived == null
      ? now().toUtc()
      : cycles!.serverNow.add(now().toUtc().difference(_metaReceived!));
  Future<void> selectCycle(String key) async {
    if (!editable || cycles?.find(key) == null || key == draft.targetCycleKey) {
      return;
    }
    update(
      draft.copy(
        targetCycleKey: key,
        continueTogether: key == cycles!.current.key
            ? draft.continueTogether
            : false,
      ),
    );
  }

  void _acceptMeta(MemberCycles meta) {
    cycles = meta;
    if (betaEnabled && !hasPending) {
      draft = draft.copy(
        betaSchedules: {
          for (final e in draft.betaSchedules.entries)
            if (e.key == meta.current.key || e.key == meta.next.key)
              e.key: e.value,
        },
      );
    }
    _metaReceived = now().toUtc();
    _cycleTimer?.cancel();
    final remaining = meta.current.endsAt.difference(meta.serverNow);
    if (remaining > Duration.zero) {
      _cycleTimer = Timer(remaining, () => unawaited(refreshCycles()));
    }
  }

  Future<void> refreshCycles() async {
    if (cycleGateway == null ||
        !eligible ||
        hasPending ||
        busy ||
        _readingMeta) {
      return;
    }
    final epoch = _epoch;
    _readingMeta = true;
    try {
      final meta = await cycleGateway!.cycles();
      if (!_current(epoch)) return;
      final changed = cycles?.current.key != meta.current.key;
      _acceptMeta(meta);
      if (changed) {
        selection = null;
        _contextGeneration++;
      }
    } on AccountReadException catch (e) {
      if (_current(epoch)) {
        selection = null;
        _fail(e);
      }
    } catch (_) {
      if (_current(epoch)) {
        selection = null;
        failure = 'INVALID_RESPONSE';
      }
    } finally {
      _readingMeta = false;
      if (_current(epoch)) _emit();
    }
  }

  static const _eligibility = RaidEligibilityPolicy();
  static const startPolicy = RecruitmentStartPolicy();
  late (String?, int) _binding;
  bool _eligible = false, _disposed = false, _activated = false;
  int _epoch = 0, _contextGeneration = 0;
  Timer? _timer;
  DateTime? _retryAt;
  _CreationCommand? _pending;
  RecruitmentCommand? _betaPending;
  bool _journalBlocked = false;
  bool get journalUnavailable => _journalBlocked;
  bool get betaEnabled =>
      gateway is BetaCreationGateway &&
      (gateway as BetaCreationGateway).betaContractActive;
  List<String> get betaTargets => [
    if (draft.targetCycleKey != null) draft.targetCycleKey!,
    if (draft.continueTogether && cycles != null) cycles!.next.key,
  ];
  BetaScheduleInput betaInput(String target) =>
      draft.betaSchedules[target] ?? const BetaScheduleInput();
  void updateBeta(String target, BetaScheduleInput input) {
    if (!editable) return;
    update(draft.copy(betaSchedules: {...draft.betaSchedules, target: input}));
  }

  bool canBetaStart(String target, int day, int minute) => startPolicy.allows(
    now: serverNow,
    weekday: day,
    minute: minute,
    durationMinutes: durationMinutes,
    targetCycleKey: target,
  );
  String? get betaValidation {
    for (final t in betaTargets) {
      final i = betaInput(t);
      if (i.weekday == null || i.minute == null) {
        return '각 주차의 출발 날짜와 시각을 선택해 주세요.';
      }
      if (!canBetaStart(t, i.weekday!, i.minute!)) {
        return '출발 가능한 날짜·시각을 다시 선택해 주세요.';
      }
      final capacity = betaCapacity;
      if (i.enabled && (i.additional < 1 || i.additional >= capacity)) {
        return '자동 조율 인원을 다시 선택해 주세요.';
      }
    }
    return betaTargets.isEmpty ? '주차를 선택해 주세요.' : null;
  }

  int get betaCapacity => draft.items.length > 1
      ? 4
      : catalog?.raids
                .where((r) => r.raidId == draft.items.firstOrNull?.raidId)
                .firstOrNull
                ?.partySize ??
            8;
  Future<void>? _consumingAck;
  // A new route must not redisplay a result already handed to the detail route.
  bool get creationSuccessConsumed =>
      createdRoomId != null && (_consumingAck != null || !hasPending);
  RecruitmentDraft draft = RecruitmentDraft();
  RaidCatalog? catalog;
  List<RecruitmentCharacter> characters = [];
  String? _availabilityKey;
  Set<String> _unavailableRaids = const {};
  List<String> _availabilityTargets(RecruitmentDraft value) => [
    if (value.targetCycleKey != null) value.targetCycleKey!,
    if (value.continueTogether && cycles != null) cycles!.next.key,
  ];
  String _availabilitySignature(RecruitmentDraft value) =>
      '${value.characterId}/${_availabilityTargets(value).join('/')}';
  List<RecruitmentGroupChoice> groups = [];
  List<String> recoveryRooms = [];
  RecruitmentCreationContext? selection;
  String? failure, groupFailure, notice, createdRoomId;
  bool loading = false,
      saving = false,
      contextLoading = false,
      groupsLoading = false;
  bool get eligible => session.isAuthenticated && _eligible;
  bool get hasPending =>
      _pending != null || _betaPending != null || _journalBlocked;
  int get editGeneration => _epoch;
  bool get busy => loading || saving;
  bool get editable =>
      eligible && !busy && !hasPending && createdRoomId == null;
  bool get retryExpired =>
      _journalBlocked ||
      (_betaPending != null &&
          (_betaPending!.state == RecruitmentCommandState.needsReview ||
              _betaPending!.validationSnapshot == null ||
              _betaPending!.expired(now().toUtc()))) ||
      _pending != null &&
          now().difference(_pending!.createdAt) >= const Duration(hours: 24);
  bool get delayPassed => _retryAt == null || !now().isBefore(_retryAt!);
  bool get canRetry =>
      eligible && hasPending && !busy && !retryExpired && delayPassed;
  RecruitmentCharacter? get character =>
      characters.where((c) => c.id == draft.characterId).firstOrNull;

  List<EligibleRaidOption> optionsFor(RecruitmentDraft value) {
    final c = catalog;
    if (c == null) return const [];
    final selected = characters
        .where((c) => c.id == value.characterId)
        .firstOrNull;
    return _eligibility
        .eligibleRaids(
          catalog: c,
          itemLevel: double.tryParse(selected?.itemLevel ?? ''),
        )
        .where(
          (option) =>
              _availabilityKey != _availabilitySignature(value) ||
              !_unavailableRaids.contains(option.raid.raidId),
        )
        .toList();
  }

  bool get availabilityReady =>
      cycleGateway == null ||
      gateway is! RecruitmentAvailabilityGateway ||
      _availabilityKey == _availabilitySignature(draft);
  List<EligibleRaidOption> get raidOptions =>
      availabilityReady ? optionsFor(draft) : const [];

  RecruitmentDraft _normalizeItems(RecruitmentDraft value) {
    final options = optionsFor(value);
    final items = <RecruitmentItemDraft>[];
    final retained = value.items
        .map((i) => i.raidId)
        .where((id) => options.any((o) => o.raid.raidId == id))
        .toSet();
    for (final old in value.items) {
      final available = options.where(
        (o) =>
            !retained.contains(o.raid.raidId) &&
            !items.any((i) => i.raidId == o.raid.raidId),
      );
      final option =
          options.where((o) => o.raid.raidId == old.raidId).firstOrNull ??
          available.firstOrNull;
      if (option == null) continue;
      final difficulty =
          option.difficulties
              .where(
                (d) =>
                    d.difficultyId == old.difficultyId &&
                    option.raid.raidId == old.raidId,
              )
              .firstOrNull ??
          option.highestDifficulty;
      items.add(
        RecruitmentItemDraft(
          option.raid.raidId,
          difficulty.difficultyId,
          minutes: old.minutes,
        ),
      );
    }
    if (items.isEmpty && options.isNotEmpty) {
      items.add(
        RecruitmentItemDraft(
          options.first.raid.raidId,
          options.first.highestDifficulty.difficultyId,
        ),
      );
    }
    return value.copy(items: items);
  }

  int? get durationMinutes {
    if (draft.items.isEmpty) return null;
    var total = 0;
    for (final item in draft.items) {
      final minutes =
          item.minutes ?? startPolicy.defaultMinutes(item.difficultyId);
      if (minutes == null) return null;
      total += minutes;
    }
    return total;
  }

  bool canStart(int minute, {int? day}) {
    final days = day == null ? draft.weekdays : {day};
    final instant = cycleGateway == null ? now() : serverNow;
    return days.isNotEmpty &&
        days.every(
          (d) => startPolicy.allows(
            now: instant,
            weekday: d,
            minute: minute,
            durationMinutes: durationMinutes,
            targetCycleKey: draft.targetCycleKey,
          ),
        );
  }

  bool canSelectDay(int day) => List.generate(
    288,
    (i) => i * 5,
  ).any((minute) => canStart(minute, day: day));

  String? get validationMessage {
    if (cycleGateway != null &&
        gateway is RecruitmentAvailabilityGateway &&
        _availabilityKey != _availabilitySignature(draft)) {
      return '참가 가능한 레이드를 확인해 주세요.';
    }
    if (cycleGateway != null &&
        (cycles == null ||
            cycles!.find(draft.targetCycleKey ?? '') == null ||
            !serverNow.isBefore(cycles!.current.endsAt))) {
      return '주차 정보를 다시 불러와 주세요.';
    }
    if (cycleGateway != null &&
        cycles!.find(draft.targetCycleKey!)!.permissions['create']?.allowed !=
            true) {
      return '선택 주차에 모집을 만들 수 없습니다.';
    }
    final input = draft.validate();
    if (input != null) return input;
    if (betaEnabled && betaValidation != null) return betaValidation;
    if (durationMinutes != null && durationMinutes! > 1440) {
      return '한 타임의 진행시간 합계는 24시간까지 설정할 수 있어요.';
    }
    if (draft.hasManualTime &&
        draft.weekdays.any(
          (day) => !canStart(draft.timeForDay(day)!, day: day),
        )) {
      return '출발 가능한 날짜·시각을 다시 선택해 주세요. 현재부터 30분 이후, 점검시간과 주차 종료 전이어야 해요.';
    }
    return null;
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch) =>
      !_disposed &&
      epoch == _epoch &&
      eligible &&
      _binding == (session.userId, session.generation) &&
      hasVerifiedAccount() &&
      _scopeBinding == scopeKey?.call();

  void _access() {
    final binding = (session.userId, session.generation);
    final available = session.isAuthenticated && hasVerifiedAccount();
    if (binding == _binding &&
        available == _eligible &&
        _scopeBinding == scopeKey?.call()) {
      return;
    }
    _scopeBinding = scopeKey?.call();
    _binding = binding;
    _eligible = available;
    _epoch++;
    _contextGeneration++;
    _timer?.cancel();
    _cycleTimer?.cancel();
    _retryAt = null;
    _pending = null;
    _betaPending = null;
    _journalBlocked = false;
    draft = RecruitmentDraft();
    _availabilityKey = null;
    _unavailableRaids = const {};
    cycles = null;
    _metaReceived = null;
    createdTargetKey = null;
    createdTargetKeys = const [];
    catalog = null;
    characters = [];
    groups = [];
    recoveryRooms = [];
    selection = null;
    failure = groupFailure = notice = createdRoomId = null;
    loading = saving = contextLoading = groupsLoading = false;
    _emit();
    if (_activated && eligible) unawaited(load());
  }

  Future<void> activate({String? target}) async {
    _activated = true;
    if (_consumingAck != null) await _consumingAck;
    if (betaEnabled &&
        commandTransport != null &&
        _betaPending == null &&
        !_journalBlocked) {
      final epoch = _epoch;
      try {
        final saved = await commandTransport!.restore(
          RecruitmentCommandOwner.creation,
        );
        if (!_current(epoch)) return;
        if (saved != null) {
          _betaPending = saved;
          draft = draft.copy(targetCycleKey: saved.targetCycles.first);
          if (saved.validationSnapshot == null) {
            failure = 'REQUEST_REVIEW_REQUIRED';
          }
          if (saved.state == RecruitmentCommandState.acknowledged) {
            _acceptBetaAck(
              saved,
              validateBetaCreationAck(
                saved,
                jsonDecode(saved.rawAck!) as Map<String, dynamic>,
              ),
            );
            _emit();
            return;
          }
          if (saved.state == RecruitmentCommandState.rejected) {
            await _releaseBetaRejection(saved);
          }
        }
      } catch (_) {
        if (_current(epoch)) {
          _journalBlocked = true;
          failure = 'REQUEST_REVIEW_REQUIRED';
        }
      }
    }
    // A successful command belongs to the detail route. A new create-route
    // entry starts a new draft; unfinished and unknown commands remain intact.
    if (!hasPending && !busy && createdRoomId != null) _resetCompleted();
    if (catalog == null && eligible) {
      await load();
    } else if (editable && gateway is RecruitmentAvailabilityGateway) {
      _availabilityKey = null;
      await refreshContext();
    }
    if (target != null && editable && cycles?.find(target) != null) {
      await selectCycle(target);
    } else if (target != null && editable && cycles != null) {
      draft = draft.copy(targetCycleKey: target, continueTogether: false);
      selection = null;
      failure = 'TARGET_CYCLE_OUT_OF_RANGE';
      _emit();
    }
  }

  Future<void> load() async {
    if (!eligible || busy || hasPending || !delayPassed) return;
    _availabilityKey = null;
    _unavailableRaids = const {};
    final epoch = _epoch;
    loading = true;
    failure = null;
    _emit();
    try {
      if (cycleGateway != null) {
        final meta = await cycleGateway!.cycles();
        if (!_current(epoch)) return;
        _acceptMeta(meta);
        final t = draft.targetCycleKey ?? meta.current.key;
        draft = draft.copy(
          targetCycleKey: t,
          continueTogether: t == meta.current.key && draft.continueTogether,
        );
      }
      final c = await gateway.catalog();
      if (!_current(epoch)) return;
      final candidates = await gateway.characters();
      if (!_current(epoch)) return;
      catalog = c;
      characters = candidates;
      final selected =
          characters.where((v) => v.id == draft.characterId).firstOrNull ??
          characters.where((v) => v.representative).firstOrNull ??
          characters.firstOrNull;
      if (selected != null) {
        draft = draft.copy(
          characterId: selected.id,
          role: selected.id == draft.characterId
              ? (selected.supportsBothRoles ? draft.role : 'dealer')
              : selected.initialRole,
        );
      }
      draft = _normalizeItems(draft);
    } on AccountReadException catch (e) {
      if (_current(epoch)) _fail(e);
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        loading = false;
        _emit();
      }
    }
    if (_current(epoch)) await refreshContext();
  }

  void update(RecruitmentDraft value) {
    if (!editable) return;
    if (value.characterId != draft.characterId) {
      final selected = characters
          .where((c) => c.id == value.characterId)
          .firstOrNull;
      if (selected != null) value = value.copy(role: selected.initialRole);
    }
    if (cycleGateway != null) {
      if (cycles?.find(value.targetCycleKey ?? '') == null) return;
      if (value.targetCycleKey != cycles!.current.key &&
          value.continueTogether) {
        value = value.copy(continueTogether: false);
      }
    }
    if (value.characterId != draft.characterId ||
        value.selectionSignature != draft.selectionSignature) {
      value = _normalizeItems(value);
    }
    final changed = value.selectionSignature != draft.selectionSignature;
    draft = value;
    failure = notice = null;
    if (changed) {
      selection = null;
      unawaited(refreshContext());
    }
    _emit();
  }

  Future<void> loadGroups() async {
    if (!editable || groupsLoading) return;
    final epoch = _epoch;
    groupsLoading = true;
    groupFailure = null;
    _emit();
    try {
      final value = await gateway.groups();
      if (_current(epoch)) groups = value;
    } on AccountReadException catch (e) {
      if (_current(epoch)) groupFailure = e.code;
    } catch (_) {
      if (_current(epoch)) groupFailure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        groupsLoading = false;
        _emit();
      }
    }
  }

  Future<void> refreshContext() async {
    if (!eligible || busy || hasPending || draft.characterId == null) {
      return;
    }
    final epoch = _epoch, generation = ++_contextGeneration;
    var snapshot = draft;
    contextLoading = true;
    _emit();
    try {
      if (cycleGateway != null &&
          gateway is RecruitmentAvailabilityGateway &&
          catalog != null &&
          _availabilityKey != _availabilitySignature(snapshot)) {
        final unavailable = await (gateway as RecruitmentAvailabilityGateway)
            .unavailableRaids(
              snapshot.characterId!,
              _availabilityTargets(snapshot),
              catalog!,
            );
        if (!_current(epoch) ||
            generation != _contextGeneration ||
            snapshot.selectionSignature != draft.selectionSignature) {
          return;
        }
        _availabilityKey = _availabilitySignature(snapshot);
        _unavailableRaids = unavailable;
        draft = _normalizeItems(snapshot);
        snapshot = draft;
      }
      if (snapshot.items.isEmpty) {
        selection = null;
        notice = '이 캐릭터로 모집할 수 있는 레이드가 없습니다.';
        return;
      }
      if (betaEnabled && betaValidation != null) {
        selection = null;
        return;
      }
      final value = await gateway.context(snapshot);
      if (_current(epoch) &&
          generation == _contextGeneration &&
          snapshot.selectionSignature == draft.selectionSignature) {
        selection = value;
        failure = null;
      }
    } on AccountReadException catch (e) {
      if (_current(epoch) && generation == _contextGeneration) {
        selection = null;
        _fail(e);
      }
    } catch (_) {
      if (_current(epoch) && generation == _contextGeneration) {
        selection = null;
        failure = 'INVALID_RESPONSE';
      }
    } finally {
      if (_current(epoch) && generation == _contextGeneration) {
        contextLoading = false;
        _emit();
      }
    }
  }

  String get defaultTitle {
    final names = draft.items
        .map((i) {
          final r = catalog?.raids
              .where((r) => r.raidId == i.raidId)
              .firstOrNull;
          return r?.displayName ?? i.raidId;
        })
        .join(' · ');
    final value = '$names 모집';
    return String.fromCharCodes(value.runes.take(60));
  }

  Future<void> submit() async {
    if (!editable || !delayPassed) return;
    final problem = validationMessage;
    if (problem != null) {
      notice = problem;
      _emit();
      return;
    }
    final epoch = _epoch;
    _contextGeneration++;
    contextLoading = false;
    saving = true;
    failure = notice = null;
    _emit();
    final snapshot = draft;
    try {
      // A preview is never write authority. Every new command gets a fresh context.
      if (cycleGateway != null) {
        final meta = await cycleGateway!.cycles();
        if (!_current(epoch)) return;
        _acceptMeta(meta);
        if (meta.find(snapshot.targetCycleKey ?? '') == null) {
          selection = null;
          failure = 'TARGET_CYCLE_OUT_OF_RANGE';
          return;
        }
        if (validationMessage != null) {
          selection = null;
          notice = validationMessage;
          return;
        }
      }
      final context = await gateway.context(snapshot);
      if (!_current(epoch)) return;
      if (cycleGateway != null && context.cycleKey != cycles!.current.key) {
        failure = 'CYCLE_CHANGED';
        selection = null;
        return;
      }
      selection = context;
      if (!context.allowed) {
        failure = context.reason ?? 'PERMISSION_DENIED';
        return;
      }
      if (context.expiresAt != null && !context.expiresAt!.isAfter(serverNow)) {
        failure = 'SELECTION_CONTEXT_CHANGED';
        return;
      }
      if (betaEnabled) {
        _betaPending = (gateway as BetaCreationGateway).prepareBetaCreation(
          snapshot,
          context,
          defaultTitle,
          newScopedCommandKey(),
          now().toUtc(),
        );
      } else {
        _pending = _CreationCommand(
          snapshot.body(context, defaultTitle),
          now(),
          context,
        );
      }
      await _send(epoch);
    } on AccountReadException catch (e) {
      if (_current(epoch)) _fail(e);
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        saving = false;
        _emit();
      }
    }
  }

  Future<void> retry() async {
    if (!canRetry) return;
    final epoch = _epoch;
    saving = true;
    failure = null;
    _emit();
    try {
      await _send(epoch);
    } finally {
      if (_current(epoch)) {
        saving = false;
        _emit();
      }
    }
  }

  Future<void> _send(int epoch) async {
    if (_betaPending != null) {
      await _sendBeta(epoch);
      return;
    }
    final command = _pending!;
    try {
      final ack = await gateway.create(
        command.key,
        jsonDecode(command.encoded) as Map<String, dynamic>,
      );
      if (!_current(epoch)) return;
      if (command.context.targetKey != null) {
        final expected = command.context;
        if (ack.roomId != expected.prospectiveRoomId ||
            ack.targetKey != expected.targetKey ||
            ack.effect != expected.effect ||
            ack.created?.length != expected.prospective?.length) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        for (final p in expected.prospective!) {
          final c = ack.created!
              .where((v) => v['target_cycle_key'] == p['target_cycle_key'])
              .firstOrNull;
          if (c == null ||
              c['room_cycle_id'] != p['room_cycle_id'] ||
              c['generation'] != p['generation'] ||
              c['target_revision'] != p['initial_target_revision']) {
            throw const AccountReadException('INVALID_RESPONSE');
          }
        }
      }
      createdTargetKey = ack.targetKey;
      createdTargetKeys = List.unmodifiable(
        ack.created?.map((v) => v['target_cycle_key'] as String) ??
            (ack.targetKey == null ? <String>[] : [ack.targetKey!]),
      );
      createdRoomId = ack.roomId;
      _pending = null;
      selection = null;
      failure = null;
    } on AccountReadException catch (e) {
      if (!_current(epoch)) return;
      _fail(e);
      // Definite rejection cannot have applied. Unknown 5xx/network/invalid ACK keep the key.
      if (e.status == 400 ||
          e.status == 403 ||
          e.status == 404 ||
          e.status == 413 ||
          (e.status == 409 &&
              !{
                'REQUEST_IN_PROGRESS',
                'IDEMPOTENCY_EXPIRED',
              }.contains(e.code))) {
        _pending = null;
        selection = null;
        notice = '입력과 현재 상태를 확인한 뒤 다시 생성해 주세요.';
      }
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    }
  }

  void _acceptBetaAck(RecruitmentCommand command, RecruitmentCreationAck ack) {
    onActiveRoomsChanged?.call(command.key);
    createdRoomId = ack.roomId;
    createdTargetKey = ack.targetKey;
    createdTargetKeys = List.unmodifiable(
      ack.created!.map((v) => v['target_cycle_key'] as String),
    );
    selection = null;
    failure = null;
  }

  Future<void> consumeCreatedSuccess() => _consumingAck ??=
      _consumeBetaSuccess().whenComplete(() => _consumingAck = null);
  Future<void> _consumeBetaSuccess() async {
    final command = _betaPending;
    if (command == null || createdRoomId == null) return;
    final epoch = _epoch;
    try {
      await commandTransport!.releaseResolved(command.owner, command.key);
      if (_current(epoch)) _betaPending = null;
    } catch (_) {
      if (_current(epoch)) {
        failure = 'REQUEST_STORAGE_FAILED';
        _emit();
      }
    }
  }

  Future<void> _releaseBetaRejection(RecruitmentCommand command) async {
    final epoch = _epoch;
    await commandTransport!.releaseResolved(command.owner, command.key);
    if (!_current(epoch)) return;
    _betaPending = null;
    selection = null;
    notice = '입력과 현재 상태를 확인한 뒤 다시 생성해 주세요.';
  }

  Future<void> _sendBeta(int epoch) async {
    final command = _betaPending!;
    if (command.validationSnapshot == null) {
      failure = 'REQUEST_REVIEW_REQUIRED';
      _emit();
      return;
    }
    try {
      final raw = await commandTransport!.submit(
        command,
        validateAck: (j) => validateBetaCreationAck(command, j),
      );
      if (!_current(epoch)) return;
      _acceptBetaAck(command, validateBetaCreationAck(command, raw));
    } on AccountReadException catch (e) {
      if (!_current(epoch)) return;
      _fail(e);
      try {
        final stored = await commandTransport!.restore(command.owner);
        if (!_current(epoch)) return;
        if (stored?.state == RecruitmentCommandState.rejected) {
          await _releaseBetaRejection(stored!);
        }
      } catch (_) {
        if (_current(epoch)) failure = 'REQUEST_STORAGE_FAILED';
      }
    } on FormatException {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } catch (_) {
      if (_current(epoch)) failure = 'REQUEST_STORAGE_FAILED';
    }
  }

  Future<void> checkCurrentRooms() async {
    if (_journalBlocked) return;
    if (!eligible || busy || !hasPending || !delayPassed) return;
    final epoch = _epoch;
    loading = true;
    _emit();
    try {
      final ids = cycleGateway == null
          ? await gateway.currentRoomIds()
          : await cycleGateway!.roomIdsFor(
              _betaPending?.targetCycles.first ?? _pending!.context.targetKey!,
            );
      if (_current(epoch)) recoveryRooms = ids;
    } on AccountReadException catch (e) {
      if (_current(epoch)) _fail(e);
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> confirmRecoveredRoom(String id) async {
    if (!eligible || busy || !hasPending || !recoveryRooms.contains(id)) return;
    if (cycleGateway != null) {
      notice = '생성 결과는 원래 요청으로 다시 확인해 주세요.';
      _emit();
      return;
    }
    final epoch = _epoch, command = _pending!;
    loading = true;
    _emit();
    try {
      final detail = await gateway.detail(id);
      if (!_current(epoch)) return;
      final body = jsonDecode(command.encoded) as Map<String, dynamic>;
      final selected = body['selection'] as Map;
      final own = detail.members
          .where((m) => m['is_me'] == true && m['room_role'] == 'leader')
          .firstOrNull;
      final c = own?['character'] as Map?;
      final requested = (body['items'] as List)
          .map((i) => '${i['raid_id']}/${i['difficulty_id']}')
          .toSet();
      final actual = (detail.room['items'] as List)
          .map((i) => '${i['raid_id']}/${i['difficulty_id']}')
          .toSet();
      final stamp = DateTime.tryParse('${detail.room['created_at']}');
      if (c?['character_id'] != selected['character_id'] ||
          c?['selected_role'] != selected['selected_role'] ||
          detail.title != body['title'] ||
          detail.room['scope'] != body['scope'] ||
          detail.room['group_id'] != body['group_id'] ||
          requested.length != actual.length ||
          !requested.containsAll(actual) ||
          stamp == null ||
          stamp.isBefore(
            command.createdAt.subtract(const Duration(minutes: 5)),
          )) {
        notice = '이전 생성 요청과 일치하는 모집인지 확인하지 못했습니다.';
        return;
      }
      createdRoomId = id;
      _pending = null;
      failure = notice = null;
    } on AccountReadException catch (e) {
      if (_current(epoch)) _fail(e);
    } catch (_) {
      if (_current(epoch)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_current(epoch)) {
        loading = false;
        _emit();
      }
    }
  }

  void startAnother() {
    if (hasPending || busy || createdRoomId == null) return;
    _resetCompleted();
    unawaited(load());
  }

  void _resetCompleted() {
    _availabilityKey = null;
    _unavailableRaids = const {};
    _epoch++;
    _contextGeneration++;
    _timer?.cancel();
    _retryAt = null;
    createdRoomId = null;
    createdTargetKey = null;
    createdTargetKeys = const [];
    draft = RecruitmentDraft();
    selection = null;
    characters = [];
    groups = [];
    recoveryRooms = [];
    failure = groupFailure = notice = null;
    contextLoading = groupsLoading = false;
    catalog = null;
  }

  void _fail(AccountReadException e) {
    failure = e.code;
    _retryAt =
        e.retryAt ?? (e.retryAfter == null ? null : now().add(e.retryAfter!));
    _timer?.cancel();
    if (_retryAt != null && !delayPassed) {
      _timer = Timer(_retryAt!.difference(now()), _emit);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _cycleTimer?.cancel();
    session.removeListener(_access);
    accessChanges.removeListener(_access);
    super.dispose();
  }
}

String recruitmentFailureMessage(String? code) => switch (code) {
  'INVALID_RESPONSE' =>
    '서버 응답을 확인하지 못했습니다. 이미 처리됐을 수 있으니 요청 결과를 다시 확인해 주세요. (응답 형식 오류)',
  'RECRUITMENT_COMMAND_NOT_READY' => '모집 기능을 준비 중입니다. 잠시 후 다시 시도해 주세요.',
  'LOCAL_STORAGE_UNAVAILABLE' ||
  'REQUEST_STORAGE_FAILED' => '요청 정보를 기기에 저장하거나 불러오지 못했습니다. 다시 시도해 주세요.',
  'IDEMPOTENCY_EXPIRED' ||
  'REQUEST_REVIEW_REQUIRED' => '이전 요청의 결과를 자동으로 확인할 수 없습니다. 문의 시 이 상태를 알려 주세요.',
  'UNRESOLVED_REQUEST_EXISTS' => '이전 요청의 결과를 먼저 확인해 주세요.',
  'APPLICATION_MEMO_TOO_LONG' => '공대장에게 보낼 메모는 20자까지 입력할 수 있습니다.',
  'APPLICATION_PRESET_LIMIT_EXCEEDED' => '저장 문구는 최대 5개까지 등록할 수 있습니다.',
  'APPLICATION_NOT_FOUND' => '신청 내역이 없거나 이미 종료되었습니다.',
  'SESSION_NOT_FOUND' => '진행 일정이 없거나 삭제되었습니다.',
  'ROOM_NOT_FOUND' || 'NOT_FOUND' => '모집방이 없거나 이미 종료되었습니다.',
  'ADMISSION_MODE_CHANGED' => '모집의 참가 방식이 바뀌었습니다. 모집방을 다시 열어 주세요.',
  'ROLE_SLOT_UNAVAILABLE' => '선택한 역할로 참가할 자리가 없습니다.',
  'CHARACTER_NOT_ELIGIBLE' => '선택한 캐릭터는 현재 모집 조건을 충족하지 않습니다.',
  'CHARACTER_ALREADY_PARTICIPATING' => '이 캐릭터는 같은 주차의 레이드에 이미 참가 중입니다.',
  'ROOM_REVIEW_REQUIRED' =>
    '모집방의 참가 또는 일정 정보가 서로 맞지 않습니다. 새로고침 후에도 같으면 문의해 주세요.',
  'PROPOSAL_CONTEXT_CHANGED' => '제안의 일정이나 조건이 바뀌었습니다. 공대장이 새 제안을 만들어 주세요.',
  'CONTEXT_INVALID' => '확인 정보가 유효하지 않습니다. 최신 내용을 다시 확인해 주세요.',
  'REQUEST_TOO_LARGE' => '일정 정보가 너무 큽니다. 선택한 내용을 줄여 다시 확인해 주세요.',
  'PLAY_NOT_STARTED' ||
  'TARGET_CYCLE_NOT_CURRENT' => '해당 주차 수요일 10시부터 완료 처리할 수 있습니다.',
  'ROUND_NOT_ACTIVE' => '진행 중인 레이드가 없습니다. 최신 상태를 확인해 주세요.',
  'CONTINUATION_REQUIRED' => '함께하기 모집에서만 미완료 종료할 수 있습니다.',
  'INVALID_REQUEST' => '입력한 내용이 서버의 허용 조건과 맞지 않습니다. 입력 내용을 확인해 주세요.',
  'PERSONAL_AVAILABILITY_REQUIRED' => '내 계정에서 개인 시간표를 먼저 설정해 주세요.',
  'WEEKLY_PARTICIPANT_REQUIRED' => '선택 주차의 참가 상태를 확인해 주세요.',
  'NO_SCHEDULE_CANDIDATE' => '선택한 인원 모두가 가능한 공통 시간이 없습니다.',
  'SCHEDULE_PROPOSAL_REQUIRED' => '확정된 일정은 일정 변경안으로 조정해 주세요.',
  'SCHEDULE_NOT_CONFIRMED' => '아직 확정된 일정이 아닙니다.',
  'SCHEDULE_TIME_REQUIRED' => '출발 날짜와 시간을 지정해 주세요.',
  'TARGET_LEADER_REQUIRED' => '선택 주차의 공대장만 변경할 수 있습니다.',
  'SCHEDULE_ENDED' || 'PARTICIPATION_ENDED' => '이 일정의 진행 또는 본인 참가가 종료되었습니다.',
  'PROPOSAL_NOT_PENDING' ||
  'PROPOSAL_TARGET_REQUIRED' => '변경안 상태와 응답 권한을 다시 확인해 주세요.',
  'REQUIRED_SESSION_REQUIRED' => '필수 일정을 하나 이상 선택해 주세요.',
  'ROOM_FULL' ||
  'PARTY_FULL' ||
  'ROLE_CAPACITY_EXCEEDED' => '참가할 자리가 없습니다. 최신 구성을 확인해 주세요.',
  'APPLICATION_STATE_CHANGED' ||
  'APPLICATION_NOT_PENDING' => '신청 상태가 변경되었습니다. 다시 확인해 주세요.',
  'SESSION_SELECTION_REQUIRED' => '참가할 필수 일정을 선택해 주세요.',
  'CURSOR_STALE' ||
  'FILTER_CONTEXT_STALE' => '목록이나 그룹 정보가 변경되었습니다. 다시 불러와 주세요.',
  'GROUP_CHARACTER_CANDIDATES_STALE' => '캐릭터 정보가 변경되었습니다. 선택을 다시 확인해 주세요.',
  'GROUP_NOT_FOUND' => '현재 이 그룹에 접근할 수 없습니다.',
  'RESPONSE_TOO_LARGE' => '조회 범위가 큽니다. 잠시 후 다시 확인해 주세요.',
  'PERMISSION_DENIED' || 'ROOM_LEADER_REQUIRED' => '현재 이 작업을 진행할 권한이 없습니다.',
  'COMMON_LEADER_REQUIRED' ||
  'COMMON_AUTHORITY_UNAVAILABLE' => '현재 이 작업을 진행할 공대장 권한이 없습니다.',
  'SOURCE_PARTICIPATION_REQUIRED' => '이번 주 참가 상태를 먼저 확인해 주세요.',
  'ROOM_COMPOSITION_CONFLICT' => '자리 중복과 파티별 직업·역할 구성을 확인해 주세요.',
  'ROOM_ITEMS_CHANGED' => '참가자나 레이드 구성이 변경되었습니다. 다시 확인해 주세요.',
  'ROOM_LAST_MEMBER_REQUIRED' => '다른 참가자가 남아 있어 모집 전체를 종료할 수 없습니다.',
  'LEADERSHIP_RESOLUTION_REQUIRED' => '영향받는 주차의 공대장 승계를 먼저 확인해 주세요.',
  'CLIENT_UPGRADE_REQUIRED' => '앱과 서버의 기능 버전이 맞지 않습니다. 앱 버전을 확인해 주세요.',
  'TARGET_CYCLE_OUT_OF_RANGE' => '대상 주차가 바뀌었습니다. 주차를 다시 선택해 주세요.',
  'TARGET_NOT_OPEN' => '이 주차에는 열린 모집이 없습니다.',
  'NETWORK_UNAVAILABLE' => '서버에 연결하지 못했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.',
  'RAID_ALREADY_COMPLETED' ||
  'WEEKLY_ALREADY_COMPLETED' ||
  'RAID_WEEKLY_COMPLETED' ||
  'WEEKLY_COMPLETED' => '해당 주차에 이미 완료한 레이드가 포함되어 있습니다.',
  'RAID_ITEM_LEVEL_REQUIRED' => '이 캐릭터는 선택한 난이도의 입장 레벨보다 낮습니다.',
  'COMBAT_POWER_REQUIRED' => '선택 역할의 저장 전투력과 최소 조건을 확인해 주세요.',
  'ROLE_NOT_SUPPORTED' => '이 직업에서 선택할 수 없는 역할입니다.',
  'CHARACTER_DATA_UNAVAILABLE' => '캐릭터 정보를 확인하지 못했습니다. 갱신 후 다시 확인해 주세요.',
  'ACCESS_CHANGED' => '로그인 상태가 변경되었습니다. 다시 열어 주세요.',
  'SERVICE_UNAVAILABLE' => '정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
  'MEMBER_RAID_LIMIT_REACHED' =>
    '동시에 참가할 수 있는 모집방 수에 도달했습니다. 참가 중인 방을 정리한 뒤 다시 시도해 주세요.',
  'MEMBER_GROUP_LIMIT_EXCEEDED' ||
  'GROUP_CAPACITY_EXCEEDED' ||
  'ROOM_RESTRICTED' => '그룹 또는 참가 한도 제한을 확인해 주세요.',
  'WEEKLY_ALREADY_PARTICIPATING' ||
  'WEEKLY_OCCUPANCY_CHANGED' => '같은 레이드의 현재 참가 상태를 확인해 주세요.',
  'SESSION_DURATION_EXCEEDED' => '한 타임의 레이드 진행시간 합계는 24시간까지 설정할 수 있어요.',
  'OWNERSHIP_REQUIRED' || 'CHARACTER_NOT_ACTIVE' => '캐릭터 인증과 활동 선택을 확인해 주세요.',
  'REQUEST_IN_PROGRESS' => '요청을 처리 중입니다. 잠시 후 결과를 다시 확인해 주세요.',
  'SELECTION_CONTEXT_CHANGED' ||
  'COMMAND_CONTEXT_EXPIRED' ||
  'REVISION_CONFLICT' ||
  'CYCLE_CHANGED' ||
  'CATALOG_VERSION_CONFLICT' => '선택 정보가 변경되었습니다. 최신 내용을 확인해 주세요.',
  'RECRUITMENT_CLOSED' ||
  'START_BEFORE_FLOOR' ||
  'INVALID_START_TIME' => '출발 시각과 모집 마감을 확인해 주세요.',
  'IMMEDIATE_CONFIRMATION_REQUIRED' =>
    '자동 조율 조건이 맞으면 즉시 출발 시간이 확정되는 것에 동의해 주세요.',
  'SCHEDULE_BEFORE_FLOOR' => '출발은 모집 생성 시점부터 최소 30분 이후로 설정해 주세요.',
  'SCHEDULE_IN_PAST' => '이미 지난 출발 시각이 포함되어 있어요. 선택한 요일과 시각을 확인해 주세요.',
  'MAINTENANCE_WINDOW' => '수요일 06~10시 점검 시간과 진행 구간이 겹치지 않도록 설정해 주세요.',
  'GROUP_MEMBERSHIP_REQUIRED' => '현재 가입한 그룹을 다시 확인해 주세요.',
  'LOGIN_REQUIRED' ||
  'SESSION_CHANGED' ||
  'UNAUTHENTICATED' => '로그인이 만료되었습니다. 다시 로그인해 주세요.',
  _ =>
    '요청 결과를 확인하지 못했습니다.${code != null && RegExp(r"^[A-Z][A-Z0-9_]{0,79}$").hasMatch(code) ? ' (오류 코드: $code)' : ''} 다시 확인해 주세요.',
};
