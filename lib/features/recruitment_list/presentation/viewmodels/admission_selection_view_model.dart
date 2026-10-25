import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/role_summary.dart';
import '../../data/admission_candidates.dart';
import '../../data/cycle_interaction_repository.dart';
import '../../data/group_character_candidates.dart' show compareCandidateLevels;
import '../../domain/backend_recruitment.dart';
import 'cycle_participation_controller.dart';

/// A sheet owns read/selection lifetime; the app controller owns original writes.
class AdmissionSelectionViewModel extends ChangeNotifier {
  AdmissionSelectionViewModel({
    required this.controller,
    required this.room,
    required this.target,
    required this.intent,
  }) {
    _binding = controller.scopeKey();
    controller.session.addListener(_access);
    controller.changes.addListener(_access);
    controller.addListener(_commandChanged);
  }
  final CycleParticipationController controller;
  final String room, target, intent;
  late String _binding;
  bool _disposed = false, loading = false, submitting = false;
  int _epoch = 0;
  String? failure, character, _submittedKey;
  String role = 'dealer';
  bool completed = false;
  List<RecruitmentCharacter> characters = const [];
  AdmissionCandidatePage? candidates;
  List<AdmissionCandidate> _eligible = const [];
  CycleAdmissionPreview? preview;
  final chosen = <String>{};
  bool get filtered => intent == 'apply' || intent == 'change_character';
  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      controller.session.isAuthenticated &&
      controller.scopeKey() == _binding;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _access() {
    if (_binding == controller.scopeKey() &&
        controller.session.isAuthenticated) {
      return;
    }
    _binding = controller.scopeKey();
    _epoch++;
    characters = const [];
    candidates = null;
    _eligible = const [];
    preview = null;
    character = null;
    chosen.clear();
    loading = submitting = completed = false;
    _submittedKey = null;
    failure = 'ACCESS_CHANGED';
    _emit();
  }

  void _commandChanged() {
    final result = controller.admissionSuccess;
    if (!_disposed &&
        _submittedKey != null &&
        result != null &&
        result.$1 == _submittedKey &&
        result.$2 == room &&
        result.$3 == target &&
        result.$4 == intent &&
        controller.scopeKey() == _binding &&
        controller.session.isAuthenticated) {
      completed = true;
      _emit();
    }
  }

  bool roleAllowed(String value) {
    if (value != 'dealer' && value != 'support') return false;
    if (!filtered) return true;
    final item = _eligible.where((v) => v.id == character).firstOrNull;
    return item?.evaluation(value).allowed == true;
  }

  String get emptyMessage {
    if (failure != null || loading) return '';
    if (candidates?.rawCount == 0 || !filtered) return '인증한 활동 캐릭터를 확인해 주세요.';
    return intent == 'apply' ? '이 모집에 신청 가능한 캐릭터가 없습니다.' : '변경 가능한 캐릭터가 없습니다.';
  }

