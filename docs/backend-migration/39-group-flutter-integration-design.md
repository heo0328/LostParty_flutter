# 그룹 전체 흐름 — Flutter 연결 설계

기본 그룹 업무 계약22b16207, 초대 표시c3814452, 모집 최초 연결·목록 표시 확장6dac5ab2. 개발서버 실행2602e459/DB0034 반영 인계를 확인했다. 기존 그룹 기능은 사용자 정상 인수했으며 현재 모집 연결 변경의 기기 인수/디자인 검수 상태는 NEXT_WORK를 따른다.

## 1. 기준·포함/제외

[그룹 제품 계약](../product/GROUP_PRODUCT_FLOW.md), [정책09 D08](09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정), [한도34](34-member-limits-and-room-restrictions.md), [최신 모집37](37-raid-scheduling-and-multi-raid-planning.md), [품질/UX](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md)를 함께 적용한다. 현재 자체 Backend·단일 Google 회원·canonical UUID로 개발한다. 베타 직전 초기화는 별도 실행이며 자료 호환/이전 리허설·빈 환경을 선행조건으로 만들지 않는다.

그룹 전용도 일반 레이드의 생성·참가·신청·일정·완료 흐름을 그대로 사용한다. 차이는 신규 목록/참가/신청의 그룹 소속 범위다. 공개범위 왕복·기존 참가/신청 보존·참가자 모두가 확인하는 소속 배지와 그룹 문제/독립 제한 구분은 제품 계약 §4/§9.2/§13을 단일 기준으로 삼는다. 이를 별도 그룹 모집 절차로 재설계하지 않는다.

전체 그룹 기획/연결 설계에는 생성·검색·요청·코드·차단·이름/대표 변경·멤버표시·추방·이전·탈퇴·해산·그룹 레이드 관리를 포함한다. 사용자 승인 구현 계획에 따라 Flutter 기능코드/Router/DI·그룹 HTTP·원요청/표시·모집 갱신 연결을 수정한다. 서버/DB·실기기·배포·자료 삭제는 이번 실행에서 제외한다. 웹소켓·공지·통계화면·BM·운영자 삭제 자동화는 별도 후속이다. 제품 UX를 API 준비 상황에 맞춰 축소하지 않는다.

