# 실시간 구독 구조

기준은 [00](00-overview.md). 본문은 확인된 소스 흐름이며 마지막 전수 위치 목록에는 모든 `.snapshots()` 호출과 실제 query 표현을 기록한다. 운영 재연결·지연/팬아웃은 미측정이다.

## 구독 묶음과 소비자

| Repository 메서드 | 대상/필터·정렬 | 실제 화면 소비 | 수명/오류·갱신 |
|---|---|---|---|
| PartyRead.watchPublicRecruitmentFirstPage → `_watchFirstPageWithGroupListings/_watchMergedListingPages` | 내 groupMembershipState/current → 공개 모집 첫 페이지 + 그룹별 raidListings 전체. 공개 filter는02 참조 | PublicRecruitmentListViewModel/RecruitmentListPage | StreamController onListen, 그룹 변경시 기존 pagesSubscription 취소 후 재구독. onCancel에서 취소. metadata cache 플래그, 공개 에러 전달; 그룹 listing onError는 무시되는 경로 존재 |
| PartyRead.watchActiveRaids | recruitments leaderPlayerId=self 및 memberPlayerIds contains self, schemaVersion2/status open | RaidStatusPage/PartyReadStreamViewModel | 두 query 결과를 ID별 합침; 두 subscription 취소; onError 전달 |
| PartyRead.watchApplications | collectionGroup applications, schemaVersion1/applicantPlayerId/cycleKey, updatedAt desc | RaidStatusPage 내 신청 | Mapper와 현재 유효 신청 필터. FirebaseException을 read failure로 변환 |
| PartyRead.watchRecruitment | 단일 원본 doc, metadata | PartyReadDetailPage/PartyReadDetailViewModel | 없는 doc는 null. viewmodel reload 또는 종료시 해제 |
| PartyRead.watchRecruitmentMembers | recruitments/{r}/members 전체 | PartyReadDetailPage | members listen 취소, mapper 표시 정제. 캐시 상태 전파 |
| PartyRead.watchRecruitmentApplications | 방 applications 전체 | 승인권한 있는 상세 | 권한 변화에 따라 subscription 생성/취소; UI 오류 표시 |
| PartyRead.watchMyApplication | applications/{self} doc | 상세 본인 신청 상태 | 로그인 player에 종속; 취소 및 오류 처리 |
| PartyRead.watchRecruitmentCycle | cycles/{cycleKey} doc | 상세 완료/과거 회차 | 필요 상태/주차 변화시 재구독. 오류는 화면의 별도 상태 처리 |
| GroupRead.watchMyGroups | players/{p}/groupRelations relation=member, updatedAt desc | GroupTabPage의 StreamBuilder, 모집/생성의 그룹 선택 | 탭 StreamBuilder가 stream을 소비하고 생성 화면은 dispose에서 cancel; repository error transformer |
| GroupRead.watchMyRequests | 동일 경로 relation in invited/applied, updatedAt desc | GroupTabPage의 StreamBuilder | 탭 StreamBuilder 수명에 따라 구독 관리; timestamp/enum mapper 검증 |
| WeeklyRaidStatus.watchCurrentCycleStatuses | players/{p}/raidStates, weeklyRaidClaims, activeRaidAssignments 각각 cycleKey; 소유권 관련 문서 추가 구독 | MyAccountViewModel 및 후보 서비스 | 세 스트림 최신값 합성 → ownershipRecordStream → projector. onCancel 세 취소; 추가 doc subscription도 helper가 관리 |
| WeeklyRaidClaim.watchCurrentCycleClaims | weeklyRaidClaims cycleKey + players/events | MyAccountViewModel fallback | 이벤트 추가 type partyCompleted/partyCompletionCancelled면 Source.server 재조회; claims 오류 전달/events 오류 무시; onCancel 둘 취소 |
| ManualVerification.watchMyRequests | manualVerificationRequests requesterPlayerId | ManualVerificationPage | async*에서 current bound Player를 먼저 결정, 요청 상태 stream. UI StreamBuilder 수명 |
| ManualVerification.watchIncomingDisputes | manualVerificationRequests previousOwnerPlayerId, owner response 상태 로컬 filter | 내 계정/수동 인증 분쟁 안내 | 동일 auth 의존, StreamBuilder가 소비. 명시적인 계정 전환 listener는 확인되지 않음 |

