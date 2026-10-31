import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/backend/group_repository.dart';
import '../../data/backend/group_models.dart';

enum GroupDetailArea { members, requests, code, management }

enum GroupPageKind {
  home,
  search,
  create,
  detail,
  invite,
  requests,
  code,
  joinCode,
  info,
  blocked,
  raids,
}

class BackendGroupViewModel extends ChangeNotifier {
  BackendGroupViewModel(this.repository, this.kind, {this.groupId}) {
    _sessionBinding = repository.readScope;
    repository.session.addListener(_sessionChanged);
    repository.changes.addListener(_groupsChanged);
  }
  final GroupRepository repository;
  final GroupPageKind kind;
  final String? groupId;
  late String _sessionBinding;
  int _epoch = 0;
  int get observation => _epoch;
  bool _disposed = false;
  bool loading = false, busy = false;
  bool hasPendingRequest = false;
  Object? failure, countsFailure;
  String? notice, cursor;
  Map<String, dynamic>? summary, management, code, counts, usage, preview;
  GroupDetailSnapshot? detail;
  List<Map<String, dynamic>> rows = [], groups = [];
  List<Map<String, dynamic>> requests = [];
  final areaLoading = <GroupDetailArea>{};
  final areaLoaded = <GroupDetailArea>{};
  final areaFailures = <GroupDetailArea, Object>{};
  List<Map<String, dynamic>> inviteCandidates = [];
  int _inviteEpoch = 0;
  void clearInviteCandidates() {
    _inviteEpoch++;
    inviteCandidates = [];
  }

  Future<void> searchInvites(String name) async {
    if (busy || !authenticated || groupId == null) return;
    clearInviteCandidates();
    final e = _inviteEpoch, scope = repository.readScope, observation = _epoch;
    bool current() =>
        !_disposed &&
        e == _inviteEpoch &&
        scope == repository.readScope &&
        observation == _epoch;
    busy = true;
    failure = null;
    notice = null;
    _emit();
    try {
      final value = await repository.get(
        '/v1/groups/$groupId/invite-candidates',
        query: {
          'character_name': name.trim(),
          'reader_profile': 'group-display-1',
        },
      );
      if (current()) inviteCandidates = groupItems(value);
    } catch (error) {
      if (current()) failure = error;
    } finally {
      if (!_disposed && scope == repository.readScope) {
        busy = false;
        _emit();
      }
    }
  }

