# 화면별 실제 데이터 흐름

기준은 [00](00-overview.md). 라우팅 근거는 [createAppRouter](../../lib/app/router/app_router.dart)이며 파일 존재보다 실제 DI를 우선한다. 메서드와 SDK 행번호 전수는 [01](01-firebase-inventory.md), 구독은 [04](04-realtime-subscriptions.md).

## 실행 화면과 액션 연결

| 경로/화면 | 조회·사용자 액션 → 실제 연결 | 저장/연관 기능·목표 인증 |
|---|---|---|
| 진입/AppBootstrap | initializeAppServices → 익명 Auth → PlayerBinding → recordAppLaunch | binding/player 생성+lastSeen. 목표에서는 guest에 이 쓰기 없음 |
| /account MyAccountPage | MyAccountViewModel → AccountRepositoryImpl(local/remote)/ownership status + weekly status/claim subscriptions | Drift 계정/형제 Character 등록·표시,server 소유 검증·대표/활동·주간 완료. 서버 식별 액션은 로그인 필요 |
| /account/characters/manage | CharacterManagementViewModel → accountRepository/활동 Repository/CharacterAutoRefreshCoordinator | local 표시순서·role/build 변경과 activity 서버 저장·표시 sync를 구분. 외부 API token 필요와 앱 로그인 필요도 별개 |
| /account/characters/:characterId | CharacterDetailViewModel → local account/build/remote armory | build JSON·itemLevel/combatPower·gem integrity 및 minimum/summary sync; localCharacterId와 server ID 별개 |
| /settings/api-token | ApiTokenSettingsPage → SecureApiTokenStore.read/write/delete | Lost Ark API JWT local secure storage. Firebase 서버 token 저장 아님 |
| /settings/game-account-verification | GameAccountVerificationPage → LocalGameAccountVerificationGateway.start/confirm | Lost Ark siblings/armory → 메모리 challenge → `_claimOwnership` Transaction → gameAccounts/characters/identity/playerGameAccounts → local server mapping 반영. 로그인 필요 |
| /settings/manual-verification | ManualVerificationPage → create/reissue/cancel/watchMyRequests/watchIncomingDisputes/loadApprovedResult | 요청·이전 owner response·방어,승인된 server IDs local 반영. 본인 인증 필요 |
| /settings | SettingsPage → OperatorAccess.isCurrentPlayerOperator,각 설정 route | 운영 메뉴 표시만으로 서버 권한 인정하지 않음. 일반 local settings는 서버 없음 |
| /settings/operator/users | OperatorUserListPage → loadUsers | operator read + legacy Player lastSeenAt patch,account/Character 요약. 운영자 필요 |
| /settings/operator/users/:playerId | OperatorUserDetailPage → loadUserDetail | Player/account/Character 소유 자료,타인 데이터 operator scope |
| /settings/operator/manual-verification | OperatorManualVerificationQueuePage → loadPendingQueue/syncExpiredDisputes 관련 refresh | pending 목록·만료분쟁 정리 부수효과,운영자 권한 |
| .../manual-verification/:requestId | OperatorManualVerificationDetailPage → loadReviewContext/reviewCancel/reviewBlock/reviewApprove/reviewForceApprove/reviewApproveDefense/reviewRejectDefense | 소유권 이전·요청 상태·Player event·분쟁 audit. detail이 Firebase Timestamp를 직접 참조 |
| /recruitments | RecruitmentListPage → PublicRecruitmentListViewModel → PartyRead.watchPublicRecruitmentFirstPage/loadPublicRecruitmentNextPage + group read/backfill | 공개+group listing 목록/주차·본인 제외. 목표 공개 read는 guest 허용,내 그룹/backfill은 로그인 분리 |
| /recruitments/create | RecruitmentCreatePage → LeaderCandidateService → activity/local build/server weekly·occupancy lookup → AtomicCreateRepository.create | original/member/raidState/event/group count/listing 원자 생성. catalog asset 조회는 Firebase 아님 |
| /recruitments/:recruitmentId | RecruitmentDetailPage → InMemoryRecruitmentStateRepository/RecruitmentCommandService/후보 서비스 | 해당 route 상세 명령의 주 저장은 in-memory demo. 서버 실제 상세와 혼동 금지; 전환시 사용/폐기 결정 |
| /raid-status | RaidStatusPage → PartyRead.watchActiveRaids/watchApplications + EventSync.sync + cleanup/lazy reconciliation | 내 active/신청 서버 read,Drift history/receipt·filter; 고아 신청/완료 관계 정리. 로그인 필요 |
| /raid-status/notifications | PartyNotificationsPage → PartyNotificationViewModel → Drift receipt + EventSync.sync | local 읽음·방별 설정과 server event GET. FCM 발송 없음 |
| /raid-status/:recruitmentId | PartyReadDetailPage → PartyReadDetailViewModel/내 신청·멤버·승인목록·회차 watch* | actual Firestore 상세. 신청/참가/승인·거절/교체·배치/제거/공개범위/완료/전환/해산은 아래 command 표 |
| /groups | GroupTabPage의 StreamBuilder → watchMyGroups/watchMyRequests | Player groupRelations,초대 수락/거절·신청 취소 등 GroupJoinViewModel 명령 연결. 로그인 필요 |
| /groups/create | GroupCreatePage → GroupCreateViewModel → GroupCreateRepository.create | 대표 Character ownership + group/member/state/relation 네 문서. 로그인 필요 |
| /groups/search | GroupSearchPage → GroupRead.searchGroups → GroupJoin.apply | normalized prefix/최근 active group 검색은 현재 auth required. 목표 공개 검색 여부 별도 확정 |
| /groups/join-by-code | GroupJoinByCodePage → GroupJoinByCodeViewModel → joinByCode | code/group/member/Player summary·relation/joinRelation atomic 경계. 로그인 필요 |
| /groups/:groupId | GroupDetailPage → loadGroup/loadMyRelation/loadGroupMemberDisplays + join/leave/transfer/disband/refreshMyDisplaySnapshot | group/character display·membership roles. 탈퇴/승계·해산 원자 경계 |
| /groups/:groupId/invite | GroupInvitePage → CharacterSearch.searchActiveCharactersByExactName → GroupJoin.invite | candidate Character/owner/summary,joinRelation·Player relation 생성/재사용 |
| /groups/:groupId/applications | GroupApplicationsPage → GroupRead.loadGroupJoinRelations/loadBlockedPlayers + GroupApplication.approve/reject/block/releaseBlock | group leader 명령,member/state/relation/stats/block count |
| /groups/:groupId/join-code | GroupJoinCodePage → GroupJoinCodeManageViewModel → createCode/revokeCode/setVisibility | code 문서+group flag/revision 원자 변경,group leader 권한 |

