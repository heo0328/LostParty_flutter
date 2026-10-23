import 'package:flutter/foundation.dart';
import '../../../account/domain/account_read_session.dart';
import '../../data/membership_readers.dart';
import '../../data/cycle_schedule.dart';

/// Dialog-owned display read. Command previews still use their original reader.
class MembershipPlanViewModel extends ChangeNotifier {
  MembershipPlanViewModel({
    required this.reader,
    required this.session,
    required this.scopeKey,
    required this.room,
    required this.target,
    this.anchor,
    this.changes,
  }) {
    _binding = scopeKey();
    session.addListener(_access);
    changes?.addListener(_access);
  }
  final MembershipReadGateway reader;
  final AccountReadSession session;
  final String Function() scopeKey;
  final String room, target;
  final MembershipRecordAnchor? anchor;
  final Listenable? changes;
  late String _binding;
  bool _disposed = false, loading = false;
  int _epoch = 0;
  MembershipReadView? profile;
  CycleScheduleView? value;
  String? failure;
  bool get readOnly => anchor != null || profile?.projection.readOnly == true;
  void _access() {
    if (session.isAuthenticated && _binding == scopeKey()) return;
    _binding = scopeKey();
    _epoch++;
    profile = null;
    value = null;
    failure = null;
    loading = false;
    if (!_disposed) notifyListeners();
  }

  bool _valid(int e) =>
      !_disposed &&
      e == _epoch &&
      session.isAuthenticated &&
      _binding == scopeKey();
  Future<void> load() async {
    if (_disposed || loading || !session.isAuthenticated) return;
    _access();
    final e = ++_epoch;
    loading = true;
    failure = null;
    profile = null;
    value = null;
    notifyListeners();
    try {
      final result = await reader.plan(room, target, anchor: anchor);
      if (!_valid(e)) return;
      final content = result.projection.content;
      final parsed = content == null
          ? null
          : CycleScheduleView(room, target, 'plan', content);
      profile = result;
      value = parsed;
    } on AccountReadException catch (error) {
      if (_valid(e)) failure = error.code;
    } catch (_) {
      if (_valid(e)) failure = 'INVALID_RESPONSE';
    } finally {
      if (_valid(e)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    session.removeListener(_access);
    changes?.removeListener(_access);
    super.dispose();
  }
}
