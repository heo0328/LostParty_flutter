import '../../../../shared/diagnostics/load_timing.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../data/local/scoped_command_key.dart';
import '../../data/member_raid_client.dart';
import '../../data/member_weekly_store.dart';
import '../../domain/account_read_session.dart';
import '../../domain/member_raid_models.dart';
import '../../domain/role_summary.dart';
import '../../domain/scoped_cache_models.dart';
import '../../domain/entities/character_weekly_raid_display_preference.dart';
import '../../domain/services/weekly_raid_display_projector.dart';
import '../models/weekly_raid_status_item.dart';
import '../../domain/entities/weekly_raid_status_projection.dart';
import 'member_account_view_model.dart';

String memberWeeklyFailure(String? code) => switch (code) {
  'PARTICIPATION_CONFIRMATION_REQUIRED' => '참가 중인 레이드는 아직 여기서 완료 처리할 수 없습니다.',
  'CYCLE_CHANGED' => '주차가 바뀌었습니다. 다시 확인해 주세요.',
  'REVISION_CONFLICT' ||
  'CATALOG_VERSION_CONFLICT' => '정보가 변경됐습니다. 다시 불러와 주세요.',
  'OWNERSHIP_REQUIRED' ||
  'CHARACTER_NOT_FOUND' ||
  'CHARACTER_UNUSABLE' => '캐릭터 정보를 다시 확인해 주세요.',
  'RATE_LIMITED' || 'REQUEST_IN_PROGRESS' => '잠시 후 다시 시도해 주세요.',
  'REQUEST_EXPIRED' || 'IDEMPOTENCY_EXPIRED' => '요청 기한이 지났습니다. 현재 상태를 확인해 주세요.',
  'LOCAL_STORAGE_FAILED' => '이 기기에 변경을 저장하지 못했습니다.',
  null => '',
  _ => '주간 레이드를 불러오거나 저장하지 못했습니다.',
};

class _WeeklyCommand {
  _WeeklyCommand(
    this.character,
    this.raid,
    this.key,
    this.body,
    this.started, {
    this.ack = false,
    this.failed = false,
  });
  factory _WeeklyCommand.fromJson(Map<String, dynamic> json) {
    roleShape(json, 'character raid key body started ack failed');
    final body = roleMap(json['body']);
    roleShape(
      body,
      'completed difficulty_id expected_cycle_key expected_catalog_version expected_revision expected_ownership_revision expected_lifecycle_revision',
    );
    final completed = raidBool(body['completed']);
    if (body['difficulty_id'] != null) raidIdentifier(body['difficulty_id']);
    roleCheck(completed || body['difficulty_id'] == null);
    raidCycleKey(body['expected_cycle_key']);
    raidText(body['expected_catalog_version']);
    for (final k in [
      'expected_revision',
      'expected_ownership_revision',
      'expected_lifecycle_revision',
    ]) {
      rolePositive(body[k]);
    }
    final key = roleId(json['key']);
    roleCheck(key[14] == '4');
    return _WeeklyCommand(
      roleId(json['character']),
      raidIdentifier(json['raid']),
      key,
      Map.unmodifiable(body),
      roleUtc(json['started']),
      ack: raidBool(json['ack']),
      failed: raidBool(json['failed']),
    );
  }
  final String character, raid, key;
  final Map<String, dynamic> body;
  final DateTime started;
  bool ack, failed;
  String get entryKey => '$character:$raid';
  Map<String, dynamic> toJson() => {
    'character': character,
    'raid': raid,
    'key': key,
    'body': body,
    'started': started.toUtc().toIso8601String(),
    'ack': ack,
    'failed': failed,
  };
}