검색·단발 상세가 모두 snapshots라고 가정하지 않는다. GroupViewModel 이름·UI 핸들러와 호출 원문은 아래 색인으로 재추적한다. 링크의 상대 경로는 checkout 내 소스 파일이다.

## 실제 파티 상세 명령 연결

| 사용자 액션 | Router에서 연결한 구현 | 저장 불변식 |
|---|---|---|
| 신청/철회 | FirestorePartyAtomicApplicationCommandRepository.apply/withdraw | 본인 소유·활동 Character,방/신청 revision,count/nonGroup count,guard·shared event |
| 즉시 참가/승인/거절 | FirestorePartyAtomicJoinCommandRepository.joinDirectly/approve/reject | 슬롯 배치·member/state·pending count·group membership·소유 차수·approve policy |
| 캐릭터/역할 변경·자리 이동/교환 | FirestorePartyAtomicMemberMutationRepository.changeCharacter/repositionMembers | aggregate/member/state/revision·동일직업/role/고정석·타인 소유 거절 |
| 나가기/추방/자격 상실 제거 | PartyAtomicMembershipCommandAdapter → AtomicMemberRemoval.remove | 대상 scope,leader successor,last1,nonGroup count,점유·이벤트·listing. setApprovalPermission은 이 adapter에서 invalidRequest 반환 |
| 공개/그룹 범위 변경 | FirestorePartyAtomicVisibilityCommandRepository.setVisibility | group qualification/count와 listing 전환,room revision |
| 완료/다음주 전환/해산/반복 설정 | PartyAtomicCycleCommandAdapter → AtomicCommandRepository.execute 또는 adapter 자체 recurrence/purge Transaction | commandId/expectedRevision/cycle/targets·state/member/event·group count,준비/완료 경계 |
| 완료 관계 자격 확인·정리/복구 | FirestoreCompletedOwnershipCleanupRepository.inspect/execute/retry + CompletedCleanupJournal | 소유 차수·stale 관찰·승계/마지막1인·이벤트 중복·재진입 |

### 대표 추적 1: 생성

`RecruitmentCreatePage`의 submit → `PartyCreateCommand`(카탈로그·선택 Character/role·visibility/group) → `FirestorePartyAtomicCreateRepository.create` → auth binding·Character/account·점유 state·기존 room·그룹 membership 읽기 → Validator/OwnershipRecordPolicy/OccupancyGate → `PartyCreateWritePlan` + `PartyAtomicCreateWritePlan` → original/member/state/event/선택 group listing/count 쓰기 → Rules before/after 검증 → command result/UI 이동. stale 점유 삭제 후 생성은 별도 Transaction일 수 있다. 이미 만들어진 동일 ID는 재진입 판단한다.

### 대표 추적 2: 그룹 가입

`GroupSearchPage` 또는 초대/코드 화면 → join/application/code ViewModel → command Repository + `GroupCommandRunner` → binding·Player·group/대상Character·member·membershipState·relations·block/code 확인 → WritePlan → group count/revision/member·Player summary/relation·joinRelation·필요 stats/code 상태 갱신 → Rules 원자 결합 → UI 목록은 relation subscription으로 갱신. 실제 가입은 표시 Snapshot만으로 결정하지 않는다.

### 대표 추적 3: 수동 완료

MyAccountViewModel 체크 액션 → WeeklyRaidClaimCommandRepository(실제 default는 WeeklyRaidStatusCommandRepository) → inspect impact/소유·state/room/멤버 관찰 → completion command → state/claim 호환·pending 신청 정리·member/aggregate/event/listing 갱신 → weekly stream/projector 및 local receipt/history. 표면 체크박스 한 개라도 서버에 여러 관계가 영향을 받는다.

## 로컬/외부 의존과 미확인