근거: [PartyRead](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart), [GroupRead](../../lib/features/group/data/repositories/firestore_group_read_repository.dart), [WeeklyStatus](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart), [ownership stream](../../lib/features/account/data/repositories/ownership_record_stream.dart), [ManualVerification](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart).

## 화면 수명과 실시간이 아닌 조회

`PartyReadDetailPage`는 init/reload, 권한 변경 때 myApplication/member/application/cycle 구독을 관리하고 dispose에서 모두 취소한다. `PublicRecruitmentListViewModel`은 첫 페이지 구독·내 그룹 구독을 관리하고 refresh/dispose에서 취소한다. `MyAccountViewModel`은 주차 갱신 때 이전 claim/status subscription을 취소한다. `StatefulShellRoute.indexedStack`의 탭은 숨겨져도 widget이 유지될 수 있으므로 “탭 이동=모든 구독 종료”로 기록하지 않는다. Router의 refreshListenable=cycleRuntime이 있지만 다른 브랜치의 CycleBoundPage 개선은 이 기준에 없다.

그룹 상세/member/request/block 조회, 그룹/캐릭터 검색, 운영 사용자 목록·수동 승인 대기 목록은 `get()` 기반이다. FCM push나 모든 방의 서버 이벤트 stream으로 연결된 구조가 아니다. `FirestorePartyEventSyncService.sync`는 partyEvents audience filter + occurredAt order의 단발 get을 Drift에 적용한다. `FirestorePartyEventReadRepository.loadRecentEvents`도 제한된 get이며 Router의 주 경로에 default로 주입되는지 구분해야 한다. 알림 receipt는 local Drift stream으로 갱신한다.

SDK snapshots의 네트워크 복구를 앱 자체 cursor/replay 계약으로 대체하는 코드는 확인되지 않았다. `isFromCache`, metadata changes, Source.server 사용을 REST/WS로 바꿀 때 동일 UI 결과를 재현할지 별도 결정한다. 이벤트 sync의 전체 결과 get은 watermark pagination이 아니며 기록 증가 시 비용/트래픽 위험을 [07](07-migration-risks.md)에 기록했다.

## 향후 REST + WebSocket 기능 요구 — 제안, 메시지 계약 미확정

초기 REST snapshot과 구독 재연결 후 재조회/이벤트 replay의 관계, snapshot revision과 event 순서, 중복 event 적용 방지, reconnect cursor/보관 기간을 설계해야 한다. 방/그룹/사용자 scope 구독 허용은 서버가 결정하고 kick/탈퇴/권한 상실·token 폐기시 구독을 회수해야 한다. WS subscribe 요청의 Player ID를 신뢰하지 않는다.

비로그인에게는 공개 scope만 가능하고 guest-specific server receipt/구독 설정을 저장하지 않는다. 내 서버 알림 읽음 동기화는 현재 기기전용 읽음 정책을 바꾸므로 미결정이다. Polling fallback·backoff·모바일 background 복구·Swift 공유 메시지 versioning·한도는 후속 계약에서 정한다. endpoint/topic/schema는 이 문서에서 정하지 않는다.

## snapshots 호출 전수 위치와 원문 context
모든 lib Dart의 snapshots 호출을 수집했다. query 변수(`claimsQuery` 등)는 같은 파일의 위 선언과 본문 표를 대조한다. 최대12행 앞 context이며 자동 발췌는 완전한 query 선언을 보장하지 않는다.