/// App-owned. Server GET is authoritative; persisted commands never become
/// optimistic completion records or cross-member activity.
class MemberWeeklyViewModel extends ChangeNotifier {
  MemberWeeklyViewModel({
    required this.model,
    required this.client,
    required this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    model.addListener(_modelChanged);
    model.runtime.session.addListener(_modelChanged);
  }
  final MemberAccountViewModel model;
  final MemberRaidClient client;
  final MemberWeeklyStore store;
  final DateTime Function() now;
  RaidCatalog? catalog;
  MemberRaidCycle? cycle;
  String? failure;
  bool loading = false, writing = false;
  bool _saving = false;
  bool get busy => loading || writing || _saving;
  bool _disposed = false,
      _active = false,
      _loaded = false,
      _current = false,
      _refreshAgain = false;
  int _epoch = 0;
  AccountReadScope? _session;
  StorageScope? _scope;
  String? _signature;
  int? _signatureGeneration;
  String? _settledSignature;
  int? _settledGeneration;
  DateTime? _receivedAt, _retryAt;
  Timer? _cycleTimer, _retryTimer;
  Future<void>? _flight;
  Future<void> _disk = Future.value();
  Map<String, MemberWeeklyEntry> _entries = {};
  Map<String, CharacterWeeklyRaidDisplayPreference> _display = {};
  _WeeklyCommand? _pending;
  bool get hasPending => _pending != null;
  String? get pendingCharacter => _pending?.character;
  String? get pendingRaid => _pending?.raid;
  bool get pendingFailed => _pending?.failed == true;
  int get retrySeconds => _retryAt == null
      ? 0
      : ((_retryAt!.difference(now().toUtc()).inMilliseconds / 1000).ceil())
            .clamp(0, 86400);
  bool get canRetry =>
      model.signedIn &&
      !busy &&
      hasPending &&
      !pendingFailed &&
      retrySeconds == 0;
  bool get canUseCurrent => hasPending && pendingFailed && _current && !busy;
  bool get ready => _current && !loading && _cycleCurrent;

  /// The current member/targets had their weekly read attempted, even on failure.
  /// This is display sequencing only and never grants write permission.
  bool get initialDisplaySettled =>
      model.signedIn &&
      !loading &&
      _settledSignature == _targets() &&
      _settledGeneration == model.runtime.readGeneration;
  bool get _cycleCurrent =>
      cycle != null &&
      _receivedAt != null &&
      !now().toUtc().isBefore(_receivedAt!) &&
      cycle!.serverTime
          .add(now().toUtc().difference(_receivedAt!))
          .isBefore(cycle!.endsAt);
  List<MemberCharacterState> get _characters => [
    for (final s in model.sections)
      if (!s.cached && s.registration.ownershipStatus == 'owned')
        for (final c in s.visible)
          if (c.observation.lifecycleState == 'active' ||
              c.observation.lifecycleState == 'suspect')
            c,
  ];
  String _targets() => [
    for (final s in model.sections)
      if (!s.cached && s.registration.ownershipStatus == 'owned')
        for (final c in s.visible)
          '${s.registration.accountId}/${s.registration.ownershipRevision}/'
              '${c.ref.characterId}/${c.observation.lifecycleRevision}/'
              '${c.observation.profileJson}',
  ].join('|');
  void initialize() {
    _active = true;
    _modelChanged();
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _modelChanged() {
    if (_disposed) return;
    final signedIn = model.signedIn;
    final next = signedIn ? accountReadScope(model.runtime.session) : null;
    final scope = signedIn ? model.runtime.scope : null;
    if (next != _session || scope != _scope) {
      _epoch++;
      _session = next;
      _scope = scope;
      _loaded = false;
      _signature = null;
      _signatureGeneration = null;
      _settledSignature = null;
      _settledGeneration = null;
      _entries = {};
      _display = {};
      _pending = null;
      failure = null;
      _current = false;
      loading = false;
      writing = false;
      _saving = false;
      _cycleTimer?.cancel();
      _retryTimer?.cancel();
      _retryAt = null;
      _emit();
    }
    if (!_active ||
        next == null ||
        model.loading ||
        model.failure != null ||
        writing) {
      return;
    }
    final signature = _targets();
    if (signature == _signature &&
        _signatureGeneration == model.runtime.readGeneration) {
      return;
    }
    _signature = signature;
    _signatureGeneration = model.runtime.readGeneration;
    unawaited(refresh());
  }

  void _guard(int epoch, AccountReadScope member, StorageScope scope) {
    if (_disposed || epoch != _epoch) {
      throw const AccountReadException('SESSION_CHANGED');
    }
    model.runtime.requireCurrent(member, scope);
  }

  Future<void> _persist(StorageScope scope) {
    final encoded = jsonEncode({
      'schema': 1,
      'pending': _pending?.toJson(),
      'display': {
        for (final entry in _display.entries)
          entry.key: {
            'count': entry.value.displayCount,
            'raids': entry.value.raidIds,
          },
      },
    });
    final result = _disk.then((_) => store.write(scope, encoded));
    _disk = result.catchError((Object _) {});
    return result;
  }

  Future<void> _load(StorageScope scope, void Function() guard) async {
    if (_loaded) return;
    await _disk;
    guard();
    final raw = await store.read(scope);
    guard();
    if (raw != null) {
      final data = roleMap(jsonDecode(raw));
      roleShape(data, 'schema pending display');
      roleCheck(data['schema'] == 1);
      final prefs = <String, CharacterWeeklyRaidDisplayPreference>{};
      for (final e in roleMap(data['display']).entries) {
        roleId(e.key);
        final d = roleMap(e.value);
        roleShape(d, 'count raids');
        final pref = CharacterWeeklyRaidDisplayPreference(
          characterId: 0,
          displayCount: raidNonnegative(d['count']),
          raidIds: List.unmodifiable(raidList(d['raids']).map(raidIdentifier)),
        );
        roleCheck(pref.isValid);
        prefs[e.key] = pref;
      }
      _display = prefs;
      _pending = data['pending'] == null
          ? null
          : _WeeklyCommand.fromJson(roleMap(data['pending']));
    }
    _loaded = true;
  }

  void _cooldown(AccountReadException e) {
    _retryAt =
        e.retryAt ??
        (e.retryAfter == null ? null : now().toUtc().add(e.retryAfter!));
    _retryTimer?.cancel();
    if (retrySeconds > 0) {
      _retryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        _emit();
        if (retrySeconds == 0) t.cancel();
      });
    }
  }