Drift AccountRepository의 계정 등록·라벨·build·필터·읽음과 Lost Ark sibling/armory request는 Firebase CRUD와 구분한다. 새 OAuth token을 Lost Ark API JWT 자리에 넣지 않는다. 후보 service의 서버/가짜 상태 혼합은 의도와 actual behavior 검토가 필요한 현재 구조이며 이번에 고치지 않았다.

네비게이션·actual 화면 탭·실기기 동작·로그아웃 이후 메모리 session 복구는 실행하지 않았다. 표는 code trace이지 모든 액션 성공 확인이 아니다. target guest 허용 범위는03,API 기능 연결은06을 따른다.

## presentation 호출·수명 source 색인
화면/VM의 Repository/Gateway/Service 명령·watch/listen/dispose의 source 표현. 아래에는 Router 비연결 화면도 포함되며 위 실행 화면 표와 대조한다. delegate/지역 변수 기반 호출은 원문 전체 확인이 필요하다.

### [lib/features/account/presentation/pages/api_token_settings_page.dart](../../lib/features/account/presentation/pages/api_token_settings_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 34 | `_tokenController.dispose();` |
| 35 | `super.dispose();` |

### [lib/features/account/presentation/pages/character_detail_page.dart](../../lib/features/account/presentation/pages/character_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 9 | `import '../../domain/repositories/account_repository.dart';` |
| 42 | `_viewModel.dispose();` |
| 43 | `super.dispose();` |

### [lib/features/account/presentation/pages/character_management_page.dart](../../lib/features/account/presentation/pages/character_management_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 9 | `import '../../domain/repositories/account_repository.dart';` |
| 10 | `import '../../domain/repositories/activity_characters_repository.dart';` |
| 11 | `import '../../domain/repositories/nice_group_auto_refresh_settings_repository.dart';` |
| 12 | `import '../../domain/repositories/representative_character_sync_gateway.dart';` |
| 58 | `_viewModel.dispose();` |
| 59 | `super.dispose();` |

### [lib/features/account/presentation/pages/game_account_verification_page.dart](../../lib/features/account/presentation/pages/game_account_verification_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 8 | `import '../../domain/repositories/account_identity_gateway.dart';` |
| 9 | `import '../../domain/repositories/account_repository.dart';` |
| 10 | `import '../../domain/repositories/game_account_verification_gateway.dart';` |
| 44 | `_challenge = widget.gateway.activeChallenge;` |
| 50 | `_directController.dispose();` |
| 51 | `super.dispose();` |
| 55 | `final accounts = await widget.accountRepository.loadAccounts();` |
| 76 | `final challenge = await widget.gateway.start(` |
| 93 | `final result = await widget.gateway.confirm(challenge.challengeId);` |
| 119 | `account = await widget.accountManagementRepository.addAccount(` |
| 140 | `await widget.mappingRepository.bindServerIdentity(` |
| 149 | `final refreshed = await widget.accountRepository.loadAccounts();` |

### [lib/features/account/presentation/pages/my_account_page.dart](../../lib/features/account/presentation/pages/my_account_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 12 | `import '../../domain/repositories/account_repository.dart';` |
| 13 | `import '../../domain/repositories/character_weekly_raid_display_repository.dart';` |
| 14 | `import '../../domain/repositories/weekly_raid_claim_repository.dart';` |
| 15 | `import '../../domain/repositories/weekly_raid_claim_command_repository.dart';` |
| 16 | `import '../../domain/repositories/weekly_raid_status_repository.dart';` |
| 17 | `import '../../domain/services/character_summary_sync_service.dart';` |
| 18 | `import '../../domain/services/representative_character_sync_service.dart';` |
| 21 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 105 | `_characterNameController.dispose();` |
| 107 | `_viewModel.dispose();` |
| 108 | `unawaited(_manualRefreshSubscription?.cancel());` |
| 109 | `super.dispose();` |
| 1219 | `_labelController.dispose();` |
| 1220 | `_characterController.dispose();` |
| 1221 | `super.dispose();` |
| 1285 | `_labelController.dispose();` |
| 1286 | `super.dispose();` |
| 1358 | `_timer?.cancel();` |
| 1367 | `_timer?.cancel();` |
| 1368 | `super.dispose();` |

### [lib/features/account/presentation/viewmodels/character_detail_view_model.dart](../../lib/features/account/presentation/viewmodels/character_detail_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 7 | `import '../../domain/repositories/account_repository.dart';` |
| 66 | `_snapshots = await _accountRepository.loadCharacterBuildSnapshots(` |
| 81 | `await _accountRepository.setPreferredCharacterRole(` |
| 107 | `_draft = await _accountRepository.createCharacterBuildDraft(` |
| 154 | `await _accountRepository.commitCharacterBuildDraft(` |
| 158 | `_snapshots = await _accountRepository.loadCharacterBuildSnapshots(` |
| 163 | `await _accountRepository.setPreferredCharacterRole(` |

