import 'package:flutter/foundation.dart';

import '../../domain/entities/recruitment_aggregate.dart';
import '../../domain/entities/recruitment_application.dart';
import '../../domain/repositories/recruitment_state_repository.dart';
import '../../domain/state/recruitment_state_machine.dart';

class InMemoryRecruitmentStateRepository extends ChangeNotifier
    implements RecruitmentStateRepository {
  final Map<String, RecruitmentAggregate> _store = {};

  void seed(RecruitmentAggregate aggregate) {
    _store[aggregate.id] = aggregate;
  }

  @override
  Future<bool> create(RecruitmentAggregate aggregate) async {
    if (_store.containsKey(aggregate.id)) return false;
    _store[aggregate.id] = aggregate;
    notifyListeners();
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
    notifyListeners();
    return updated;
  }

  @override
  Future<RecruitmentAggregate?> updateAggregateIfRevision({
    required String recruitmentId,
    required int expectedRevision,
    required String title,
    required RecruitmentMetadata metadata,
    required RecruitmentState nextState,
    required DateTime updatedAt,
  }) async {
    final current = _store[recruitmentId];
    if (current == null || current.revision != expectedRevision) return null;
    final updated = current.copyWith(
      title: title,
      metadata: metadata,
      state: nextState,
      revision: current.revision + 1,
      updatedAt: updatedAt,
    );
    _store[recruitmentId] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<bool> deleteIfRevision({
    required String recruitmentId,
    required int expectedRevision,
  }) async {
    final current = _store[recruitmentId];
    if (current == null || current.revision != expectedRevision) return false;
    _store.remove(recruitmentId);
    notifyListeners();
    return true;
  }

  @override
  Future<int> supersedePendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
    required String excludingRecruitmentId,
    required DateTime updatedAt,
  }) async {
    var changedCount = 0;
    for (final entry in _store.entries.toList(growable: false)) {
      final aggregate = entry.value;
      if (aggregate.id == excludingRecruitmentId ||
          aggregate.metadata.raidId != raidId) {
        continue;
      }
      final application = aggregate.state.applications[applicantUserId];
      if (application == null ||
          application.characterId != characterId ||
          application.status != RecruitmentApplicationStatus.pending) {
        continue;
      }
      _store[entry.key] = aggregate.copyWith(
        state: aggregate.state.copyWith(
          applications: {
            ...aggregate.state.applications,
            applicantUserId: application.copyWith(
              status: RecruitmentApplicationStatus.superseded,
            ),
          },
        ),
        revision: aggregate.revision + 1,
        updatedAt: updatedAt,
      );
      changedCount++;
    }
    if (changedCount > 0) notifyListeners();
    return changedCount;
  }

  @override
  Future<int> countPendingApplications({
    required String applicantUserId,
    required String characterId,
    required String raidId,
  }) async => _store.values.where((aggregate) {
    if (aggregate.metadata.raidId != raidId) return false;
    final application = aggregate.state.applications[applicantUserId];
    return application?.characterId == characterId &&
        application?.status == RecruitmentApplicationStatus.pending;
  }).length;
}
