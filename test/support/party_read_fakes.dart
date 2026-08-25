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

const emptyPublicRecruitmentPage = PublicRecruitmentPage(
  items: [],
  hasMore: false,
  isFromCache: false,
);

const emptyMembers = PartyReadSnapshot<PartyMemberDisplay>(
  items: [],
  isFromCache: false,
);

class FakePartyReadRepository implements PartyReadRepository {
  FakePartyReadRepository({
    Stream<PartyReadSnapshot<ActiveRaidSummary>>? activeRaids,
    Stream<PartyReadSnapshot<PartyApplicationSummary>>? applications,
    Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>>? recruitment,
    Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>>? myApplication,
    Stream<PartyReadSnapshot<PartyMemberDisplay>>? members,
    Stream<PublicRecruitmentPage>? publicFirstPage,
    Future<PublicRecruitmentPage> Function({
      required String cycleKey,
      required PublicRecruitmentPageCursor cursor,
      int limit,
    })?
    loadNextPage,
  }) : _activeRaids = activeRaids ?? Stream.value(emptyActiveRaids),
       _applications = applications ?? Stream.value(emptyApplications),
       _recruitment = recruitment,
       _myApplication = myApplication,
       _members = members ?? Stream.value(emptyMembers),
       _publicFirstPage =
           publicFirstPage ?? Stream.value(emptyPublicRecruitmentPage),
       _loadNextPage = loadNextPage;

  final Stream<PartyReadSnapshot<ActiveRaidSummary>> _activeRaids;
  final Stream<PartyReadSnapshot<PartyApplicationSummary>> _applications;
  final Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>>? _recruitment;
  final Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>>?
  _myApplication;
  final Stream<PartyReadSnapshot<PartyMemberDisplay>> _members;
  final Stream<PublicRecruitmentPage> _publicFirstPage;
  final Future<PublicRecruitmentPage> Function({
    required String cycleKey,
    required PublicRecruitmentPageCursor cursor,
    int limit,
  })?
  _loadNextPage;

  String? requestedActiveRaidsPlayerId;
  String? requestedApplicationsPlayerId;
  String? requestedApplicationsCycleKey;
  String? requestedRecruitmentId;
  String? requestedMembersRecruitmentId;
  String? requestedPublicFirstPageCycleKey;
  String? requestedNextPageCycleKey;
  PublicRecruitmentPageCursor? requestedNextPageCursor;
  var nextPageCallCount = 0;

  @override
  Stream<PublicRecruitmentPage> watchPublicRecruitmentFirstPage({
    required String cycleKey,
    int limit = publicRecruitmentPageSize,
  }) {
    requestedPublicFirstPageCycleKey = cycleKey;
    return _publicFirstPage;
  }

  @override
  Future<PublicRecruitmentPage> loadPublicRecruitmentNextPage({
    required String cycleKey,
    required PublicRecruitmentPageCursor cursor,
    int limit = publicRecruitmentPageSize,
  }) async {
    nextPageCallCount += 1;
    requestedNextPageCycleKey = cycleKey;
    requestedNextPageCursor = cursor;
    final loader = _loadNextPage;
    if (loader == null) {
      return emptyPublicRecruitmentPage;
    }
    return loader(cycleKey: cycleKey, cursor: cursor, limit: limit);
  }

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
  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  ) {
    requestedRecruitmentId = recruitmentId;
    return _recruitment ??
        Stream.value(
          const PartyReadDetailSnapshot(item: null, isFromCache: false),
        );
  }

  @override
  Stream<PartyReadSnapshot<PartyMemberDisplay>> watchRecruitmentMembers(
    String recruitmentId,
  ) {
    requestedMembersRecruitmentId = recruitmentId;
    return _members;
  }

  @override
  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  }) {
    return _myApplication ??
        Stream.value(
          const PartyReadDetailSnapshot(item: null, isFromCache: false),
        );
  }
}

class FakePublicRecruitmentPageCursor extends PublicRecruitmentPageCursor {
  const FakePublicRecruitmentPageCursor(this.id);

  final String id;
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
