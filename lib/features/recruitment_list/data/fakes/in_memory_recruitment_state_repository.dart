import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/repositories/recruitment_state_repository.dart';
import '../../domain/state/recruitment_state_machine.dart';

class InMemoryRecruitmentStateRepository implements RecruitmentStateRepository {
  final Map<String, RecruitmentAggregate> _store = {};

  @override
  Future<bool> create(RecruitmentAggregate aggregate) async {
    if (_store.containsKey(aggregate.id)) return false;
    _store[aggregate.id] = aggregate;
    return true;
  }

  @override
  Future<RecruitmentAggregate?> getById(String recruitmentId) async =>
      _store[recruitmentId];

  @override
  Future<List<PublicRecruitmentSummary>> getPublicRecruitments() async {
    final summaries =
        _store.values
            .where((aggregate) => aggregate.state.isRecruiting)
            .map(PublicRecruitmentSummary.fromAggregate)
            .toList(growable: false)
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return summaries;
  }

  @override
  Future<RecruitmentAggregate?> updateIfRevision({
    required String recruitmentId,
    required int expectedRevision,
    required RecruitmentState nextState,
    required DateTime updatedAt,
  }) async {
    final current = _store[recruitmentId];
    if (current == null || current.revision != expectedRevision) return null;
    final updated = current.copyWith(
      state: nextState,
      revision: current.revision + 1,
      updatedAt: updatedAt,
    );
    _store[recruitmentId] = updated;
    return updated;
  }
}
