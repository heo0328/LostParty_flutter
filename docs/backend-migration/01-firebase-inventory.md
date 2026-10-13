# Firebase 의존성 전수 목록

기준/조사 한계는 [00](00-overview.md). `lib/**/*.dart`390개를 전수 검색해 Firebase 관련 파일62개를 확인했다. SDK 선언·실제 호출·데이터 타입만 쓰는 helper·Router 비연결/legacy 구현을 구분한다. 하단에 파일별 클래스/메서드·실제 SDK 연결 표현의 행번호를 기록한다. import만 있는 파일을 호출 파일로 오인하지 않는다.

## SDK와 설정

| 대상 | 현재 소스 확인 | 실제 사용 범위/제거 영향 |
|---|---|---|
| firebase_core | pubspec ^4.13.0, `firebase_app_initializer.initializeFirebaseApp` | 앱 시작 initializeApp, platform options·FirebaseException/Firebase.apps 상태. 미래 FCM 유지 여부에 따라 Core 제거 범위 재평가 |
| firebase_auth | pubspec6.6.0, AnonymousAuthInitializer | 익명 sign-in/currentUser UID, Repository binding 검증. OAuth 제공자 연결로 재구현할 코드가 아니라 기존 익명 경로 제거 영향 |
| cloud_firestore | pubspec6.9.0 | query/doc/collectionGroup/Transaction/Batch/snapshots/Timestamp/FieldValue/GetOptions/SetOptions 및 Exception |
| cloud_functions | pubspec/lib SDK 호출 없음 | firebase.json에도 Functions 배포 설정 없음. 운영 외부 프로젝트 배포 여부는 미확인 |
| firebase_storage | pubspec/lib SDK 호출 없음 | 인증 증거 업로드가 Storage API로 연결된 증거 없음. 이미지 URL 표시와 업로드 저장소 구분; S3 조건부 |
| firebase_messaging | pubspec/lib SDK 호출 없음 | FCM token/subscribe/send 미구현. 현재 알림은 Firestore event + local receipt이며 FCM은 조건부 미래 범위 |
| 기타 Firebase SDK | analytics/crashlytics/remote_config/app_check/database SDK 사용을 현재 pubspec/lib에서 발견하지 못함 | 플랫폼/외부 운영 서비스 활성 여부 별도 실사 |

이 버전은 pubspec 선언 기준이다. lock/platform artifact의 해석 버전과 런타임 환경은 별도 확인할 수 있으며 “최신 버전”으로 평가하지 않는다. `pubspec.lock`, `lib/firebase_options.dart`, `firebase.json`, `.firebaserc`, Android google-services 설정/build, iOS/macOS/windows generated plugin registration이 제거 영향 자료다. API key/token 값은 문서로 복사하지 않는다.

## 실제 DI와 호출 목적

| 호출군 | 클래스·메서드 | 경로/화면과 처리 |
|---|---|---|
| bootstrap/player | AnonymousAuthInitializer.initialize; FirestorePlayerBindingStore.getOrCreateActivePlayerId; FirestorePlayerActivityRepository.recordAppLaunch | 앱 진입, authBindings/players 원자 생성 및 lastSeen 갱신 |
| operator | FirestoreOperatorAccessRepository.isCurrentPlayerOperator/loadWriteReadiness/loadUsers/loadUserDetail | 설정의 운영자 화면, binding/assignment/player/account/character 조회. loadUsers는 legacy Player patch도 수행 |
| game ownership | LocalGameAccountVerificationGateway.start/confirm/_claimOwnership; FirestoreAccountOwnershipStatusGateway.loadStatuses | 계정/장비 인증. Lost Ark 직접 조회와 gameAccounts/characters/identity claims/playerGameAccounts 동시 갱신 |
| character projection | CharacterSummary/CombatPower/MinimumDisplaySync gateways; RepresentativeCharacterSync.loadState/setRepresentative/seedRepresentative | 내 계정·관리·대표 변경·startup refresh. 본인 active 소유를 읽고 server Character 표시/대표 동기화 |
| activity | FirestoreActivityCharactersRepository.load/save/loadProjections | 활동 Character 표시·후보. players/characterActivity + account/Character 소유 관계; chunk 쓰기 |
| weekly | FirestoreWeeklyRaidClaimRepository.watchCurrentCycleClaims 및 inspect/create/delete/cleanup; WeeklyRaidStatusRepository.watchCurrentCycleStatuses; WeeklyRaidStatusCommandRepository | 내 계정 체크박스, 후보/정리. state+legacy claim/assignment reader와 command writer 분리 |
| party read | FirestorePartyReadRepository.watch* / loadPublicRecruitmentNextPage | 목록·레이드 현황·실제 상세, private group listing merge, collection-group applications |
| party create/application | FirestorePartyAtomicCreateRepository.create; AtomicApplicationCommandRepository.apply/withdraw | 생성/신청/철회, Character ownership·방/멤버/aggregate·raidState·guard/event·listing |
| party join/manage | AtomicJoinCommandRepository.joinDirectly/approve/reject; AtomicMemberMutation.changeCharacter/repositionMembers; AtomicMemberRemoval.remove; AtomicVisibility.setVisibility | 실제 PartyReadDetailPage: 슬롯 배치·신청 결정·멤버 변경/삭제·그룹 범위 변경 |
| lifecycle | AtomicCommandRepository.execute/findAggregate/_certifyAdvance + PartyAtomicCycleCommandAdapter | 완료/전환/해산/반복 설정; 대상 최대8인의 핵심 상태·group count·원자 event |
| cleanup/reconcile | CompletedOwnershipCleanup.inspect/execute/retry/pending; LazyCycleReconciliation.reconcile; ApplicationCleanup.deleteOrphan; ActiveRaidAssignmentLookup.blocksCandidate | 완료 관계 정리·자동 늦은 주차 조회 보정·고아 신청·후보 점유 판정. secure journal 부수효과 |
| group read/search | FirestoreGroupReadRepository.watchMyGroups/watchMyRequests/load*/searchGroups; GroupCharacterSearchRepository.searchActiveCharactersByExactName/loadActiveCharactersForPlayer | 그룹 탭/검색/상세/초대 후보, group relation/projection과 Character 조회 |
| group commands | GroupCreate.create; GroupJoin.invite/apply/accept/reject/cancel/leave/transferLeadership/disband/refreshMyDisplaySnapshot; GroupApplication.approve/reject/block/releaseBlock; GroupJoinCode.create/revoke/setVisibility/joinByCode | group/member/state/relation/joinRelation/stats/block/code의 원자 쓰기, role/count/revision 검증 |
| manual verification | FirestoreManualVerificationRepository.create/reissue/cancel/watch*/loadReviewContext/review* /syncExpiredDisputes | 본인·이전 소유자·운영자 workflow, 소유권 이전/분쟁/방어·Player events |
| event/history | FirestorePartyEventSyncService.sync; FirestorePartyEventReadRepository.loadRecentEvents | shared partyEvents→local Drift history/notification, 후자는 존재하지만 Router default injection과 구분 |
| listing | FirestorePartyRaidListingBackfill.backfillOwnGroupListings; PartyRaidListingSync.write | dev의 그룹 모집 복사본 유지/복구. L1 제거가 미통합이므로 이번 범위에 포함 |

## 연결 상태와 잔존 코드

`app_router.createAppRouter`는 Firebase repositories를 실제 생성 화면과 `/raid-status/:recruitmentId`의 PartyReadDetailPage에 주입한다. AtomicCreate 클래스의 “운영 Router에는 아직 연결하지 않는다” 주석은 실제 Router641행 부근과 불일치한다. 연결 상태는 Router를 기준으로 판정한다.

동시에 `/recruitments/:recruitmentId`의 RecruitmentDetailPage는 InMemoryRecruitmentStateRepository/RecruitmentCommandService로 연결돼 있다. 후보에는 `FakeUserSession(playerSession.playerId)`·`FakeRecruitmentClock(DateTime.now())`, 로컬 seed·weekly clear·assignment와 server lookup이 혼합된다. 모든 Fake 클래스를 단순 test-only로 분류하면 실제 DI를 놓친다.

기존 FirestorePartyCreate/Join/Membership/Cycle/Application/VisibilityCommandRepository는 비원자/legacy 구현으로 파일이 존재한다. AtomicCycle adapter는 recurrence/purge를 자체 Firestore 경로로 처리하고, AtomicMembership adapter의 setApprovalPermission은 invalidRequest를 반환한다. 이름이 비슷한 legacy Repository로 실제 위임된다고 추정하지 않는다. 전체 비연결 코드를 기능 제거 대상으로 확정하기 전 참조와 독립 테스트 사용을 확인한다. 아래 클래스/메서드 목록과 실제 adapter 참조를 대조한다. `Timestamp`만 쓰는 mapper/Domain 타입도 향후 SDK 제거 시 영향 대상이다.

## 조사 방법과 범위

lib의 Firebase imports/symbols, 모든 collection/doc/query/snapshots/runTransaction/batch/SDK value 표현을 정적으로 수집했다. 생성 Dart·platform SDK registration도 확인했다. test/tools는 contract/fixture 근거로만 참조하며 실험 파일을 운영 호출로 세지 않는다. 행번호는 e24baab checkout 기준이며 향후 변경되면 재검색해야 한다. source trace는 DB 접근 기록이나 실행 coverage가 아니다.

## 파일별 클래스·메서드와 SDK 사용 지점 전수 색인
아래는 import/symbol이 발견된62파일 전체다. 호출 행 표는 SDK 경로/값/읽기·쓰기·query 표현의 정적 출현 위치이며 local `.get` 또는 helper 정의도 포함될 수 있다. method 선언 표와 위 실제 DI 표를 함께 대조한다. source 식을 그대로 기재하며 자동 추출 context를 실행 완료 사실로 해석하지 않는다.

### lib/app/bootstrap/anonymous_auth_initializer.dart
근거: [lib/app/bootstrap/anonymous_auth_initializer.dart](../../lib/app/bootstrap/anonymous_auth_initializer.dart). 클래스: `FirebaseAnonymousAuthGateway`, `AnonymousAuthInitializer`.
메서드/선언(여러 줄 signature는 시작 행): L4 `String? get currentAuthUid;`; L6 `Future<void> signInAnonymously();`; L15 `String? get currentAuthUid => _firebaseAuth.currentUser?.uid;`; L18 `Future<void> signInAnonymously() async {`; L28 `Future<String> initialize() async {`.

| 행 | source 표현 |
|---|---|
| 12 | `final FirebaseAuth _firebaseAuth;` |
| 15 | `String? get currentAuthUid => _firebaseAuth.currentUser?.uid;` |
| 19 | `await _firebaseAuth.signInAnonymously();` |
| 32 | `await _gateway.signInAnonymously();` |

### lib/app/bootstrap/app_services_initializer.dart
근거: [lib/app/bootstrap/app_services_initializer.dart](../../lib/app/bootstrap/app_services_initializer.dart). 클래스: top-level/helper.

| 행 | source 표현 |
|---|---|
| 14 | `FirebaseAnonymousAuthGateway(FirebaseAuth.instance),` |
| 17 | `FirestorePlayerBindingStore(FirebaseFirestore.instance),` |
| 20 | `FirebaseFirestore.instance,` |

### lib/app/bootstrap/firebase_app_initializer.dart
근거: [lib/app/bootstrap/firebase_app_initializer.dart](../../lib/app/bootstrap/firebase_app_initializer.dart). 클래스: top-level/helper.

| 행 | source 표현 |
|---|---|
| 6 | `return Firebase.initializeApp(` |

### lib/app/router/app_router.dart
근거: [lib/app/router/app_router.dart](../../lib/app/router/app_router.dart). 클래스: top-level/helper.

| 행 | source 표현 |
|---|---|
| 165 | `firestore: FirebaseFirestore.instance,` |
| 172 | `firestore: FirebaseFirestore.instance,` |
| 183 | `firestore: FirebaseFirestore.instance,` |
| 184 | `firebaseAuth: FirebaseAuth.instance,` |
| 196 | `FirestorePartyReadRepository(firestore: FirebaseFirestore.instance);` |
| 199 | `firestore: FirebaseFirestore.instance,` |
| 205 | `firestore: FirebaseFirestore.instance,` |
| 206 | `firebaseAuth: FirebaseAuth.instance,` |
| 211 | `firestore: FirebaseFirestore.instance,` |
| 212 | `firebaseAuth: FirebaseAuth.instance,` |
| 221 | `firestore: FirebaseFirestore.instance,` |
| 222 | `firebaseAuth: FirebaseAuth.instance,` |
| 233 | `firestore: FirebaseFirestore.instance,` |
| 243 | `firestore: FirebaseFirestore.instance,` |
| 244 | `firebaseAuth: FirebaseAuth.instance,` |
| 247 | `firestore: FirebaseFirestore.instance,` |
| 248 | `firebaseAuth: FirebaseAuth.instance,` |
| 253 | `firestore: FirebaseFirestore.instance,` |
| 276 | `firestore: FirebaseFirestore.instance,` |
| 277 | `firebaseAuth: FirebaseAuth.instance,` |
| 291 | `firestore: FirebaseFirestore.instance,` |
| 292 | `firebaseAuth: FirebaseAuth.instance,` |
| 300 | `firestore: FirebaseFirestore.instance,` |
| 301 | `firebaseAuth: FirebaseAuth.instance,` |
| 311 | `firestore: FirebaseFirestore.instance,` |
| 312 | `firebaseAuth: FirebaseAuth.instance,` |
| 317 | `firestore: FirebaseFirestore.instance,` |
| 318 | `firebaseAuth: FirebaseAuth.instance,` |
| 324 | `firestore: FirebaseFirestore.instance,` |
| 325 | `firebaseAuth: FirebaseAuth.instance,` |
| 351 | `firestore: FirebaseFirestore.instance,` |
| 352 | `firebaseAuth: FirebaseAuth.instance,` |
| 359 | `firestore: FirebaseFirestore.instance,` |
| 360 | `firebaseAuth: FirebaseAuth.instance,` |
| 364 | `(Firebase.apps.isEmpty` |
| 385 | `firestore: FirebaseFirestore.instance,` |
| 453 | `firestore: FirebaseFirestore.instance,` |
| 454 | `auth: FirebaseAuth.instance,` |
| 475 | `firestore: FirebaseFirestore.instance,` |
| 476 | `firebaseAuth: FirebaseAuth.instance,` |
| 496 | `firestore: FirebaseFirestore.instance,` |
| 497 | `auth: FirebaseAuth.instance,` |
| 504 | `firestore: FirebaseFirestore.instance,` |
| 505 | `firebaseAuth: FirebaseAuth.instance,` |
| 509 | `firestore: FirebaseFirestore.instance,` |
| 510 | `firebaseAuth: FirebaseAuth.instance,` |
| 516 | `firestore: FirebaseFirestore.instance,` |
| 517 | `firebaseAuth: FirebaseAuth.instance,` |
| 521 | `firestore: FirebaseFirestore.instance,` |
| 522 | `firebaseAuth: FirebaseAuth.instance,` |
| 531 | `firestore: FirebaseFirestore.instance,` |
| 532 | `firebaseAuth: FirebaseAuth.instance,` |
| 642 | `firestore: FirebaseFirestore.instance,` |
| 643 | `firebaseAuth: FirebaseAuth.instance,` |
| 647 | `newRecruitmentId: () => FirebaseFirestore.instance` |
| 648 | `.collection('recruitments')` |
| 649 | `.doc()` |
| 727 | `firestore: FirebaseFirestore.instance,` |
| 728 | `firebaseAuth: FirebaseAuth.instance,` |

### lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart
근거: [lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart](../../lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart). 클래스: `FirestoreAccountOwnershipStatusGateway`.
메서드/선언(여러 줄 signature는 시작 행): L18 `Future<Map<String, String>> loadStatuses(`; L69 `String _statusFor({`.

| 행 | source 표현 |
|---|---|
| 9 | `required FirebaseFirestore firestore,` |
| 10 | `required FirebaseAuth firebaseAuth,` |
| 14 | `final FirebaseFirestore _firestore;` |
| 15 | `final FirebaseAuth _firebaseAuth;` |
| 23 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 26 | `.collection('authBindings')` |
| 27 | `.doc(authUid)` |
| 28 | `.get(const GetOptions(source: Source.server));` |
| 38 | `.collection('players')` |
| 39 | `.doc(playerId)` |
| 40 | `.get(const GetOptions(source: Source.server));` |
| 48 | `.collection('playerGameAccounts')` |
| 49 | `.doc('${playerId}_$id')` |
| 50 | `.get(const GetOptions(source: Source.server)),` |
| 52 | `.collection('gameAccounts')` |
| 53 | `.doc(id)` |
| 54 | `.get(const GetOptions(source: Source.server)),` |

### lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart). 클래스: `FirestoreCharacterCombatPowerSyncGateway`.
메서드/선언(여러 줄 signature는 시작 행): L18 `Future<void> updateCombatPowers(`.

| 행 | source 표현 |
|---|---|
| 9 | `required FirebaseFirestore firestore,` |
| 10 | `required FirebaseAuth firebaseAuth,` |
| 14 | `final FirebaseFirestore _firestore;` |
| 15 | `final FirebaseAuth _firebaseAuth;` |
| 22 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 33 | `await _firestore.runTransaction<void>((transaction) async {` |
| 34 | `final binding = await transaction.get(` |
| 35 | `_firestore.collection('authBindings').doc(uid),` |
| 43 | `final player = await transaction.get(` |
| 44 | `_firestore.collection('players').doc(playerId),` |
| 49 | `final ref = _firestore.collection('characters').doc(entry.key);` |
| 50 | `final character = await transaction.get(ref);` |
| 59 | `final ownership = await transaction.get(` |
| 61 | `.collection('playerGameAccounts')` |
| 62 | `.doc('${playerId}_$accountId'),` |
| 68 | `transaction.update(ref, {` |
| 70 | `'updatedAt': FieldValue.serverTimestamp(),` |

### lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart). 클래스: `FirestoreCharacterMinimumDisplaySyncGateway`.
메서드/선언(여러 줄 signature는 시작 행): L19 `Future<bool> syncMinimumDisplay(CharacterMinimumDisplayPatch patch) async {`; L98 `static Map<String, Object?>? _integrityUpdate({`; L134 `static bool _sameItemLevel(Object? existing, double next) {`; L144 `static String _formatItemAvgLevel(double value) {`.

| 행 | source 표현 |
|---|---|
| 10 | `required FirebaseFirestore firestore,` |
| 11 | `required FirebaseAuth firebaseAuth,` |
| 15 | `final FirebaseFirestore _firestore;` |
| 16 | `final FirebaseAuth _firebaseAuth;` |
| 34 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 39 | `return _firestore.runTransaction<bool>((transaction) async {` |
| 40 | `final binding = await transaction.get(` |
| 41 | `_firestore.collection('authBindings').doc(uid),` |
| 49 | `final player = await transaction.get(` |
| 50 | `_firestore.collection('players').doc(playerId),` |
| 55 | `final ref = _firestore.collection('characters').doc(serverCharacterId);` |
| 56 | `final character = await transaction.get(ref);` |
| 65 | `final ownership = await transaction.get(` |
| 67 | `.collection('playerGameAccounts')` |
| 68 | `.doc('${playerId}_$accountId'),` |
| 92 | `updates['updatedAt'] = FieldValue.serverTimestamp();` |
| 93 | `transaction.update(ref, updates);` |
| 118 | `fields['checkedAt'] = Timestamp.fromDate(next.checkedAt.toUtc());` |
| 127 | `Timestamp timestamp => timestamp.toDate().toUtc(),` |

### lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart). 클래스: `FirestoreCharacterSummarySyncGateway`.
메서드/선언(여러 줄 signature는 시작 행): L18 `Future<void> updateSummaries(List<CharacterSummaryServerPatch> patches) async {`.

| 행 | source 표현 |
|---|---|
| 9 | `required FirebaseFirestore firestore,` |
| 10 | `required FirebaseAuth firebaseAuth,` |
| 14 | `final FirebaseFirestore _firestore;` |
| 15 | `final FirebaseAuth _firebaseAuth;` |
| 21 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 26 | `final binding = await _firestore.collection('authBindings').doc(authUid).get();` |
| 32 | `await _firestore.runTransaction((transaction) async {` |
| 36 | `await transaction.get(` |
| 37 | `_firestore.collection('characters').doc(patch.serverCharacterId),` |
| 42 | `final now = FieldValue.serverTimestamp();` |
| 58 | `if (existingFetchedAt is Timestamp &&` |
| 63 | `transaction.update(snapshot.reference, {` |
| 67 | `'lastSummaryFetchedAt': Timestamp.fromDate(patch.fetchedAt.toUtc()),` |

### lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart). 클래스: `FirestoreRepresentativeCharacterSyncGateway`.
메서드/선언(여러 줄 signature는 시작 행): L18 `FirebaseFirestore get _firestore =>`; L22 `Future<RepresentativeCharacterSyncState> loadState({`; L34 `Future<RepresentativeCharacterSyncState> setRepresentative({`; L77 `Future<RepresentativeCharacterSyncState> seedRepresentative({`; L111 `Future<void> _requireOwnedCharacter(`; L136 `void _requireActiveOwnership(`; L160 `String? _string(Object? value) =>`.

| 행 | source 표현 |
|---|---|
| 8 | `FirebaseFirestore? firestore,` |
| 14 | `final FirebaseFirestore? _providedFirestore;` |
| 18 | `FirebaseFirestore get _firestore =>` |
| 19 | `_providedFirestore ?? FirebaseFirestore.instance;` |
| 27 | `).get(const GetOptions(source: Source.server));` |
| 40 | `return _firestore.runTransaction((transaction) async {` |
| 41 | `final ownership = await transaction.get(ownershipReference);` |
| 65 | `transaction.update(ownershipReference, {` |
| 67 | `'representativeCharacterUpdatedAt': FieldValue.serverTimestamp(),` |
| 82 | `return _firestore.runTransaction((transaction) async {` |
| 83 | `final ownership = await transaction.get(ownershipReference);` |
| 101 | `transaction.update(ownershipReference, {` |
| 116 | `final character = await transaction.get(` |
| 117 | `_firestore.collection('characters').doc(characterId),` |
| 133 | `.collection('playerGameAccounts')` |
| 134 | `.doc('${playerId}_$gameAccountId');` |
| 158 | `value is Timestamp ? value.toDate().toUtc() : null;` |

### lib/features/account/data/gateways/local_game_account_verification_gateway.dart
근거: [lib/features/account/data/gateways/local_game_account_verification_gateway.dart](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart). 클래스: `LocalGameAccountVerificationGateway`, `_LocalChallenge`, `_EquipmentIdentity`.
메서드/선언(여러 줄 signature는 시작 행): L46 `GameAccountVerificationChallenge? get activeChallenge {`; L57 `Future<GameAccountVerificationChallenge> start({`; L97 `Future<GameAccountVerificationResult> confirm(String challengeId) async {`; L135 `Map<String, _EquipmentIdentity> _equipment(`; L164 `Future<GameAccountVerificationResult> _claimOwnership(`; L342 `String _identityKey(String serverName, String characterName) =>`; L363 `GameAccountVerificationChallenge get publicValue =>`; L379 `bool operator ==(Object other) =>`.

| 행 | source 표현 |
|---|---|
| 19 | `required FirebaseFirestore firestore,` |
| 20 | `required FirebaseAuth firebaseAuth,` |
| 39 | `final FirebaseFirestore _firestore;` |
| 40 | `final FirebaseAuth _firebaseAuth;` |
| 111 | `.where(current.containsKey)` |
| 119 | `for (final slot in _slots.keys.where(` |
| 145 | `final matching = _slots.entries.where((entry) => entry.value == type);` |
| 167 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 172 | `.collection('characterIdentityClaims')` |
| 173 | `.doc(_identityKey(item.serverName, item.characterName)),` |
| 177 | `return _firestore.runTransaction((transaction) async {` |
| 178 | `final binding = await transaction.get(` |
| 179 | `_firestore.collection('authBindings').doc(authUid),` |
| 190 | `claims.add(await transaction.get(ref));` |
| 193 | `.where((snapshot) => snapshot.exists)` |
| 201 | `? _firestore.collection('gameAccounts').doc()` |
| 202 | `: _firestore.collection('gameAccounts').doc(accountIds.single);` |
| 205 | `: await transaction.get(accountRef);` |
| 224 | `? _firestore.collection('characters').doc(characterId)` |
| 225 | `: _firestore.collection('characters').doc(),` |
| 235 | `await transaction.get(_firestore.collection('characters').doc(id)),` |
| 245 | `final now = FieldValue.serverTimestamp();` |
| 249 | `transaction.update(snapshot.reference, {` |
| 257 | `transaction.set(accountRef, {` |
| 272 | `.where((item) => item.id == characterRef.id)` |
| 274 | `transaction.set(characterRef, {` |
| 290 | `transaction.set(claimRefs[index], {` |
| 306 | `transaction.set(` |
| 308 | `.collection('playerGameAccounts')` |
| 309 | `.doc('${playerId}_${accountRef.id}'),` |
| 317 | `SetOptions(merge: true),` |
| 320 | `transaction.set(` |
| 322 | `.collection('playerGameAccounts')` |
| 323 | `.doc('${previousOwner}_${accountRef.id}'),` |
| 331 | `SetOptions(merge: true),` |

### lib/features/account/data/mappers/activity_characters_firebase_mapper.dart
근거: [lib/features/account/data/mappers/activity_characters_firebase_mapper.dart](../../lib/features/account/data/mappers/activity_characters_firebase_mapper.dart). 클래스: top-level/helper.

| 행 | source 표현 |
|---|---|
| 5 | `ActivityCharactersSaveException mapActivityCharactersFirebaseException(` |
| 6 | `FirebaseException error,` |
| 11 | `'ActivityCharacters FirebaseException: ${error.code} ${error.message}',` |

### lib/features/account/data/repositories/firestore_activity_characters_repository.dart
근거: [lib/features/account/data/repositories/firestore_activity_characters_repository.dart](../../lib/features/account/data/repositories/firestore_activity_characters_repository.dart). 클래스: `FirestoreActivityCharactersRepository`, `_ActivitySavePreparation`.
메서드/선언(여러 줄 signature는 시작 행): L31 `Future<ActivityCharacters> load({required String playerId}) async {`; L61 `Future<ActivityCharacters> save(SaveActivityCharactersCommand command) async {`; L155 `bool _activityDocumentMatches(`; L180 `Future<List<ActivityCharacterProjection>> loadProjections({`; L231 `Future<String> _requirePlayerId(Transaction transaction) async {`; L263 `Future<List<OwnedActivityCharacter>> _loadOwnedCharacters(`.

| 행 | source 표현 |
|---|---|
| 18 | `required FirebaseFirestore firestore,` |
| 19 | `required FirebaseAuth firebaseAuth,` |
| 23 | `final FirebaseFirestore _firestore;` |
| 24 | `final FirebaseAuth _firebaseAuth;` |
| 55 | `} on FirebaseException catch (error) {` |
| 56 | `throw mapActivityCharactersFirebaseException(error);` |
| 63 | `final preparation = await _firestore.runTransaction((transaction) async {` |
| 74 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 93 | `.where(` |
| 114 | `await _firestore.runTransaction((transaction) async {` |
| 116 | `transaction.set(` |
| 125 | `.where(existingByCharacterId.containsKey)` |
| 128 | `await _firestore.runTransaction((transaction) async {` |
| 131 | `final snapshot = await transaction.get(` |
| 139 | `transaction.delete(_activityRef(plan.playerId, characterId));` |
| 150 | `} on FirebaseException catch (error) {` |
| 151 | `throw mapActivityCharactersFirebaseException(error);` |
| 164 | `existing['updatedAt'] is Timestamp;` |
| 226 | `} on FirebaseException catch (error) {` |
| 227 | `throw mapActivityCharactersFirebaseException(error);` |
| 232 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 239 | `final binding = await transaction.get(` |
| 240 | `_firestore.collection('authBindings').doc(uid),` |
| 251 | `final player = await transaction.get(` |
| 252 | `_firestore.collection('players').doc(playerId),` |
| 277 | `final snapshot = await transaction.get(` |
| 278 | `_firestore.collection('characters').doc(characterId),` |
| 289 | `ownershipCache[gameAccountId] = (await transaction.get(` |
| 291 | `.collection('playerGameAccounts')` |
| 292 | `.doc('${playerId}_$gameAccountId'),` |
| 323 | `.collection('players')` |
| 324 | `.doc(playerId)` |
| 325 | `.collection('characterActivity');` |
| 332 | `.collection('players')` |
| 333 | `.doc(playerId)` |
| 334 | `.collection('activityCharacterProjections');` |
| 341 | `return _activityCollection(playerId).doc(characterId);` |

### lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart). 클래스: `FirestoreWeeklyRaidClaimRepository`, `_ManualClaimConflictContext`, `_PendingClaimApplication`.
메서드/선언(여러 줄 signature는 시작 행): L40 `Future<WeeklyRaidClaimCommandResult> cleanupOrphanParticipation(`; L48 `Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(`; L69 `Stream<List<WeeklyRaidClaim>> watchCurrentCycleClaims({`; L146 `List<WeeklyRaidClaim> _mapCurrentCycleClaims(`; L189 `Future<WeeklyRaidClaimCommandResult> createManualClaim(`; L399 `Future<_ManualClaimConflictContext> _loadConflictContext(`; L480 `Future<WeeklyRaidClaimCommandResult> deleteManualClaim(`; L523 `String? _claimId({`; L551 `Future<T> Function() read,`.

| 행 | source 표현 |
|---|---|
| 23 | `required FirebaseFirestore firestore,` |
| 24 | `FirebaseAuth? firebaseAuth,` |
| 26 | `_firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,` |
| 29 | `Timestamp timestamp => timestamp.toDate(),` |
| 31 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |
| 35 | `final FirebaseFirestore _firestore;` |
| 36 | `final FirebaseAuth _firebaseAuth;` |
| 51 | `if (_firebaseAuth.currentUser == null) {` |
| 59 | `} on FirebaseException catch (error) {` |
| 81 | `.collection('players')` |
| 82 | `.doc(playerId)` |
| 83 | `.collection('weeklyRaidClaims')` |
| 84 | `.where('cycleKey', isEqualTo: cycleKey);` |
| 86 | `.collection('players')` |
| 87 | `.doc(playerId)` |
| 88 | `.collection('events');` |
| 105 | `const GetOptions(source: Source.server),` |
| 117 | `claimsSub = claimsQuery.snapshots().listen(` |
| 125 | `eventsSub = eventsQuery.snapshots().listen(` |
| 175 | `if (error is FirebaseException) {` |
| 194 | `if (_firebaseAuth.currentUser == null) {` |
| 224 | `.collection('players')` |
| 225 | `.doc(command.playerId)` |
| 226 | `.collection('activeRaidAssignments')` |
| 227 | `.doc('${command.characterId}_${command.raidId}');` |
| 228 | `return await _firestore.runTransaction((transaction) async {` |
| 229 | `final claim = await transaction.get(claimRef);` |
| 230 | `final assignment = await transaction.get(assignmentRef);` |
| 252 | `recruitmentRef = _firestore.collection('recruitments').doc(recruitmentId);` |
| 253 | `memberRef = recruitmentRef.collection('members').doc(command.playerId);` |
| 254 | `final recruitment = await transaction.get(recruitmentRef);` |
| 255 | `final member = await transaction.get(memberRef);` |
| 272 | `nextLeader = await transaction.get(` |
| 273 | `recruitmentRef.collection('members').doc(remaining.first),` |
| 280 | `final application = await transaction.get(candidate.applicationRef);` |
| 281 | `final recruitment = await transaction.get(candidate.recruitmentRef);` |
| 301 | `final now = FieldValue.serverTimestamp();` |
| 332 | `transaction.update(recruitmentRef!, recruitmentPatch);` |
| 338 | `transaction.delete(memberRef!);` |
| 339 | `transaction.delete(assignmentRef);` |
| 341 | `transaction.update(` |
| 342 | `recruitmentRef.collection('members').doc(nextLeaderId),` |
| 367 | `transaction.update(pending.applicationRef, {` |
| 370 | `'revision': FieldValue.increment(1),` |
| 375 | `transaction.set(claimRef, {` |
| 383 | `'cycleStartedAt': Timestamp.fromDate(command.cycleStartedAt.toUtc()),` |
| 384 | `'cycleEndsAt': Timestamp.fromDate(command.cycleEndsAt.toUtc()),` |
| 390 | `} on FirebaseException catch (error) {` |
| 403 | `.collection('players')` |
| 404 | `.doc(command.playerId)` |
| 405 | `.collection('activeRaidAssignments')` |
| 406 | `.doc('${command.characterId}_${command.raidId}');` |
| 417 | `.collection('recruitments')` |
| 418 | `.doc(activeRecruitmentId)` |
| 430 | `.collection('members')` |
| 431 | `.doc(nextId)` |
| 439 | `.collectionGroup('applications')` |
| 440 | `.where('schemaVersion', isEqualTo: 1)` |
| 441 | `.where('applicantPlayerId', isEqualTo: command.playerId)` |
| 442 | `.where('cycleKey', isEqualTo: command.cycleKey)` |
| 443 | `.orderBy('updatedAt', descending: true)` |
| 483 | `if (_firebaseAuth.currentUser == null) {` |
| 500 | `await _firestore.runTransaction((transaction) async {` |
| 501 | `final claim = await transaction.get(claimRef);` |
| 502 | `if (claim.exists) transaction.delete(claimRef);` |
| 505 | `} on FirebaseException catch (error) {` |
| 518 | `.collection('players')` |
| 519 | `.doc(playerId)` |
| 520 | `.collection('weeklyRaidClaims')` |
| 521 | `.doc(claimId);` |
| 555 | `} on FirebaseException catch (error) {` |

### lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart). 클래스: `FirestoreWeeklyRaidStatusCommandRepository`, `_StatusCommandContext`, `_PendingStatusApplication`, `_ManualClaimTransactionOutcome`, `_WeeklyRaidStateContractException`.
메서드/선언(여러 줄 signature는 시작 행): L38 `Future<WeeklyRaidClaimImpactResult> inspectManualClaimImpact(`; L68 `Future<WeeklyRaidClaimCommandResult> createManualClaim(`; L277 `Future<WeeklyRaidClaimCommandResult> cleanupOrphanParticipation(`; L397 `Future<WeeklyRaidClaimCommandResult> _completeActiveState({`; L617 `Future<WeeklyRaidClaimCommandResult> deleteManualClaim(`; L716 `Future<_StatusCommandContext> _loadContext(`; L916 `Future<void> _supersedePendingApplications(`; L991 `Future<GameAccountOwnershipSnapshot> _ownership(`; L1026 `Map<String, dynamic>? _currentRecord(`; L1070 `void _validateObservation(`; L1098 `Future<String?> _boundPlayerId(Transaction transaction, String uid) async {`; L1111 `bool _validCreate(CreateManualWeeklyRaidClaimCommand command) =>`; L1121 `bool _validCleanup(CleanupOrphanRaidParticipationCommand command) =>`; L1150 `void _validateOrphanState(`; L1167 `void _validateOrphanAssignment(`; L1181 `void _validateStateIdentity(`; L1194 `void _validateAssignmentIdentity(`; L1207 `void _validateDeleteState(`; L1257 `String? _claimId(String cycleKey, String characterId, String raidId) {`; L1279 `Future<T?> _readAccessiblePendingRecruitment<T>(`.

