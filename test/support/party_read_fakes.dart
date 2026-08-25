import 'package:lost_party/features/raid_status/domain/services/party_event_sync_service.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/party_read_models.dart';
import 'package:lost_party/features/recruitment_list/domain/entities/recruitment_aggregate.dart';
import 'package:lost_party/features/recruitment_list/domain/repositories/party_read_repository.dart';

const emptyActiveRaids = PartyReadSnapshot<ActiveRaidSummary>(
  items: [],
  isFromCache: false,
);

const emptyApplications = PartyReadSnapshot<PartyApplicationSummary>(
  items: [],
  isFromCache: false,
);

class FakePartyReadRepository implements PartyReadRepository {
  FakePartyReadRepository({
    Stream<PartyReadSnapshot<ActiveRaidSummary>>? activeRaids,
    Stream<PartyReadSnapshot<PartyApplicationSummary>>? applications,
  }) : _activeRaids = activeRaids ?? Stream.value(emptyActiveRaids),
       _applications = applications ?? Stream.value(emptyApplications);

  final Stream<PartyReadSnapshot<ActiveRaidSummary>> _activeRaids;
  final Stream<PartyReadSnapshot<PartyApplicationSummary>> _applications;

  String? requestedActiveRaidsPlayerId;
  String? requestedApplicationsPlayerId;
  String? requestedApplicationsCycleKey;

  @override
  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  }) {
    requestedActiveRaidsPlayerId = playerId;
    return _activeRaids;
  }

  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  }) {
    requestedApplicationsPlayerId = playerId;
    requestedApplicationsCycleKey = cycleKey;
    return _applications;
  }

  @override
  Stream<PartyReadSnapshot<PublicRecruitmentSummary>> watchPublicRecruitments({
    required String cycleKey,
  }) => Stream<PartyReadSnapshot<PublicRecruitmentSummary>>.empty();

  @override
  Stream<PublicRecruitmentSummary?> watchRecruitment(String recruitmentId) =>
      Stream<PublicRecruitmentSummary?>.empty();
}

class FakePartyEventSyncService implements PartyEventSyncService {
  FakePartyEventSyncService({
    this.result = const PartyEventSyncResult.success(0),
  });

  final PartyEventSyncResult result;
  var syncCount = 0;

  @override
  Future<PartyEventSyncResult> sync() async {
    syncCount += 1;
    return result;
  }
}