### [lib/features/account/presentation/viewmodels/character_management_view_model.dart](../../lib/features/account/presentation/viewmodels/character_management_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 9 | `import '../../domain/repositories/account_repository.dart';` |
| 10 | `import '../../domain/repositories/activity_characters_repository.dart';` |
| 11 | `import '../../domain/repositories/nice_group_auto_refresh_settings_repository.dart';` |
| 12 | `import '../../domain/repositories/representative_character_sync_gateway.dart';` |
| 270 | `final saved = await repository.save(` |
| 285 | `await _accountRepository.updateCharacterVisibility(` |
| 292 | `await _accountRepository.updateCharacterDisplayOrder(` |
| 296 | `await _accountRepository.updateDisplayLimit(` |
| 305 | `await settingsRepository.saveEnabled(` |
| 312 | `await _accountRepository.setRepresentativeCharacter(` |
| 335 | `_allAccounts = await _accountRepository.loadAccounts();` |
| 338 | `_account = await _accountRepository.loadMainAccount();` |
| 365 | `_draftNiceGroupAutoRefreshEnabled = await repository.loadEnabled(` |
| 377 | `final loaded = await repository.load(playerId: _playerId);` |
| 613 | `await _accountRepository.setRepresentativeCharacter(` |
| 631 | `state = await _representativeSyncGateway.seedRepresentative(` |
| 676 | `return _accountRepository.markRepresentativeReconciled(` |
| 683 | `_cooldownTimer?.cancel();` |
| 687 | `timer.cancel();` |
| 695 | `_cooldownTimer?.cancel();` |
| 696 | `super.dispose();` |

### [lib/features/account/presentation/viewmodels/my_account_view_model.dart](../../lib/features/account/presentation/viewmodels/my_account_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 16 | `import '../../domain/repositories/account_repository.dart';` |
| 17 | `import '../../domain/repositories/character_weekly_raid_display_repository.dart';` |
| 18 | `import '../../domain/repositories/weekly_raid_claim_command_repository.dart';` |
| 19 | `import '../../domain/repositories/weekly_raid_claim_repository.dart';` |
| 20 | `import '../../domain/repositories/weekly_raid_status_repository.dart';` |
| 21 | `import '../../domain/services/character_summary_sync_service.dart';` |
| 22 | `import '../../domain/services/representative_character_sync_service.dart';` |
| 25 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 211 | `await repository.save(preference);` |
| 225 | `await repository.clear(character.id);` |
| 261 | `await repository.save(preference);` |
| 306 | `return await repository.createManualClaim(` |
| 320 | `return await repository.deleteManualClaim(` |
| 356 | `return repository.inspectManualClaimImpact(` |
| 397 | `return await repository.cleanupOrphanParticipation(` |
| 437 | `_raidCatalog = await repository.loadCatalog();` |
| 443 | `_weeklyRaidDisplayPreferences = await repository.loadAll();` |
| 452 | `unawaited(_statusSubscription?.cancel());` |
| 454 | `.watchCurrentCycleStatuses(playerId: playerId, cycleKey: cycleKey)` |
| 472 | `unawaited(_claimSubscription?.cancel());` |
| 474 | `.watchCurrentCycleClaims(playerId: playerId, cycleKey: cycleKey)` |
| 492 | `unawaited(_claimSubscription?.cancel());` |
| 493 | `unawaited(_statusSubscription?.cancel());` |
| 494 | `super.dispose();` |
| 498 | `_accounts = await _accountRepository.loadAccounts();` |
| 499 | `await _representativeSyncService?.synchronizeAccounts(_accounts);` |
| 501 | `_accounts = await _accountRepository.loadAccounts();` |
| 514 | `final snapshots = await _accountRepository.loadCharacterBuildSnapshots(` |
| 555 | `_characters = await _accountRepository.fetchCharacters(characterName);` |
| 557 | `final report = await _summarySyncService.syncAccounts(` |
| 569 | `_lookupProfile = await _accountRepository.fetchCharacterProfile(` |
| 575 | `_accounts = await _accountRepository.loadAccounts();` |
| 609 | `final report = await syncService.syncAccounts(` |
| 619 | `_accounts = await _accountRepository.loadAccounts();` |
| 642 | `await repository.addAccount(` |
| 646 | `_accounts = await _accountRepository.loadAccounts();` |
| 665 | `await repository.updateAccount(` |
| 670 | `_accounts = await _accountRepository.loadAccounts();` |
| 679 | `await repository.deleteAccount(accountId);` |
| 680 | `_accounts = await _accountRepository.loadAccounts();` |
| 693 | `_accounts = await _accountRepository.loadAccounts();` |

### [lib/features/group/presentation/pages/group_create_page.dart](../../lib/features/group/presentation/pages/group_create_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 35 | `_name.dispose();` |
| 36 | `super.dispose();` |

### [lib/features/group/presentation/pages/group_detail_page.dart](../../lib/features/group/presentation/pages/group_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 14 | `import '../../domain/repositories/group_read_repository.dart';` |
| 67 | `_group = widget.readRepository.loadGroup(widget.groupId);` |

### [lib/features/group/presentation/pages/group_invite_page.dart](../../lib/features/group/presentation/pages/group_invite_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 31 | `_controller.dispose();` |
| 32 | `super.dispose();` |

### [lib/features/group/presentation/pages/group_join_by_code_page.dart](../../lib/features/group/presentation/pages/group_join_by_code_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 35 | `_codeController.dispose();` |
| 36 | `super.dispose();` |