  final Map<String, List<Map<String, dynamic>>> activities = {};
  final Map<String, Object> activityFailures = {};
  int homeTab = 0;
  String relationView = 'received_invitations';
  String query = '';
  bool get authenticated => repository.session.isAuthenticated;
  bool get leader => detail?.leader == true;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    final next = repository.readScope;
    if (next == _sessionBinding) return;
    _sessionBinding = next;
    _epoch++;
    loading = busy = false;
    detail = null;
    summary = management = code = counts = usage = preview = null;
    rows = [];
    _clearDetailAreas();
    clearInviteCandidates();
    groups = [];
    activities.clear();
    _activityLoading.clear();
    activityFailures.clear();
    failure = null;
    notice = null;
    hasPendingRequest = false;
    cursor = null;
    _emit();
    if (authenticated) load();
  }

  void _groupsChanged() {
    if (!busy && authenticated) load();
  }

  Future<void> load({bool more = false}) async {
    if (_disposed || !authenticated) return;
    final e = ++_epoch, binding = repository.readScope;
    bool current() =>
        !_disposed && e == _epoch && binding == repository.readScope;
    loading = true;
    failure = null;
    _emit();
    try {
      if (!more) {
        if (kind == GroupPageKind.invite) clearInviteCandidates();
        detail = null;
        management = null;
        code = null;
        usage = null;
        cursor = null;
        rows = [];
        _clearDetailAreas();
        activities.clear();
        _activityLoading.clear();
        activityFailures.clear();
      }
      if (kind == GroupPageKind.home) {
        final value = await repository.all(
          '/v1/me/groups',
          query: {'reader_profile': 'group-display-1'},
        );
        if (!current()) return;
        groups = value;
        try {
          final value = await repository.get('/v1/me/group-request-counts');
          if (!current()) return;
          counts = value;
          countsFailure = null;
        } catch (error) {
          if (!current()) return;
          counts = null;
          countsFailure = error;
        }
        if (homeTab == 0) {
          final value = await repository.get('/v1/me/usage-limits');
          if (!current()) return;
          usage = value;
          rows = groups;
        } else {
          final value = await repository.all(
            '/v1/me/group-relations',
            query: {'view': relationView, 'state': 'pending'},
          );
          if (!current()) return;
          rows = value;
          // Include managed applications in the existing requests tab.
          if (relationView == 'received_invitations') {
            for (final g in groups.where(
              (g) => g['my_membership']['role'] == 'leader',
            )) {
              final value = await repository.all(
                '/v1/groups/${g['group']['group_id']}/join-relations',
                query: {'state': 'pending'},
              );
              if (!current()) return;
              final ids = rows.map((r) => r['relation_id']).toSet();
              rows = [
                ...rows,
                ...value.where(
                  (r) =>
                      r['kind'] == 'application' && ids.add(r['relation_id']),
                ),
              ];
            }
          }
        }
      } else if (kind == GroupPageKind.search) {
        if (query.trim().isNotEmpty) {
          final page = await repository.get(
            '/v1/groups',
            query: {'q': query.trim(), 'limit': 20, 'cursor': ?cursor},
          );
          if (!current()) return;
          rows = [...rows, ...groupItems(page)];
          cursor = page['next_cursor'];
        }
      } else if (groupId != null) {
        final pub = await repository.get('/v1/groups/$groupId');
        if (!current()) return;
        summary = pub;
        GroupDetailSnapshot? next;
        try {
          final value = await repository.get(
            '/v1/me/groups/$groupId',
            query: {'reader_profile': 'group-display-1'},
          );
          if (!current()) return;
          next = GroupDetailSnapshot(value);
        } on AccountReadException catch (error) {
          if (error.status != 403 || error.code == 'ACCOUNT_DISABLED') rethrow;
        }
        if (!current()) return;
        detail = next;
        if (detail != null && kind == GroupPageKind.detail) {
          await Future.wait([
            for (final area in GroupDetailArea.values)
              if (area != GroupDetailArea.requests || leader)
                _loadArea(area, e, binding),
          ]);
        } else if (detail != null) {
          final value = await repository.get(
            '/v1/groups/$groupId/management',
            query: {'management_profile': 'group-management-1'},
          );
          if (!current()) return;
          management = value;
          final path = '/v1/groups/$groupId';
          final listPath = switch (kind) {
            GroupPageKind.detail || GroupPageKind.info => '$path/members',
            GroupPageKind.requests => '$path/join-relations',
            GroupPageKind.blocked => '$path/blocked-subjects',
            _ => null,
          };
          if (listPath != null) {
            final value = await repository.all(
              listPath,
              query: {
                if (kind == GroupPageKind.detail ||
                    kind == GroupPageKind.info ||
                    kind == GroupPageKind.blocked)
                  'reader_profile': 'group-display-1',
                if (kind == GroupPageKind.requests) 'state': 'pending',
              },
            );
            if (!current()) return;
            rows = value;
          }
          if (kind == GroupPageKind.code) {
            final value = await repository.get('$path/join-code');
            if (!current()) return;
            code = value;
          }
          if (kind == GroupPageKind.raids) {
            final page = await repository.get(
              '$path/raid-rooms',
              query: {'limit': 20, 'cursor': ?cursor},
            );
            if (!current()) return;
            counts = page;
            rows = [...rows, ...groupItems(page)];
            cursor = page['next_cursor'];
          }
        }
      }
      if (current()) {
        final pending = await repository.pending();
        if (current()) hasPendingRequest = pending != null;
      }
    } catch (error) {
      if (current()) {
        failure = error;
        if (more &&
            error is AccountReadException &&
            error.code == 'CURSOR_STALE') {
          loading = false;
          await load();
          return;
        }
      }
    } finally {
      if (current()) {
        loading = false;
        _emit();
      }
    }
  }

  void _clearDetailAreas() {
    requests = [];
    areaLoading.clear();
    areaLoaded.clear();
    areaFailures.clear();
  }

  Future<void> reloadArea(GroupDetailArea area) async {
    if (busy || loading || detail == null || areaLoading.contains(area)) return;
    if (area == GroupDetailArea.requests && !leader) return;
    await _loadArea(area, _epoch, repository.readScope);
  }

  Future<void> _loadArea(GroupDetailArea area, int epoch, String scope) async {
    bool current() =>
        !_disposed && epoch == _epoch && scope == repository.readScope;
    areaLoading.add(area);
    areaLoaded.remove(area);
    areaFailures.remove(area);
    _emit();
    final path = '/v1/groups/$groupId';
    try {
      switch (area) {
        case GroupDetailArea.members:
          final value = await repository.all(
            '$path/members',
            query: {'reader_profile': 'group-display-1'},
          );
          if (current()) rows = value;
        case GroupDetailArea.requests:
          final value = await repository.all(
            '$path/join-relations',
            query: {'state': 'pending'},
          );
          if (current()) requests = value;
        case GroupDetailArea.code:
          final value = await repository.get('$path/join-code');
          if (current()) code = value;
        case GroupDetailArea.management:
          final value = await repository.get(
            '$path/management',
            query: {'management_profile': 'group-management-1'},
          );
          if (current()) management = value;
      }
      if (current()) areaLoaded.add(area);
    } catch (error) {
      if (current()) areaFailures[area] = error;
    } finally {
      if (current()) {
        areaLoading.remove(area);
        _emit();
      }
    }
  }

  final Set<String> _activityLoading = {};
  Future<void> activity(String membership) async {
    if (activities.containsKey(membership) ||
        !_activityLoading.add(membership)) {
      return;
    }
    final e = _epoch, scope = repository.readScope;
    try {
      final value = await repository.all(
        '/v1/groups/$groupId/members/$membership/activity-characters',
      );
      if (_disposed || e != _epoch || scope != repository.readScope) return;
      activities[membership] = value;
      activityFailures.remove(membership);
    } catch (error) {
      if (!_disposed && e == _epoch) activityFailures[membership] = error;
    }
    _activityLoading.remove(membership);
    _emit();
  }

  Future<Map<String, dynamic>?> act(
    String method,
    String path,
    Map<String, dynamic> body, {
    String successNotice = '처리되었습니다.',
  }) async {
    if (busy) return null;
    final scope = repository.readScope;
    busy = true;
    failure = null;
    notice = null;
    _emit();
    try {
      final result = await repository.command(method, path, body);
      if (_disposed || scope != repository.readScope) return null;
      notice = successNotice;
      await load(); // A refresh error must not turn success into a retry command.
      return result;
    } catch (error) {
      if (!_disposed && scope == repository.readScope) failure = error;
      return null;
    } finally {
      if (!_disposed && scope == repository.readScope) {
        await _readPending(scope);
        if (!_disposed && scope == repository.readScope) {
          busy = false;
          _emit();
        }
      }
    }
  }

  Future<void> recover() async {
    if (busy) return;
    busy = true;
    failure = null;
    _emit();
    final scope = repository.readScope;
    try {
      final pending = await repository.pending();
      if (_disposed || scope != repository.readScope) return;
      if (pending == null) {
        hasPendingRequest = false;
        notice = null;
        return;
      }
      await repository.recover();
      if (_disposed || scope != repository.readScope) return;
      notice = '이전 요청의 처리가 확인되었습니다.';
      await load();
    } catch (error) {
      if (!_disposed && scope == repository.readScope) failure = error;
    } finally {
      if (!_disposed && scope == repository.readScope) {
        await _readPending(scope);
        if (!_disposed && scope == repository.readScope) {
          busy = false;
          _emit();
        }
      }
    }
  }

  Future<void> _readPending(String scope) async {
    try {
      final pending = await repository.pending();
      if (!_disposed && scope == repository.readScope) {
        hasPendingRequest = pending != null;
      }
    } catch (error) {
      if (!_disposed && scope == repository.readScope) failure ??= error;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    repository.session.removeListener(_sessionChanged);
    repository.changes.removeListener(_groupsChanged);
    super.dispose();
  }
}