| 행 | source 표현 |
|---|---|
| 27 | `required FirebaseFirestore firestore,` |
| 28 | `required FirebaseAuth firebaseAuth,` |
| 33 | `final FirebaseFirestore _firestore;` |
| 34 | `final FirebaseAuth _firebaseAuth;` |
| 41 | `if (_firebaseAuth.currentUser == null) {` |
| 58 | `} on FirebaseException catch (error) {` |
| 72 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 101 | `final outcome = await _firestore.runTransaction((transaction) async {` |
| 129 | `final state = await transaction.get(stateRef);` |
| 130 | `final claim = await transaction.get(claimRef);` |
| 131 | `final assignment = await transaction.get(assignmentRef);` |
| 185 | `transaction.delete(stateRef);` |
| 225 | `final now = FieldValue.serverTimestamp();` |
| 226 | `transaction.set(stateRef, {` |
| 238 | `'cycleStartedAt': Timestamp.fromDate(` |
| 241 | `'cycleEndsAt': Timestamp.fromDate(command.cycleEndsAt.toUtc()),` |
| 267 | `} on FirebaseException catch (error) {` |
| 280 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 292 | `return await _firestore.runTransaction((transaction) async {` |
| 310 | `.collection('recruitments')` |
| 311 | `.doc(command.recruitmentId);` |
| 312 | `final state = await transaction.get(stateRef);` |
| 313 | `final assignment = await transaction.get(assignmentRef);` |
| 314 | `final recruitment = await transaction.get(recruitmentRef);` |
| 380 | `if (stateData != null) transaction.delete(stateRef);` |
| 381 | `if (assignmentData != null) transaction.delete(assignmentRef);` |
| 388 | `} on FirebaseException catch (error) {` |
| 419 | `.collection('recruitments')` |
| 420 | `.doc(recruitmentId);` |
| 422 | `.collection('members')` |
| 423 | `.doc(command.playerId);` |
| 424 | `final recruitment = await transaction.get(recruitmentRef);` |
| 425 | `final membership = await transaction.get(memberRef);` |
| 448 | `.where((slot) => slot.playerId == command.playerId)` |
| 462 | `.where((slot) => slot.playerId != command.playerId)` |
| 465 | `.collection('members')` |
| 466 | `.doc(successor.playerId);` |
| 467 | `final successorDoc = await transaction.get(successorRef);` |
| 497 | `groupRef = _firestore.collection('groups').doc(groupId);` |
| 498 | `final group = await transaction.get(groupRef);` |
| 506 | `final now = FieldValue.serverTimestamp();` |
| 526 | `transaction.update(successorRef, plan.successorMembershipPatch!);` |
| 574 | `transaction.update(recruitmentRef, recruitmentPatch);` |
| 575 | `transaction.delete(memberRef);` |
| 576 | `transaction.update(stateRef, {` |
| 579 | `'revision': FieldValue.increment(1),` |
| 583 | `if (assignmentData != null) transaction.delete(assignmentRef);` |
| 586 | `.collection('groups')` |
| 587 | `.doc(groupId)` |
| 588 | `.collection('raidListings')` |
| 589 | `.doc(aggregate.recruitmentId);` |
| 591 | `transaction.delete(listingRef);` |
| 594 | `transaction.set(` |
| 605 | `transaction.update(ref, {` |
| 608 | `'revision': FieldValue.increment(1),` |
| 612 | `transaction.set(_firestore.collection('partyEvents').doc(eventId), event);` |
| 620 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 637 | `return await _firestore.runTransaction((transaction) async {` |
| 650 | `.collection('players')` |
| 651 | `.doc(command.playerId)` |
| 652 | `.collection('weeklyRaidClaims')` |
| 653 | `.doc(claimId);` |
| 654 | `final state = await transaction.get(stateRef);` |
| 655 | `final claim = await transaction.get(claimRef);` |
| 656 | `final assignment = await transaction.get(` |
| 693 | `if (stateData['status'] == 'completed') transaction.delete(stateRef);` |
| 695 | `if (claimData != null) transaction.delete(claimRef);` |
| 707 | `} on FirebaseException catch (error) {` |
| 731 | `).get(const GetOptions(source: Source.server));` |
| 808 | `.collection('recruitments')` |
| 809 | `.doc(recruitmentId)` |
| 861 | `.collection('members')` |
| 862 | `.doc(successorId)` |
| 870 | `.collectionGroup('applications')` |
| 871 | `.where('schemaVersion', isEqualTo: 1)` |
| 872 | `.where('applicantPlayerId', isEqualTo: command.playerId)` |
| 873 | `.where('cycleKey', isEqualTo: command.cycleKey)` |
| 874 | `.orderBy('updatedAt', descending: true)` |
| 922 | `await _firestore.runTransaction((transaction) async {` |
| 923 | `final recruitment = await transaction.get(candidate.recruitmentRef);` |
| 924 | `final application = await transaction.get(candidate.applicationRef);` |
| 925 | `final state = await transaction.get(` |
| 968 | `transaction.update(candidate.recruitmentRef, {` |
| 969 | `'pendingApplicationCount': FieldValue.increment(-1),` |
| 971 | `'pendingNonGroupApplicantCount': FieldValue.increment(-1),` |
| 972 | `'revision': FieldValue.increment(1),` |
| 973 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 975 | `transaction.update(candidate.applicationRef, {` |
| 978 | `'revision': FieldValue.increment(1),` |
| 979 | `'decidedAt': FieldValue.serverTimestamp(),` |
| 980 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 983 | `} on FirebaseException {` |
| 996 | `final characterRef = _firestore.collection('characters').doc(characterId);` |
| 1000 | `const GetOptions(source: Source.server),` |
| 1002 | `: await transaction.get(characterRef))` |
| 1008 | `final accountRef = _firestore.collection('gameAccounts').doc(accountId);` |
| 1011 | `? await accountRef.get(const GetOptions(source: Source.server))` |
| 1012 | `: await transaction.get(accountRef))` |
| 1099 | `final binding = await transaction.get(` |
| 1100 | `_firestore.collection('authBindings').doc(uid),` |
| 1143 | `recruitmentCycleEndsAt: rawCycleEndsAt is Timestamp` |
| 1232 | `.collection('players')` |
| 1233 | `.doc(playerId)` |
| 1234 | `.collection('raidStates')` |
| 1235 | `.doc(` |
| 1244 | `.collection('players')` |
| 1245 | `.doc(playerId)` |
| 1246 | `.collection('activeRaidAssignments')` |
| 1247 | `.doc('${characterId}_$raidId');` |
| 1252 | `.collection('players')` |
| 1253 | `.doc(command.playerId)` |
| 1254 | `.collection('weeklyRaidClaims')` |
| 1255 | `.doc(_claimId(command.cycleKey, command.characterId, command.raidId)!);` |
| 1284 | `} on FirebaseException catch (error) {` |

### lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart). 클래스: `FirestoreWeeklyRaidStatusRepository`.
메서드/선언(여러 줄 signature는 시작 행): L20 `Stream<List<WeeklyRaidStatusProjection>> watchCurrentCycleStatuses({`; L239 `void _validateCommon({`.

| 행 | source 표현 |
|---|---|
| 14 | `required FirebaseFirestore firestore,` |
| 17 | `final FirebaseFirestore _firestore;` |
| 32 | `final player = _firestore.collection('players').doc(playerId);` |
| 34 | `.collection('raidStates')` |
| 35 | `.where('cycleKey', isEqualTo: cycleKey);` |
| 37 | `.collection('weeklyRaidClaims')` |
| 38 | `.where('cycleKey', isEqualTo: cycleKey);` |
| 40 | `.collection('activeRaidAssignments')` |
| 41 | `.where('cycleKey', isEqualTo: cycleKey);` |
| 69 | `stateSub = stateQuery.snapshots().listen(` |
| 92 | `claimSub = claimQuery.snapshots().listen(` |
| 116 | `assignmentSub = assignmentQuery.snapshots().listen(` |
| 150 | `.doc(path)` |
| 151 | `.snapshots()` |
| 266 | `if (error is FirebaseException) {` |

### lib/features/account/presentation/pages/game_account_verification_page.dart
근거: [lib/features/account/presentation/pages/game_account_verification_page.dart](../../lib/features/account/presentation/pages/game_account_verification_page.dart). 클래스: `GameAccountVerificationPage`, `_GameAccountVerificationPageState`.
메서드/선언(여러 줄 signature는 시작 행): L34 `List<LocalGameAccount> _accounts = const [];`; L38 `bool _busy = false;`; L39 `String? _message;`; L42 `void initState() {`; L49 `void dispose() {`; L54 `Future<void> _loadAccounts() async {`; L64 `Future<void> _start({required bool direct}) async {`; L89 `Future<void> _confirm() async {`; L109 `Future<void> _saveBinding(`; L173 `Future<void> _run(Future<void> Function() action) async {`; L213 `String _apiErrorMessage(LostArkApiErrorType type) => switch (type) {`; L224 `String _resultMessage(GameAccountVerificationResult result) =>`.

| 행 | source 표현 |
|---|---|
| 152 | `.where((item) => item.id == boundAccountId)` |
| 190 | `} on FirebaseException catch (error) {` |

### lib/features/group/data/repositories/firestore_group_application_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_application_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_application_command_repository.dart). 클래스: `FirestoreGroupApplicationCommandRepository`, `_GroupLeaderContext`.
메서드/선언(여러 줄 signature는 시작 행): L43 `Future<GroupJoinCommandResult> approveApplication(`; L122 `Future<GroupJoinCommandResult> rejectApplication(`; L164 `Future<GroupJoinCommandResult> blockApplicant(`; L225 `Future<GroupJoinCommandResult> releaseBlock(`; L254 `Future<_GroupLeaderContext> _leaderContext(`; L347 `Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) =>`.

| 행 | source 표현 |
|---|---|
| 25 | `required FirebaseFirestore firestore,` |
| 26 | `required FirebaseAuth firebaseAuth,` |
| 38 | `final FirebaseFirestore _firestore;` |
| 57 | `.collection('joinRelations')` |
| 58 | `.doc(command.targetPlayerId);` |
| 59 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 80 | `.collection('members')` |
| 81 | `.doc(command.targetPlayerId);` |
| 82 | `if ((await transaction.get(memberRef)).exists) {` |
| 93 | `final serverTimestamp = FieldValue.serverTimestamp();` |
| 100 | `addedGroupIdUnion: FieldValue.arrayUnion([command.groupId]),` |
| 101 | `incrementByOne: FieldValue.increment(1),` |
| 104 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 105 | `transaction.set(memberRef, plan.member!);` |
| 106 | `transaction.set(` |
| 109 | `SetOptions(merge: true),` |
| 111 | `transaction.set(` |
| 114 | `SetOptions(merge: true),` |
| 116 | `transaction.update(groupRef, plan.groupPatch);` |
| 136 | `.collection('joinRelations')` |
| 137 | `.doc(command.targetPlayerId);` |
| 138 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 150 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 152 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 153 | `transaction.set(` |
| 156 | `SetOptions(merge: true),` |
| 158 | `transaction.update(groupRef, plan.groupPatch);` |
| 178 | `.collection('joinRelations')` |
| 179 | `.doc(command.targetPlayerId);` |
| 180 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 185 | `.collection('applicantStats')` |
| 186 | `.doc(command.targetPlayerId);` |
| 190 | `data: _data(await transaction.get(statsRef)),` |
| 193 | `final alreadyBlocked = (await transaction.get(blockRef)).exists;` |
| 201 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 206 | `transaction.update(relationRef, relationPatch);` |
| 207 | `transaction.set(` |
| 210 | `SetOptions(merge: true),` |
| 215 | `transaction.set(blockRef, plan.blockDocument!);` |
| 219 | `transaction.update(groupRef, plan.groupPatch);` |
| 238 | `if (!(await transaction.get(blockRef)).exists) {` |
| 245 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 247 | `transaction.delete(blockRef);` |
| 248 | `transaction.update(groupRef, plan.groupPatch);` |
| 259 | `final group = _group(await transaction.get(groupRef));` |
| 266 | `final callerMember = await transaction.get(` |
| 267 | `groupRef.collection('members').doc(playerId),` |
| 301 | `_firestore.collection('groups').doc(groupId);` |
| 306 | `) => _groupRef(groupId).collection('blockedPlayers').doc(playerId);` |
| 311 | `.collection('players')` |
| 312 | `.doc(playerId)` |
| 313 | `.collection('groupMembershipState')` |
| 314 | `.doc(GroupCreateWritePlan.membershipStateDocumentId);` |
| 320 | `.collection('players')` |
| 321 | `.doc(playerId)` |
| 322 | `.collection('groupRelations')` |
| 323 | `.doc(groupId);` |

### lib/features/group/data/repositories/firestore_group_character_search_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_character_search_repository.dart](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart). 클래스: `FirestoreGroupCharacterSearchRepository`.
메서드/선언(여러 줄 signature는 시작 행): L19 `Future<List<GroupRequestCharacter>> searchActiveCharactersByExactName(`; L42 `Future<List<GroupRequestCharacter>> loadActiveCharactersForPlayer(`.

| 행 | source 표현 |
|---|---|
| 13 | `required FirebaseFirestore firestore,` |
| 16 | `final FirebaseFirestore _firestore;` |
| 27 | `.collection('characters')` |
| 28 | `.where('status', isEqualTo: 'active')` |
| 29 | `.where('characterName', isEqualTo: exactName)` |
| 30 | `.limit(limit)` |
| 49 | `.collection('characters')` |
| 50 | `.where('status', isEqualTo: 'active')` |
| 51 | `.where('ownerPlayerId', isEqualTo: ownerPlayerId)` |
| 52 | `.limit(limit)` |
| 115 | `Timestamp timestamp => timestamp.toDate().toUtc(),` |
| 131 | `if (error is FirebaseException) {` |

### lib/features/group/data/repositories/firestore_group_create_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_create_repository.dart](../../lib/features/group/data/repositories/firestore_group_create_repository.dart). 클래스: `FirestoreGroupCreateRepository`.
메서드/선언(여러 줄 signature는 시작 행): L28 `Future<GroupCreateResult> create(GroupCreateCommand command) async {`.

| 행 | source 표현 |
|---|---|
| 16 | `required FirebaseFirestore firestore,` |
| 17 | `required FirebaseAuth firebaseAuth,` |
| 23 | `final FirebaseFirestore _firestore;` |
| 24 | `final FirebaseAuth _firebaseAuth;` |
| 32 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 43 | `return await _firestore.runTransaction((transaction) async {` |
| 44 | `final bindingRef = _firestore.collection('authBindings').doc(authUid);` |
| 45 | `final binding = await transaction.get(bindingRef);` |
| 56 | `final playerRef = _firestore.collection('players').doc(playerId);` |
| 58 | `.collection('characters')` |
| 59 | `.doc(command.representativeCharacterId);` |
| 60 | `final player = await transaction.get(playerRef);` |
| 61 | `final character = await transaction.get(characterRef);` |
| 90 | `final ownership = await transaction.get(` |
| 92 | `.collection('playerGameAccounts')` |
| 93 | `.doc('${playerId}_$gameAccountId'),` |
| 116 | `.collection('players')` |
| 117 | `.doc(playerId)` |
| 118 | `.collection('groupMembershipState')` |
| 119 | `.doc(GroupCreateWritePlan.membershipStateDocumentId);` |
| 120 | `final membershipStateSnapshot = await transaction.get(` |
| 135 | `final groupRef = _firestore.collection('groups').doc();` |
| 140 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 153 | `transaction.set(groupRef, plan.group);` |
| 154 | `transaction.set(` |
| 155 | `groupRef.collection('members').doc(playerId),` |
| 158 | `transaction.set(membershipStateRef, plan.membershipState);` |
| 159 | `transaction.set(` |
| 161 | `.collection('players')` |
| 162 | `.doc(playerId)` |
| 163 | `.collection('groupRelations')` |
| 164 | `.doc(groupRef.id),` |
| 171 | `} on FirebaseException catch (error) {` |
| 180 | `Timestamp timestamp => timestamp.toDate(),` |
| 182 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |

### lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart). 클래스: `FirestoreGroupJoinCodeCommandRepository`, `_LeaderContext`.
메서드/선언(여러 줄 signature는 시작 행): L52 `Future<GroupJoinCodeCommandResult> createCode(`; L93 `Future<GroupJoinCodeCommandResult> revokeCode(`; L135 `Future<GroupJoinCodeCommandResult> setVisibility(`; L166 `Future<GroupJoinCodeCommandResult> joinByCode(`; L272 `Future<GroupJoinCodeCommandResult> _run(`; L288 `Future<_LeaderContext> _leaderContext(`; L404 `Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) {`.

| 행 | source 표현 |
|---|---|
| 28 | `required FirebaseFirestore firestore,` |
| 29 | `required FirebaseAuth firebaseAuth,` |
| 45 | `final FirebaseFirestore _firestore;` |
| 73 | `if ((await transaction.get(codeRef)).exists) {` |
| 84 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 86 | `transaction.set(codeRef, plan.joinCodeDocument!);` |
| 87 | `transaction.update(groupRef, plan.groupPatch);` |
| 113 | `final codeSnap = await transaction.get(codeRef);` |
| 126 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 128 | `transaction.delete(codeRef);` |
| 129 | `transaction.update(groupRef, plan.groupPatch);` |
| 156 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 158 | `transaction.update(groupRef, plan.groupPatch);` |
| 177 | `final codeSnap = await transaction.get(codeRef);` |
| 194 | `final group = _group(await transaction.get(groupRef));` |
| 208 | `data: _data(await transaction.get(_membershipStateRef(playerId))),` |
| 226 | `await transaction.get(` |
| 227 | `_firestore.collection('characters').doc(command.characterId),` |
| 242 | `final relationRef = groupRef.collection('joinRelations').doc(playerId);` |
| 243 | `final existing = _joinRelation(await transaction.get(relationRef));` |
| 245 | `final existingPlayerRelation = await transaction.get(playerRelationRef);` |
| 256 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 262 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 264 | `transaction.set(groupRef.collection('members').doc(playerId), plan.member!);` |
| 265 | `transaction.set(_membershipStateRef(playerId), plan.membershipState!);` |
| 266 | `transaction.set(playerRelationRef, plan.playerRelation!);` |
| 267 | `transaction.update(groupRef, plan.groupPatch);` |
| 293 | `final group = _group(await transaction.get(groupRef));` |
| 302 | `final memberSnap = await transaction.get(` |
| 303 | `groupRef.collection('members').doc(playerId),` |
| 321 | `_firestore.collection('groups').doc(groupId);` |
| 324 | `_firestore.collection('groupJoinCodes').doc(code);` |
| 329 | `.collection('players')` |
| 330 | `.doc(playerId)` |
| 331 | `.collection('groupMembershipState')` |
| 332 | `.doc(GroupCreateWritePlan.membershipStateDocumentId);` |
| 338 | `.collection('players')` |
| 339 | `.doc(playerId)` |
| 340 | `.collection('groupRelations')` |
| 341 | `.doc(groupId);` |

### lib/features/group/data/repositories/firestore_group_join_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_join_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart). 클래스: `FirestoreGroupJoinCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L52 `Future<GroupJoinCommandResult> invite(GroupInviteCommand command) async {`; L137 `Future<GroupJoinCommandResult> apply(GroupApplyCommand command) async {`; L223 `Future<GroupJoinCommandResult> acceptInvitation(`; L299 `Future<GroupJoinCommandResult> rejectInvitation(`; L352 `Future<GroupJoinCommandResult> cancelInvitation(`; L420 `Future<GroupJoinCommandResult> leave(GroupLeaveCommand command) async {`; L495 `Future<GroupJoinCommandResult> transferLeadership(`; L576 `Future<GroupJoinCommandResult> disband(GroupDisbandCommand command) async {`; L718 `Future<void> refreshMyDisplaySnapshot(`; L778 `Future<GroupJoinCommandResult> _run(`; L889 `Map<String, Object?>? _data(DocumentSnapshot<Map<String, dynamic>> snapshot) =>`.