### [lib/features/group/presentation/pages/group_join_code_page.dart](../../lib/features/group/presentation/pages/group_join_code_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../domain/repositories/group_read_repository.dart';` |
| 43 | `_group = widget.readRepository.loadGroup(widget.groupId);` |

### [lib/features/group/presentation/pages/group_search_page.dart](../../lib/features/group/presentation/pages/group_search_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 31 | `_query.dispose();` |
| 32 | `super.dispose();` |

### [lib/features/group/presentation/pages/group_tab_page.dart](../../lib/features/group/presentation/pages/group_tab_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 7 | `import '../../domain/repositories/group_read_repository.dart';` |
| 92 | `.watchMyGroups(widget.playerId);` |
| 156 | `.watchMyRequests(widget.playerId);` |
| 268 | `.watchMyGroups(widget.playerId);` |

### [lib/features/group/presentation/viewmodels/group_application_view_model.dart](../../lib/features/group/presentation/viewmodels/group_application_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 4 | `import '../../domain/repositories/group_application_command_repository.dart';` |
| 5 | `import '../../domain/repositories/group_read_repository.dart';` |
| 42 | `final member = await readRepository.loadGroupMember(` |
| 50 | `final applications = await readRepository.loadGroupJoinRelations(` |
| 54 | `final blockedPlayers = await readRepository.loadBlockedPlayers(` |
| 64 | `commandRepository.approveApplication(_decisionFor(relation));` |
| 67 | `commandRepository.rejectApplication(_decisionFor(relation));` |
| 70 | `commandRepository.blockApplicant(_decisionFor(relation));` |
| 73 | `commandRepository.releaseBlock(` |

### [lib/features/group/presentation/viewmodels/group_character_options.dart](../../lib/features/group/presentation/viewmodels/group_character_options.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 2 | `import '../../../account/domain/repositories/account_repository.dart';` |
| 3 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 43 | `final accounts = await accountRepository.loadAccounts();` |

### [lib/features/group/presentation/viewmodels/group_create_view_model.dart](../../lib/features/group/presentation/viewmodels/group_create_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 1 | `import '../../../account/domain/repositories/account_repository.dart';` |
| 2 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 5 | `import '../../domain/repositories/group_create_repository.dart';` |
| 42 | `}) => createRepository.create(` |

### [lib/features/group/presentation/viewmodels/group_join_code_view_model.dart](../../lib/features/group/presentation/viewmodels/group_join_code_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 1 | `import '../../../account/domain/repositories/account_repository.dart';` |
| 2 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 6 | `import '../../domain/repositories/group_join_code_command_repository.dart';` |
| 7 | `import '../../domain/repositories/group_read_repository.dart';` |
| 35 | `final result = await commandRepository.createCode(` |
| 49 | `final result = await commandRepository.revokeCode(` |
| 61 | `}) => commandRepository.setVisibility(` |
| 93 | `}) => commandRepository.joinByCode(` |

### [lib/features/group/presentation/viewmodels/group_join_view_model.dart](../../lib/features/group/presentation/viewmodels/group_join_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 1 | `import '../../../account/domain/repositories/account_repository.dart';` |
| 2 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 3 | `import '../../../account/domain/repositories/character_combat_power_sync_gateway.dart';` |
| 14 | `import '../../domain/repositories/group_character_search_repository.dart';` |
| 15 | `import '../../domain/repositories/group_join_command_repository.dart';` |
| 16 | `import '../../domain/repositories/group_read_repository.dart';` |
| 126 | `searchRepository.searchActiveCharactersByExactName(characterName);` |
| 131 | `}) => commandRepository.invite(` |
| 150 | `readRepository.watchMyRequests(playerId);` |
| 153 | `commandRepository.acceptInvitation(_decisionFor(relation));` |
| 156 | `commandRepository.rejectInvitation(_decisionFor(relation));` |
| 188 | `}) => readRepository.loadMyRelation(playerId: playerId, groupId: groupId);` |
| 193 | `}) => readRepository.loadGroupMember(groupId: groupId, playerId: playerId);` |
| 208 | `await combatPowerSyncGateway?.updateCombatPowers({` |
| 224 | `final displays = await readRepository.loadGroupMemberDisplays(groupId);` |
| 243 | `final member = await readRepository.loadGroupMember(` |
| 261 | `await commandRepository.refreshMyDisplaySnapshot(` |
| 287 | `}) => commandRepository.apply(` |
| 295 | `commandRepository.acceptInvitation(` |
| 303 | `commandRepository.rejectInvitation(` |
| 311 | `commandRepository.leave(GroupLeaveCommand(groupId: groupId));` |
| 317 | `}) => commandRepository.transferLeadership(` |
| 328 | `}) => commandRepository.disband(` |

### [lib/features/group/presentation/viewmodels/group_read_view_model.dart](../../lib/features/group/presentation/viewmodels/group_read_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 3 | `import '../../domain/repositories/group_read_repository.dart';` |
| 45 | `readRepository.searchGroups(query: query);` |