과거 구현 재사용은 [협업 지침 §6](../project/ai_rules.md#6-architecture-principles)의 검토 기준을 따른다. 기존 그룹 화면/Domain이 남아 있다는 사실은 그대로 연결할 설계 승인이나 기능 완료가 아니다. 각 흐름을 `현재 사용자 목적/정책·UX → 과거 기술 수단/제약 → 자체 Backend에서 유지·제거·교체할 책임 → 영향/검증` 순서로 검토한다. Firebase 때문에 생긴 Stream/Projection/클라이언트 WritePlan 우회는 현재 서버 원장·권한·HTTP 갱신에 맞게 바로잡는다. 기존 gemValidationSnapshot도 같은 저장형식 복제가 아니라 사용자에게 필요한 보석/빌드 상태 의미가 현재 analysis/issues로 정확히 전달되는지 대조한다. 현재 Backend의 DTO/명령도 같은 기준으로 검토하며 임의 정상값 합성은 하지 않는다.

## 2. 확인 근거와 과거 구현

- 현재 일반 앱: `lib/main.dart` → BackendApp. `lib/app/backend_app.dart`의 `/groups`·검색·생성·코드 가입·그룹 상세 및 관리 하위 경로는 BackendGroupPage/BackendGroupViewModel·GroupRepository에 연결했다. 단순히 과거 화면이 남은 상태와 실제 현재 연결을 구분한다.
- 잔존 구현: `lib/features/group/presentation`의 탭/검색/생성/상세/초대/신청/코드 화면과 ViewModel, Domain의 이름 정규화/Validator·역할/관계 모델. 기존 탭은 내 그룹·요청 현황, 상세는 공개요약과 membership 확인 후 private 멤버 읽기를 분리한다.
- 과거 저장: GroupReadRepository의 watchMyGroups/watchMyRequests와 Player 역방향 Projection, WritePlan의 요청·membership·카운터·활동시각 Transaction을 Firestore Repository/Rules가 실행했다. 현재 새 서버에서 클라이언트 WritePlan을 실행하거나 Firestore 원장을 복원하지 않는다. 상태 전이/검증 의도만 서버 계약과 대조한다.
- 표시: 기존 GroupMemberDisplay에는 전투력·아이템레벨·보석 검증 표시가 있고 상세에서 멤버의 활동 캐릭터를 펼쳤다. 기본 G1 응답만으로는 부족했으나 현재 인계의 opt-in 표시 DTO·활동 조회가 해당 자료를 제공한다. 표시값을0으로 채우거나 남의 로컬 계정DB를 조회해 메우지 않는다.
- 과거 기기 확인·Task-11 완료/후속 및 D2/D3 기록은 [DEV_LOG](../project/DEV_LOG.md#group-design-20261028)에 모았다. 과거8~9월 Firebase 인수는 현재 Backend 인수가 아니다.

Backend의 이전 경로404는 문서 이동이었다. 초기 조사 SHA1b6f57bb의 다음 파일을 읽고 당시 Python Router/Schema 및 JSON 형태의 `openapi/two-cycle.openapi.yaml` 경로·DTO를 대조했다.

- [현재 그룹 기능 지도](https://github.com/heo0328/lostparty-backend/blob/1b6f57bb2cfebc5c8ce9f796d59beea0e05cc1dd/docs/features/groups/README.md)의 discovery/joining/management.
- `docs/archive/work-records/features/groups/ISSUE_12_GROUP_G1_SPEC.md`, `ISSUE_12_GROUP_G2_SPEC.md`, `ISSUE_16_GROUP_G3_SPEC.md`는 이력 명세이며 현재 소스/OpenAPI와 함께 읽는다.
- `app/groups/router.py`, `admission_router.py`, `schemas.py`, `admission_schemas.py`, `management.py`: 당시 disband=false/`GROUP_RECRUITMENT_STATE_UNAVAILABLE`, 해산 write 경로 없음 확인(과거 조사). 모집이 구현됐다는 이유로 해산까지 활성화됐다고 추정하지 않는다.
- [Issue12 이전 소비 회신](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6259124455), [Issue16 이전 통합/미완료](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6262944673). 현재 소스 조회와 개발 서버 실행 버전/실회원 인수는 별개이며 이번에는 서버를 조작하지 않았다.

### 2.1 현재 Backend 인계·대조 결과

[Issue12 인계](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6466328231)·[Issue16 인계](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6466327755)의 고정 source/계약은 `22b1620747707afaa87ba84223e5a2beb886f658`다. 같은 SHA의 display_schemas.py·display.py·management_schemas.py·router.py·profile_schemas.py, 표시/관리 계약과 JSON 형태의 two-cycle.openapi.yaml을 대조했다. 이전 설계-only/미구현 상태는 DEV_LOG 및 과거 커밋 이력이며 현재 상태를 대체하지 않는다.

- 구현 인계: reader_profile=group-display-1, membership별 활동 조회, 개인/그룹 요청집계·활동시각, management_profile=group-management-1, 조건부 해산·추방·대표 변경·그룹원 공통 레이드 목록, 기존 실제 주차 참가 보존. 그룹장 별도 레이드 변경 경로는 없다.
- 제공/실행 경계: 신규 기능은 DB0034_group_features가 필요하다. 기존0023/0033에서 명시 요청은503 GROUP_FEATURE_NOT_READY다. Backend는 개발서버/DB를 반영하거나 다시 조회하지 않았다고 보고했다. 격리 시험 선택 노드 중복제거152개는 동일HEAD 전체 일괄시험이 아니다. Flutter는 이번에 시험을 재실행하거나 서버/기기 인수를 하지 않았다.
- 표시: 현재 회원·소유/활동/생명주기와 canonical UUID를 사용한다. 수치는 역할별 마지막 성공과 현재 analysis 오류를 분리하며 null/출처·관측시각을 유지한다. 과거 subject를 이름으로 재연결하지 않는다. 개인 표시 개수/원정대 전체나 카드별 provider 호출을 요구하지 않는다.
- 보석/빌드 소비 결론: 기존 gemValidationSnapshot의 보석 개수 필드는 재현 계약이 아니다. 현재 Flutter scoped_role_build_mapper가 저장하는 GEM_SLOT_COUNT·FOREIGN_CLASS_GEM·UNMATCHED_SKILL_GEM 오류는 ‘보석 오류’, ARK_GRID_MINIMUM·ARK_GRID_CONDITION 오류는 ‘아크그리드 오류’에 대응할 수 있다. warning은 error로 올리지 않으며 unknown 오류는 일반 분석 오류로 표시한다. clean/미확인·분석 없음과 전투력 last-success를 혼동하지 않는다. 기존 스냅샷/카운트 합성을 위한 Backend 신규 저장·API 요구는 하지 않는다. 실제 화면 어댑터와 역할별 표시는 Flutter 구현에서 검증한다.
- 기존 모집 연결: 일반 활동 조회의 membership_id/canonical character_id를 현재 모집 filter-context의 alias.group_membership_id·후보와 대조한다. 일반 열람 응답은 후보 token/명령 권한이 아니다. 가입·탈퇴/회원 전환 뒤 표시와 필터/후보 context를 함께 무효화한다.

## 3. 기능별 상태·담당·완료 기준

그룹 탭·관리 기능의 일반 Flutter 연결은 이번 코드로 구현했고 신규 Backend 실서버 연동/실기기 인수는 미완료다. 아래 담당·다음 행동은 원 구현 기준과 연결 후 인수할 경계를 포함한다. 기존 모집의 그룹 레이드 생성·검색은 이미 연결돼 있으며 아래 표의 해당 행은 새 그룹 membership/갱신과의 추가 연계를 뜻한다. 서버 제공은 위 고정 소스 확인 수준이다. 상세 제품 정책은 제품 문서에만 두며 이 표는 남은 구현을 관리한다.

| 기능 | 기존 부품/흐름 | 현재 Backend | 담당·다음 행동 / 완료 기준 |
|---|---|---|---|
| 내 그룹·공개 검색·상세 | 탭/검색/상세·ReadRepository | G1 제공 | Flutter / HTTP·페이지·권한 연결, 실제 Router→조회→표시 및 복귀 갱신 |
| 생성·이름 변경 | 생성 VM·정규화, 수정은 화면 연결 대조 필요 | POST/PATCH 제공 | Flutter / 현재 소유/활동 선택·버전·한도 소비, 생성 후 상세·목록/사용량 갱신 |
| 멤버 카드·활동 캐릭터 펼침 | 카드/표시 DTO·기존 계정 조회 의존 | 표시 profile·활동 GET 구현 인계, 서버 미반영 | Flutter / 현재 DTO를 역할별 표시로 연결, 과거 스냅샷 저장 복제 없이 null/오류·갱신 검증 |
| 직접 초대 | 정확 이름 검색→대상 확인→전송 | G2 제공 | Flutter / 전역 user ID 대신 target_character_id·현재 버전, 일반 멤버 초대·충돌 기존관계 안내 |
| 신청·요청관리 | 신청·수신초대·보낸신청·그룹장 관리 | G2 제공 | Flutter / kind/state/permissions·만료·cursor 소비, 승인/거절/철회 후 관련 목록 갱신 |
| 신청금지·해제 | 그룹장 관리 | G2+표시 profile 구현 인계, 서버 미반영 | Flutter / subject_id·누적·차단·현재 표시 DTO 소비, 과거 참조 없는 스펙은 미확인 유지 |
| 초대코드 | 생성/공개/복사·입력확인/즉시가입 | G2 제공 | Flutter / 원문조회·재생성10분·폐기·OFF 의미 동기화, 현재권한 재조회 |
| 그룹장 이전·일반 탈퇴 | 상세 확인→이전, 별도 탈퇴 | G3 제공 | Flutter / membership UUID/CAS·최소 ACK·현재 GET·이전 후 새 revision 탈퇴 |
| 조건부 해산 | 1인·pending·활성 전용방 검사 | POST 구현 인계, 서버 미반영 | Flutter / 서버 원본 판정·CAS/ACK·성공 후 갱신 연결 |
| 멤버 추방 | 권한/목록·후속 요구 | remove POST 구현 인계, 서버 미반영 | Flutter / 새 membership 보호·기존 레이드 보존·갱신 연결 |
| 그룹 대표 변경 | 대표 needs_update·별도 선택 요구 | representative PUT 구현 인계, 서버 미반영 | Flutter / 그룹장 소유·활동 선택·noop·개인 대표/그룹명 보존 연결 |
| 자격 상실 정리·그룹장 복구승계 | 과거 별도 정책/부품 | 대응 공개 계약 미확인 | Backend Issue16 / 계정 자격 상실과 단순 그룹탈퇴 구분·후임 없음 경로 확정. 임의 승계 금지 |
| 그룹 레이드 생성·검색 | 현재 모집 기능의 그룹 연결 | 모집37 경로/원장 사용 | Flutter / 새 그룹 membership 갱신을 현재 모집의 context/후보·캐시와 연결, 기존 C/N·원ACK 유지 |
| 그룹 레이드 조회·공대장 관리 | 일반 모집 생성/상세 재사용 | 공통 raid-rooms GET·기존 참가보존 구현 인계, 서버 미반영 | Flutter / 실제 주차 공대장 안내→기존 상세. 별도 그룹장 변경 권한 없음 |
| 그룹 사용량 배지 | 설계34 확정 요구·기존 셸 재사용 | GET /v1/me/usage-limits 제공 | Flutter / used/limit·회원수명·변경 후 갱신. 실패를0으로 표시하지 않으며 미확인 표시는 구현 전 기존 셸과 통일 |
| 활동시각·이력/운영 정리 | 제품 §17 장기 요구 | 전체 운영 화면/삭제계약 미확인 | 별도 운영 파트 / 현재 화면에 필요한 활동시각 필드만 먼저 계약 확인, 삭제 구현은 별도 |

## 4. 화면·조회·명령 대응

| 사용자 진입 | 사용할 현재 API | 응답·연결 기준 |
|---|---|---|
| 내 그룹/그룹 상세 | GET /v1/me/groups, /v1/me/groups/{group_id} | GroupDetail·my_membership·capacity·permissions, 공개요약과 private상세 분리 |
| 그룹 검색/비회원 요약 | GET /v1/groups?q=, /v1/groups/{group_id} | GroupSummaryPage/GroupSummary. 서버 공개 GET은 익명도 가능하나 초대/신청 등 본인 명령은 로그인 세션 필요 |
| 생성/이름수정 | POST /v1/groups, PATCH /v1/groups/{group_id} | 생성201 GroupDetail, 이름변경200. 자동 이름은 name 생략(null 전송 금지), 정규화 정책 재사용 |
| 멤버 | GET /v1/groups/{group_id}/members | membership_id·revision·role·display·is_me. 현재멤버만 읽고 타회원 전역UUID를 만들어내지 않음 |
| 초대/신청 | GET /v1/groups/{group_id}/invite-candidates, POST .../invitations, POST .../applications | 정확 이름 저장자료 검색·선택 revision. 게임 API를 카드별로 호출하지 않음 |
| 요청현황/관리 | GET /v1/me/group-relations, /v1/groups/{group_id}/join-relations, /v1/group-relations/{relation_id} | 현재 actor·kind·권한 범위의 RelationPage/Relation, 그룹장 관리권한 분리 |
| 수락/승인/거절/취소 | POST /v1/group-relations/{relation_id}/accept 또는 approve/reject/cancel | accept는 GroupDetail, approve는 Relation. 승인자에게 상대 private membership을 가정하지 않음 |
| 금지/해제 | GET /v1/groups/{group_id}/blocked-subjects, POST .../join-subjects/{subject_id}/block 또는 unblock | 그룹별 subject 참조·revision, 그룹장 전용 |
| 코드관리 | GET/POST /v1/groups/{group_id}/join-code, POST .../regenerate 또는 revoke, PUT .../visibility | JoinCode 현재권한·code_id/revision·regenerate_available_at. null 원문을 오류나 빈 코드로 바꾸지 않음 |
| 코드입력/가입 | POST /v1/group-join-codes/preview, /join | preview 확인→현재 선택/버전으로 join. 코드 원문을 URL/로그에 넣지 않음 |
| 이전/탈퇴 | GET /v1/groups/{group_id}/management, POST .../leadership-transfer 또는 leave | 관리 권한·최소 ACK 후 현재 상세/멤버/관리 재조회 |

인계 추가 API는 GET members에 reader_profile=group-display-1, GET /v1/groups/{group_id}/members/{membership_id}/activity-characters, GET /v1/me/group-request-counts 및 /v1/groups/{group_id}/join-request-counts, GET management에 management_profile=group-management-1, POST /v1/groups/{group_id}/disband, POST /v1/groups/{group_id}/members/{membership_id}/remove, PUT /v1/groups/{group_id}/representative, GET /v1/groups/{group_id}/raid-rooms다. 기존 내 그룹/상세·차단목록도 reader profile을 명시한다. 모집 detail/plan의 보존 그룹 상태는 include_group_state=true에서만 제공한다. 이 목록은 고정 소스 제공이며 현재 서버 실행 가능 판정이 아니다.

기존 `/groups`와 하위 화면 진입점을 유지한다. 그룹별 상세·초대·신청관리·코드 화면도 BackendApp DI에 명시적으로 연결한다. 기존 AccountRepository의 구 Player/정수 로컬ID 조회로 canonical 자료를 우회하지 않고 현재 scoped 계정 읽기 계약을 사용한다. 기존 normalizer/표현 로직은 현재 정책과 맞는 부분만 재사용하되 document ID 검사만으로 UUID/서버 자격을 검증했다고 보지 않는다. 50개 고정 문구는 서버 유효 한도 기반 안내로 교체 대상이다.

### 조회 수명·재사용

그룹 기능의 현재 회원/환경 scope 안에서 목록·상세·멤버·요청·관리·코드를 각각 소유한다. 화면은 ViewModel 상태를 보고 Repository가 HTTP/DTO를 처리한다. watch*는 화면 호환을 위한 상태 통지로 바꿀 수 있으나 Firestore 실시간 보장·상시 폴링을 흉내내지 않는다. 수신 stream 유지 여부는 구현의 작은 내부 선택이며 새로운 서버 구독 계약을 만들지 않는다.

그룹 최초 진입·명시 새로고침·복귀·관련 명령 ACK가 갱신 지점이다. 내 그룹/요청 현황은 필요한 탭을 읽고 상세는 membership에 맞는 private 자료를 읽는다. 앱 초기 로딩에 그룹 전체·그룹별 멤버/요청을 강제 추가하지 않는다. 이미 받은 유효 표시 자료는 재사용하고 카드별 추가 요청을 하지 않는다. 그룹원 펼침도 승인된 최소 일괄조회 계약을 우선한다.

로그아웃/회원·환경 변경/화면 종료 뒤 늦은 응답은 무시한다. query·group·membership/권한세대가 다른 cursor/캐시를 섞지 않는다. 서버 page limit20/최대50, next_cursor를 따르며 로컬 필터 빈 결과를 마지막 페이지로 보지 않는다. CURSOR_STALE은 해당 목록 첫페이지 재조회로 유한 회복하고 실패는 명시 갱신으로 남긴다. 정확한 요청 배지 총수가 API에 없으면 첫페이지 길이를 전체 건수로 단정하지 않고 계약 확인 대상으로 둔다.

### 명령·식별자·원자성

actor는 서버 세션, 그룹은 group_id, 현재 가입은 membership_id, 요청은 relation_id, 차단은 subject_id다. 캐릭터 선택은 registration_id/character_id와 registration/ownership/roster/lifecycle 버전이다. 서버가 준 membership/target revision·limits/usage revision을 DTO별 필수 항목대로 사용하고 상대 전역회원ID나 client snapshot을 권한으로 전송하지 않는다.

이전/탈퇴 입력은 expected_group_revision·expected_members_revision·expected_membership_id/revision, 이전은 target_membership_id/revision을 추가한다. 이전 성공 후 기존 그룹장은 일반 멤버로 남고 새 조회값으로 별도 탈퇴한다. 재가입은 새 membership UUID이며 과거 탈퇴 ACK를 복구해도 새 관계에 명령을 재실행하지 않는다.

요청 key/body/대상/세션 scope를 확인 후 한 번 확정해 중복 입력을 막는다. 응답 유실은 동일 요청 재확인, 확정 거절은 명확히 안내하고 현재 상태를 재조회한다. 키나 본문을 임의로 바꾸어 반복 실행하지 않는다. 영속 원요청이 필요한 명령은 기존 공통 명령/보안 저장 수명을 재사용할 수 있는지 구현 전 검토하고, 코드 원문은 일반 로그·캐시·멱등 결과에 남기지 않는다. 과거 ACK는 현재 가입·권한·코드 증거가 아니다. 성공 뒤 조회 실패는 성공을 실패로 뒤집지 않고 갱신 재시도를 제공한다.

서버 transaction이 관계/멤버·인원·사용량·revision·요청종료·ACK를 원자 확정한다. 클라이언트는 기존 WritePlan을 서버 상태와 이중 적용하지 않는다. 최종 가입의 정원/현재활동·차단·24시간 만료 검사는 서버 권위다. 생성·신청과 달리 기존 membership 정리에 새로운1700/활동/대표 자격을 덧붙이지 않는다.

### 성공 후 갱신

| 성공 동작 | 갱신 범위 |
|---|---|
| 생성/가입확정/탈퇴/추방/해산 | 내 그룹·그룹 사용량·해당 상세/멤버/관리·관련 요청, 현재 모집 그룹선택/context·관련 캐시 무효화 |
| 초대/신청/거절/취소/차단 | 해당 관계·본인/관리 요청·차단 목록, 필요한 상세만 |
| 이름/대표 변경 | 해당 상세·내 그룹/표시요약·검색의 관련 캐시 |
| 이전 | 해당 상세·멤버·관리·요청관리·코드 원문 접근권한. 가입수는 새로 증가시키지 않음 |
| 코드관리 | 해당 코드현재값/권한/재발급 가능시각. 관계 가입은 join 성공 때만 갱신 |

그룹 해산·삭제 후에도 기존 참가방을 유지하고 사라진 그룹을 통한 신규 모집만 차단하는 제품 §13을 따른다. 일반 해산 허용 조건은 별개로 유지하며 자동 공개전환/재연결은 하지 않는다. 서버 FK/soft delete·원그룹 표시/배지의 최소 계약을 G-RAID에서 확인하고, 물리삭제/자료변환으로 먼저 해결하지 않는다.

실제 모집 참가 관계는 그룹 가입/탈퇴만으로 변경하지 않는다. 기존 참가방/기록·C/N 권한/원ACK를 보존한다. 그룹장 권한만으로 공개 전환·모집 해산·승인·편성·완료 권한을 부여하지 않는다. 그룹원 누구나 기존 자격/한도에 따라 그룹 레이드를 개설하며 관리는 해당 레이드 공대장 권한을 따른다.

## 5. 계약 보완과 미결정 구분

현재 제품과 다르게 바꿀 차후 수정안은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에 같은 항목을 갱신한다. 이 문서는 현재 연결 설계이며 별도 미래 수정안 사본을 만들지 않는다. 현재 서버 계약과 미제공 범위는 기능 상태 표와 아래 항목에서 관리한다. 사용자 지시로 확정 범위의 명세·개발·검증·인계를 요청했으며, 계약 질문만 하는 단계는 종료했다. 추가 제품결정이 필요한 부분만 분리한다.

| ID | 종류 | 확인된 차이·필요 답변 | 담당/협업·해소 조건 |
|---|---|---|---|
| G-DISPLAY | 구현 인계·Flutter 연결 대기 | 표시/활동/집계 제공, 과거 보석 count 재현 요구 불필요 | Flutter / §2.1 DTO 소비·오류 표시·모집 후보 연결 검증. Backend에는 구체 코드 차이만 회신 |
| G-MANAGE | 구현 인계·Flutter 연결 대기 | 해산/추방/대표 제공, 복구승계는 별도 | Flutter / 원자 명령·현재 권한·원ACK/새 관계 보호 연결. 개발환경 반영 준비는 Backend |
| G-RAID | 구현 인계·실제 연동 대기 | 공통 방목록/그룹 소멸 기존 참가보존 제공, 그룹장 별도 권한 제외 완료 | Flutter / 현재 모집과 연결·필터 갱신, Backend / 개발환경 반영 전 범위/준비 확인. G-RECOVERY와 분리 |
| G-RECOVERY | 제품 결정이 필요할 수 있는 후속 | 계정자격 상실 후 유효 후임이 없는 그룹의 운영 복구 | Backend가 현재 lifecycle 보장/기존 정책과의 차이를 먼저 제시한 뒤 필요한 사용자 결정만 질문. 임의 그룹삭제/승격 금지 |
| G-OPS | 별도 운영 후속 | §17 보관·정리 요구와 현재 감사/이력 원장 대응 | 운영 파트에서 정책/개인정보·보관 차이 검토, 이번에 자동삭제/DB변환 안 함 |

위 계약 확인은 기술 질문이며 이미 확정된15/5·즉시 이전·기존 레이드 유지·코드 정책을 다시 사용자 결정 대기로 두지 않는다. 기존 UX 변경이 필요하다는 답변이 오면 변경 전후·효과를 사용자와 협의한다. 현재 1차 개발 요청은 [Issue12](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6464116834)·[Issue16](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464117245)이며 인계/회신 대기는 NEXT_WORK에서 관리한다. 이전 계약질문은 당시 경과다. 기존 API 재개발·운영배포·자료초기화는 요청하지 않았다.

### 실제 Flutter 연결 구조

GroupContract는22b16207 OpenAPI에서 그룹38동작/연결70스키마를 추출한 고정 검증 projection을 사용한다. GroupRepository는 Dio/현재 AccountReadSession·환경을 확인하고 profile·요청/응답·cursor를 검증한다. 보안 journal은 그룹 namespace로 분리하며 원 key/raw body를 먼저 저장하고 미확정 복구·확정거절 정리·ACK저장 후 해제를 처리한다. ACK는 권한으로 보관하지 않고 저장 실패/회원 전환 경계도 현재 화면에 성공 권한을 주지 않는다.

BackendGroupPage와 ViewModel은 기존 내그룹/요청 탭·검색/생성·카드·활동 펼침·관리 진입을 현재 DTO로 연결한다. GroupMember/Player Projection·로컬 계정조회/클라이언트 WritePlan은 일반 경로에서 실행하지 않는다. 활동 캐릭터 선택은 scoped runtime의 현재 인증/소유·활동·revision 자료를 사용한다. 이름·대표·요청/차단·코드·이전/탈퇴·추방/해산 명령은 각각 인계 경로/CAS로 실행한다. 코드 평문은 일반 캐시/로그 없이 메모리·필요한 원요청 secure 저장으로 한정한다.

앱 소유 GroupChanges는 그룹변경을 모집 생성·검색에 전달한다. 모집 원요청/다른 초안·선택 주차는 보존하고 그룹/context/후보·결과 페이지를 갱신하며 실제 alias/membership·캐릭터 후보로 선택을 재대조한다. 보존 그룹 상태는 일반 상세의 application-display 경로와 참가자의 membership detail/plan 경로 모두 include_group_state=true를 명시하고 검증된 확장만 표시 데이터로 전달한다. 기존 beta 응답/명령 parser와 원ACK는 변경하지 않는다.

### 모집 최초 연결·목록 표시 — 6dac5ab2 소비 계약

일반 앱 BackendApp DI는 검색/내 참가·신청 목록에 include_group_state=true를 query로 지정한다. POST 검색 본문은 기존 그대로다. 응답 root group_states와 room_groups의 UUID·상태·중복/페이지 대응을 검증해 카드 표시 metadata로 보존한다. 신청 admission_origin은 과거 스냅샷이므로 현재 연결로 덮지 않는다. content=null인 기록은 현재 참가자를 합성하지 않는다. 소속 밖 공개 모집도 서버 이름을 표시하며 ended 보존 이름과 unavailable/null을 구분한다. 카드 이름 목적의 내 그룹 조회와 카드별 조회는 없다.

미연결 방의 기존 공통설정에서 현재 내 그룹을 선택하면 common-context의 target_group_id로 재검토한다. root target_group(group/members/membership revision·permission)을 선택 UUID와 대조하고 확인 서명에 포함한다. 선택 그룹·영향 주차·기존 참가/신청/예약 보존을 확인한 뒤 기존 common-settings PUT에 group_id/scope=group/expected_group_revision을 함께 보낸다. 교체/해제는 거절하고, 연결 뒤 기존 전체공개/전용 왕복은 유지한다. 대상/권한/revision 변경은 재확인하며 미확정 명령에는 원본문·키를 유지한다. 성공 ACK 후 GroupChanges로 그룹/필터/context/후보와 목록을 무효화하고 기존 주차별 상세 갱신을 사용한다. 후속 조회 실패는 새 명령을 만들지 않는다.

소속 배지는 일반/application-display의 data.members와 membership-actions의 data.content.data.members를 같은 상세 변환·렌더링으로 전달한다. 조회자 소속에 따른 숨김은 확인되지 않았다. 대상별 true/false 보존, null/누락 거절과 history content=null 유지를 시험한다. 해당 제보의 실기기 재현 없이 해결 완료로 판정하지 않으며 현재 결과는 DEV_LOG/기기 인수는 NEXT_WORK에서 관리한다.

## 6. 구현 단계·회귀와 인수

### 초대 후보 표시 후속 — c3814452 소비 설계 (2026-10-29)

담당 Flutter. 기준은 Backend c38144528c42eda7fcf2912fa412d3a005fc68e7 OpenAPI·display_schemas의 DisplayInviteCandidates/DisplayInviteCandidate와 [구현 인계](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6496536145)다. 2026-10-30 Flutter 조회/역할표시·검색 수명 연결과 직접18PASS/그룹 분석0을 확인했다. Backend 실행5d24244b/DB0034의 실제 반영 인계도 확인했으며 이후 기존 그룹 기능은 사용자 전체 정상 인수했다. 기본 업무 계약22b16207을 전면 교체하는 작업이 아니라 초대 후보 GET의 opt-in 표시 확장만 소비한다.

- 계약: 기존 GET invite-candidates에 character_name과 reader_profile=group-display-1을 명시한다. 응답 profile/evaluated_at/items와 기존 후보필드+character_spec을 검증한다. 고정 wire projection은 해당 query/응답 및 추가2 DTO를 c3814452에 맞춰 갱신하고 기존 component/명령 계약이 바뀌지 않는지 diff로 확인한다. profile 누락 또는 구 DTO를 성공으로 수용하는 fallback은 두지 않는다. 기존 GroupRepository의 profile 일치 검사와 strict DTO 검증을 유지한다.
- 화면: 초대 후보 카드의 이름·서버·직업·초대 버튼/진입은 유지한다. 단일 combat_power 표시를 기존 groupSpecText(character_spec)의 역할별 표시로 교체한다. dealer/support 수치를 합치거나 최댓값으로 대표하지 않으며 마지막 성공 수치와 현재 분석·보석/아크그리드 오류·warning/null 의미를 보존한다. 숫자가 없다는 이유로 재인증·새 저장을 요구하지 않는다. 후보 수치는 저장 자료로, 현재 실시간 게임 수치 보장이 아니다.
- 검색/수명: Flutter는 앞뒤 공백 제거만 유지하고 ASCII 대소문자 무시 정확검색은 서버에 맡긴다. 부분검색·와일드카드·로컬 소문자화/후보별 외부조회는 추가하지 않는다. 새 검색 시작/실패 시 과거 후보를 새 결과처럼 남기지 않고 입력·조회 세대와 회원/환경을 묶어 늦은 결과를 폐기한다. 기존 서버/UUID 순서·최대50건·cursor 없음은 유지한다.
- 초대 쓰기: 기존 target_character_id·ownership/lifecycle revision·group/membership revision과 원본문/멱등키 흐름은 그대로다. character_spec이나 단일 전투력을 권한/명령 입력으로 보내지 않는다. 초대 대상은 현재 인증·등록된 캐릭터의 소유 회원이며 활동선택 조건을 새로 추가하지 않는다. 대표 선택 레벨 정렬399b66ab와 전송 결과 안내7a4dd636는 보존한다.
- 자동검증: 명시 query와 새 DTO 수용, profile 불일치/필드 누락 거절, 역할별 성공+현재 오류/자료없음 표시, 구 DTO fallback 금지, 검색 연속 입력/실패·회원전환 후 늦은 결과 폐기를 직접 시험한다. 기존 초대 명령 원요청/ACK·성공 후 갱신 시험을 회귀로 사용한다. 기본은 그룹 직접 시험·변경 lib/test 분석·포맷/diff검토이며 앱 공용 동작은 이번에 바꾸지 않는다.
- 실행 순서: 고정계약 diff→초대 조회/profile·표시·검색 수명 연결→직접 시험/분석→커밋·푸시 및 Issue12 소비 결과 회신. Backend가 이번 수정의 개발환경 실행SHA/0034 유지·확인/미확인을 인계한 뒤 사용자가 대소문자 다른 동일 이름 조회→후보 역할별 전투력→초대 전송/수락을 확인한다. 서버 미반영 중 새 profile을 현재 서버에 강제 시험하지 않는다. 구현 준비와 서버 교체는 별도이며 이 설계가 배포 지시는 아니다.
- Penpot: 실제 연결한 후보의 역할별 수치·상태·초대 결과를03 기존 직접초대 화면/설명에서 갱신한다. 자료없는 후보도 미확인으로 구분하고 앱과 다르게 정상값을 합성하지 않는다. 화면 확인 전02 이동은 하지 않는다.

완료 조건은 고정 opt-in 계약의 실제 Flutter 연결·직접검증/인계, 새 서버 반영 확인 후 사용자 후보검색/표시·초대 흐름 확인이다. 새 DB·중복 전투력 저장·게임 API 호출·대표 선택 정책 변경·전체 앱 리디자인은 제외한다.

1차 Penpot 러프디자인은03의 기존 그룹 메인 보드(0f0035d1-2d8f-8071-8008-dbabf5c8d408)에8개 흐름 섹션/16개 화면과 공통 상태 가이드로 작성했다. 제품의 새 확정 정책/구현 완료가 아니라 사용자 검토 대상이다. 화면별 API 제공/미제공 경계는 이 문서의 표를 따르고, 메인/섹션에 사용자 흐름·결과/권한과 구현 의도를 표시한다. 실제 보드 링크·현재 다음 행동은 NEXT_WORK, 디자인 운영은 기존 공통 지침을 따른다.


현재 승인된 문서 파트와 미래 구현을 구분한다. 이후 구현 착수 시 최신 서버 SHA/실행계약·회신을 확인하고 아래 단계별 연결/자동검증/사용자 인수를 구분해 기록한다.

우선 완료할 사용 흐름은 제품 §2의 `초대·가입 → 그룹원 활동 캐릭터 확인 → 모집 그룹/그룹원/캐릭터 필터 → 기존 참가·신청`이다. 그룹 관리 API 전체 완료를 이 독립 흐름의 선행조건으로 두지 않는다. 기존 모집37의 그룹 후보/필터 연결을 재사용하고, 새 그룹 가입·탈퇴 뒤 후보와 필터가 현재 소속으로 갱신되는지 확인한다. 완료 기준에는 원하는 그룹원·특정 캐릭터가 참가한 모집을 찾고 기존 상세/참가 흐름으로 이어지는 실제 연결을 포함한다. 관리·복구 경계가 핵심 기능처럼 시안을 점유하지 않도록 같은 보드에서 흐름을 정리한다.

1. 조회·생성·이름/멤버 표시: G1 HTTP/계정 scope/DTO, 탭·하위 Router/DI, 사용량과 생성 성공 갱신. G-DISPLAY 미해소 기능은 연결 대기이며 전체 상세 완료로 보고하지 않는다.
2. 관계·코드: G2·권한/요청 수명·Relation와GroupDetail·코드 원문 수명, 기존 카드·확인 동작 연결.
3. 이전·탈퇴: G3·새 membership/최소 ACK·새 revision, 관련 사용량/모집 context 갱신.
4. 관리·그룹 레이드: 인계된 G-MANAGE/G-RAID 계약으로 해산·추방·대표·그룹 모집 조회와 기존 공대장 관리 연결. 단순 서버 모드 변경이나 미지원 경로 호출로 완료하지 않는다.
5. 일반 main→DI/Router→조회/명령→ACK→갱신까지 최종 검증하고 기능별 사용자 기기 인수 후 통합 판단. 소분류 문서 파트 종료는 dev/main 병합 조건이 아니다.

자동검증은 private 비회원/역할 위조·마지막 자리/동시 수락·초대/신청 충돌·24시간 만료·차단 우회·코드 OFF/재발급10분/폐기·원요청/ACK/rollback·탈퇴/재가입/과거 ACK·권한 변경·회원 전환/늦은 응답·cursor·조회실패 갱신에 집중한다. 서버가 이미 검증한 동일 코드 결과를 반복 요청하지 않고 새 구현/계약 변경의 직접 경계를 검증한다.

회귀는 기존 계정 카드/대표·활동/로그인, 일반/그룹 단일·묶음/C/N 모집·검색후보/참가·권한·완료·기록·원요청 복구다. DI/공용 계약 영향이 표적 범위로 설명되지 않으면 최종 상태에서 전체 flutter test/analyze로 확대한다. 이번 문서만으로 Flutter 시험을 반복하지 않는다.

실기기는 구현과 서버 준비 뒤 사용자가 생성→상세, 초대/신청/코드의3경로, 요청·차단, 이전→별도탈퇴, 해산 조건 안내·그룹 레이드 연결을 소수 항목으로 확인한다. 기존 로그인/첫 인증과 완료한 모집 전체 시험을 반복 요구하지 않는다. 지금 실회원 명령·설치/조작·신규 기기 시험을 실행하거나 통과로 기록하지 않는다.

설계 문서 완료는 전체 기능의 근거·현재상태·담당·다음행동·완료조건과 기술/제품 미결정 구분을 갖춘 상태다. 서버 답변이 필요한 상세 계약을 구현 확정 또는 기능 완료로 주장하지 않는다.