| 행 | source 표현 |
|---|---|
| 35 | `required FirebaseFirestore firestore,` |
| 36 | `required FirebaseAuth firebaseAuth,` |
| 46 | `final FirebaseFirestore _firestore;` |
| 47 | `final FirebaseAuth _firebaseAuth;` |
| 57 | `final group = _group(await transaction.get(groupRef));` |
| 69 | `final callerMember = await transaction.get(` |
| 70 | `groupRef.collection('members').doc(playerId),` |
| 79 | `await transaction.get(` |
| 80 | `_firestore.collection('characters').doc(command.targetCharacterId),` |
| 96 | `final targetMember = await transaction.get(` |
| 97 | `groupRef.collection('members').doc(targetPlayerId),` |
| 106 | `.collection('joinRelations')` |
| 107 | `.doc(targetPlayerId);` |
| 108 | `final existing = _joinRelation(await transaction.get(relationRef));` |
| 123 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 126 | `transaction.set(relationRef, plan.joinRelationDocument!);` |
| 127 | `transaction.set(` |
| 131 | `transaction.update(groupRef, plan.groupPatch);` |
| 142 | `final group = _group(await transaction.get(groupRef));` |
| 157 | `data: _data(await transaction.get(_membershipStateRef(playerId))),` |
| 166 | `await transaction.get(` |
| 167 | `_firestore.collection('characters').doc(command.characterId),` |
| 182 | `final relationRef = groupRef.collection('joinRelations').doc(playerId);` |
| 183 | `final existing = _joinRelation(await transaction.get(relationRef));` |
| 191 | `final statsRef = groupRef.collection('applicantStats').doc(playerId);` |
| 192 | `final statsSnapshot = await transaction.get(statsRef);` |
| 207 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 211 | `transaction.set(relationRef, plan.joinRelationDocument!);` |
| 212 | `transaction.set(statsRef, plan.applicantStats!);` |
| 213 | `transaction.set(` |
| 217 | `transaction.update(groupRef, plan.groupPatch);` |
| 230 | `final group = _group(await transaction.get(groupRef));` |
| 244 | `data: _data(await transaction.get(_membershipStateRef(playerId))),` |
| 263 | `final relationRef = groupRef.collection('joinRelations').doc(playerId);` |
| 264 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 274 | `await transaction.get(playerRelationRef),` |
| 283 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 286 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 287 | `transaction.set(` |
| 288 | `groupRef.collection('members').doc(playerId),` |
| 291 | `transaction.set(_membershipStateRef(playerId), plan.membershipState!);` |
| 292 | `transaction.set(playerRelationRef, plan.playerRelation);` |
| 293 | `transaction.update(groupRef, plan.groupPatch);` |
| 306 | `final group = _group(await transaction.get(groupRef));` |
| 318 | `final relationRef = groupRef.collection('joinRelations').doc(playerId);` |
| 319 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 333 | `await transaction.get(playerRelationRef),` |
| 341 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 344 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 345 | `transaction.set(playerRelationRef, plan.playerRelation);` |
| 346 | `transaction.update(groupRef, plan.groupPatch);` |
| 359 | `final group = _group(await transaction.get(groupRef));` |
| 371 | `final callerMember = await transaction.get(` |
| 372 | `groupRef.collection('members').doc(playerId),` |
| 381 | `.collection('joinRelations')` |
| 382 | `.doc(command.targetPlayerId);` |
| 383 | `final relation = _joinRelation(await transaction.get(relationRef));` |
| 407 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 409 | `transaction.update(relationRef, plan.joinRelationPatch!);` |
| 410 | `transaction.set(` |
| 414 | `transaction.update(groupRef, plan.groupPatch);` |
| 426 | `.collection('recruitments')` |
| 427 | `.where('leaderPlayerId', isEqualTo: playerId)` |
| 428 | `.where('groupId', isEqualTo: command.groupId)` |
| 429 | `.where('status', whereIn: const ['active', 'completed'])` |
| 430 | `.limit(20)` |
| 443 | `final group = _group(await transaction.get(groupRef));` |
| 455 | `final memberRef = groupRef.collection('members').doc(playerId);` |
| 456 | `final memberSnapshot = await transaction.get(memberRef);` |
| 471 | `data: _data(await transaction.get(_membershipStateRef(playerId))),` |
| 484 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 486 | `transaction.delete(memberRef);` |
| 487 | `transaction.update(groupRef, plan.groupPatch);` |
| 488 | `transaction.update(_membershipStateRef(playerId), plan.membershipState);` |
| 489 | `transaction.delete(_playerRelationRef(playerId, command.groupId));` |
| 507 | `final groupSnapshot = await transaction.get(groupRef);` |
| 531 | `final outgoingRef = groupRef.collection('members').doc(playerId);` |
| 533 | `.collection('members')` |
| 534 | `.doc(command.targetPlayerId);` |
| 535 | `final outgoingSnapshot = await transaction.get(outgoingRef);` |
| 536 | `final incomingSnapshot = await transaction.get(incomingRef);` |
| 566 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 568 | `transaction.update(groupRef, plan.groupPatch);` |
| 569 | `transaction.update(outgoingRef, plan.outgoingLeaderPatch);` |
| 570 | `transaction.update(incomingRef, plan.incomingLeaderPatch);` |
| 582 | `.collection('joinRelations')` |
| 583 | `.where('status', isEqualTo: GroupRequestStatus.pending.name)` |
| 584 | `.limit(1)` |
| 591 | `} on FirebaseException catch (error) {` |
| 596 | `final groupSnapshot = await transaction.get(groupRef);` |
| 645 | `final memberRef = groupRef.collection('members').doc(playerId);` |
| 646 | `final memberSnapshot = await transaction.get(memberRef);` |
| 661 | `data: _data(await transaction.get(_membershipStateRef(playerId))),` |
| 673 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 675 | `transaction.update(groupRef, plan.groupPatch);` |
| 676 | `transaction.delete(memberRef);` |
| 677 | `transaction.update(_membershipStateRef(playerId), plan.membershipState);` |
| 678 | `transaction.delete(_playerRelationRef(playerId, command.groupId));` |
| 721 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 725 | `await _firestore.runTransaction((transaction) async {` |
| 726 | `final bindingRef = _firestore.collection('authBindings').doc(authUid);` |
| 727 | `final binding = await transaction.get(bindingRef);` |
| 738 | `).collection('members').doc(playerId);` |
| 739 | `final memberSnapshot = await transaction.get(memberRef);` |
| 748 | `final characterSnapshot = await transaction.get(` |
| 749 | `_firestore.collection('characters').doc(characterId),` |
| 758 | `transaction.update(` |
| 768 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 799 | `_firestore.collection('groups').doc(groupId);` |
| 804 | `.collection('players')` |
| 805 | `.doc(playerId)` |
| 806 | `.collection('groupMembershipState')` |
| 807 | `.doc(GroupCreateWritePlan.membershipStateDocumentId);` |
| 813 | `.collection('players')` |
| 814 | `.doc(playerId)` |
| 815 | `.collection('groupRelations')` |
| 816 | `.doc(groupId);` |
| 903 | `Timestamp timestamp => timestamp.toDate(),` |

### lib/features/group/data/repositories/firestore_group_read_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_read_repository.dart](../../lib/features/group/data/repositories/firestore_group_read_repository.dart). 클래스: `FirestoreGroupReadRepository`.
메서드/선언(여러 줄 signature는 시작 행): L39 `Stream<GroupReadSnapshot<GroupRelation>> watchMyGroups(String playerId) {`; L60 `Stream<GroupReadSnapshot<GroupRelation>> watchMyRequests(String playerId) {`; L87 `Future<GroupRelation?> loadMyRelation({`; L106 `Future<List<GroupJoinRelation>> loadGroupJoinRelations({`; L131 `Future<GroupMember?> loadGroupMember({`; L150 `Future<List<GroupMember>> loadGroupMembers(String groupId) async {`; L167 `Future<List<GroupMemberDisplay>> loadGroupMemberDisplays(`; L189 `Future<List<GroupBlockedPlayer>> loadBlockedPlayers({`; L211 `Future<List<GroupPublicSummary>> searchGroups({`; L244 `Future<GroupPublicSummary?> loadGroup(String groupId) async {`; L287 `Future<Map<String, Map<String, Object?>>> _loadCharacterDataById(`.

| 행 | source 표현 |
|---|---|
| 20 | `required FirebaseFirestore firestore,` |
| 26 | `Timestamp timestamp => timestamp.toDate(),` |
| 28 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |
| 34 | `final FirebaseFirestore _firestore;` |
| 41 | `.collection('players')` |
| 42 | `.doc(playerId)` |
| 43 | `.collection('groupRelations')` |
| 44 | `.where('relation', isEqualTo: GroupRelationKind.member.name)` |
| 45 | `.orderBy('updatedAt', descending: true)` |
| 46 | `.snapshots(includeMetadataChanges: true)` |
| 62 | `.collection('players')` |
| 63 | `.doc(playerId)` |
| 64 | `.collection('groupRelations')` |
| 65 | `.where(` |
| 72 | `.orderBy('updatedAt', descending: true)` |
| 73 | `.snapshots(includeMetadataChanges: true)` |
| 93 | `.collection('players')` |
| 94 | `.doc(playerId)` |
| 95 | `.collection('groupRelations')` |
| 96 | `.doc(groupId)` |
| 113 | `.collection('groups')` |
| 114 | `.doc(groupId)` |
| 115 | `.collection('joinRelations')` |
| 116 | `.where('kind', isEqualTo: kind.name)` |
| 117 | `.where('status', isEqualTo: GroupRequestStatus.pending.name)` |
| 118 | `.orderBy('createdAt')` |
| 119 | `.limit(limit)` |
| 137 | `.collection('groups')` |
| 138 | `.doc(groupId)` |
| 139 | `.collection('members')` |
| 140 | `.doc(playerId)` |
| 153 | `.collection('groups')` |
| 154 | `.doc(groupId)` |
| 155 | `.collection('members')` |
| 195 | `.collection('groups')` |
| 196 | `.doc(groupId)` |
| 197 | `.collection('blockedPlayers')` |
| 198 | `.orderBy('createdAt', descending: true)` |
| 199 | `.limit(limit)` |
| 247 | `.collection('groups')` |
| 248 | `.doc(groupId)` |
| 258 | `.collection('groups')` |
| 259 | `.where('status', isEqualTo: GroupStatus.active.name)` |
| 260 | `.orderBy('lastActivityAt', descending: true)` |
| 261 | `.orderBy(FieldPath.documentId, descending: true)` |
| 262 | `.limit(limit);` |
| 269 | `.collection('groups')` |
| 270 | `.where('status', isEqualTo: GroupStatus.active.name)` |
| 271 | `.where(field, isGreaterThanOrEqualTo: normalizedQuery)` |
| 272 | `.where(` |
| 276 | `.orderBy(field)` |
| 277 | `.orderBy(FieldPath.documentId)` |
| 278 | `.limit(limit);` |
| 292 | `.where((id) => id.isNotEmpty)` |
| 298 | `(id) => _firestore.collection('characters').doc(id).get(),` |
| 322 | `if (error is FirebaseException) {` |

### lib/features/group/data/repositories/group_command_runner.dart
근거: [lib/features/group/data/repositories/group_command_runner.dart](../../lib/features/group/data/repositories/group_command_runner.dart). 클래스: `GroupCommandRunner`.
메서드/선언(여러 줄 signature는 시작 행): L19 `Future<GroupJoinCommandResult> run(`; L35 `Future<T> runMapped<T>({`.

| 행 | source 표현 |
|---|---|
| 11 | `required FirebaseFirestore firestore,` |
| 12 | `required FirebaseAuth firebaseAuth,` |
| 16 | `final FirebaseFirestore _firestore;` |
| 17 | `final FirebaseAuth _firebaseAuth;` |
| 43 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 48 | `return await _firestore.runTransaction((transaction) async {` |
| 49 | `final binding = await transaction.get(` |
| 50 | `_firestore.collection('authBindings').doc(authUid),` |
| 59 | `final player = await transaction.get(` |
| 60 | `_firestore.collection('players').doc(playerId),` |
| 73 | `} on FirebaseException catch (error) {` |
| 97 | `Timestamp timestamp => timestamp.toDate(),` |
| 99 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |

### lib/features/manual_verification/data/firestore_manual_verification_repository.dart
근거: [lib/features/manual_verification/data/firestore_manual_verification_repository.dart](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart). 클래스: `FirestoreManualVerificationRepository`.
메서드/선언(여러 줄 signature는 시작 행): L47 `Future<ManualVerificationRequest> createRequest({`; L137 `Future<ManualVerificationRequest> reissueRequest(String requestId) async {`; L174 `Future<void> cancelRequest(String requestId) async {`; L198 `Stream<List<ManualVerificationRequest>> watchMyRequests() async* {`; L213 `Stream<List<ManualVerificationRequest>> watchIncomingDisputes() async* {`; L235 `Future<GameAccountVerificationResult> loadApprovedResult(`; L280 `Future<ManualVerificationReviewContext> loadReviewContext(`; L332 `Future<List<ManualVerificationRequest>> loadPendingQueue() async {`; L352 `Future<void> reviewCancel({`; L372 `Future<void> reviewBlock({`; L416 `Future<GameAccountVerificationResult> reviewApprove(String requestId) async {`; L495 `Future<GameAccountVerificationResult> reviewForceApprove(String requestId) async {`; L560 `Future<void> reviewApproveDefense(String defenseRequestId) async {`; L678 `Future<GameAccountVerificationResult> reviewRejectDefense(`; L749 `Future<void> syncExpiredDisputes() async {`; L772 `Future<GameAccountVerificationResult> reviewApproveUnowned(`; L777 `Future<GameAccountVerificationResult> _claimForRequester({`; L1010 `Future<void> _openDispute({`; L1046 `Future<void> _finalizeExpiredDispute(`; L1093 `Future<void> _writeDisputeOpenedEvent({`; L1125 `Future<({String playerId, String gameAccountId})?> _resolveActiveOwner(`; L1148 `Future<({String playerId, String gameAccountId})> _resolveForceTransferOwner(`; L1178 `Future<ManualVerificationRequest> _requireDefenseDispute({`; L1228 `Future<void> _reviewStatus({`; L1246 `void _requirePending(Map<String, dynamic>? data) {`; L1258 `void _requireForceEligible(Map<String, dynamic>? data) {`; L1271 `Future<void> _assertNotBlocked(`; L1298 `Future<void> _assertNotAlreadyOwner({`; L1329 `Future<ManualVerificationRequest?> _activePendingForAccount({`; L1354 `Future<({int target, int player})> _attemptCounts({`; L1378 `Map<String, Object?> _createPayload({`; L1470 `Future<String> _requirePlayerId() async {`; L1518 `Future<String> _requireOperator() async {`.

| 행 | source 표현 |
|---|---|
| 21 | `FirebaseFirestore? firestore,` |
| 22 | `FirebaseAuth? firebaseAuth,` |
| 26 | `_firestore = firestore ?? FirebaseFirestore.instance,` |
| 27 | `_firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,` |
| 35 | `final FirebaseFirestore _firestore;` |
| 36 | `final FirebaseAuth _firebaseAuth;` |
| 41 | `_firestore.collection('manualVerificationRequests');` |
| 44 | `_firestore.collection('manualVerificationBlocks');` |
| 107 | `final reference = _requests.doc();` |
| 131 | `} on FirebaseException catch (error) {` |
| 139 | `final snapshot = await _requests.doc(requestId).get();` |
| 156 | `'createdAt': FieldValue.serverTimestamp(),` |
| 157 | `'expiresAt': Timestamp.fromDate(now.add(_requestTtl)),` |
| 158 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 176 | `final snapshot = await _requests.doc(requestId).get();` |
| 192 | `'resolvedAt': FieldValue.serverTimestamp(),` |
| 193 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 201 | `.where('requesterPlayerId', isEqualTo: playerId)` |
| 202 | `.snapshots()` |
| 216 | `.where('previousOwnerPlayerId', isEqualTo: playerId)` |
| 217 | `.snapshots()` |
| 222 | `.where((request) => request.isAwaitingOwnerResponse)` |
| 239 | `final snapshot = await _requests.doc(requestId).get();` |
| 261 | `.collection('characters')` |
| 262 | `.where('gameAccountId', isEqualTo: accountId)` |
| 285 | `.doc('${request.requesterPlayerId}_${request.targetIdentityKey}')` |
| 337 | `.where('status', isEqualTo: 'pendingProof')` |
| 342 | `.where((request) => !request.isExpiredAt(now))` |
| 346 | `} on FirebaseException catch (error) {` |
| 366 | `} on FirebaseException catch (error) {` |
| 378 | `final snapshot = await _requests.doc(requestId).get();` |
| 385 | `await _firestore.runTransaction((transaction) async {` |
| 386 | `final request = await transaction.get(snapshot.reference);` |
| 388 | `transaction.update(snapshot.reference, {` |
| 391 | `'reviewedAt': FieldValue.serverTimestamp(),` |
| 393 | `'resolvedAt': FieldValue.serverTimestamp(),` |
| 394 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 396 | `transaction.set(_blocks.doc(blockId), {` |
| 405 | `'blockedAt': FieldValue.serverTimestamp(),` |
| 410 | `} on FirebaseException catch (error) {` |
| 419 | `final snapshot = await _requests.doc(requestId).get();` |
| 456 | `return _firestore.runTransaction((transaction) async {` |
| 457 | `final live = await transaction.get(snapshot.reference);` |
| 489 | `} on FirebaseException catch (error) {` |
| 498 | `final snapshot = await _requests.doc(requestId).get();` |
| 537 | `return _firestore.runTransaction((transaction) async {` |
| 538 | `final live = await transaction.get(snapshot.reference);` |
| 554 | `} on FirebaseException catch (error) {` |
| 562 | `final defenseSnapshot = await _requests.doc(defenseRequestId).get();` |
| 577 | `final disputeSnapshot = await _requests.doc(disputeId).get();` |
| 626 | `await _firestore.runTransaction((transaction) async {` |
| 627 | `final liveDefense = await transaction.get(defenseSnapshot.reference);` |
| 629 | `final liveDispute = await transaction.get(disputeSnapshot.reference);` |
| 639 | `if (deadline is Timestamp && now.isBefore(deadline.toDate().toUtc())) {` |
| 647 | `final nowField = FieldValue.serverTimestamp();` |
| 648 | `transaction.update(defenseSnapshot.reference, {` |
| 656 | `transaction.update(disputeSnapshot.reference, {` |
| 664 | `transaction.set(_blocks.doc(blockId), {` |
| 683 | `final defenseSnapshot = await _requests.doc(defenseRequestId).get();` |
| 692 | `final disputeSnapshot = await _requests.doc(disputeId).get();` |
| 712 | `return _firestore.runTransaction((transaction) async {` |
| 713 | `final liveDefense = await transaction.get(defenseSnapshot.reference);` |
| 715 | `final liveDispute = await transaction.get(disputeSnapshot.reference);` |
| 730 | `final nowField = FieldValue.serverTimestamp();` |
| 731 | `transaction.update(defenseSnapshot.reference, {` |
| 743 | `} on FirebaseException catch (error) {` |
| 752 | `.where('status', isEqualTo: 'awaitingOwnerResponse')` |
| 766 | `} on FirebaseException catch (error) {` |
| 791 | `.collection('characterIdentityClaims')` |
| 792 | `.doc(characterIdentityKey(item.serverName, item.characterName)),` |
| 797 | `claims.add(await transaction.get(ref));` |
| 800 | `.where((snapshot) => snapshot.exists)` |
| 818 | `? _firestore.collection('gameAccounts').doc(resolvedGameAccountId)` |
| 820 | `? _firestore.collection('gameAccounts').doc()` |
| 821 | `: _firestore.collection('gameAccounts').doc(accountIds.single);` |
| 822 | `final account = await transaction.get(accountRef);` |
| 866 | `? _firestore.collection('characters').doc(characterId)` |
| 867 | `: _firestore.collection('characters').doc(),` |
| 877 | `await transaction.get(_firestore.collection('characters').doc(id)),` |
| 886 | `final now = FieldValue.serverTimestamp();` |
| 890 | `transaction.update(snapshot.reference, {` |
| 898 | `transaction.set(accountRef, {` |
| 913 | `.where((item) => item.id == characterRef.id)` |
| 915 | `transaction.set(characterRef, {` |
| 931 | `transaction.set(claimRefs[index], {` |
| 947 | `transaction.set(` |
| 949 | `.collection('playerGameAccounts')` |
| 950 | `.doc('${requesterPlayerId}_${accountRef.id}'),` |
| 958 | `SetOptions(merge: true),` |
| 963 | `transaction.set(` |
| 965 | `.collection('playerGameAccounts')` |
| 966 | `.doc('${previousOwner}_${accountRef.id}'),` |
| 974 | `SetOptions(merge: true),` |
| 1002 | `transaction.update(requestRef, requestUpdate);` |
| 1018 | `final deadline = Timestamp.fromDate(` |
| 1021 | `final nowField = FieldValue.serverTimestamp();` |
| 1041 | `} on FirebaseException {` |
| 1059 | `await _firestore.runTransaction((transaction) async {` |
| 1060 | `final live = await transaction.get(requestRef);` |
| 1066 | `if (deadline is! Timestamp \|\|` |
| 1098 | `required Timestamp ownerResponseDeadlineAt,` |
| 1102 | `final expiresAt = Timestamp.fromDate(` |
| 1106 | `.collection('players')` |
| 1107 | `.doc(recipientPlayerId)` |
| 1108 | `.collection('events')` |
| 1109 | `.doc(eventId)` |
| 1120 | `'occurredAt': FieldValue.serverTimestamp(),` |
| 1130 | `.collection('characterIdentityClaims')` |
| 1131 | `.doc(identityKey)` |
| 1138 | `final account = await _firestore.collection('gameAccounts').doc(accountId).get();` |
| 1183 | `final snapshot = await _requests.doc(defenseOfRequestId).get();` |
| 1234 | `final snapshot = await _requests.doc(requestId).get();` |
| 1239 | `'reviewedAt': FieldValue.serverTimestamp(),` |
| 1241 | `'resolvedAt': FieldValue.serverTimestamp(),` |
| 1242 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 1283 | `final snapshot = await _blocks.doc(blockId).get();` |
| 1290 | `} on FirebaseException catch (error) {` |
| 1305 | `.collection('gameAccounts')` |
| 1306 | `.doc(targetGameAccountId)` |
| 1336 | `.where('requesterPlayerId', isEqualTo: playerId)` |
| 1361 | `.where('requesterPlayerId', isEqualTo: playerId)` |
| 1410 | `'createdAt': FieldValue.serverTimestamp(),` |
| 1411 | `'expiresAt': Timestamp.fromDate(now.add(_requestTtl)),` |
| 1412 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 1422 | `if (value is Timestamp) return value.toDate().toUtc();` |
| 1471 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 1478 | `final binding = await _firestore.collection('authBindings').doc(authUid).get();` |
| 1496 | `ManualVerificationException _mapFirebase(FirebaseException error) {` |
| 1521 | `.collection('operatorAssignments')` |
| 1522 | `.doc(playerId)` |
| 1530 | `final player = await _firestore.collection('players').doc(playerId).get();` |

### lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart
근거: [lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart](../../lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart). 클래스: `OperatorManualVerificationDetailPage`, `_OperatorManualVerificationDetailPageState`, `_DetailState`.
메서드/선언(여러 줄 signature는 시작 행): L32 `String? _message;`; L35 `void initState() {`; L40 `Future<_DetailState> _load() async {`; L55 `Future<void> _run(Future<void> Function() action) async {`; L97 `Future<void> _promptReason({`; L127 `Future<void> _confirmForceApprove() async {`; L156 `Future<void> _confirmRejectDefense() async {`.

| 행 | source 표현 |
|---|---|
| 47 | `queue.where((item) => item.id == widget.requestId).firstOrNull;` |
| 76 | `} on FirebaseException catch (error) {` |

### lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart
근거: [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart). 클래스: `FirestoreOperatorAccessRepository`.
메서드/선언(여러 줄 signature는 시작 행): L19 `FirebaseFirestore get _firestore =>`; L22 `FirebaseAuth get _firebaseAuth =>`; L26 `Future<bool> isCurrentPlayerOperator() async {`; L41 `Future<OperatorWriteReadiness> loadWriteReadiness() async {`; L85 `Future<List<OperatorUserSummary>> loadUsers({int limit = 50}) async {`; L110 `Future<OperatorUserDetail?> loadUserDetail(String playerId) async {`; L191 `Future<void> _requireOperator() async {`; L197 `Future<String?> _currentPlayerId() async {`; L215 `Future<void> _prepareLegacyPlayers() async {`; L232 `Future<Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>>`; L254 `Future<Map<String, List<String>>> _representativeNames(`; L315 `String? _representativeLabel(List<String> names) {`; L324 `String? _string(Object? value) =>`.

| 행 | source 표현 |
|---|---|
| 10 | `FirebaseFirestore? firestore,` |
| 11 | `FirebaseAuth? firebaseAuth,` |
| 13 | `_providedFirebaseAuth = firebaseAuth;` |
| 15 | `final FirebaseFirestore? _providedFirestore;` |
| 16 | `final FirebaseAuth? _providedFirebaseAuth;` |
| 19 | `FirebaseFirestore get _firestore =>` |
| 20 | `_providedFirestore ?? FirebaseFirestore.instance;` |
| 22 | `FirebaseAuth get _firebaseAuth =>` |
| 23 | `_providedFirebaseAuth ?? FirebaseAuth.instance;` |
| 30 | `.collection('operatorAssignments')` |
| 31 | `.doc(playerId)` |
| 36 | `final player = await _firestore.collection('players').doc(playerId).get();` |
| 42 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 53 | `final binding = await _firestore.collection('authBindings').doc(authUid).get();` |
| 68 | `final player = await _firestore.collection('players').doc(playerId).get();` |
| 70 | `.collection('operatorAssignments')` |
| 71 | `.doc(playerId)` |
| 89 | `.collection('players')` |
| 90 | `.orderBy('lastSeenAt')` |
| 91 | `.limit(limit)` |
| 112 | `final player = await _firestore.collection('players').doc(playerId).get();` |
| 116 | `.collection('playerGameAccounts')` |
| 117 | `.where('playerId', isEqualTo: playerId)` |
| 120 | `.collection('characters')` |
| 121 | `.where('ownerPlayerId', isEqualTo: playerId)` |
| 147 | `.collection('gameAccounts')` |
| 148 | `.doc(gameAccountId)` |
| 179 | `.where(` |
| 198 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 201 | `.collection('authBindings')` |
| 202 | `.doc(authUid)` |
| 217 | `final snapshot = await _firestore.collection('players').get();` |
| 219 | `.where((document) => !document.data().containsKey('lastSeenAt'))` |
| 222 | `final batch = _firestore.batch();` |
| 225 | `batch.update(document.reference, {'lastSeenAt': null});` |
| 227 | `await batch.commit();` |
| 241 | `.collection('playerGameAccounts')` |
| 242 | `.where('playerId', whereIn: ids)` |
| 243 | `.where('status', isEqualTo: 'active')` |
| 261 | `.where((id) => id.isNotEmpty)` |
| 270 | `.collection('characters')` |
| 271 | `.where(FieldPath.documentId, whereIn: ids)` |
| 322 | `value is Timestamp ? value.toDate() : null;` |

### lib/features/player/data/datasources/firestore_player_binding_store.dart
근거: [lib/features/player/data/datasources/firestore_player_binding_store.dart](../../lib/features/player/data/datasources/firestore_player_binding_store.dart). 클래스: `FirestorePlayerBindingStore`.
메서드/선언(여러 줄 signature는 시작 행): L14 `Future<String> getOrCreateActivePlayerId({required String authUid}) {`; L48 `String _activePlayerId(Map<String, dynamic>? data) {`; L59 `void _requireActivePlayer(Map<String, dynamic>? data) {`.

| 행 | source 표현 |
|---|---|
| 11 | `final FirebaseFirestore _firestore;` |
| 15 | `final bindingRef = _firestore.collection('authBindings').doc(authUid);` |
| 17 | `return _firestore.runTransaction((transaction) async {` |
| 18 | `final binding = await transaction.get(bindingRef);` |
| 21 | `final player = await transaction.get(` |
| 22 | `_firestore.collection('players').doc(playerId),` |
| 28 | `final playerRef = _firestore.collection('players').doc();` |
| 29 | `final now = FieldValue.serverTimestamp();` |
| 30 | `transaction.set(playerRef, {` |
| 37 | `transaction.set(bindingRef, {` |

### lib/features/player/data/repositories/firestore_player_activity_repository.dart
근거: [lib/features/player/data/repositories/firestore_player_activity_repository.dart](../../lib/features/player/data/repositories/firestore_player_activity_repository.dart). 클래스: `FirestorePlayerActivityRepository`.
메서드/선언(여러 줄 signature는 시작 행): L11 `Future<void> recordAppLaunch({required String playerId}) {`.

| 행 | source 표현 |
|---|---|
| 8 | `final FirebaseFirestore _firestore;` |
| 12 | `return _firestore.collection('players').doc(playerId).update({` |
| 13 | `'lastSeenAt': FieldValue.serverTimestamp(),` |

### lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart
근거: [lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart](../../lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart). 클래스: `FirestorePartyEventReadRepository`.
메서드/선언(여러 줄 signature는 시작 행): L22 `Future<List<PartyEvent>> loadRecentEvents({`.

| 행 | source 표현 |
|---|---|
| 8 | `FirestorePartyEventReadRepository({required FirebaseFirestore firestore})` |
| 12 | `Timestamp timestamp => timestamp.toDate().toUtc(),` |
| 14 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |
| 18 | `final FirebaseFirestore _firestore;` |
| 34 | `.collection('partyEvents')` |
| 35 | `.where('audiencePlayerIds', arrayContains: playerId)` |
| 36 | `.orderBy('occurredAt', descending: true)` |
| 37 | `.limit(limit)` |
| 56 | `} on FirebaseException catch (error) {` |

### lib/features/raid_status/data/services/firestore_party_event_sync_service.dart
근거: [lib/features/raid_status/data/services/firestore_party_event_sync_service.dart](../../lib/features/raid_status/data/services/firestore_party_event_sync_service.dart). 클래스: `FirestorePartyEventSyncService`.
메서드/선언(여러 줄 signature는 시작 행): L31 `Future<PartyEventSyncResult> sync() async {`.

| 행 | source 표현 |
|---|---|
| 11 | `required FirebaseFirestore firestore,` |
| 12 | `required FirebaseAuth firebaseAuth,` |
| 19 | `Timestamp timestamp => timestamp.toDate().toUtc(),` |
| 21 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |
| 25 | `final FirebaseFirestore _firestore;` |
| 26 | `final FirebaseAuth _firebaseAuth;` |
| 32 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 39 | `final binding = await _firestore.collection('authBindings').doc(uid).get();` |
| 50 | `.collection('partyEvents')` |
| 51 | `.where('audiencePlayerIds', arrayContains: playerId)` |
| 52 | `.orderBy('occurredAt')` |
| 109 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/mappers/party_application_event_writer.dart
근거: [lib/features/recruitment_list/data/mappers/party_application_event_writer.dart](../../lib/features/recruitment_list/data/mappers/party_application_event_writer.dart). 클래스: `PartyApplicationEventWriter`.
메서드/선언(여러 줄 signature는 시작 행): L10 `static void write({`.

| 행 | source 표현 |
|---|---|
| 12 | `required FirebaseFirestore firestore,` |
| 46 | `final expiresAt = Timestamp.fromDate(` |
| 50 | `.collection('players')` |
| 51 | `.doc(recipientPlayerId)` |
| 52 | `.collection('events')` |
| 53 | `.doc(eventId);` |
| 54 | `transaction.set(` |

### lib/features/recruitment_list/data/mappers/party_create_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_create_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_create_write_plan.dart). 클래스: `PartyCreateWritePlan`.
메서드/선언(여러 줄 signature는 시작 행): L120 `static Map<String, Object?> _approvalPolicy(PartyCreateCommand command) => {`.

| 행 | source 표현 |
|---|---|
| 46 | `: Timestamp.fromDate(metadata.raidStartAt!.toUtc()),` |
| 57 | `'cycleStartedAt': Timestamp.fromDate(cycle.startedAt),` |
| 58 | `'cycleEndsAt': Timestamp.fromDate(cycle.endsAt),` |

### lib/features/recruitment_list/data/mappers/party_lifecycle_event_writer.dart
근거: [lib/features/recruitment_list/data/mappers/party_lifecycle_event_writer.dart](../../lib/features/recruitment_list/data/mappers/party_lifecycle_event_writer.dart). 클래스: `PartyLifecycleEventWriter`.
메서드/선언(여러 줄 signature는 시작 행): L10 `static void writeToRecipients({`; L46 `static void write({`.

| 행 | source 표현 |
|---|---|
| 12 | `required FirebaseFirestore firestore,` |
| 48 | `required FirebaseFirestore firestore,` |
| 74 | `final expiresAt = Timestamp.fromDate(` |
| 78 | `.collection('players')` |
| 79 | `.doc(recipientPlayerId)` |
| 80 | `.collection('events')` |
| 81 | `.doc(eventId);` |
| 82 | `transaction.set(` |

### lib/features/recruitment_list/data/mappers/party_membership_event_writer.dart
근거: [lib/features/recruitment_list/data/mappers/party_membership_event_writer.dart](../../lib/features/recruitment_list/data/mappers/party_membership_event_writer.dart). 클래스: `PartyMembershipEventWriter`.
메서드/선언(여러 줄 signature는 시작 행): L10 `static void writeToRecipients({`; L62 `static void write({`.

| 행 | source 표현 |
|---|---|
| 12 | `required FirebaseFirestore firestore,` |
| 64 | `required FirebaseFirestore firestore,` |
| 103 | `final expiresAt = Timestamp.fromDate(` |
| 107 | `.collection('players')` |
| 108 | `.doc(recipientPlayerId)` |
| 109 | `.collection('events')` |
| 110 | `.doc(eventId);` |
| 111 | `transaction.set(` |

### lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart
근거: [lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart](../../lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart). 클래스: `PartyRaidListingSyncPlan`, `PartyRaidListingTx`.
메서드/선언(여러 줄 signature는 시작 행): L75 `static Future<PartyRaidListingTx> read({`; L92 `void write({`.

| 행 | source 표현 |
|---|---|
| 60 | `required FirebaseFirestore firestore,` |
| 65 | `.collection('groups')` |
| 66 | `.doc(groupId)` |
| 67 | `.collection('raidListings')` |
| 68 | `.doc(recruitmentId),` |
| 77 | `required FirebaseFirestore firestore,` |
| 85 | `.collection('groups')` |
| 86 | `.doc(groupId)` |
| 87 | `.collection('raidListings')` |
| 88 | `.doc(recruitmentId);` |
| 89 | `return PartyRaidListingTx._(listingRef, await transaction.get(listingRef));` |
| 105 | `transaction.delete(listingRef);` |
| 111 | `transaction.set(listingRef, document);` |

### lib/features/recruitment_list/data/mappers/raid_state_availability.dart
근거: [lib/features/recruitment_list/data/mappers/raid_state_availability.dart](../../lib/features/recruitment_list/data/mappers/raid_state_availability.dart). 클래스: `RaidStateAvailability`.
메서드/선언(여러 줄 signature는 시작 행): L26 `static bool isStub(Map<String, dynamic>? data) {`.

| 행 | source 표현 |
|---|---|
| 57 | `start is Timestamp &&` |
| 58 | `end is Timestamp &&` |
| 60 | `data['guardCheckedAt'] is Timestamp;` |

### lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart
근거: [lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart](../../lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart). 클래스: `CompletedCleanupJournal`.
메서드/선언(여러 줄 signature는 시작 행): L16 `String _key(CompletedOwnershipCleanup request) =>`; L19 `Future<void> save(CompletedOwnershipCleanup request) =>`; L22 `Future<void> remove(CompletedOwnershipCleanup request) =>`; L25 `Future<void> run(`; L34 `Future<List<CompletedOwnershipCleanup>> pending(String actorId) async {`; L60 `static String encode(CompletedOwnershipCleanup r) => jsonEncode({`.

| 행 | source 표현 |
|---|---|
| 38 | `for (final entry in values.entries.where((e) => e.key.startsWith(prefix))) {` |
| 50 | `if (value is! Timestamp) {` |
| 56 | `static Timestamp? _restoreTime(dynamic value) => value == null` |
| 58 | `: Timestamp((value as List)[0] as int, value[1] as int);` |

### lib/features/recruitment_list/data/repositories/firestore_active_raid_assignment_lookup.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_active_raid_assignment_lookup.dart](../../lib/features/recruitment_list/data/repositories/firestore_active_raid_assignment_lookup.dart). 클래스: `FirestoreActiveRaidAssignmentLookup`.
메서드/선언(여러 줄 signature는 시작 행): L17 `Future<bool> blocksCandidate({`.

| 행 | source 표현 |
|---|---|
| 10 | `required FirebaseFirestore firestore,` |
| 13 | `final FirebaseFirestore _firestore;` |
| 22 | `}) => _firestore.runTransaction((transaction) async {` |
| 23 | `final character = await transaction.get(` |
| 24 | `_firestore.collection('characters').doc(characterId),` |

### lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart). 클래스: `FirestoreCompletedOwnershipCleanupRepository`.
메서드/선언(여러 줄 signature는 시작 행): L19 `Future<String> _actor(Transaction tx) async {`; L32 `Future<GameAccountOwnershipSnapshot> _authority(`; L48 `Future<CompletedOwnershipCleanup> _inspect(`; L199 `Future<CompletedOwnershipCleanup> inspect(String roomId, String targetId) =>`; L217 `Future<List<CompletedOwnershipCleanup>> pending(String actorId) =>`; L221 `Future<void> forget(CompletedOwnershipCleanup observation) =>`; L225 `Future<void> retry(CompletedOwnershipCleanup observation) async {`; L253 `Future<void> execute(CompletedOwnershipCleanup observation) =>`; L256 `Future<void> _execute(`.

| 행 | source 표현 |
|---|---|
| 15 | `final FirebaseFirestore firestore;` |
| 16 | `final FirebaseAuth auth;` |
| 22 | `final binding = (await tx.get(` |
| 23 | `firestore.collection('authBindings').doc(uid),` |
| 37 | `final data = (await tx.get(` |
| 38 | `firestore.collection('characters').doc(character),` |
| 64 | `final member = (await tx.get(` |
| 66 | `.collection('recruitments')` |
| 67 | `.doc(roomId)` |
| 68 | `.collection('members')` |
| 69 | `.doc(targetId),` |
| 150 | `final nextMember = (await tx.get(` |
| 152 | `.collection('recruitments')` |
| 153 | `.doc(roomId)` |
| 154 | `.collection('members')` |
| 155 | `.doc(successorId),` |
| 193 | `FieldValue.serverTimestamp(),` |
| 200 | `firestore.runTransaction((tx) async {` |
| 202 | `final room = (await tx.get(` |
| 203 | `firestore.collection('recruitments').doc(roomId),` |
| 212 | `firestore.collection('partyEvents').doc().id,` |
| 226 | `final actor = await firestore.runTransaction(_actor);` |
| 233 | `.collection('partyEvents')` |
| 234 | `.doc(observation.eventId)` |
| 235 | `.get(const GetOptions(source: Source.server)))` |
| 237 | `} on FirebaseException catch (error) {` |
| 258 | `) => firestore.runTransaction((tx) async {` |
| 263 | `final ref = firestore.collection('recruitments').doc(observation.roomId);` |
| 264 | `final room = (await tx.get(ref)).data();` |
| 267 | `final receipt = (await tx.get(` |
| 268 | `firestore.collection('partyEvents').doc(observation.eventId),` |
| 296 | `final now = FieldValue.serverTimestamp();` |
| 304 | `final groupRef = firestore.collection('groups').doc(groupId);` |
| 305 | `final group = (await tx.get(groupRef)).data();` |
| 312 | `tx.update(groupRef, {` |
| 318 | `tx.delete(groupRef.collection('raidListings').doc(observation.roomId));` |
| 320 | `tx.update(ref, patch);` |
| 321 | `tx.set(` |
| 322 | `firestore.collection('partyEvents').doc(observation.eventId),` |
| 327 | `tx.update(ref, patch);` |
| 328 | `tx.delete(ref.collection('members').doc(observation.targetId));` |
| 330 | `tx.update(ref.collection('members').doc(observation.successorId), {` |
| 336 | `tx.set(` |
| 338 | `.collection('groups')` |
| 339 | `.doc(room['groupId'] as String)` |
| 340 | `.collection('raidListings')` |
| 341 | `.doc(observation.roomId),` |
| 348 | `tx.set(` |
| 349 | `firestore.collection('partyEvents').doc(observation.eventId),` |

### lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart](../../lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart). 클래스: `FirestoreLazyCycleReconciliationGateway`.
메서드/선언(여러 줄 signature는 시작 행): L20 `Future<LazyCycleReconciliationResult> reconcile({`; L107 `Future<LazyCycleReconciliationResult> _resolveConcurrentOutcome({`.

| 행 | source 표현 |
|---|---|
| 11 | `required FirebaseFirestore firestore,` |
| 16 | `final FirebaseFirestore _firestore;` |
| 26 | `.collection('recruitments')` |
| 27 | `.doc(recruitmentId)` |
| 85 | `} on FirebaseException catch (error) {` |
| 112 | `.collection('recruitments')` |
| 113 | `.doc(recruitmentId)` |

### lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart). 클래스: `FirestorePartyApplicationCleanupRepository`.
메서드/선언(여러 줄 signature는 시작 행): L18 `Future<PartyApplicationCleanupResult> deleteOrphan({`.

| 행 | source 표현 |
|---|---|
| 9 | `required FirebaseFirestore firestore,` |
| 10 | `required FirebaseAuth firebaseAuth,` |
| 14 | `final FirebaseFirestore _firestore;` |
| 15 | `final FirebaseAuth _firebaseAuth;` |
| 27 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 34 | `final binding = await _firestore.collection('authBindings').doc(uid).get();` |
| 42 | `.collection('recruitments')` |
| 43 | `.doc(recruitmentId)` |
| 44 | `.collection('applications')` |
| 45 | `.doc(applicantPlayerId)` |
| 48 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart). 클래스: `FirestorePartyApplicationCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L24 `Future<PartyApplicationCommandResult> apply(PartyApplyCommand command) async {`; L217 `Future<PartyApplicationCommandResult> withdraw(`; L292 `Future<PartyApplicationCommandResult> _run(`.

| 행 | source 표현 |
|---|---|
| 15 | `required FirebaseFirestore firestore,` |
| 16 | `required FirebaseAuth firebaseAuth,` |
| 20 | `final FirebaseFirestore _firestore;` |
| 21 | `final FirebaseAuth _firebaseAuth;` |
| 30 | `.collection('recruitments')` |
| 31 | `.doc(command.recruitmentId);` |
| 33 | `.collection('characters')` |
| 34 | `.doc(command.characterId);` |
| 36 | `.collection('applications')` |
| 37 | `.doc(playerId);` |
| 38 | `final recruitment = await transaction.get(recruitmentRef);` |
| 39 | `final character = await transaction.get(characterRef);` |
| 40 | `final application = await transaction.get(applicationRef);` |
| 81 | `final claim = await transaction.get(` |
| 83 | `.collection('players')` |
| 84 | `.doc(playerId)` |
| 85 | `.collection('weeklyRaidClaims')` |
| 86 | `.doc(` |
| 131 | `final now = FieldValue.serverTimestamp();` |
| 135 | `transaction.set(` |
| 186 | `transaction.update(` |
| 225 | `.collection('recruitments')` |
| 226 | `.doc(command.recruitmentId);` |
| 227 | `final ref = recruitmentRef.collection('applications').doc(playerId);` |
| 228 | `final recruitment = await transaction.get(recruitmentRef);` |
| 229 | `final snapshot = await transaction.get(ref);` |
| 256 | `final now = FieldValue.serverTimestamp();` |
| 258 | `transaction.update(` |
| 295 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 302 | `return await _firestore.runTransaction((transaction) async {` |
| 303 | `final binding = await transaction.get(` |
| 304 | `_firestore.collection('authBindings').doc(uid),` |
| 317 | `} on FirebaseException catch (error) {` |
| 321 | `'PartyApplication apply/withdraw FirebaseException: '` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart). 클래스: `FirestorePartyAtomicApplicationCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L34 `Future<PartyApplicationCommandResult> apply(PartyApplyCommand command) async {`; L48 `Future<PartyApplicationCommandResult> _applyOnce(`; L274 `Future<PartyApplicationCommandResult> withdraw(`; L335 `Future<PartyApplicationCommandResult> _run(`.

| 행 | source 표현 |
|---|---|
| 22 | `required FirebaseFirestore firestore,` |
| 23 | `required FirebaseAuth firebaseAuth,` |
| 28 | `final FirebaseFirestore _firestore;` |
| 29 | `final FirebaseAuth _firebaseAuth;` |
| 52 | `.collection('recruitments')` |
| 53 | `.doc(command.recruitmentId);` |
| 55 | `.collection('characters')` |
| 56 | `.doc(command.characterId);` |
| 58 | `.collection('applications')` |
| 59 | `.doc(playerId);` |
| 60 | `final recruitment = await transaction.get(recruitmentRef);` |
| 61 | `final character = await transaction.get(characterRef);` |
| 62 | `final application = await transaction.get(applicationRef);` |
| 144 | `transaction.delete(occupancy.stateRef);` |
| 188 | `final groupMember = await transaction.get(` |
| 190 | `.collection('groups')` |
| 191 | `.doc(groupId)` |
| 192 | `.collection('members')` |
| 193 | `.doc(playerId),` |
| 198 | `final now = FieldValue.serverTimestamp();` |
| 216 | `transaction.set(applicationRef, plan.application);` |
| 217 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 218 | `transaction.set(` |
| 220 | `.collection('partyEvents')` |
| 221 | `.doc(plan.event['eventId']! as String),` |
| 262 | `transaction.update(applicationRef, plan.application);` |
| 263 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 264 | `transaction.set(` |
| 266 | `.collection('partyEvents')` |
| 267 | `.doc(plan.event['eventId']! as String),` |
| 283 | `.collection('recruitments')` |
| 284 | `.doc(command.recruitmentId);` |
| 286 | `.collection('applications')` |
| 287 | `.doc(playerId);` |
| 288 | `final recruitment = await transaction.get(recruitmentRef);` |
| 289 | `final application = await transaction.get(applicationRef);` |
| 310 | `final now = FieldValue.serverTimestamp();` |
| 317 | `transaction.update(` |
| 324 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 325 | `transaction.set(` |
| 327 | `.collection('partyEvents')` |
| 328 | `.doc(plan.event['eventId']! as String),` |
| 338 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 345 | `return await _firestore.runTransaction((transaction) async {` |
| 346 | `final binding = await transaction.get(` |
| 347 | `_firestore.collection('authBindings').doc(uid),` |
| 360 | `} on FirebaseException catch (error) {` |
| 364 | `'PartyAtomicApplication FirebaseException: ${error.code} ${error.message}',` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart). 클래스: `FirestorePartyAtomicCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L23 `Future<PartyAtomicCommandResult> execute(PartyCommandEnvelope command) async {`; L238 `Future<PartyCommandAggregate?> findAggregate(String recruitmentId) async {`; L257 `Future<PartyAtomicCommandResult?> _certifyAdvance(`.

| 행 | source 표현 |
|---|---|
| 14 | `required FirebaseFirestore firestore,` |
| 15 | `required FirebaseAuth firebaseAuth,` |
| 19 | `final FirebaseFirestore _firestore;` |
| 20 | `final FirebaseAuth _firebaseAuth;` |
| 38 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 50 | `final result = await _firestore.runTransaction((transaction) async {` |
| 53 | `final binding = await transaction.get(` |
| 54 | `_firestore.collection('authBindings').doc(uid),` |
| 72 | `.collection('recruitments')` |
| 73 | `.doc(command.recruitmentId);` |
| 75 | `final recruitmentSnapshot = await transaction.get(recruitmentRef);` |
| 108 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 109 | `incrementOne: FieldValue.increment(1),` |
| 120 | `.collection('players')` |
| 121 | `.doc(target.playerId)` |
| 122 | `.collection('raidStates')` |
| 123 | `.doc(target.raidStateId);` |
| 131 | `recruitmentPatch['cycleStartedAt'] = Timestamp.fromDate(` |
| 134 | `recruitmentPatch['cycleEndsAt'] = Timestamp.fromDate(` |
| 141 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 142 | `final group = await transaction.get(groupRef);` |
| 151 | `transaction.update(groupRef, {` |
| 154 | `'revision': FieldValue.increment(1),` |
| 155 | `'updatedAt': FieldValue.serverTimestamp(),` |
| 159 | `.collection('groups')` |
| 160 | `.doc(groupId)` |
| 161 | `.collection('raidListings')` |
| 162 | `.doc(command.recruitmentId);` |
| 164 | `transaction.delete(listingRef);` |
| 167 | `transaction.set(` |
| 181 | `transaction.update(recruitmentRef, recruitmentPatch);` |
| 185 | `transaction.delete(ref);` |
| 187 | `transaction.set(ref, {` |
| 189 | `if (write.removeCompletedAt) 'completedAt': FieldValue.delete(),` |
| 190 | `}, SetOptions(merge: true));` |
| 192 | `transaction.update(ref, write.patch!);` |
| 195 | `transaction.set(` |
| 196 | `_firestore.collection('partyEvents').doc(command.commandId),` |
| 209 | `} on FirebaseException catch (error, stackTrace) {` |
| 242 | `(await _firestore.collection('recruitments').doc(recruitmentId).get())` |
| 248 | `} on FirebaseException {` |
| 264 | `final rejected = await _firestore.runTransaction<PartyAtomicCommandResult?>((` |
| 267 | `final binding = (await tx.get(` |
| 268 | `_firestore.collection('authBindings').doc(uid),` |
| 276 | `final raw = (await tx.get(` |
| 277 | `_firestore.collection('recruitments').doc(command.recruitmentId),` |
| 303 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 304 | `incrementOne: FieldValue.increment(1),` |
| 311 | `tx.set(` |
| 313 | `.collection('players')` |
| 314 | `.doc(slot.playerId)` |
| 315 | `.collection('raidStates')` |
| 316 | `.doc(stateId),` |
| 326 | `'guardCycleStartedAt': Timestamp.fromDate(` |
| 329 | `'guardCycleEndsAt': Timestamp.fromDate(` |
| 333 | `'guardCheckedAt': FieldValue.serverTimestamp(),` |
| 335 | `SetOptions(merge: true),` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart). 클래스: `FirestorePartyAtomicCreateRepository`.
메서드/선언(여러 줄 signature는 시작 행): L32 `Future<PartyCreateResult> create(PartyCreateCommand command) async {`.

| 행 | source 표현 |
|---|---|
| 21 | `required FirebaseFirestore firestore,` |
| 22 | `required FirebaseAuth firebaseAuth,` |
| 27 | `final FirebaseFirestore _firestore;` |
| 28 | `final FirebaseAuth _firebaseAuth;` |
| 39 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 50 | `final result = await _firestore.runTransaction<PartyCreateResult?>((` |
| 53 | `final binding = await transaction.get(` |
| 54 | `_firestore.collection('authBindings').doc(authUid),` |
| 67 | `.collection('characters')` |
| 68 | `.doc(command.leaderCharacterId);` |
| 70 | `.collection('recruitments')` |
| 71 | `.doc(command.recruitmentId);` |
| 77 | `.collection('players')` |
| 78 | `.doc(playerId)` |
| 79 | `.collection('raidStates')` |
| 80 | `.doc(raidStateId);` |
| 82 | `final character = await transaction.get(characterRef);` |
| 83 | `final recruitment = await transaction.get(recruitmentRef);` |
| 84 | `final raidState = await transaction.get(raidStateRef);` |
| 138 | `assignedRecruitment = await transaction.get(` |
| 139 | `_firestore.collection('recruitments').doc(raidStateRecruitmentId),` |
| 164 | `as Timestamp?)` |
| 174 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 175 | `group = await transaction.get(groupRef);` |
| 176 | `membership = await transaction.get(` |
| 177 | `groupRef.collection('members').doc(playerId),` |
| 225 | `(assignedRecruitment?.data()?['cycleEndsAt'] as Timestamp?)` |
| 270 | `final now = FieldValue.serverTimestamp();` |
| 299 | `final claim = await transaction.get(` |
| 301 | `.collection('players')` |
| 302 | `.doc(playerId)` |
| 303 | `.collection('weeklyRaidClaims')` |
| 304 | `.doc(claimId),` |
| 331 | `transaction.delete(raidStateRef);` |
| 337 | `transaction.delete(raidStateRef);` |
| 341 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 355 | `transaction.update(groupRef, groupPlan.groupPatch);` |
| 358 | `transaction.set(` |
| 359 | `groupRef.collection('raidListings').doc(command.recruitmentId),` |
| 365 | `transaction.set(recruitmentRef, plan.recruitment);` |
| 366 | `transaction.set(` |
| 367 | `recruitmentRef.collection('members').doc(playerId),` |
| 370 | `transaction.set(raidStateRef, plan.raidState);` |
| 371 | `transaction.set(` |
| 373 | `.collection('partyEvents')` |
| 374 | `.doc(plan.event['eventId']! as String),` |
| 384 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart). 클래스: `FirestorePartyAtomicJoinCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L42 `Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command) async {`; L68 `Future<PartyJoinResult> approve(PartyDecideApplicationCommand command) async {`; L81 `Future<PartyJoinResult> reject(PartyDecideApplicationCommand command) async {`; L139 `Future<PartyJoinResult> _join({`; L491 `Future<PartyJoinResult> _run(`; L541 `Future<bool> _canApprove(`.

| 행 | source 표현 |
|---|---|
| 30 | `required FirebaseFirestore firestore,` |
| 31 | `required FirebaseAuth firebaseAuth,` |
| 36 | `final FirebaseFirestore _firestore;` |
| 37 | `final FirebaseAuth _firebaseAuth;` |
| 86 | `.collection('recruitments')` |
| 87 | `.doc(command.recruitmentId);` |
| 89 | `.collection('applications')` |
| 90 | `.doc(command.applicantPlayerId);` |
| 91 | `final recruitment = await transaction.get(recruitmentRef);` |
| 92 | `final application = await transaction.get(applicationRef);` |
| 118 | `final now = FieldValue.serverTimestamp();` |
| 127 | `transaction.update(applicationRef, plan.applicationPatch);` |
| 128 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 129 | `transaction.set(` |
| 131 | `.collection('partyEvents')` |
| 132 | `.doc(plan.event['eventId']! as String),` |
| 154 | `.collection('recruitments')` |
| 155 | `.doc(recruitmentId);` |
| 156 | `final recruitment = await transaction.get(recruitmentRef);` |
| 199 | `.collection('applications')` |
| 200 | `.doc(playerId);` |
| 201 | `final application = await transaction.get(applicationRef);` |
| 252 | `final characterRef = _firestore.collection('characters').doc(characterId);` |
| 254 | `.collection('players')` |
| 255 | `.doc(playerId)` |
| 256 | `.collection('raidStates')` |
| 257 | `.doc(` |
| 263 | `final character = await transaction.get(characterRef);` |
| 323 | `transaction.delete(occupancy.stateRef);` |
| 363 | `final groupMember = await transaction.get(` |
| 365 | `.collection('groups')` |
| 366 | `.doc(groupId)` |
| 367 | `.collection('members')` |
| 368 | `.doc(playerId),` |
| 397 | `final now = FieldValue.serverTimestamp();` |
| 449 | `transaction.update(recruitmentRef, approvalPlan.recruitmentPatch);` |
| 450 | `transaction.update(applicationRef, approvalPlan.applicationPatch);` |
| 451 | `transaction.set(` |
| 452 | `recruitmentRef.collection('members').doc(playerId),` |
| 455 | `transaction.set(raidStateRef, approvalPlan.raidState);` |
| 461 | `transaction.set(` |
| 463 | `.collection('partyEvents')` |
| 464 | `.doc(approvalPlan.event['eventId']! as String),` |
| 470 | `transaction.update(recruitmentRef, joinPlan.recruitmentPatch);` |
| 471 | `transaction.set(` |
| 472 | `recruitmentRef.collection('members').doc(playerId),` |
| 475 | `transaction.set(raidStateRef, joinPlan.raidState);` |
| 481 | `transaction.set(` |
| 483 | `.collection('partyEvents')` |
| 484 | `.doc(joinPlan.event['eventId']! as String),` |
| 494 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 499 | `return await _firestore.runTransaction((transaction) async {` |
| 500 | `final binding = await transaction.get(` |
| 501 | `_firestore.collection('authBindings').doc(uid),` |
| 514 | `} on FirebaseException catch (error, stack) {` |
| 517 | `'PartyAtomicJoin FirebaseException code=${error.code} message=${error.message}',` |
| 548 | `final member = await transaction.get(` |
| 550 | `.collection('recruitments')` |
| 551 | `.doc(recruitmentId)` |
| 552 | `.collection('members')` |
| 553 | `.doc(playerId),` |
| 588 | `if (value is Timestamp) return value.toDate();` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart). 클래스: `FirestorePartyAtomicMemberMutationRepository`.
메서드/선언(여러 줄 signature는 시작 행): L40 `Future<PartyMembershipResult> changeCharacter(`; L377 `Future<PartyMembershipResult> repositionMembers(`; L458 `Future<PartyMembershipResult> _run(`.

| 행 | source 표현 |
|---|---|
| 28 | `required FirebaseFirestore firestore,` |
| 29 | `required FirebaseAuth firebaseAuth,` |
| 34 | `final FirebaseFirestore _firestore;` |
| 35 | `final FirebaseAuth _firebaseAuth;` |
| 51 | `.collection('recruitments')` |
| 52 | `.doc(command.recruitmentId);` |
| 53 | `final memberRef = recruitmentRef.collection('members').doc(playerId);` |
| 54 | `final recruitment = await transaction.get(recruitmentRef);` |
| 55 | `final member = await transaction.get(memberRef);` |
| 107 | `.collection('characters')` |
| 108 | `.doc(command.newCharacterId);` |
| 110 | `.collection('players')` |
| 111 | `.doc(playerId)` |
| 112 | `.collection('raidStates')` |
| 113 | `.doc(` |
| 119 | `final character = await transaction.get(characterRef);` |
| 120 | `final previousCharacter = await transaction.get(` |
| 121 | `_firestore.collection('characters').doc(oldCharacterId),` |
| 153 | `final previousRaidState = await transaction.get(previousRaidStateRef);` |
| 256 | `final groupMember = await transaction.get(` |
| 258 | `.collection('groups')` |
| 259 | `.doc(aggregate.groupId!)` |
| 260 | `.collection('members')` |
| 261 | `.doc(playerId),` |
| 287 | `final now = FieldValue.serverTimestamp();` |
| 313 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 314 | `transaction.update(memberRef, plan.membershipPatch);` |
| 320 | `transaction.set(` |
| 322 | `.collection('partyEvents')` |
| 323 | `.doc(plan.event['eventId']! as String),` |
| 348 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 349 | `transaction.update(memberRef, plan.membershipPatch);` |
| 350 | `transaction.delete(previousRaidStateRef);` |
| 360 | `transaction.set(nextRaidStateRef, plan.nextRaidState);` |
| 366 | `transaction.set(` |
| 368 | `.collection('partyEvents')` |
| 369 | `.doc(plan.event['eventId']! as String),` |
| 386 | `.collection('recruitments')` |
| 387 | `.doc(command.recruitmentId);` |
| 388 | `final recruitment = await transaction.get(recruitmentRef);` |
| 417 | `final now = FieldValue.serverTimestamp();` |
| 428 | `final memberRef = recruitmentRef.collection('members').doc(entry.key);` |
| 429 | `final member = await transaction.get(memberRef);` |
| 436 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 438 | `transaction.update(` |
| 439 | `recruitmentRef.collection('members').doc(entry.key),` |
| 448 | `transaction.set(` |
| 450 | `.collection('partyEvents')` |
| 451 | `.doc(plan.event['eventId']! as String),` |
| 463 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 470 | `final result = await _firestore.runTransaction((transaction) async {` |
| 477 | `final binding = await transaction.get(` |
| 478 | `_firestore.collection('authBindings').doc(uid),` |
| 497 | `} on FirebaseException catch (error, stackTrace) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart). 클래스: `FirestorePartyAtomicMemberRemovalRepository`.
메서드/선언(여러 줄 signature는 시작 행): L28 `Future<PartyMembershipResult> remove(`.

| 행 | source 표현 |
|---|---|
| 19 | `required FirebaseFirestore firestore,` |
| 20 | `required FirebaseAuth firebaseAuth,` |
| 24 | `final FirebaseFirestore _firestore;` |
| 25 | `final FirebaseAuth _firebaseAuth;` |
| 32 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 39 | `return await _firestore.runTransaction((transaction) async {` |
| 40 | `final binding = await transaction.get(` |
| 41 | `_firestore.collection('authBindings').doc(uid),` |
| 54 | `.collection('recruitments')` |
| 55 | `.doc(command.recruitmentId);` |
| 56 | `final recruitment = await transaction.get(recruitmentRef);` |
| 73 | `.where((slot) => slot.playerId == command.targetPlayerId)` |
| 81 | `.collection('members')` |
| 82 | `.doc(command.targetPlayerId);` |
| 83 | `final targetMembership = await transaction.get(targetMembershipRef);` |
| 95 | `.where((slot) => slot.playerId != command.targetPlayerId)` |
| 98 | `.collection('members')` |
| 99 | `.doc(successor.playerId);` |
| 100 | `final snapshot = await transaction.get(successorMembershipRef);` |
| 127 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 128 | `final actorGroupMember = await transaction.get(` |
| 129 | `groupRef.collection('members').doc(actorPlayerId),` |
| 131 | `final targetGroupMember = await transaction.get(` |
| 132 | `groupRef.collection('members').doc(command.targetPlayerId),` |
| 145 | `.collection('players')` |
| 146 | `.doc(command.targetPlayerId)` |
| 147 | `.collection('raidStates')` |
| 148 | `.doc(` |
| 157 | `final raidState = await transaction.get(raidStateRef);` |
| 167 | `final now = FieldValue.serverTimestamp();` |
| 179 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 180 | `transaction.delete(targetMembershipRef);` |
| 181 | `transaction.delete(raidStateRef);` |
| 184 | `transaction.update(` |
| 190 | `transaction.set(` |
| 192 | `.collection('groups')` |
| 193 | `.doc(aggregate.groupId!)` |
| 194 | `.collection('raidListings')` |
| 195 | `.doc(command.recruitmentId),` |
| 202 | `transaction.set(` |
| 204 | `.collection('partyEvents')` |
| 205 | `.doc(plan.event['eventId']! as String),` |
| 210 | `} on FirebaseException catch (error, stackTrace) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart). 클래스: `FirestorePartyAtomicVisibilityCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L27 `Future<PartyVisibilityResult> setVisibility(`.

| 행 | source 표현 |
|---|---|
| 18 | `required FirebaseFirestore firestore,` |
| 19 | `required FirebaseAuth firebaseAuth,` |
| 23 | `final FirebaseFirestore _firestore;` |
| 24 | `final FirebaseAuth _firebaseAuth;` |
| 33 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 41 | `return await _firestore.runTransaction((transaction) async {` |
| 42 | `final binding = await transaction.get(` |
| 43 | `_firestore.collection('authBindings').doc(uid),` |
| 56 | `.collection('recruitments')` |
| 57 | `.doc(command.recruitmentId);` |
| 58 | `final recruitment = await transaction.get(recruitmentRef);` |
| 105 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 106 | `final group = await transaction.get(groupRef);` |
| 113 | `final leaderMember = await transaction.get(` |
| 114 | `groupRef.collection('members').doc(playerId),` |
| 132 | `final now = FieldValue.serverTimestamp();` |
| 141 | `.collection('raidListings')` |
| 142 | `.doc(command.recruitmentId);` |
| 143 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 144 | `transaction.update(groupRef, plan.groupPatch);` |
| 146 | `transaction.delete(listingRef);` |
| 148 | `transaction.set(` |
| 158 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart). 클래스: `FirestorePartyCreateRepository`.
메서드/선언(여러 줄 signature는 시작 행): L24 `Future<PartyCreateResult> create(PartyCreateCommand command) async {`.

| 행 | source 표현 |
|---|---|
| 13 | `required FirebaseFirestore firestore,` |
| 14 | `required FirebaseAuth firebaseAuth,` |
| 19 | `final FirebaseFirestore _firestore;` |
| 20 | `final FirebaseAuth _firebaseAuth;` |
| 29 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 37 | `return await _firestore.runTransaction((transaction) async {` |
| 38 | `final bindingRef = _firestore.collection('authBindings').doc(authUid);` |
| 39 | `final binding = await transaction.get(bindingRef);` |
| 51 | `.collection('characters')` |
| 52 | `.doc(command.leaderCharacterId);` |
| 54 | `.collection('recruitments')` |
| 55 | `.doc(command.recruitmentId);` |
| 57 | `.collection('players')` |
| 58 | `.doc(playerId)` |
| 59 | `.collection('activeRaidAssignments')` |
| 60 | `.doc('${command.leaderCharacterId}_${command.metadata.raidId}');` |
| 62 | `.collection('players')` |
| 63 | `.doc(playerId)` |
| 64 | `.collection('weeklyRaidClaims')` |
| 65 | `.doc(` |
| 73 | `final character = await transaction.get(characterRef);` |
| 74 | `final recruitment = await transaction.get(recruitmentRef);` |
| 75 | `final assignment = await transaction.get(assignmentRef);` |
| 76 | `final claim = await transaction.get(claimRef);` |
| 85 | `assignedRecruitment = await transaction.get(` |
| 86 | `_firestore.collection('recruitments').doc(assignmentRecruitmentId),` |
| 94 | `final groupRef = _firestore.collection('groups').doc(groupId);` |
| 95 | `final membershipRef = groupRef.collection('members').doc(playerId);` |
| 96 | `group = await transaction.get(groupRef);` |
| 97 | `membership = await transaction.get(membershipRef);` |
| 136 | `(assignedRecruitment?.data()?['cycleEndsAt'] as Timestamp?)` |
| 186 | `final now = FieldValue.serverTimestamp();` |
| 195 | `final memberRef = recruitmentRef.collection('members').doc(playerId);` |
| 196 | `transaction.set(recruitmentRef, plan.recruitment);` |
| 197 | `transaction.set(memberRef, plan.leaderMembership);` |
| 198 | `transaction.set(recruitmentRef.collection('slots').doc('0_0'), {` |
| 205 | `transaction.delete(assignmentRef);` |
| 207 | `transaction.set(assignmentRef, plan.assignment);` |
| 210 | `transaction.set(` |
| 212 | `.collection('groups')` |
| 213 | `.doc(groupId)` |
| 214 | `.collection('raidListings')` |
| 215 | `.doc(command.recruitmentId),` |
| 221 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart). 클래스: `FirestorePartyCycleCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L31 `Future<PartyCycleResult> complete(PartyCompleteCycleCommand command) async {`; L259 `Future<PartyCycleResult> setRecurrence(`; L311 `Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command) async {`; L500 `Future<PartyCycleResult> disband(PartyDisbandCommand command) async {`; L669 `Future<PartyCycleResult> purgeStaleOwnAssignment(`; L765 `Future<List<Map<String, Object?>>?> _memberSnapshot(`; L789 `void _writeEvents(`; L833 `Future<QuerySnapshot<Map<String, dynamic>>?> _loadMembers(String id) async {`; L841 `Future<QuerySnapshot<Map<String, dynamic>>?> _loadApplications(`; L860 `Future<PartyCycleResult> _run(`; L898 `Map<String, dynamic>? data,`; L899 `String cycleKey,`.

| 행 | source 표현 |
|---|---|
| 20 | `required FirebaseFirestore firestore,` |
| 21 | `required FirebaseAuth firebaseAuth,` |
| 26 | `final FirebaseFirestore _firestore;` |
| 27 | `final FirebaseAuth _firebaseAuth;` |
| 44 | `.collection('cycles')` |
| 45 | `.doc(command.cycleKey);` |
| 46 | `final recruitment = await transaction.get(recruitmentRef);` |
| 47 | `final cycle = await transaction.get(cycleRef);` |
| 94 | `if (cycleStartedAt is! Timestamp \|\| cycleEndsAt is! Timestamp) {` |
| 129 | `snap: await transaction.get(` |
| 135 | `snap: await transaction.get(` |
| 156 | `await transaction.get(` |
| 172 | `final now = FieldValue.serverTimestamp();` |
| 174 | `transaction.update(` |
| 184 | `transaction.set(` |
| 210 | `transaction.update(recruitmentRef, completePatch);` |
| 224 | `transaction.delete(orphan.reference);` |
| 233 | `transaction.set(` |
| 251 | `transaction.delete(assignment.ref);` |
| 268 | `final recruitment = await transaction.get(ref);` |
| 298 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 300 | `transaction.update(ref, recurrencePatch);` |
| 322 | `.collection('cycles')` |
| 323 | `.doc(command.expectedCycleKey);` |
| 324 | `final recruitment = await transaction.get(recruitmentRef);` |
| 325 | `final cycle = await transaction.get(cycleRef);` |
| 379 | `final assignment = await transaction.get(ref);` |
| 408 | `final now = FieldValue.serverTimestamp();` |
| 410 | `transaction.set(` |
| 429 | `transaction.update(` |
| 456 | `timestamp: (date) => Timestamp.fromDate(date),` |
| 458 | `transaction.update(recruitmentRef, advancePatch);` |
| 468 | `transaction.set(` |
| 482 | `transaction.update(assignment.ref, {` |
| 488 | `transaction.delete(assignment.ref);` |
| 517 | `final recruitment = await transaction.get(recruitmentRef);` |
| 547 | `memberSnapshots.add(await transaction.get(member.reference));` |
| 551 | `applicationSnapshots.add(await transaction.get(application.reference));` |
| 568 | `.collection('players')` |
| 569 | `.doc(current.id)` |
| 570 | `.collection('activeRaidAssignments')` |
| 571 | `.doc('${characterId}_$raidId'),` |
| 578 | `assignmentSnapshots.add(await transaction.get(assignmentRef));` |
| 592 | `final slot = await transaction.get(` |
| 593 | `recruitmentRef.collection('slots').doc('${partyIndex}_$slotIndex'),` |
| 622 | `final now = FieldValue.serverTimestamp();` |
| 626 | `transaction.delete(current.reference);` |
| 630 | `transaction.delete(assignment.reference);` |
| 634 | `transaction.delete(slot.reference);` |
| 640 | `transaction.update(recruitmentRef, disbandPatch);` |
| 677 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 682 | `.collection('authBindings')` |
| 683 | `.doc(authUid)` |
| 726 | `} on FirebaseException catch (error) {` |
| 744 | `.collection('players')` |
| 745 | `.doc(playerId)` |
| 746 | `.collection('weeklyRaidClaims')` |
| 747 | `.doc(` |
| 760 | `.collection('players')` |
| 761 | `.doc(playerId)` |
| 762 | `.collection('activeRaidAssignments')` |
| 763 | `.doc('${characterId}_$raidId');` |
| 771 | `final current = await transaction.get(member.reference);` |
| 798 | `final expiresAt = Timestamp.fromDate(` |
| 810 | `.collection('players')` |
| 811 | `.doc(playerId)` |
| 812 | `.collection('events')` |
| 813 | `.doc(eventId);` |
| 814 | `transaction.set(` |
| 835 | `return await _recruitment(id).collection('members').get();` |
| 836 | `} on FirebaseException {` |
| 845 | `return await _recruitment(id).collection('applications').get();` |
| 846 | `} on FirebaseException {` |
| 852 | `_firestore.collection('recruitments').doc(id);` |
| 863 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 867 | `return await _firestore.runTransaction((transaction) async {` |
| 868 | `final binding = await transaction.get(` |
| 869 | `_firestore.collection('authBindings').doc(uid),` |
| 882 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart). 클래스: `FirestorePartyJoinCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L31 `Future<PartyJoinResult> joinDirectly(PartyDirectJoinCommand command) async {`; L51 `Future<PartyJoinResult> approve(PartyDecideApplicationCommand command) async {`; L64 `Future<PartyJoinResult> reject(PartyDecideApplicationCommand command) async {`; L135 `Future<PartyJoinResult> _join({`; L481 `Future<PartyJoinResult> _run(`; L509 `Future<bool> _canApprove(`.

| 행 | source 표현 |
|---|---|
| 22 | `required FirebaseFirestore firestore,` |
| 23 | `required FirebaseAuth firebaseAuth,` |
| 27 | `final FirebaseFirestore _firestore;` |
| 28 | `final FirebaseAuth _firebaseAuth;` |
| 69 | `.collection('recruitments')` |
| 70 | `.doc(command.recruitmentId);` |
| 72 | `.collection('applications')` |
| 73 | `.doc(command.applicantPlayerId);` |
| 74 | `final recruitment = await transaction.get(recruitmentRef);` |
| 75 | `final application = await transaction.get(applicationRef);` |
| 94 | `final now = FieldValue.serverTimestamp();` |
| 101 | `transaction.update(applicationRef, {` |
| 148 | `if (_firebaseAuth.currentUser == null) {` |
| 152 | `.collection('recruitments')` |
| 153 | `.doc(recruitmentId);` |
| 156 | `knownMembers = await recruitmentRef.collection('members').get();` |
| 157 | `} on FirebaseException catch (error) {` |
| 161 | `final recruitment = await transaction.get(recruitmentRef);` |
| 188 | `.collection('applications')` |
| 189 | `.doc(playerId);` |
| 190 | `final application = await transaction.get(applicationRef);` |
| 228 | `final characterRef = _firestore.collection('characters').doc(characterId);` |
| 230 | `.collection('players')` |
| 231 | `.doc(playerId)` |
| 232 | `.collection('activeRaidAssignments')` |
| 233 | `.doc('${characterId}_${r?['raidId']}');` |
| 234 | `final character = await transaction.get(characterRef);` |
| 235 | `final assignment = await transaction.get(assignmentRef);` |
| 243 | `assignedRecruitment = await transaction.get(` |
| 244 | `_firestore.collection('recruitments').doc(assignmentRecruitmentId),` |
| 253 | `claim = await transaction.get(` |
| 255 | `.collection('players')` |
| 256 | `.doc(playerId)` |
| 257 | `.collection('weeklyRaidClaims')` |
| 258 | `.doc(` |
| 314 | `final current = await transaction.get(known.reference);` |
| 375 | `final now = FieldValue.serverTimestamp();` |
| 400 | `final memberRef = recruitmentRef.collection('members').doc(playerId);` |
| 401 | `transaction.update(recruitmentRef, plan.recruitmentUpdate);` |
| 407 | `transaction.set(memberRef, plan.membership);` |
| 409 | `transaction.set(` |
| 410 | `recruitmentRef.collection('slots').doc(placement.slot!.documentId),` |
| 419 | `transaction.set(assignmentRef, plan.assignment);` |
| 451 | `transaction.update(applicationRef, {` |
| 484 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 488 | `return await _firestore.runTransaction((transaction) async {` |
| 489 | `final binding = await transaction.get(` |
| 490 | `_firestore.collection('authBindings').doc(uid),` |
| 502 | `} on FirebaseException catch (error) {` |
| 516 | `final member = await transaction.get(` |
| 518 | `.collection('recruitments')` |
| 519 | `.doc(recruitmentId)` |
| 520 | `.collection('members')` |
| 521 | `.doc(playerId),` |
| 555 | `if (value is Timestamp) return value.toDate();` |
| 561 | `if (value is Timestamp) return value.toDate();` |

### lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart). 클래스: `FirestorePartyMembershipCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L26 `Future<PartyMembershipResult> changeCharacter(`; L311 `Future<PartyMembershipResult> leave(PartyRemoveMemberCommand command) async {`; L320 `Future<PartyMembershipResult> kick(PartyRemoveMemberCommand command) async {`; L329 `Future<PartyMembershipResult> removeLostGroupQualification(`; L339 `Future<PartyMembershipResult> _remove(`; L546 `Future<PartyMembershipResult> setApprovalPermission(`; L591 `Future<PartyMembershipResult> repositionMembers(`; L837 `Future<QuerySnapshot<Map<String, dynamic>>?> _members(`; L852 `Future<PartyReplacementPlan?> _replacementPlan(`; L908 `Future<PartyMembershipResult> _run(`; L952 `Map<String, dynamic>? data,`.

| 행 | source 표현 |
|---|---|
| 18 | `required FirebaseFirestore firestore,` |
| 19 | `required FirebaseAuth firebaseAuth,` |
| 22 | `final FirebaseFirestore _firestore;` |
| 23 | `final FirebaseAuth _firebaseAuth;` |
| 33 | `if (_firebaseAuth.currentUser == null)` |
| 44 | `.collection('recruitments')` |
| 45 | `.doc(command.recruitmentId);` |
| 46 | `final memberRef = recruitmentRef.collection('members').doc(playerId);` |
| 47 | `final recruitment = await transaction.get(recruitmentRef);` |
| 48 | `final member = await transaction.get(memberRef);` |
| 73 | `.collection('characters')` |
| 74 | `.doc(command.newCharacterId);` |
| 85 | `final character = await transaction.get(characterRef);` |
| 86 | `final oldAssignment = await transaction.get(oldAssignmentRef);` |
| 87 | `final newAssignment = await transaction.get(newAssignmentRef);` |
| 90 | `: await transaction.get(` |
| 92 | `.collection('players')` |
| 93 | `.doc(playerId)` |
| 94 | `.collection('weeklyRaidClaims')` |
| 95 | `.doc(` |
| 178 | `final now = FieldValue.serverTimestamp();` |
| 199 | `transaction.update(` |
| 216 | `transaction.delete(` |
| 218 | `.collection('slots')` |
| 219 | `.doc('${oldPartyIndex as int}_${oldSlotIndex as int}'),` |
| 221 | `transaction.set(` |
| 222 | `recruitmentRef.collection('slots').doc(destination.documentId),` |
| 233 | `transaction.delete(oldAssignmentRef);` |
| 236 | `transaction.update(oldAssignmentRef, {` |
| 241 | `transaction.delete(oldAssignmentRef);` |
| 242 | `transaction.set(newAssignmentRef, {` |
| 259 | `transaction.update(recruitmentRef, patch);` |
| 272 | `transaction.update(recruitmentRef, patch);` |
| 345 | `.collection('recruitments')` |
| 346 | `.doc(command.recruitmentId);` |
| 348 | `.collection('members')` |
| 349 | `.doc(command.targetPlayerId);` |
| 350 | `final recruitment = await transaction.get(recruitmentRef);` |
| 351 | `final target = await transaction.get(targetRef);` |
| 374 | `final actorRaidMember = await transaction.get(` |
| 375 | `recruitmentRef.collection('members').doc(actorPlayerId),` |
| 377 | `final actorGroupMember = await transaction.get(` |
| 379 | `.collection('groups')` |
| 380 | `.doc(groupId)` |
| 381 | `.collection('members')` |
| 382 | `.doc(actorPlayerId),` |
| 384 | `final targetGroupMember = await transaction.get(` |
| 386 | `.collection('groups')` |
| 387 | `.doc(groupId)` |
| 388 | `.collection('members')` |
| 389 | `.doc(command.targetPlayerId),` |
| 424 | `final now = FieldValue.serverTimestamp();` |
| 429 | `final nextLeaderDoc = await transaction.get(` |
| 430 | `recruitmentRef.collection('members').doc(nextLeader),` |
| 457 | `transaction.update(recruitmentRef, recruitmentPatch);` |
| 463 | `transaction.delete(targetRef);` |
| 469 | `transaction.delete(` |
| 471 | `.collection('slots')` |
| 472 | `.doc('${targetPartyIndex}_$targetSlotIndex'),` |
| 475 | `transaction.delete(` |
| 485 | `transaction.update(` |
| 486 | `recruitmentRef.collection('members').doc(nextLeader),` |
| 555 | `.collection('recruitments')` |
| 556 | `.doc(command.recruitmentId);` |
| 558 | `.collection('members')` |
| 559 | `.doc(command.targetPlayerId);` |
| 560 | `final recruitment = await transaction.get(recruitmentRef);` |
| 561 | `final target = await transaction.get(targetRef);` |
| 574 | `final now = FieldValue.serverTimestamp();` |
| 575 | `transaction.update(` |
| 582 | `transaction.update(recruitmentRef, {` |
| 606 | `.collection('recruitments')` |
| 607 | `.doc(command.recruitmentId);` |
| 608 | `final recruitmentSnapshot = await transaction.get(recruitmentRef);` |
| 649 | `final snapshot = await transaction.get(known.reference);` |
| 736 | `final now = FieldValue.serverTimestamp();` |
| 742 | `transaction.update(recruitmentRef, patch);` |
| 748 | `transaction.update(` |
| 749 | `recruitmentRef.collection('members').doc(command.sourcePlayerId),` |
| 757 | `.collection('slots')` |
| 758 | `.doc('${sourcePartyIndex}_$sourceSlotIndex');` |
| 760 | `.collection('slots')` |
| 761 | `.doc(` |
| 765 | `transaction.delete(sourceSlotRef);` |
| 766 | `transaction.set(destinationSlotRef, {` |
| 773 | `transaction.update(` |
| 774 | `recruitmentRef.collection('members').doc(destinationPlayerId),` |
| 781 | `transaction.update(sourceSlotRef, {` |
| 785 | `transaction.update(destinationSlotRef, {` |
| 840 | `if (_firebaseAuth.currentUser == null) return null;` |
| 843 | `.collection('recruitments')` |
| 844 | `.doc(recruitmentId)` |
| 845 | `.collection('members')` |
| 847 | `} on FirebaseException {` |
| 862 | `final snapshot = await transaction.get(item.reference);` |
| 911 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 917 | `return await _firestore.runTransaction((transaction) async {` |
| 918 | `final binding = await transaction.get(` |
| 919 | `_firestore.collection('authBindings').doc(uid),` |
| 931 | `} on FirebaseException catch (error) {` |
| 945 | `.collection('players')` |
| 946 | `.doc(playerId)` |
| 947 | `.collection('activeRaidAssignments')` |
| 948 | `.doc('${characterId}_$raidId');` |

### lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart). 클래스: `FirestorePartyRaidListingBackfill`.
메서드/선언(여러 줄 signature는 시작 행): L14 `Future<void> backfillOwnGroupListings({required String playerId}) async {`; L41 `Future<void> _createIfMissing({`.

| 행 | source 표현 |
|---|---|
| 9 | `required FirebaseFirestore firestore,` |
| 12 | `final FirebaseFirestore _firestore;` |
| 17 | `.collection('recruitments')` |
| 18 | `.where('schemaVersion', isEqualTo: 2)` |
| 19 | `.where('memberPlayerIds', arrayContains: playerId)` |
| 20 | `.where('status', isEqualTo: 'active')` |
| 21 | `.limit(50)` |
| 47 | `.collection('groups')` |
| 48 | `.doc(groupId)` |
| 49 | `.collection('raidListings')` |
| 50 | `.doc(recruitmentId);` |
| 52 | `.collection('recruitments')` |
| 53 | `.doc(recruitmentId);` |
| 54 | `await _firestore.runTransaction((transaction) async {` |
| 55 | `final current = await transaction.get(recruitmentRef);` |
| 56 | `final listing = await transaction.get(listingRef);` |
| 69 | `transaction.set(` |

### lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart). 클래스: `FirestorePartyReadRepository`, `_FirestorePublicRecruitmentPageCursor`.
메서드/선언(여러 줄 signature는 시작 행): L29 `Stream<PublicRecruitmentPage> watchPublicRecruitmentFirstPage({`; L41 `Stream<PublicRecruitmentPage> _watchFirstPageWithGroupListings({`; L86 `Stream<PublicRecruitmentPage> _watchMergedListingPages({`; L169 `List<String> _activeGroupIds(`; L236 `bool _listingIsOpenForCycle(Map<String, Object?> data, String cycleKey) {`; L247 `Future<PublicRecruitmentPage> loadPublicRecruitmentNextPage({`; L312 `Stream<PartyReadSnapshot<ActiveRaidSummary>> watchActiveRaids({`; L339 `Stream<PartyReadSnapshot<PartyApplicationSummary>> watchApplications({`; L368 `Stream<PartyReadDetailSnapshot<PublicRecruitmentSummary>> watchRecruitment(`; L387 `Stream<PartyReadSnapshot<PartyMemberDisplay>> watchRecruitmentMembers(`; L411 `Stream<PartyReadSnapshot<PartyApplicationSummary>> watchRecruitmentApplications(`; L434 `Stream<PartyReadDetailSnapshot<PartyApplicationSummary?>> watchMyApplication({`; L456 `Stream<PartyReadDetailSnapshot<PartyCycleSnapshot?>> watchRecruitmentCycle({`; L498 `Stream<PartyReadSnapshot<ActiveRaidSummary>> _combineActiveQueries(`.

| 행 | source 표현 |
|---|---|
| 15 | `FirestorePartyReadRepository({required FirebaseFirestore firestore})` |
| 19 | `Timestamp timestamp => timestamp.toDate(),` |
| 21 | `_ => throw const FormatException('Expected Firestore Timestamp.'),` |
| 25 | `final FirebaseFirestore _firestore;` |
| 68 | `.collection('players')` |
| 69 | `.doc(currentPlayerId)` |
| 70 | `.collection('groupMembershipState')` |
| 71 | `.doc('current')` |
| 72 | `.snapshots(includeMetadataChanges: true)` |
| 93 | `.limit(limit)` |
| 94 | `.snapshots(includeMetadataChanges: true);` |
| 146 | `.collection('groups')` |
| 147 | `.doc(groupIds[groupIndex])` |
| 148 | `.collection('raidListings')` |
| 149 | `.snapshots(includeMetadataChanges: true)` |
| 258 | `.startAfterDocument(cursor.snapshot)` |
| 259 | `.limit(limit)` |
| 273 | `.collection('recruitments')` |
| 274 | `.where('schemaVersion', isEqualTo: 2)` |
| 275 | `.where('visibility', isEqualTo: 'public')` |
| 276 | `.where('status', isEqualTo: 'active')` |
| 277 | `.where('manualRecruitmentEnabled', isEqualTo: true)` |
| 278 | `.where('hasAvailableSlot', isEqualTo: true)` |
| 279 | `.where('targetCycleKey', isEqualTo: cycleKey)` |
| 280 | `.orderBy('updatedAt', descending: true)` |
| 281 | `.orderBy(FieldPath.documentId, descending: true);` |
| 291 | `.where(` |
| 319 | `.collection('recruitments')` |
| 320 | `.where('schemaVersion', isEqualTo: 2)` |
| 321 | `.where('leaderPlayerId', isEqualTo: playerId)` |
| 322 | `.where('status', whereIn: openStatuses)` |
| 323 | `.snapshots(includeMetadataChanges: true);` |
| 325 | `.collection('recruitments')` |
| 326 | `.where('schemaVersion', isEqualTo: 2)` |
| 327 | `.where('memberPlayerIds', arrayContains: playerId)` |
| 328 | `.where('status', whereIn: openStatuses)` |
| 329 | `.snapshots(includeMetadataChanges: true);` |
| 344 | `.collectionGroup('applications')` |
| 345 | `.where('schemaVersion', isEqualTo: 1)` |
| 346 | `.where('applicantPlayerId', isEqualTo: playerId)` |
| 347 | `.where('cycleKey', isEqualTo: cycleKey)` |
| 348 | `.orderBy('updatedAt', descending: true)` |
| 349 | `.snapshots(includeMetadataChanges: true)` |
| 355 | `.where(` |
| 372 | `.collection('recruitments')` |
| 373 | `.doc(recruitmentId)` |
| 374 | `.snapshots(includeMetadataChanges: true)` |
| 391 | `.collection('recruitments')` |
| 392 | `.doc(recruitmentId)` |
| 393 | `.collection('members')` |
| 394 | `.snapshots(includeMetadataChanges: true)` |
| 415 | `.collection('recruitments')` |
| 416 | `.doc(recruitmentId)` |
| 417 | `.collection('applications')` |
| 418 | `.snapshots(includeMetadataChanges: true)` |
| 439 | `.collection('recruitments')` |
| 440 | `.doc(recruitmentId)` |
| 441 | `.collection('applications')` |
| 442 | `.doc(playerId)` |
| 443 | `.snapshots(includeMetadataChanges: true)` |
| 461 | `.collection('recruitments')` |
| 462 | `.doc(recruitmentId)` |
| 463 | `.collection('cycles')` |
| 464 | `.doc(cycleKey)` |
| 465 | `.snapshots(includeMetadataChanges: true)` |
| 581 | `if (error is FirebaseException) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart). 클래스: `FirestorePartyVisibilityCommandRepository`.
메서드/선언(여러 줄 signature는 시작 행): L22 `Future<PartyVisibilityResult> setVisibility(`; L147 `Future<PartyVisibilityResult> _run(`.

| 행 | source 표현 |
|---|---|
| 13 | `required FirebaseFirestore firestore,` |
| 14 | `required FirebaseAuth firebaseAuth,` |
| 18 | `final FirebaseFirestore _firestore;` |
| 19 | `final FirebaseAuth _firebaseAuth;` |
| 29 | `.collection('recruitments')` |
| 30 | `.doc(command.recruitmentId);` |
| 34 | `.collection('applications')` |
| 35 | `.where('status', isEqualTo: 'pending')` |
| 36 | `.limit(20)` |
| 39 | `} on FirebaseException catch (error) {` |
| 44 | `final recruitment = await transaction.get(recruitmentRef);` |
| 83 | `final leaderMember = await transaction.get(` |
| 96 | `final member = await transaction.get(_groupMember(groupId, memberId));` |
| 105 | `final member = await transaction.get(` |
| 125 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 128 | `transaction.update(recruitmentRef, plan.recruitmentPatch);` |
| 142 | `.collection('groups')` |
| 143 | `.doc(groupId)` |
| 144 | `.collection('members')` |
| 145 | `.doc(playerId);` |
| 150 | `final uid = _firebaseAuth.currentUser?.uid;` |
| 157 | `return await _firestore.runTransaction((transaction) async {` |
| 158 | `final binding = await transaction.get(` |
| 159 | `_firestore.collection('authBindings').doc(uid),` |
| 172 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/party_atomic_cycle_command_adapter.dart
근거: [lib/features/recruitment_list/data/repositories/party_atomic_cycle_command_adapter.dart](../../lib/features/recruitment_list/data/repositories/party_atomic_cycle_command_adapter.dart). 클래스: `PartyAtomicCycleCommandAdapter`.
메서드/선언(여러 줄 signature는 시작 행): L30 `Future<PartyCycleResult> complete(PartyCompleteCycleCommand command) =>`; L39 `Future<PartyCycleResult> advance(PartyAdvanceCycleCommand command) =>`; L49 `Future<PartyCycleResult> disband(PartyDisbandCommand command) =>`; L57 `Future<PartyCycleResult> setRecurrence(`; L137 `Future<PartyCycleResult> purgeStaleOwnAssignment(`; L206 `Future<PartyCycleResult> _executeLifecycle({`.

| 행 | source 표현 |
|---|---|
| 18 | `required FirebaseFirestore firestore,` |
| 19 | `required FirebaseAuth firebaseAuth,` |
| 25 | `final FirebaseFirestore _firestore;` |
| 26 | `final FirebaseAuth _firebaseAuth;` |
| 64 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 69 | `return await _firestore.runTransaction((transaction) async {` |
| 70 | `final binding = await transaction.get(` |
| 71 | `_firestore.collection('authBindings').doc(authUid),` |
| 82 | `.collection('recruitments')` |
| 83 | `.doc(command.recruitmentId);` |
| 84 | `final recruitment = await transaction.get(ref);` |
| 111 | `serverTimestamp: FieldValue.serverTimestamp(),` |
| 113 | `transaction.update(ref, patch);` |
| 115 | `transaction.set(` |
| 117 | `.collection('groups')` |
| 118 | `.doc(data['groupId'] as String)` |
| 119 | `.collection('raidListings')` |
| 120 | `.doc(command.recruitmentId),` |
| 129 | `} on FirebaseException catch (error) {` |
| 145 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 150 | `.collection('authBindings')` |
| 151 | `.doc(authUid)` |
| 162 | `.collection('recruitments')` |
| 163 | `.doc(command.recruitmentId)` |
| 184 | `.collection('players')` |
| 185 | `.doc(playerId)` |
| 186 | `.collection('raidStates')` |
| 187 | `.doc(stateId);` |
| 201 | `} on FirebaseException catch (error) {` |
| 223 | `final authUid = _firebaseAuth.currentUser?.uid;` |
| 229 | `.collection('authBindings')` |
| 230 | `.doc(authUid)` |
| 242 | `.collection('recruitments')` |
| 243 | `.doc(recruitmentId)` |
| 314 | `} on FirebaseException catch (error, stackTrace) {` |

### lib/features/recruitment_list/data/repositories/party_character_ownership_reader.dart
근거: [lib/features/recruitment_list/data/repositories/party_character_ownership_reader.dart](../../lib/features/recruitment_list/data/repositories/party_character_ownership_reader.dart). 클래스: `PartyCharacterOwnershipReader`.
메서드/선언(여러 줄 signature는 시작 행): L8 `static Future<GameAccountOwnershipSnapshot> read({`.

| 행 | source 표현 |
|---|---|
| 10 | `required FirebaseFirestore firestore,` |
| 18 | `final account = await transaction.get(` |
| 19 | `firestore.collection('gameAccounts').doc(gameAccountId),` |

### lib/features/recruitment_list/data/repositories/party_raid_listing_backfill_batch.dart
근거: [lib/features/recruitment_list/data/repositories/party_raid_listing_backfill_batch.dart](../../lib/features/recruitment_list/data/repositories/party_raid_listing_backfill_batch.dart). 클래스: top-level/helper.
메서드/선언(여러 줄 signature는 시작 행): L5 `List<String> roomIds,`; L6 `Future<void> Function(String roomId) repair,`.

| 행 | source 표현 |
|---|---|
| 20 | `} on FirebaseException catch (error) {` |

### lib/features/recruitment_list/data/repositories/party_raid_state_occupancy_inspector.dart
근거: [lib/features/recruitment_list/data/repositories/party_raid_state_occupancy_inspector.dart](../../lib/features/recruitment_list/data/repositories/party_raid_state_occupancy_inspector.dart). 클래스: `PartyRaidStateOccupancyInspector`, `PartyRaidStateOccupancyInspection`.
메서드/선언(여러 줄 signature는 시작 행): L15 `static Future<PartyRaidStateOccupancyInspection> inspect({`.

| 행 | source 표현 |
|---|---|
| 17 | `required FirebaseFirestore firestore,` |
| 27 | `.collection('players')` |
| 28 | `.doc(playerId)` |
| 29 | `.collection('raidStates')` |
| 30 | `.doc(` |
| 36 | `final state = await transaction.get(stateRef);` |
| 39 | `final claim = await transaction.get(` |
| 41 | `.collection('players')` |
| 42 | `.doc(playerId)` |
| 43 | `.collection('weeklyRaidClaims')` |
| 44 | `.doc('${requestedCycleKey}_${characterId}_$raidId'),` |
| 70 | `final assignment = await transaction.get(` |
| 72 | `.collection('players')` |
| 73 | `.doc(playerId)` |
| 74 | `.collection('activeRaidAssignments')` |
| 75 | `.doc('${characterId}_$raidId'),` |
| 145 | `recruitment = await transaction.get(` |
| 146 | `firestore.collection('recruitments').doc(recruitmentId),` |
| 165 | `(recruitment?.data()?['cycleEndsAt'] as Timestamp?)?.toDate(),` |
| 174 | `final assignment = await transaction.get(` |
| 176 | `.collection('players')` |
| 177 | `.doc(playerId)` |
| 178 | `.collection('activeRaidAssignments')` |
| 179 | `.doc('${characterId}_$raidId'),` |

### lib/firebase_options.dart
근거: [lib/firebase_options.dart](../../lib/firebase_options.dart). 클래스: `DefaultFirebaseOptions`.
메서드/선언(여러 줄 signature는 시작 행): L18 `static FirebaseOptions get currentPlatform {`.
SDK 직접 실행 표현은 이 패턴에서 없음. import/type/helper·설정 연결 여부를 원문에서 확인한다.

### lib/shared/character_build/character_optional_display_preservation.dart
근거: [lib/shared/character_build/character_optional_display_preservation.dart](../../lib/shared/character_build/character_optional_display_preservation.dart). 클래스: top-level/helper.
메서드/선언(여러 줄 signature는 시작 행): L9 `Map<String, dynamic>? existing,`.

| 행 | source 표현 |
|---|---|
| 42 | `Timestamp timestamp => timestamp.toDate().toUtc(),` |