### [lib/features/manual_verification/presentation/pages/manual_verification_page.dart](../../lib/features/manual_verification/presentation/pages/manual_verification_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 9 | `import '../../../account/domain/repositories/account_identity_gateway.dart';` |
| 10 | `import '../../../account/domain/repositories/account_repository.dart';` |
| 13 | `import '../../domain/repositories/manual_verification_repository.dart';` |
| 53 | `_requestStream = widget.repository.watchMyRequests();` |
| 54 | `_disputeStream = widget.repository.watchIncomingDisputes();` |
| 59 | `final accounts = await widget.accountRepository.loadAccounts();` |
| 76 | `final created = await widget.repository.createRequest(` |
| 107 | `final created = await widget.repository.createRequest(` |
| 152 | `final result = await widget.repository.loadApprovedResult(request.id);` |
| 194 | `await widget.mappingRepository.bindServerIdentity(` |
| 459 | `await widget.repository.cancelRequest(request.id);` |

### [lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart](../../lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../../operator_access/domain/repositories/operator_access_repository.dart';` |
| 7 | `import '../../domain/repositories/manual_verification_repository.dart';` |
| 41 | `if (!await widget.operatorAccessRepository.isCurrentPlayerOperator()) {` |
| 44 | `final queue = await widget.repository.loadPendingQueue();` |
| 51 | `final context = await widget.repository.loadReviewContext(request);` |
| 69 | `await widget.operatorAccessRepository.loadWriteReadiness();` |
| 83 | `await widget.operatorAccessRepository.loadWriteReadiness();` |
| 153 | `await _run(() => widget.repository.reviewForceApprove(widget.requestId));` |
| 182 | `await _run(() => widget.repository.reviewRejectDefense(widget.requestId));` |
| 252 | `() => widget.repository.reviewApprove(request.id),` |
| 280 | `() => widget.repository.reviewApproveDefense(` |
| 306 | `onConfirm: (reason) => widget.repository.reviewCancel(` |
| 320 | `onConfirm: (reason) => widget.repository.reviewBlock(` |

### [lib/features/manual_verification/presentation/pages/operator_manual_verification_queue_page.dart](../../lib/features/manual_verification/presentation/pages/operator_manual_verification_queue_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../../operator_access/domain/repositories/operator_access_repository.dart';` |
| 7 | `import '../../domain/repositories/manual_verification_repository.dart';` |
| 35 | `if (!await widget.operatorAccessRepository.isCurrentPlayerOperator()) {` |
| 38 | `return _QueueState.allowed(await widget.repository.loadPendingQueue());` |

### [lib/features/operator_access/presentation/pages/operator_user_detail_page.dart](../../lib/features/operator_access/presentation/pages/operator_user_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../domain/repositories/operator_access_repository.dart';` |
| 27 | `_detail = widget.repository.loadUserDetail(widget.playerId);` |

### [lib/features/operator_access/presentation/pages/operator_user_list_page.dart](../../lib/features/operator_access/presentation/pages/operator_user_list_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 6 | `import '../../domain/repositories/operator_access_repository.dart';` |
| 29 | `if (!await widget.repository.isCurrentPlayerOperator()) {` |
| 33 | `await widget.repository.loadUsers(limit: _limit),` |

### [lib/features/raid_status/presentation/pages/completed_cleanup_recovery_page.dart](../../lib/features/raid_status/presentation/pages/completed_cleanup_recovery_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 31 | `final requests = await widget.repository.pending(widget.playerId);` |
| 46 | `await widget.repository.retry(request);` |
| 87 | `await widget.repository.forget(request);` |

### [lib/features/raid_status/presentation/pages/party_notifications_page.dart](../../lib/features/raid_status/presentation/pages/party_notifications_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 7 | `import '../../domain/services/party_event_sync_service.dart';` |
| 42 | `_viewModel.dispose();` |
| 43 | `super.dispose();` |

### [lib/features/raid_status/presentation/pages/party_read_detail_page.dart](../../lib/features/raid_status/presentation/pages/party_read_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 15 | `import '../../../../shared/game_catalog/domain/services/class_synergy_service.dart';` |
| 31 | `import '../../../recruitment_list/domain/repositories/party_application_command_repository.dart';` |
| 32 | `import '../../../recruitment_list/domain/repositories/party_cycle_command_repository.dart';` |
| 33 | `import '../../../recruitment_list/domain/repositories/party_join_command_repository.dart';` |
| 34 | `import '../../../recruitment_list/domain/repositories/party_membership_command_repository.dart';` |
| 35 | `import '../../../recruitment_list/domain/repositories/party_read_repository.dart';` |
| 36 | `import '../../../recruitment_list/domain/repositories/party_visibility_command_repository.dart';` |
| 39 | `import '../../../recruitment_list/domain/services/recruitment_leader_candidate_service.dart';` |
| 41 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 43 | `import '../../../account/domain/repositories/weekly_raid_claim_command_repository.dart';` |
| 44 | `import '../../domain/services/party_event_sync_service.dart';` |
| 100 | `await repository.retry(observation);` |
| 132 | `await repository.inspect(widget.recruitmentId, member.playerId);` |
| 165 | `await repository.execute(observation);` |
| 241 | `widget.partyReadRepository.watchRecruitment(widget.recruitmentId),` |
| 279 | `await widget.eventSyncService?.sync();` |
| 349 | `_myApplicationSubscription?.cancel();` |
| 351 | `_membersSubscription?.cancel();` |
| 353 | `_applicationsSubscription?.cancel();` |
| 355 | `_cycleSubscription?.cancel();` |
| 363 | `() => widget.partyReadRepository.watchRecruitment(widget.recruitmentId),` |
| 383 | `.watchRecruitmentMembers(widget.recruitmentId)` |
| 388 | `.watchMyApplication(` |
| 428 | `await repository.purgeStaleOwnAssignment(` |
| 440 | `_applicationsSubscription?.cancel();` |
| 454 | `.watchRecruitmentApplications(widget.recruitmentId)` |
| 466 | `_cycleSubscription?.cancel();` |
| 473 | `_cycleSubscription?.cancel();` |
| 477 | `.watchRecruitmentCycle(` |
| 495 | `_myApplicationSubscription?.cancel();` |
| 496 | `_membersSubscription?.cancel();` |
| 497 | `_applicationsSubscription?.cancel();` |
| 498 | `_cycleSubscription?.cancel();` |
| 499 | `_viewModel.dispose();` |
| 500 | `super.dispose();` |
| 577 | `final candidates = await candidateService.load(` |
| 727 | `final result = await repository.cleanupOrphanParticipation(` |
| 762 | `final result = await repository.withdraw(` |
| 797 | `? await repository.approve(command)` |
| 798 | `: await repository.reject(command);` |
| 1248 | `candidates = await candidateService.load(` |
| 1337 | `final result = await repository.changeCharacter(` |
| 1450 | `final result = await repository.repositionMembers(` |
| 1612 | `final result = await cycleRepository.disband(` |
| 1679 | `final result = await repository.complete(` |
| 1748 | `final result = await repository.setRecurrence(` |
| 1806 | `final result = await repository.disband(` |
| 1864 | `final result = await repository.setVisibility(` |
| 2004 | `await sync.sync();` |
| 2727 | `return service.alwaysPrimaryLabels(` |