### [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:117](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart)
```dart
          const GetOptions(source: Source.server),
        );
        emitSnapshot(snapshot);
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(_readException(error), stackTrace);
        }
      }
    }

    controller = StreamController<List<WeeklyRaidClaim>>(
      onListen: () {
        claimsSub = claimsQuery.snapshots().listen(
          emitSnapshot,
          onError: (Object error, StackTrace stackTrace) {
```

### [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:125](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart)
```dart
    }

    controller = StreamController<List<WeeklyRaidClaim>>(
      onListen: () {
        claimsSub = claimsQuery.snapshots().listen(
          emitSnapshot,
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(_readException(error), stackTrace);
            }
          },
        );
        eventsSub = eventsQuery.snapshots().listen(
          (snapshot) {
            final shouldRefresh = snapshot.docChanges.any((change) {
```

### [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:69](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart)
```dart
      }
      controller.add([...states!, ...claims!, ...assignments!]);
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) {
        controller.addError(_readException(error), stackTrace);
      }
    }

    controller = StreamController<List<WeeklyRaidStatusRecord>>(
      onListen: () {
        stateSub = stateQuery.snapshots().listen(
          (snapshot) {
            try {
```

### [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:92](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart)
```dart
                  .toList(growable: false);
              emitIfReady();
            } catch (error, stackTrace) {
              states = null;
              addError(error, stackTrace);
            }
          },
          onError: (Object error, StackTrace stack) {
            states = null;
            addError(error, stack);
          },
        );
        claimSub = claimQuery.snapshots().listen(
          (snapshot) {
            try {
```

### [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:116](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart)
```dart
                  .toList(growable: false);
              emitIfReady();
            } catch (error, stackTrace) {
              claims = null;
              addError(error, stackTrace);
            }
          },
          onError: (Object error, StackTrace stack) {
            claims = null;
            addError(error, stack);
          },
        );
        assignmentSub = assignmentQuery.snapshots().listen(
          (snapshot) {
            try {
```

### [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:151](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart)
```dart
        );
      },
      onCancel: () async {
        await stateSub?.cancel();
        await claimSub?.cancel();
        await assignmentSub?.cancel();
      },
    );
    return watchCurrentOwnershipRecords(
          controller.stream,
          (path) => _firestore
              .doc(path)
              .snapshots()
              .map((snapshot) => snapshot.data()),
        )
```

### [lib/features/group/data/repositories/firestore_group_read_repository.dart:46](../../lib/features/group/data/repositories/firestore_group_read_repository.dart)
```dart
  final FirebaseFirestore _firestore;
  final GroupNameNormalizer _normalizer;
  final GroupDocumentMapper _mapper;

  @override
  Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) {
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('groupRelations')
        .where('relation', isEqualTo: GroupRelationKind.member.name)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => GroupReadSnapshot(
```

### [lib/features/group/data/repositories/firestore_group_read_repository.dart:73](../../lib/features/group/data/repositories/firestore_group_read_repository.dart)
```dart
    return _firestore
        .collection('players')
        .doc(playerId)
        .collection('groupRelations')
        .where(
          'relation',
          whereIn: [
            GroupRelationKind.invited.name,
            GroupRelationKind.applied.name,
          ],
        )
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => GroupReadSnapshot(
```

### [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:202](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart)
```dart
    await snapshot.reference.update({
      'status': 'cancelled',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<ManualVerificationRequest>> watchMyRequests() async* {
    final playerId = await _requirePlayerId();
    yield* _requests
        .where('requesterPlayerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
```

