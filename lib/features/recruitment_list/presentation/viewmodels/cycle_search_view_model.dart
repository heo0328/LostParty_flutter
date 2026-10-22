import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../../account/domain/member_cycle_models.dart';
import '../../../account/domain/role_summary.dart';
import '../../../../shared/raid_catalog/domain/entities/raid_catalog.dart';
import '../../domain/backend_recruitment.dart';
import '../../data/cycle_read_repository.dart';
import '../../data/group_character_candidates.dart';
import '../../data/cycle_interaction_repository.dart';
import 'cycle_participation_controller.dart';

class CycleSearchViewModel extends ChangeNotifier {
  CycleSearchViewModel({
    required this.gateway,
    required this.session,
    required this.changes,
    required this.scopeKey,
    this.mutations,
  }) {
    _binding = scopeKey();
    session.addListener(_access);
    changes.addListener(_access);
    mutations?.addListener(_mutation);
  }
  final CycleInteractionGateway gateway;
  final AccountReadSession session;
  final Listenable changes;
  final String Function() scopeKey;
  final CycleParticipationController? mutations;
  late String _binding;
  bool _disposed = false, loading = false, groupLoading = false;
  int _epoch = 0, _groupEpoch = 0, _mutationVersion = 0;
  Timer? _timer;
  MemberCycles? cycles;
  RaidCatalog? catalog;
  List<RecruitmentGroupChoice> groups = [];
  CycleFilterContext? groupContext;
  List<CandidateMember> candidateMembers = [];
  String? candidateCursor, candidateFailure;
  bool candidateLoading = false, selectionPending = false;
  final _candidateCursors = <String>{};
  final _candidateCache =
      <String, (CycleFilterContext, List<CandidateMember>, String?, String)>{};

  void _clearCandidates() {
    candidateMembers = [];
    candidateCursor = candidateFailure = null;
    candidateLoading = false;
    selectionPending = false;
    _candidateCursors.clear();
  }

  void selectMember(String ref, bool selected) {
    final members = Map<String, Set<String>>.of(filter.members);
    if (selected) {
      members[ref] = {};
    } else {
      members.remove(ref);
    }
    selectionPending = false;
    update(filter.copy(members: members));
  }

  void selectCharacter(String ref, String id) {
    final members = Map<String, Set<String>>.of(filter.members);
    final ids = {...?members[ref]};
    if (!ids.add(id)) ids.remove(id);
    if (ids.isEmpty) {
      members.remove(ref);
    } else {
      members[ref] = ids;
    }
    selectionPending = false;
    update(filter.copy(members: members));
  }