### [lib/features/raid_status/presentation/pages/raid_status_page.dart](../../lib/features/raid_status/presentation/pages/raid_status_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 9 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 11 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 12 | `import '../../../group/domain/repositories/group_character_search_repository.dart';` |
| 13 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 20 | `import '../../../recruitment_list/domain/repositories/party_application_cleanup_repository.dart';` |
| 21 | `import '../../../recruitment_list/domain/repositories/party_read_repository.dart';` |
| 25 | `import '../../domain/services/party_event_sync_service.dart';` |
| 26 | `import '../../domain/services/throttled_party_event_sync_service.dart';` |
| 92 | `streamFactory: () => widget.partyReadRepository.watchActiveRaids(` |
| 101 | `widget.partyReadRepository.watchRecruitmentMembers(recruitmentId),` |
| 107 | `streamFactory: () => widget.partyReadRepository.watchApplications(` |
| 264 | `final result = await repository.deleteOrphan(` |
| 281 | `_tabController.dispose();` |
| 282 | `_activeRaids.dispose();` |
| 283 | `_applications.dispose();` |
| 284 | `_history.dispose();` |
| 285 | `super.dispose();` |

### [lib/features/raid_status/presentation/viewmodels/active_raid_filter_view_model.dart](../../lib/features/raid_status/presentation/viewmodels/active_raid_filter_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 6 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 8 | `import '../../../group/domain/repositories/group_character_search_repository.dart';` |
| 9 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 12 | `import '../../../recruitment_list/domain/repositories/party_read_repository.dart';` |
| 352 | `await repository.loadCatalog(),` |
| 413 | `.watchMyGroups(_playerId)` |
| 610 | `_subscription?.cancel();` |
| 612 | `_groupsSubscription?.cancel();` |
| 614 | `super.dispose();` |

### [lib/features/raid_status/presentation/viewmodels/party_notification_view_model.dart](../../lib/features/raid_status/presentation/viewmodels/party_notification_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../domain/services/party_event_sync_service.dart';` |
| 98 | `final result = await _syncService.sync();` |
| 173 | `super.dispose();` |

### [lib/features/raid_status/presentation/viewmodels/party_read_detail_view_model.dart](../../lib/features/raid_status/presentation/viewmodels/party_read_detail_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 6 | `import '../../../recruitment_list/domain/repositories/party_read_repository.dart';` |
| 47 | `_subscription?.cancel();` |
| 78 | `_subscription?.cancel();` |
| 80 | `super.dispose();` |

### [lib/features/raid_status/presentation/viewmodels/party_read_stream_view_model.dart](../../lib/features/raid_status/presentation/viewmodels/party_read_stream_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 6 | `import '../../../recruitment_list/domain/repositories/party_read_repository.dart';` |
| 70 | `_subscription?.cancel();` |
| 72 | `super.dispose();` |

### [lib/features/raid_status/presentation/viewmodels/raid_history_view_model.dart](../../lib/features/raid_status/presentation/viewmodels/raid_history_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 3 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 5 | `import '../../domain/services/party_event_sync_service.dart';` |
| 146 | `return await _syncService.sync();` |
| 159 | `final catalog = await repository.loadCatalog();` |
| 248 | `super.dispose();` |