  Future<void> refresh({bool reloadCatalog = false}) {
    if (_disposed ||
        !model.signedIn ||
        model.loading ||
        writing ||
        retrySeconds > 0) {
      return Future.value();
    }
    if (_flight case final flight?) {
      _refreshAgain = true;
      return flight;
    }
    final epoch = _epoch,
        member = accountReadScope(model.runtime.session),
        scope = model.runtime.scope;
    final generation = model.runtime.readGeneration, signature = _targets();
    void guard() {
      _guard(epoch, member, scope);
      if (generation != model.runtime.readGeneration ||
          signature != _targets()) {
        throw const AccountReadException('STALE_READ');
      }
    }

    loading = true;
    _current = false;
    failure = null;
    late final Future<void> flight;
    flight =
        Future<void>(
          () => LoadTiming.run(LoadStage.weeklyRefresh, () async {
            try {
              await LoadTiming.run(
                LoadStage.weeklyCache,
                () => _load(scope, guard),
              );
              guard();
              if (catalog == null || reloadCatalog) {
                catalog = await LoadTiming.run(
                  LoadStage.catalog,
                  client.catalog,
                );
                guard();
              }
              final publicCycle = await LoadTiming.run(
                LoadStage.cycle,
                client.cycle,
              );
              guard();
              final received = now().toUtc();
              final ids =
                  _characters.map((c) => c.ref.characterId).toSet().toList()
                    ..sort();
              final pending = _pending;
              if (pending != null && !ids.contains(pending.character)) {
                final row = model.sections
                    .where(
                      (s) =>
                          !s.cached &&
                          s.registration.ownershipStatus == 'owned',
                    )
                    .expand((s) => s.characters)
                    .where((c) => c.ref.characterId == pending.character)
                    .firstOrNull;
                if (row != null) ids.add(pending.character);
              }
              final entries = <String, MemberWeeklyEntry>{};
              final raidIds = catalog!.raids.map((r) => r.raidId).toSet();
              for (var i = 0; i < ids.length; i += 50) {
                final chunk = ids.skip(i).take(50).toList();
                final batch = await LoadTiming.run(
                  LoadStage.weeklyBatch,
                  () => client.states(chunk),
                );
                guard();
                if (batch.catalogVersion != catalog!.catalogVersion) {
                  throw const AccountReadException('CATALOG_VERSION_CONFLICT');
                }
                if (batch.cycle.key != publicCycle.key ||
                    batch.cycleKey != publicCycle.key) {
                  throw const AccountReadException('CYCLE_CHANGED');
                }
                final expected = {
                  for (final id in chunk)
                    for (final raid in raidIds) '$id:$raid',
                };
                for (final entry in batch.entries) {
                  if (entry.cycleKey != publicCycle.key ||
                      !expected.remove(entry.key) ||
                      entries.containsKey(entry.key)) {
                    throw const AccountReadException('INVALID_RESPONSE');
                  }
                  entries[entry.key] = entry;
                }
                if (expected.isNotEmpty) {
                  throw const AccountReadException('INVALID_RESPONSE');
                }
              }
              guard();
              final until = publicCycle.endsAt.difference(
                publicCycle.serverTime.add(now().toUtc().difference(received)),
              );
              if (until <= Duration.zero) {
                throw const AccountReadException('CYCLE_CHANGED');
              }
              cycle = publicCycle;
              _receivedAt = received;
              _entries = entries;
              _current = true;
              _cycleTimer?.cancel();
              _cycleTimer = Timer(until, () {
                if (!_disposed) {
                  _current = false;
                  _emit();
                  unawaited(refresh());
                }
              });
            } catch (e) {
              LoadTiming.failure();
              if (!_disposed && epoch == _epoch) {
                failure = e is AccountReadException
                    ? e.code
                    : e is FormatException || e is TypeError
                    ? 'INVALID_RESPONSE'
                    : 'LOCAL_STORAGE_FAILED';
                if (e is AccountReadException) _cooldown(e);
              }
            } finally {
              if (!_disposed && epoch == _epoch) {
                if (generation == model.runtime.readGeneration &&
                    signature == _targets()) {
                  _settledSignature = signature;
                  _settledGeneration = generation;
                }
                loading = false;
                _emit();
              }
            }
          }, root: true),
        ).whenComplete(() {
          if (!identical(_flight, flight)) return;
          _flight = null;
          if (_refreshAgain) {
            _refreshAgain = false;
            if (!_disposed) unawaited(refresh());
          }
        });
    _flight = flight;
    _emit();
    return flight;
  }