  Future<void> loadCandidates({bool more = false}) async {
    final group = filter.groupId, context = groupContext;
    if (_disposed ||
        candidateLoading ||
        groupLoading ||
        group == null ||
        context == null ||
        (more && candidateCursor == null)) {
      return;
    }
    final e = _groupEpoch,
        binding = _binding,
        oldCursor = more ? candidateCursor : null;
    candidateLoading = true;
    candidateFailure = null;
    _emit();
    try {
      final page = await gateway.candidates(group, context, cursor: oldCursor);
      if (_disposed || e != _groupEpoch || binding != scopeKey()) return;
      if (more &&
          (page.token != filter.candidateToken ||
              (page.cursor != null &&
                  (page.cursor == oldCursor ||
                      _candidateCursors.contains(page.cursor))))) {
        throw const AccountReadException('CURSOR_STALE');
      }
      final combined = page.appendTo(more ? candidateMembers : []);
      if (page.cursor == null) {
        roleCheck(combined.length == context.members.length);
      }
      candidateMembers = combined;
      candidateCursor = page.cursor;
      if (!more) _candidateCursors.clear();
      if (page.cursor != null) _candidateCursors.add(page.cursor!);
      filter = filter.copy(candidateToken: page.token);
      _filters[target!] = filter;
      _candidateCache[group] = (
        context,
        candidateMembers,
        candidateCursor,
        page.token,
      );
    } on AccountReadException catch (error) {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        if (more &&
            {'CURSOR_STALE', 'FILTER_CONTEXT_STALE'}.contains(error.code)) {
          candidateLoading = false;
          await selectGroup(group, preserve: true, recovered: true);
          return;
        }
        candidateFailure = error.code;
        selectionPending = filter.members.isNotEmpty;
        if ({
          'CURSOR_STALE',
          'FILTER_CONTEXT_STALE',
          'GROUP_NOT_FOUND',
        }.contains(error.code)) {
          candidateMembers = [];
          candidateCursor = null;
          _candidateCache.remove(group);
          _pages.clear();
          rows = [];
          cursor = null;
          if (error.code != 'CURSOR_STALE') groupContext = null;
        }
      }
    } catch (_) {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        candidateFailure = 'INVALID_RESPONSE';
      }
    } finally {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        candidateLoading = false;
        _emit();
      }
    }
  }

  Future<void> refreshCandidates() async {
    final group = filter.groupId;
    if (group == null || candidateLoading || groupLoading) return;
    await selectGroup(group, preserve: true);
  }

  String? target, failure, cursor, groupFailure;
  String? _digest;
  List<CycleRoomCard> rows = [];
  CycleSearchFilter filter = CycleSearchFilter();
  final _filters = <String, CycleSearchFilter>{};
  final _pages = <(String, String), (List<CycleRoomCard>, String?, String?)>{};
  final _cursors = <String>{};
  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      session.isAuthenticated &&
      scopeKey() == _binding;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _access() {
    if (_binding == scopeKey() && session.isAuthenticated) return;
    _binding = scopeKey();
    _epoch++;
    _groupEpoch++;
    _filters.clear();
    _clearCandidates();
    _candidateCache.clear();
    _pages.clear();
    _cursors.clear();
    cycles = null;
    groupContext = null;
    target = null;
    rows = [];
    groups = [];
    filter = CycleSearchFilter();
    cursor = null;
    _digest = null;
    failure = groupFailure = null;
    loading = groupLoading = false;
    _timer?.cancel();
    _emit();
    if (session.isAuthenticated) unawaited(load());
  }

  void _mutation() {
    final m = mutations!;
    if (m.mutationVersion == _mutationVersion) return;
    _mutationVersion = m.mutationVersion;
    final t = m.lastTarget;
    _pages.removeWhere((k, _) => k.$1 == t);
    if (target == t) {
      _epoch++;
      loading = false;
      unawaited(refresh());
    }
  }

  Future<void> load() async {
    if (_disposed || loading) return;
    final e = ++_epoch;
    loading = true;
    failure = null;
    _emit();
    try {
      if (catalog == null) {
        final labels = await gateway.catalog();
        if (_disposed || e != _epoch) return;
        catalog = labels;
      }
      if (!session.isAuthenticated) return;
      final meta = await gateway.cycles();
      if (!_valid(e)) return;
      cycles = meta;
      target = meta.find(target ?? '')?.key ?? meta.current.key;
      _timer?.cancel();
      _timer = Timer(
        meta.current.endsAt.difference(meta.serverNow),
        () => unawaited(refresh()),
      );
    } on AccountReadException catch (error) {
      if (!_disposed && e == _epoch) failure = error.code;
    } catch (_) {
      if (!_disposed && e == _epoch) failure = 'INVALID_RESPONSE';
    } finally {
      if (!_disposed && e == _epoch) {
        loading = false;
        _emit();
      }
    }
    if (_valid(e) && target != null && failure == null) {
      if (filter.groupId != null && groupContext == null) {
        await selectGroup(filter.groupId, preserve: true);
      } else {
        await search();
      }
    }
  }

  Future<void> refresh() async {
    if (loading) return;
    _pages.removeWhere((k, _) => k.$1 == target);
    await load();
  }

  void selectTarget(String t) {
    if (cycles?.find(t) == null || target == t) return;
    _filters[target ?? ''] = filter;
    target = t;
    filter = _filters[t] ?? CycleSearchFilter();
    groupContext = null;
    _groupEpoch++;
    groupLoading = false;
    _clearCandidates();
    final cached = _candidateCache[filter.groupId];
    if (cached != null) {
      groupContext = cached.$1;
      candidateMembers = cached.$2;
      candidateCursor = cached.$3;
      filter = filter.copy(token: cached.$1.token, candidateToken: cached.$4);
      _select();
    } else if (filter.groupId != null) {
      unawaited(selectGroup(filter.groupId, preserve: true));
    } else {
      _select();
    }
  }

  void update(CycleSearchFilter next) {
    if (target == null) return;
    if (next.category != filter.category && next.category != 'group_linked') {
      _groupEpoch++;
      groupContext = null;
      _clearCandidates();
      groupLoading = false;
      groupFailure = null;
    }
    filter = next;
    _filters[target!] = next;
    _select();
  }

  void selectGroups(Set<String> ids) {
    if (ids.length <= 1) {
      unawaited(selectGroup(ids.firstOrNull));
      return;
    }
    _groupEpoch++;
    _clearCandidates();
    groupContext = null;
    groupFailure = null;
    groupLoading = false;
    update(
      filter.copy(clearGroup: true, groupIds: ids, category: 'group_linked'),
    );
  }

  void _select() {
    _epoch++;
    loading = false;
    failure = null;
    _cursors.clear();
    final page = _pages[(target!, filter.signature)];
    rows = page?.$1 ?? [];
    cursor = page?.$2;
    _digest = page?.$3;
    _emit();
    if (page == null) unawaited(search());
  }

  Future<void> selectGroup(
    String? group, {
    bool preserve = false,
    bool recovered = false,
  }) async {
    final previous = filter,
        previousContext = groupContext ?? _candidateCache[group]?.$1;
    final e = ++_groupEpoch;
    groupContext = null;
    _clearCandidates();
    groupFailure = null;
    if (!preserve) {
      filter = filter.copy(
        clearGroup: true,
        category: group == null ? filter.category : 'group_linked',
      );
    }
    if (group == null) {
      groupLoading = false;
      update(filter);
      return;
    }
    filter = filter.copy(groupId: group);
    groupLoading = true;
    selectionPending = preserve && previous.members.isNotEmpty;
    _epoch++;
    loading = false;
    rows = [];
    cursor = null;
    _emit();
    final binding = _binding;
    try {
      final context = await gateway.filterContext(group);
      if (_disposed || e != _groupEpoch || binding != scopeKey()) return;
      groupContext = context;
      final members = <String, Set<String>>{};
      for (final selected
          in preserve
              ? previous.members.entries
              : <MapEntry<String, Set<String>>>[]) {
        final oldAlias = previousContext?.aliases[selected.key];
        final ref = oldAlias == null
            ? (context.aliases.containsKey(selected.key) ? selected.key : null)
            : context.aliases.entries
                  .where((v) => v.value == oldAlias)
                  .firstOrNull
                  ?.key;
        if (ref == null) {
          throw const AccountReadException('FILTER_CONTEXT_STALE');
        }
        members[ref] = selected.value;
      }
      filter = filter
          .copy(clearGroup: true, category: 'group_linked')
          .copy(groupId: group, token: context.token, members: members);
      groupLoading = false;
      await loadCandidates();
      if (_disposed || e != _groupEpoch || binding != scopeKey()) return;
      if (candidateFailure != null) return;
      _filters[target!] = filter;
      await search(recovered: recovered);
    } on AccountReadException catch (error) {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        groupFailure = error.code;
        selectionPending = preserve && previous.members.isNotEmpty;
        if (preserve) filter = previous;
        if (error.code == 'GROUP_NOT_FOUND') {
          _candidateCache.remove(group);
          _pages.clear();
        }
      }
    } catch (_) {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        groupFailure = 'INVALID_RESPONSE';
      }
    } finally {
      if (!_disposed && e == _groupEpoch && binding == scopeKey()) {
        groupLoading = false;
        _emit();
      }
    }
  }

  Future<void> loadGroups() async {
    if (!session.isAuthenticated || groupLoading) return;
    final binding = _binding;
    try {
      final v = await gateway.groups();
      if (!_disposed && binding == scopeKey()) {
        groups = v;
        _emit();
      }
    } on AccountReadException catch (error) {
      if (!_disposed && binding == scopeKey()) {
        groupFailure = error.code;
        _emit();
      }
    }
  }

  Future<void> search({bool more = false, bool recovered = false}) async {
    if (_disposed ||
        loading ||
        groupLoading ||
        candidateLoading ||
        (filter.groupId != null &&
            (groupContext == null ||
                candidateFailure != null ||
                groupFailure != null)) ||
        !session.isAuthenticated ||
        target == null ||
        (more && cursor == null)) {
      return;
    }
    final e = ++_epoch,
        t = target!,
        f = filter,
        previous = more ? cursor : null;
    loading = true;
    failure = null;
    _emit();
    try {
      final page = await gateway.search(t, f, cursor: previous);
      if (!_valid(e)) return;
      if (more &&
          (page.digest != _digest ||
              (page.cursor != null &&
                  (page.cursor == previous ||
                      _cursors.contains(page.cursor))))) {
        throw const AccountReadException('CURSOR_STALE');
      }
      final combined = more ? [...rows, ...page.rows] : page.rows;
      roleCheck(combined.map((r) => r.id).toSet().length == combined.length);
      selectionPending = false;
      rows = List.unmodifiable(combined);
      cursor = page.cursor;
      _digest = page.digest;
      if (!more) _cursors.clear();
      if (cursor != null) _cursors.add(cursor!);
      _pages[(t, f.signature)] = (rows, cursor, _digest);
    } on AccountReadException catch (error) {
      if (_valid(e)) {
        if (f.candidateToken != null &&
            {
              'GROUP_CHARACTER_CANDIDATES_STALE',
              'FILTER_CONTEXT_STALE',
            }.contains(error.code) &&
            !recovered) {
          loading = false;
          selectionPending = f.members.isNotEmpty;
          _pages.removeWhere((k, _) => k.$1 == t);
          await selectGroup(f.groupId, preserve: true, recovered: true);
          return;
        }
        failure = error.code;
        if (f.candidateToken != null) {
          selectionPending = f.members.isNotEmpty;
          rows = [];
          cursor = null;
          _pages.remove((t, f.signature));
          if (error.code == 'GROUP_NOT_FOUND') {
            _candidateCache.remove(f.groupId);
            candidateMembers = [];
            candidateCursor = null;
            groupContext = null;
          }
        }
        if ({
          'CURSOR_STALE',
          'FILTER_CONTEXT_STALE',
          'CYCLE_CHANGED',
        }.contains(error.code)) {
          rows = [];
          cursor = null;
          _pages.remove((t, f.signature));
          if (error.code == 'FILTER_CONTEXT_STALE') groupContext = null;
        }
      }
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        loading = false;
        _emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _groupEpoch++;
    _timer?.cancel();
    session.removeListener(_access);
    changes.removeListener(_access);
    mutations?.removeListener(_mutation);
    super.dispose();
  }
}