### [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:217](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart)
```dart
              .map((doc) => _mapRequest(doc.id, doc.data(), _clock()))
              .toList();
          requests.sort((left, right) => right.createdAt.compareTo(left.createdAt));
          return requests;
        });
  }

  @override
  Stream<List<ManualVerificationRequest>> watchIncomingDisputes() async* {
    final playerId = await _requirePlayerId();
    yield* _requests
        .where('previousOwnerPlayerId', isEqualTo: playerId)
        .snapshots()
        .map((snapshot) {
          final now = _clock();
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:72](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart

    controller = StreamController<PublicRecruitmentPage>(
      onListen: () {
        if (currentPlayerId.trim().isEmpty) {
          listenPages(const []);
          return;
        }
        stateSubscription = _firestore
            .collection('players')
            .doc(currentPlayerId)
            .collection('groupMembershipState')
            .doc('current')
            .snapshots(includeMetadataChanges: true)
            .listen(
              (snapshot) => listenPages(_activeGroupIds(snapshot)),
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:94](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
    );
    return controller.stream;
  }

  Stream<PublicRecruitmentPage> _watchMergedListingPages({
    required String cycleKey,
    required String currentPlayerId,
    required List<String> groupIds,
    required int limit,
  }) {
    final public = _publicRecruitmentsQuery(cycleKey)
        .limit(limit)
        .snapshots(includeMetadataChanges: true);
    if (groupIds.isEmpty) {
      return public.map(
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:149](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
          public.listen((snapshot) {
            latestPublic = snapshot;
            emit();
          }, onError: controller.addError),
        );
        for (var index = 0; index < groupIds.length; index += 1) {
          final groupIndex = index;
          subscriptions.add(
            _firestore
                .collection('groups')
                .doc(groupIds[groupIndex])
                .collection('raidListings')
                .snapshots(includeMetadataChanges: true)
                .listen(
                  (snapshot) {
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:323](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
  @override
  Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({
    required String playerId,
  }) {
    // 1회성 완료 후 해산 전(`completed`)도 멤버가 상세·해산에 다시 들어갈 수 있게 남긴다.
    // 공개 모집 목록은 active만 유지한다.
    const openStatuses = ['active', 'completed'];
    final owned = _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 2)
        .where('leaderPlayerId', isEqualTo: playerId)
        .where('status', whereIn: openStatuses)
        .snapshots(includeMetadataChanges: true);
    final joined = _firestore
        .collection('recruitments')
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:329](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
    const openStatuses = ['active', 'completed'];
    final owned = _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 2)
        .where('leaderPlayerId', isEqualTo: playerId)
        .where('status', whereIn: openStatuses)
        .snapshots(includeMetadataChanges: true);
    final joined = _firestore
        .collection('recruitments')
        .where('schemaVersion', isEqualTo: 2)
        .where('memberPlayerIds', arrayContains: playerId)
        .where('status', whereIn: openStatuses)
        .snapshots(includeMetadataChanges: true);

    return _combineActiveQueries(
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:349](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart

  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({
    required String playerId,
    required String cycleKey,
  }) {
    return _firestore
        .collectionGroup('applications')
        .where('schemaVersion', isEqualTo: 1)
        .where('applicantPlayerId', isEqualTo: playerId)
        .where('cycleKey', isEqualTo: cycleKey)
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadSnapshot(
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:374](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
          ),
        )
        .transform(_errorTransformer());
  }

  @override
  Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(
    String recruitmentId,
  ) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadDetailSnapshot(
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:394](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
        )
        .transform(_errorTransformer());
  }

  @override
  Stream<PartyReadSnapshot<PartyMemberDisplay>> watchRecruitmentMembers(
    String recruitmentId,
  ) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .collection('members')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final items =
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:418](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
        })
        .transform(_errorTransformer());
  }

  @override
  Stream<PartyReadSnapshot<PartyApplicationSummary>> watchRecruitmentApplications(
    String recruitmentId,
  ) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .collection('applications')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final items = snapshot.docs
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:443](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
  }

  @override
  Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({
    required String recruitmentId,
    required String playerId,
  }) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .collection('applications')
        .doc(playerId)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => PartyReadDetailSnapshot(
```

### [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:465](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart)
```dart
  }

  @override
  Stream<PartyReadDetailSnapshot<PartyCycleSnapshot?>> watchRecruitmentCycle({
    required String recruitmentId,
    required String cycleKey,
  }) {
    return _firestore
        .collection('recruitments')
        .doc(recruitmentId)
        .collection('cycles')
        .doc(cycleKey)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          if (!snapshot.exists) {
```