  CharacterWeeklyRaidDisplayPreference? preference(String character) =>
      _display[character];
  String? rosterDisplayToken(String registrationId) {
    final section = model.sections
        .where(
          (s) =>
              s.registration.registrationId == registrationId &&
              !s.cached &&
              s.registration.ownershipStatus == 'owned',
        )
        .firstOrNull;
    if (section == null) return null;
    final r = section.registration;
    return jsonEncode([
      r.version,
      r.settings.version,
      r.ownershipRevision,
      r.rosterRevision,
      for (final c in section.characters)
        [
          c.ref.characterId,
          c.observation.lifecycleRevision,
          c.observation.profileJson,
        ],
    ]);
  }

  bool canEditRosterDisplay(String id) =>
      _loaded && !busy && catalog != null && rosterDisplayToken(id) != null;

  Future<void> saveRosterDisplay(String id, int count, String token) async {
    if (!canEditRosterDisplay(id) ||
        token != rosterDisplayToken(id) ||
        count < 0 ||
        count > WeeklyRaidDisplayProjector.maxDisplayCount) {
      return;
    }
    final section = model.sections.firstWhere(
      (s) => s.registration.registrationId == id,
    );
    final member = accountReadScope(model.runtime.session),
        scope = model.runtime.scope,
        epoch = _epoch;
    final before = Map<String, CharacterWeeklyRaidDisplayPreference>.of(
      _display,
    );
    writing = true;
    _emit();
    try {
      for (final row in section.characters.where(
        (c) => c.observation.usable == true,
      )) {
        final selected = WeeklyRaidDisplayProjector.selectionForCount(
          eligible: eligible(row.ref),
          requestedCount: count,
        );
        _display[row.ref.characterId] = CharacterWeeklyRaidDisplayPreference(
          characterId: 0,
          displayCount: selected.length,
          raidIds: selected.map((r) => r.raidId).toList(),
        );
      }
      await _persist(scope);
      _guard(epoch, member, scope);
      failure = null;
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        _display = before;
        failure = 'LOCAL_STORAGE_FAILED';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        writing = false;
        _emit();
      }
    }
  }

  List<WeeklyRaidDisplayCandidate> eligible(ScopedCharacterRef ref) {
    if (catalog == null) return const [];
    final row = model.character(ref);
    if (row == null) return const [];
    final level = double.tryParse(
      '${(jsonDecode(row.observation.profileJson) as Map)['item_level']}',
    );
    if (level == null || !level.isFinite) return const [];
    return WeeklyRaidDisplayProjector.eligibleCandidates(
      catalog: catalog!,
      itemLevel: level,
    );
  }

  List<WeeklyRaidDisplayCandidate> displayed(ScopedCharacterRef ref) =>
      WeeklyRaidDisplayProjector.resolve(
        eligible: eligible(ref),
        preference: preference(ref.characterId),
      );
  bool canEditDisplay(ScopedCharacterRef ref) =>
      _loaded && !busy && model.detailsAvailable(ref) && catalog != null;
  Future<void> saveDisplay(
    ScopedCharacterRef ref,
    CharacterWeeklyRaidDisplayPreference? pref,
  ) async {
    if (!canEditDisplay(ref) || (pref != null && !pref.isValid)) return;
    final member = accountReadScope(model.runtime.session),
        scope = model.runtime.scope,
        epoch = _epoch;
    final before = Map<String, CharacterWeeklyRaidDisplayPreference>.of(
      _display,
    );
    writing = true;
    try {
      if (pref == null) {
        _display.remove(ref.characterId);
      } else {
        _display[ref.characterId] = pref;
      }
      await _persist(scope);
      _guard(epoch, member, scope);
      failure = null;
    } catch (e) {
      if (!_disposed && epoch == _epoch) {
        _display = before;
        failure = 'LOCAL_STORAGE_FAILED';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        writing = false;
        _emit();
      }
    }
  }

  MemberWeeklyEntry? entry(ScopedCharacterRef ref, String raid) =>
      _entries['${ref.characterId}:$raid'];
  bool canChange(ScopedCharacterRef ref, String raid) {
    final value = entry(ref, raid);
    return ready &&
        !busy &&
        !hasPending &&
        retrySeconds == 0 &&
        model.detailsAvailable(ref) &&
        value != null &&
        model.sections.any(
          (s) =>
              s.registration.accountId == ref.accountId &&
              s.registration.ownershipRevision == value.ownershipRevision,
        ) &&
        value.lifecycleRevision ==
            model.character(ref)!.observation.lifecycleRevision &&
        (value.completed ? value.canClear : value.canMark);
  }

  List<WeeklyRaidStatusItem> items(ScopedCharacterRef ref) => [
    for (final c in displayed(ref))
      WeeklyRaidStatusItem(
        raidId: c.raidId,
        difficultyId: c.difficultyId,
        label: c.label,
        isCompleted: entry(ref, c.raidId)?.completed ?? false,
        statusKind: entry(ref, c.raidId) == null && !busy && failure != null
            ? WeeklyRaidStatusKind.inconsistent
            : entry(ref, c.raidId)?.participating == true
            ? WeeklyRaidStatusKind.active
            : null,
        toggleAllowed: canChange(ref, c.raidId),
      ),
  ];
  Future<void> change(
    ScopedCharacterRef ref,
    WeeklyRaidStatusItem raid,
    bool completed,
  ) async {
    if (!canChange(ref, raid.raidId)) return;
    final value = entry(ref, raid.raidId)!;
    if (completed == value.completed) return;
    final body = Map<String, dynamic>.unmodifiable({
      'completed': completed,
      'difficulty_id': completed ? raid.difficultyId : null,
      'expected_cycle_key': cycle!.key,
      'expected_catalog_version': catalog!.catalogVersion,
      'expected_revision': value.revision,
      'expected_ownership_revision': value.ownershipRevision,
      'expected_lifecycle_revision': value.lifecycleRevision,
    });
    _pending = _WeeklyCommand(
      ref.characterId,
      raid.raidId,
      newScopedCommandKey(),
      body,
      now().toUtc(),
    );
    await _send();
  }

  Future<void> retry() async {
    if (canRetry) await _send();
  }

  Future<void> _send() async {
    if (_saving || _pending == null || writing || !model.signedIn) return;
    final epoch = _epoch;
    _saving = true;
    try {
      await _sendPending();
    } finally {
      if (!_disposed && epoch == _epoch) {
        _saving = false;
        _emit();
      }
    }
  }

  Future<void> _sendPending() async {
    final command = _pending;
    if (command == null || writing || !model.signedIn) return;
    final epoch = _epoch,
        member = accountReadScope(model.runtime.session),
        scope = model.runtime.scope;
    void guard() => _guard(epoch, member, scope);
    writing = true;
    _current = false;
    failure = null;
    _emit();
    try {
      final age = now().toUtc().difference(command.started);
      if (!command.ack &&
          (age < Duration.zero || age >= const Duration(hours: 24))) {
        command.failed = true;
        await _persist(scope);
        throw const AccountReadException('REQUEST_EXPIRED');
      }
      await _persist(scope);
      guard();
      if (!command.ack) {
        final ack = await client.put(
          command.character,
          command.raid,
          command.key,
          command.body,
        );
        guard();
        roleCheck(
          ack.characterId == command.character &&
              ack.raidId == command.raid &&
              ack.cycleKey == command.body['expected_cycle_key'] &&
              ack.ownershipRevision ==
                  command.body['expected_ownership_revision'] &&
              ack.lifecycleRevision ==
                  command.body['expected_lifecycle_revision'] &&
              ack.revision >= (command.body['expected_revision'] as int) &&
              ack.revision <= (command.body['expected_revision'] as int) + 1 &&
              ack.manual == command.body['completed'],
        );
        command.ack = true;
        await _persist(scope);
        guard();
      }
    } catch (e) {
      if (!_disposed && epoch == _epoch) {
        final code = e is AccountReadException
            ? e.code
            : e is FormatException || e is TypeError
            ? 'INVALID_RESPONSE'
            : 'LOCAL_STORAGE_FAILED';
        failure = code;
        if (e is AccountReadException) _cooldown(e);
        if ({
          'REVISION_CONFLICT',
          'CATALOG_VERSION_CONFLICT',
          'CYCLE_CHANGED',
          'PARTICIPATION_CONFIRMATION_REQUIRED',
          'RAID_INACTIVE',
          'CHARACTER_UNUSABLE',
          'CHARACTER_NOT_FOUND',
          'OWNERSHIP_REQUIRED',
          'IDEMPOTENCY_CONFLICT',
          'IDEMPOTENCY_EXPIRED',
        }.contains(code)) {
          command.failed = true;
          try {
            await _persist(scope);
          } catch (_) {
            /* Retain the original durable command. */
          }
        }
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        writing = false;
        _emit();
      }
    }
    if (_disposed || epoch != _epoch) return;
    if (command.ack) {
      await refresh();
      if (_disposed || epoch != _epoch) return;
      if (_current && _entries.containsKey(command.entryKey)) {
        writing = true;
        _pending = null;
        try {
          await _persist(scope);
          guard();
        } catch (_) {
          if (epoch == _epoch) {
            _pending = command;
            failure = 'LOCAL_STORAGE_FAILED';
          }
        }
        if (!_disposed && epoch == _epoch) {
          writing = false;
          _emit();
        }
      }
    }
  }

  Future<void> useCurrent() async {
    if (!canUseCurrent) return;
    final command = _pending!, scope = model.runtime.scope, epoch = _epoch;
    writing = true;
    _emit();
    _pending = null;
    try {
      await _persist(scope);
      if (!_disposed && epoch == _epoch) {
        failure = null;
      }
    } catch (_) {
      if (!_disposed && epoch == _epoch) {
        _pending = command;
        failure = 'LOCAL_STORAGE_FAILED';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        writing = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _cycleTimer?.cancel();
    _retryTimer?.cancel();
    model.removeListener(_modelChanged);
    model.runtime.session.removeListener(_modelChanged);
    super.dispose();
  }
}
