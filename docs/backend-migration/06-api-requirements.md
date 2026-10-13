# 향후 API 기능 요구사항

기준 [00](00-overview.md). 아래 ID는 향후 GitHub Issue 후보이며 실제 Issue를 생성하지 않았다. REST endpoint/HTTP method/DTO/SQL schema를 정한 표가 아니다. “인증” 열은 목표 서버 정책이며 현재 SDK 권한은 [03](03-auth-and-permissions.md)에서 별도 확인한다. 기존 구현의 UI명과 callable은 [05](05-screen-data-flows.md)/[01](01-firebase-inventory.md)로 추적한다.

| ID | 화면·사용자 액션 | 필요한 데이터/결과와 불변식 | 목표 인증 | 기존 소스 클래스·호출 |
|---|---|---|---|---|
| AUTH-01 | 진입/로그인 알럿 → 제공자 로그인 | Discord/Google/Apple identity 검증·내부 principal·자체 token. guest 회원 생성 없음 | login 시작 가능,identity 확정 후 발급 | initializeAppServices/AnonymousAuthInitializer/PlayerBindingStore의 제거 영향 |
| AUTH-02 | 재실행/로그아웃/계정 전환 | session 갱신·Refresh 회전/폐기·provider 연결/충돌. 정책 미결정 | 유효 session/Refresh;타인 연결 금지 | currentUser UID + authBindings lookup,새 기능 현재 미구현 |
| AUTH-03 제외 | 기존 사용자 데이터 연결 | 사용자 정책으로 기존 UID/Player linking/import/recovery 미구현 | 해당 없음 | 기존 PlayerBindingStore는 제거 영향 근거만 유지 |
| USER-01 | 로그인한 앱 진입/내 계정 | 내 profile/status,lastSeen 등 필요 자료. guest activity write 없음 | 본인 | PlayerActivity.recordAppLaunch/PlayerSession |
| PUB-01 | 모집 목록 탐색/다음 페이지 | 공개 active 모집·주차·빈자리·정렬/opaque cursor와 최소 공개 필드 | 비로그인 허용 | PartyRead.watchPublicRecruitmentFirstPage/loadPublicRecruitmentNextPage |
| PUB-02 | 공개 방 상세 | 공개 metadata/허용된 member Snapshot·상태,숨겨야 할 개인정보 결정 | 공개 부분 비로그인,private/group 별도 | PartyRead.watchRecruitment/watchRecruitmentMembers |
| OWN-01 | 게임 계정 인증 시작/확인 | 서버 challenge·장비 proof·기한·형제 Character/identity·소유 차수 이전. game auth와 OAuth 분리 | 본인 로그인 | LocalGameAccountVerificationGateway.start/confirm/_claimOwnership |
| OWN-02 | 계정/Character 소유 상태·대표 변경 | 현재 ownership status/revision,대표 소유 확인·활동 제약 | 본인,공개 표시 projection 별도 | OwnershipStatus.loadStatuses;RepresentativeSync.loadState/set/seed |
| CHAR-01 | 캐릭터 갱신/후보 | Character 최소 summary·build Snapshot 관련 소유 scope,external API token 사용 방식 결정 | 사용자별 갱신 본인;공개 display 범위 별도 | CharacterSummary/CombatPower/MinimumDisplaySync;LostArkApiClient.get |
| CHAR-02 | 활동 목록 조회·저장 | 대표 포함/순서/소유 Character projection,중간 실패 대응 | 본인 | ActivityCharactersRepository.load/save/loadProjections |
| PARTY-01 | 방 만들기 | 검증된 raid/catalog·character/role·구성/visibility,room+member+state+event·group count 원자 확정 | 로그인,소유 Character/group 자격 | AtomicCreateRepository.create |
| PARTY-02 | 신청/철회/내 신청 목록 | 신청 상태/role/build/소유 차수,중복·pending count·기한·stale cleanup | 본인 | AtomicApplication.apply/withdraw;PartyRead.watchApplications/watchMyApplication |
| PARTY-03 | 즉시 참가/승인/거절 | application/version/배치·room/member/state/guard/event 원자성,최대8인/마지막 자리 충돌 | 본인 참가;leader/승인권자 결정 | AtomicJoin.joinDirectly/approve/reject |
| PARTY-04 | 캐릭터·role/자리 변경 | 소유 state 충돌·배치/동일직업/role·leader 고정석·membership generation | 허용된 본인/leader 행위 | AtomicMemberMutation.changeCharacter/repositionMembers |
| PARTY-05 | 탈퇴/추방/승인권한 조정 | actor-role/target·leader 승계/마지막1인·count·점유 해제/event | 본인/leader/허용 정책 | AtomicMembershipAdapter/AtomicMemberRemoval.remove;setApprovalPermission은 현재 adapter invalidRequest,향후 지원 여부 결정 |
| PARTY-06 | 범위 변경/그룹방 | private audience·group membership·activeRecruitmentCount·projection 일관성 | leader/유효 group | AtomicVisibility.setVisibility;PartyRaidListingSync.write |
| PARTY-07 | 완료/미완료 종료/반복/전환/해산 | commandId/version·expected cycle/target·최대8인 결과/역사·소유 차수·준비 자료 | 명령별 leader/허용 member | AtomicCycleAdapter/AtomicCommand.execute/findAggregate/_certifyAdvance |
| PARTY-08 | 내 레이드 현황/회차 | leader/member room 합성·claim/assignment/state compatibility·history | 본인/방 자격 | PartyRead.watchActiveRaids/watchRecruitmentCycle;LazyCycleReconciliation.reconcile |
| WEEK-01 | 주간 완료 표시/개인 체크·취소 | current cycle status·ownership projection,변경 영향·준비/legacy 충돌·pending 정리 | 본인 또는허용 파티 명령 | WeeklyRaidStatus.watchCurrentCycleStatuses;StatusCommand.inspect/create/delete/cleanup |
| CLEAN-01 | 고아 신청·참가 자격 확인/정리/재시도 | 관찰 snapshot/revision·소유 변경·현재 권한·dedup,정상 관계 보존 | 해당 command actor | ApplicationCleanup.deleteOrphan;CompletedOwnershipCleanup.inspect/execute/retry;CompletedCleanupJournal |
| GROUP-01 | 그룹 검색/상세/초대 대상 검색 | normalized prefix/최근 목록·대표 summary,exact Character·owner/display 최소 정보 | 공개 범위 미결정;member/request 정보 로그인 | GroupRead.searchGroups/loadGroup/loadGroupMemberDisplays;GroupCharacterSearch.search* |
| GROUP-02 | 그룹 생성/내 목록 | 대표 Character·group/member/state/relation,50한도·membership unique | 본인 | GroupCreate.create;GroupRead.watchMyGroups/watchMyRequests |
| GROUP-03 | 초대/신청/수락·거절·취소 | pending kind/status/expiry·memberCount·Player relation/active groups·block 검증 | 본인/member/leader 역할별 | GroupJoin.invite/apply/acceptInvitation/rejectInvitation/cancelInvitation |
| GROUP-04 | 신청 승인/차단·해제 | leader 권한·applicantStats/attempt·member/summary 원자성 | group leader | GroupApplication.approveApplication/rejectApplication/blockApplicant/releaseBlock |
| GROUP-05 | 탈퇴/승계/마지막 해산·표시 갱신 | 이전/새 leader role 동시 변경,count/revision·본인 Snapshot 제한 | 본인/group leader | GroupJoin.leave/transferLeadership/disband/refreshMyDisplaySnapshot |
| GROUP-06 | 코드 생성/폐기/표시/가입 | 유일 code·group flag·회원 자격/차단·정원·relation consistency | leader 관리;로그인 가입 | GroupJoinCode.createCode/revokeCode/setVisibility/joinByCode |
| EVENT-01 | 알림/이력 갱신/상세 입장 | audience-authorized event·ordered sync/replay/dedup·retention,읽음 기기전용 유지 여부 | 본인/audience | PartyEventSync.sync/PartyEventRead.loadRecentEvents → Drift sync history/receipt |
| MANUAL-01 | 수동 인증 요청/재발급/취소·방어 | request code/attempt/기한·분쟁/previous owner,검증 자료 공개 scope | 본인/이전 owner | ManualVerification.create/reissue/cancel/watch*/loadApprovedResult |
| ADMIN-01 | 운영 사용자 목록/상세 | Player/status/account/대표·lastSeen,read와 legacy patch 책임 분리 | 서버 운영자 | OperatorAccess.isCurrentPlayerOperator/loadUsers/loadUserDetail/loadWriteReadiness |
| ADMIN-02 | 수동 검토/강제 승인/방어 결정/만료 처리 | operator evidence·reason/status transition·소유권 이전·감사,event audience | 서버 운영자/서버 만료 작업 | ManualVerification.loadPendingQueue/loadReviewContext/review*/syncExpiredDisputes |
| WS-01 | 화면 진입/갱신/재연결 |04의 public/own/group/room scope snapshot/change/replay·revision·권한회수 | scope별 server 인가,public은 guest 가능 | 04 snapshots 전체 목록 |