### [lib/features/recruitment_list/presentation/pages/recruitment_create_page.dart](../../lib/features/recruitment_list/presentation/pages/recruitment_create_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 10 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 12 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 20 | `import '../../domain/repositories/party_create_repository.dart';` |
| 21 | `import '../../domain/services/recruitment_command_service.dart';` |
| 22 | `import '../../domain/services/recruitment_application_candidate_service.dart';` |
| 23 | `import '../../domain/services/recruitment_leader_candidate_service.dart';` |
| 101 | `_groupsSubscription?.cancel();` |
| 102 | `_title.dispose();` |
| 103 | `_combatPower.dispose();` |
| 104 | `super.dispose();` |
| 109 | `final catalog = await widget.catalogRepository.loadCatalog();` |
| 262 | `.watchMyGroups(playerId)` |
| 378 | `}) => widget.candidateService.load(` |
| 383 | `startAt: widget.candidateService.clock.now(),` |
| 741 | `final pendingCount = await widget.commandService.countPendingApplications(` |
| 809 | `final result = await widget.commandService.createRecruitment(` |
| 869 | `final result = await repository.create(` |

### [lib/features/recruitment_list/presentation/pages/recruitment_detail_page.dart](../../lib/features/recruitment_list/presentation/pages/recruitment_detail_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 10 | `import '../../domain/repositories/recruitment_state_repository.dart';` |
| 11 | `import '../../domain/services/recruitment_application_candidate_service.dart';` |
| 12 | `import '../../domain/services/recruitment_command_service.dart';` |
| 41 | `widget.repository.getById(widget.recruitmentId);` |
| 68 | `if (state.leaderUserId == widget.commandService.currentUserId) ...[` |
| 98 | `(member) => member.userId == widget.commandService.currentUserId,` |
| 185 | `trailing: member.userId == widget.commandService.currentUserId` |
| 208 | `final userId = widget.commandService.currentUserId;` |
| 342 | `final result = await widget.commandService.deleteRecruitment(aggregate.id);` |
| 357 | `final userId = widget.commandService.currentUserId;` |
| 449 | `final userId = widget.commandService.currentUserId;` |
| 482 | `? await widget.candidateService.loadForCharacterChange(aggregate)` |
| 483 | `: await widget.candidateService.load(aggregate);` |
| 744 | `final result = await widget.commandService.changeCharacter(` |
| 771 | `final result = await widget.commandService.apply(` |
| 796 | `final result = await widget.commandService.withdraw(widget.recruitmentId);` |
| 808 | `final result = await widget.commandService.vote(` |

### [lib/features/recruitment_list/presentation/pages/recruitment_edit_page.dart](../../lib/features/recruitment_list/presentation/pages/recruitment_edit_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 6 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 12 | `import '../../domain/repositories/recruitment_state_repository.dart';` |
| 13 | `import '../../domain/services/recruitment_command_service.dart';` |
| 60 | `_title.dispose();` |
| 61 | `_combatPower.dispose();` |
| 62 | `super.dispose();` |
| 66 | `final aggregate = await widget.repository.getById(widget.recruitmentId);` |
| 67 | `final catalog = await widget.catalogRepository.loadCatalog();` |
| 70 | `aggregate.state.leaderUserId != widget.commandService.currentUserId) {` |
| 340 | `final result = await widget.commandService.updateRecruitment(` |

### [lib/features/recruitment_list/presentation/pages/recruitment_list_page.dart](../../lib/features/recruitment_list/presentation/pages/recruitment_list_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 6 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 8 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 9 | `import '../../../group/domain/repositories/group_character_search_repository.dart';` |
| 10 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 15 | `import '../../domain/repositories/party_read_repository.dart';` |
| 75 | `_viewModel.dispose();` |
| 76 | `super.dispose();` |

### [lib/features/recruitment_list/presentation/viewmodels/public_recruitment_list_view_model.dart](../../lib/features/recruitment_list/presentation/viewmodels/public_recruitment_list_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 5 | `import '../../../../shared/raid_catalog/domain/repositories/raid_catalog_repository.dart';` |
| 6 | `import '../../../account/domain/repositories/activity_characters_repository.dart';` |
| 8 | `import '../../../group/domain/repositories/group_character_search_repository.dart';` |
| 9 | `import '../../../group/domain/repositories/group_read_repository.dart';` |
| 22 | `import '../../domain/repositories/party_read_repository.dart';` |
| 231 | `.watchPublicRecruitmentFirstPage(` |
| 347 | `await _subscription?.cancel();` |
| 378 | `final page = await _repository.loadPublicRecruitmentNextPage(` |
| 443 | `await repository.loadCatalog(),` |
| 466 | `.watchMyGroups(_currentPlayerId)` |
| 595 | `.watchRecruitmentMembers(item.id)` |
| 771 | `_subscription?.cancel();` |
| 773 | `_groupsSubscription?.cancel();` |
| 775 | `super.dispose();` |

### [lib/features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart](../../lib/features/recruitment_list/presentation/viewmodels/recruitment_list_view_model.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 4 | `import '../../domain/repositories/recruitment_state_repository.dart';` |
| 27 | `super.dispose();` |
| 35 | `_recruitments = await _repository.getPublicRecruitments();` |

### [lib/features/settings/presentation/pages/settings_page.dart](../../lib/features/settings/presentation/pages/settings_page.dart)

| 행 | UI 호출/수명 표현 |
|---|---|
| 4 | `import '../../../operator_access/domain/repositories/operator_access_repository.dart';` |
| 17 | `widget.operatorAccessRepository?.isCurrentPlayerOperator() ??` |