  List<String> get exclusionMessages => [
    for (final e in candidates?.exclusions ?? <AdmissionExclusion>[])
      '${switch (e.reason) {
        'COMBAT_POWER_REQUIRED' => e.detail == 'missing' ? '전투력 정보 확인 필요 · 캐릭터 갱신 후 다시 확인해 주세요.' : '모집 전투력 조건 미달',
        'RAID_ITEM_LEVEL_REQUIRED' => '입장 레벨 미달',
        'WEEKLY_ALREADY_COMPLETED' => '해당 주차 레이드 완료',
        'WEEKLY_ALREADY_PARTICIPATING' => '해당 주차 레이드 참가 중',
        'ROOM_FULL' => '모집 정원 마감',
        _ => '파티 직업·역할 구성 불가',
      }} · ${e.count}명',
  ];

  Future<void> load({bool preserve = false}) async {
    if (_disposed ||
        completed ||
        loading ||
        submitting ||
        controller.hasPending ||
        !controller.session.isAuthenticated) {
      return;
    }
    final e = ++_epoch, oldCharacter = character, oldRole = role;
    loading = true;
    failure = null;
    preview = null;
    candidates = null;
    _eligible = const [];
    characters = const [];
    chosen.clear();
    _emit();
    try {
      final gateway = controller.gateway;
      AdmissionCandidatePage? first;
      final collected = <AdmissionCandidate>[];
      if (filtered) {
        if (gateway is! AdmissionCandidatesGateway) {
          throw const AccountReadException('INVALID_RESPONSE');
        }
        final cursors = <String>{};
        String? cursor, previous;
        while (true) {
          final page = await (gateway as AdmissionCandidatesGateway)
              .admissionCandidates(room, target, intent, cursor: cursor);
          if (!_valid(e)) return;
          final origin = first ??= page;
          if (page.identity != origin.identity) {
            throw const AccountReadException('CURSOR_STALE');
          }
          for (final item in page.items) {
            roleCheck(previous == null || previous.compareTo(item.id) < 0);
            previous = item.id;
            collected.add(item);
          }
          roleCheck(collected.length <= origin.eligibleCount);
          cursor = page.cursor;
          if (cursor == null) {
            roleCheck(collected.length == origin.eligibleCount);
            break;
          }
          roleCheck(
            collected.length < origin.eligibleCount &&
                page.items.isNotEmpty &&
                cursors.add(cursor),
          );
        }
      }
      var metadata = first?.eligibleCount == 0
          ? <RecruitmentCharacter>[]
          : await gateway.characters();
      if (!_valid(e)) return;
      if (filtered) {
        bool complete() => collected.every(
          (v) => metadata.any(
            (m) => m.id == v.id && m.registrationId == v.registration,
          ),
        );
        if (!complete()) {
          metadata = await gateway.characters();
          if (!_valid(e)) return;
        }
        if (!complete()) {
          throw const AccountReadException('CHARACTER_DATA_UNAVAILABLE');
        }
        roleCheck(metadata.map((v) => v.id).toSet().length == metadata.length);
        final order = <String, int>{};
        for (final m in metadata) {
          order.putIfAbsent(m.registrationId, () => order.length);
        }
        final display = <RecruitmentCharacter>[];
        for (final item in collected) {
          final m = metadata.singleWhere((v) => v.id == item.id);
          final row = RecruitmentCharacter(
            id: item.id,
            registrationId: item.registration,
            name: item.name,
            className: item.className,
            accountLabel: m.accountLabel,
            itemLevel: item.level,
            representative: m.representative,
            preferredRole: m.preferredRole,
          );
          roleCheck(
            row.supportsBothRoles == item.support.supported &&
                item.dealer.supported,
          );
          display.add(row);
        }
        display.sort((a, b) {
          final group = order[a.registrationId]!.compareTo(
            order[b.registrationId]!,
          );
          if (group != 0) return group;
          final level = compareCandidateLevels(a.itemLevel, b.itemLevel);
          return level == 0 ? a.id.compareTo(b.id) : level;
        });
        candidates = first;
        _eligible = List.unmodifiable(collected);
        characters = List.unmodifiable(display);
      } else {
        characters = List.unmodifiable(metadata);
      }
      character = preserve
          ? characters.where((v) => v.id == oldCharacter).firstOrNull?.id
          : characters.where((v) => v.representative).firstOrNull?.id ??
                characters.firstOrNull?.id;
      final selected = characters.where((v) => v.id == character).firstOrNull;
      role = preserve && roleAllowed(oldRole)
          ? oldRole
          : selected?.initialRole ?? 'dealer';
      if (!roleAllowed(role)) {
        role = roleAllowed('dealer') ? 'dealer' : 'support';
      }
    } on AccountReadException catch (error) {
      if (_valid(e)) failure = error.code;
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        loading = false;
        _emit();
      }
    }
    if (_valid(e) && failure == null && character != null) {
      await refreshPreview();
    }
  }

  Future<void> selectCharacter(String id) async {
    if (loading ||
        submitting ||
        controller.hasPending ||
        !characters.any((v) => v.id == id)) {
      return;
    }
    character = id;
    role = characters.singleWhere((v) => v.id == id).initialRole;
    if (!roleAllowed(role)) role = roleAllowed('dealer') ? 'dealer' : 'support';
    await refreshPreview();
  }

  Future<void> selectRole(String value) async {
    if (loading || submitting || controller.hasPending || !roleAllowed(value)) {
      return;
    }
    role = value;
    await refreshPreview();
  }

  Future<void> refreshPreview() async {
    if (_disposed || loading || character == null || controller.hasPending) {
      return;
    }
    final e = ++_epoch, id = character!, selectedRole = role;
    loading = true;
    failure = null;
    preview = null;
    chosen.clear();
    _emit();
    try {
      final value = await controller.gateway.admission(
        room,
        target,
        id,
        selectedRole,
        intent,
      );
      if (!_valid(e)) return;
      if (filtered) {
        final page = candidates!;
        if (value.scope['room_cycle_id'] != page.scope['room_cycle_id'] ||
            value.scope['target_generation'] !=
                page.scope['target_generation'] ||
            value.scope['target_revision'] != page.scope['target_revision']) {
          throw const AccountReadException('REVISION_CONFLICT');
        }
        roleCheck(
          roleMap(value.data['selection'])['registration_id'] ==
              characters.singleWhere((v) => v.id == id).registrationId,
        );
        final actor = page.actor;
        if (actor != null) {
          roleCheck(
            actor.assignments.length ==
                    (value.data['targets'] as List).length &&
                actor.assignments.every(
                  (a) => (value.data['targets'] as List).any(
                    (t) =>
                        t['item_id'] == a['item_id'] &&
                        t['round_id'] == a['round_id'],
                  ),
                ),
          );
        }
      }
      preview = value;
    } on AccountReadException catch (error) {
      if (_valid(e)) failure = error.code;
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        loading = false;
        _emit();
      }
    }
  }

  String get placementMessage {
    final actor = candidates?.actor, p = preview;
    if (actor == null || p == null) return '';
    return {
      for (final a in actor.assignments)
        for (final t in p.data['targets'] as List)
          if (t['item_id'] == a['item_id'] && t['party_no'] != a['party_no'])
            '${a['party_no']}파티 → ${t['party_no']}파티로 함께 이동합니다.',
    }.join('\n');
  }

  void chooseSessions(Set<String> values) {
    chosen
      ..clear()
      ..addAll(values);
    _emit();
  }

  Future<void> submit({String? applicationMemo}) async {
    final p = preview;
    if (_disposed ||
        loading ||
        submitting ||
        completed ||
        p == null ||
        !p.permission.allowed ||
        !roleAllowed(role) ||
        !p.display.selectionReady(chosen)) {
      return;
    }
    final e = _epoch;
    submitting = true;
    failure = null;
    _emit();
    try {
      _submittedKey = await controller.admit(
        p,
        {...chosen},
        applicationMemo: applicationMemo,
        expectedActor: candidates?.actor,
        isCurrent: () => _valid(e),
      );
      if (!_valid(e)) return;
      _commandChanged();
      if (!completed) failure = controller.failure;
    } finally {
      if (_valid(e)) {
        submitting = false;
        _emit();
      }
    }
    if (_valid(e) && !completed && !controller.hasPending && failure != null) {
      final message = failure;
      final binding = _binding;
      await load(preserve: true);
      if (!_disposed && _binding == binding && failure == null) {
        failure = message;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    controller.session.removeListener(_access);
    controller.changes.removeListener(_access);
    controller.removeListener(_commandChanged);
    characters = const [];
    candidates = null;
    _eligible = const [];
    preview = null;
    chosen.clear();
    super.dispose();
  }
}