## 최신 범위 변경

기존 사용자·데이터 이관 없음으로 AUTH-03은 제외한다. 신규 provider identity 연결/세션 관리가 필요해도 old Firebase identity와 연결하지 않는다. historical cycle/state/claim 호환 reader·데이터 backfill·Firebase listing/guard 구현은 그대로 재현할 API가 아니다. 신규 상태/명령의 보장 요건만10~11에 따라 재설계한다. local history/journal은 신규 server 권한/쓰기 자료로 import하지 않는다.

## 공통 요구

서버는 token에서 actor를 결정하고 body의 actorPlayerId/ownership/role/count/audience를 신뢰하지 않는다. command의 reference 존재·소유권·소유 차수·role·status transition·주차·revision/idempotency를 검증한다. 동시 참가/전환·partial write를 막고 event/집계·소유 state가 같은 커밋 결과를 반영해야 한다. 실제 DB lock/isolation/constraint 조합은 후속 설계 대상이다.

앱은 권한 거절,미인증,not-found,소유권 상실,revision conflict,정원/중복/주간완료,contract invalid,일시 unavailable를 구분해 표시할 정보가 필요하다. 정확한 HTTP code/error object는 OpenAPI 설계에서 확정한다. client retry와 성공했으나 응답 유실을 구분할 명령 재조회/dedup 요구가 있다.

REST cursor·date/time/timezone·nullable/missing·schema version·한도/정렬·public/private fields·WS replay/retention을 계약으로 합의해야 한다. OAuth Refresh와 Firebase 재연결,Lost Ark API rate limiting은 서로 다른 책임이다.

## 저장소 협업과 미확정

backend Git 저장소가 OpenAPI 원본과 WS 이벤트/메시지 계약을 관리한다. frontend는 승인된 version을 참조한다. 각 ID를 Issue로 옮길 때 이 문서의 화면/액션/필요자료/인가/기존 callable/불변식/결정 질문을 포함한다. 실제 Issues/endpoint/schema/table는 이번에 만들지 않는다.

PUB-02/GROUP-01 공개 필드,AUTH-03은 제외,신규 계정의 추가 제공자 연결,CHAR-01 외부 token,EVENT-01 읽음/이력 수명,ADMIN-02 만료 실행 주체·업로드 증거,모바일 OAuth/session 정책은 [07](07-migration-risks.md)의 결정을 기다린다. 근거 없는 신규 로그인·FCM·S3 기능을 현재 구현으로 적지 않는다.
