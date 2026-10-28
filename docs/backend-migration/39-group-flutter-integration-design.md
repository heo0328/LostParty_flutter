# 그룹 전체 흐름 — Flutter 연결 설계

2026-10-28 / 설계 문서화·Backend 1차 개발 요청 게시 / Flutter 그룹 탭 연결 미착수. Flutter 기준 dev `bdfe0edf`, Backend 조회 기준 dev `1b6f57bb2cfebc5c8ce9f796d59beea0e05cc1dd`.

## 1. 기준·포함/제외

[그룹 제품 계약](../product/GROUP_PRODUCT_FLOW.md), [정책09 D08](09-migration-decisions.md#d08-개발--베타--운영-데이터-수명--사용자-확정), [한도34](34-member-limits-and-room-restrictions.md), [최신 모집37](37-raid-scheduling-and-multi-raid-planning.md), [품질/UX](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md)를 함께 적용한다. 현재 자체 Backend·단일 Google 회원·canonical UUID로 개발한다. 베타 직전 초기화는 별도 실행이며 자료 호환/이전 리허설·빈 환경을 선행조건으로 만들지 않는다.

그룹 전용도 일반 레이드의 생성·참가·신청·일정·완료 흐름을 그대로 사용한다. 차이는 신규 목록/참가/신청의 그룹 소속 범위다. 공개범위 왕복·기존 참가/신청 보존·참가자 모두가 확인하는 소속 배지와 그룹 문제/독립 제한 구분은 제품 계약 §4/§9.2/§13을 단일 기준으로 삼는다. 이를 별도 그룹 모집 절차로 재설계하지 않는다.

전체 그룹 기획/연결 설계에는 생성·검색·요청·코드·차단·이름/대표 변경·멤버표시·추방·이전·탈퇴·해산·그룹 레이드 관리를 포함한다. 이번에는 기능코드/Router/DI·서버/DB·실기기·배포·자료 삭제를 변경하지 않는다. 웹소켓·공지·통계화면·BM·운영자 삭제 자동화는 별도 후속이다. 제품 UX를 API 준비 상황에 맞춰 축소하지 않는다.

## 2. 확인 근거와 과거 구현

- 현재 일반 앱: `lib/main.dart` → BackendApp. `lib/app/backend_app.dart`의 `/groups`·검색·생성·코드 가입은 pending이다. 기존 화면이 남았다는 이유로 현재 기능 완료로 표시하지 않는다.
- 잔존 구현: `lib/features/group/presentation`의 탭/검색/생성/상세/초대/신청/코드 화면과 ViewModel, Domain의 이름 정규화/Validator·역할/관계 모델. 기존 탭은 내 그룹·요청 현황, 상세는 공개요약과 membership 확인 후 private 멤버 읽기를 분리한다.
- 과거 저장: GroupReadRepository의 watchMyGroups/watchMyRequests와 Player 역방향 Projection, WritePlan의 요청·membership·카운터·활동시각 Transaction을 Firestore Repository/Rules가 실행했다. 현재 새 서버에서 클라이언트 WritePlan을 실행하거나 Firestore 원장을 복원하지 않는다. 상태 전이/검증 의도만 서버 계약과 대조한다.
- 표시: 기존 GroupMemberDisplay에는 전투력·아이템레벨·보석 검증 표시가 있고 상세에서 멤버의 활동 캐릭터를 펼쳤다. 새 G1 응답에는 이를 채울 전체 필드가 없다. 표시값을0으로 채우거나 남의 로컬 계정DB를 조회해 메우지 않는다.
- 과거 기기 확인·Task-11 완료/후속 및 D2/D3 기록은 [DEV_LOG](../project/DEV_LOG.md#group-design-20261028)에 모았다. 과거8~9월 Firebase 인수는 현재 Backend 인수가 아니다.

Backend의 이전 경로404는 문서 이동이었다. 위 고정 SHA의 다음 파일을 읽고 현재 Python Router/Schema 및 JSON 형태의 `openapi/two-cycle.openapi.yaml` 경로·DTO를 대조했다.

- [현재 그룹 기능 지도](https://github.com/heo0328/lostparty-backend/blob/1b6f57bb2cfebc5c8ce9f796d59beea0e05cc1dd/docs/features/groups/README.md)의 discovery/joining/management.
- `docs/archive/work-records/features/groups/ISSUE_12_GROUP_G1_SPEC.md`, `ISSUE_12_GROUP_G2_SPEC.md`, `ISSUE_16_GROUP_G3_SPEC.md`는 이력 명세이며 현재 소스/OpenAPI와 함께 읽는다.
- `app/groups/router.py`, `admission_router.py`, `schemas.py`, `admission_schemas.py`, `management.py`: 현재 disband=false/`GROUP_RECRUITMENT_STATE_UNAVAILABLE`, 해산 write 경로 없음 확인. 모집이 구현됐다는 이유로 해산까지 활성화됐다고 추정하지 않는다.
- [Issue12 이전 소비 회신](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6259124455), [Issue16 이전 통합/미완료](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6262944673). 현재 소스 조회와 개발 서버 실행 버전/실회원 인수는 별개이며 이번에는 서버를 조작하지 않았다.

### 2.1 1차 Backend 회신 확인 — 설계와 실제 구현 구분

2026-10-28 [Issue12 회신](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6464713065)·[Issue16 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464713503)의 설계 SHA는 `92c1702f84720ce76789f100bf0acdb1efd29c82`(feat/group-management)다. [표시 제안](https://github.com/heo0328/lostparty-backend/blob/92c1702f84720ce76789f100bf0acdb1efd29c82/docs/features/groups/discovery/display-contract-proposal.md)·[관리 제안](https://github.com/heo0328/lostparty-backend/blob/92c1702f84720ce76789f100bf0acdb1efd29c82/docs/features/groups/management/phase-one-contract-proposal.md)을 확인했다. app/alembic/openapi/tests 변경0, 서버/DB 반영·실회원/Flutter 인수 미실행 보고다. 아래 기존 제공 API 표에 제안 endpoint를 실행 가능 경로로 추가하지 않는다.

- 표시: reader_profile=group-display-1 opt-in, 현재 membership별 활동 캐릭터 조회, canonical/유효 소유·활동 자료, 역할별 마지막 성공 수치와 현재 분석 오류·null/출처를 분리한다. 오래된 차단 subject를 이름으로 재연결하지 않는다. 기존 gemValidationSnapshot과 integrity displayLabels의 정확한 issues/code 매핑은 Flutter가 실제 DTO 인계 시 대조한다. 저장되지 않은 원본/정상 상태 합성은 요구하지 않는다.
- 집계: 실효 pending·현재 권한 기준, action_required는 받은 초대와 처리할 가입 신청의 relation 합집합이다. 보낸 신청·관리 초대는 별도 현황이며 필수 처리 수에 더하지 않는다. 조회 실패는0건이 아니다. last_activity는 실제 의미 있는 쓰기만 갱신하며 과거 자료가 없으면 null이다.
- 그룹 관리: management profile opt-in, CAS·원ACK·코드/관계/사용량 원자 처리, 실제 활성 전용방 검사·불명확 count=null 방향을 대조했다. 추방·대표·조건부 그룹 해산은 미구현이다. 그룹 자체와 레이드 생명주기 분리·기존 참가 보존은 유지한다.
- 권한 정정: 제안의 비참가 그룹장 command-context/make-public/end는 제품 §9.3의 최신 사용자 지시에 맞춰 제외해야 한다. 그룹장1인/다인방 강제종료 범위를 고르는 질문으로 축소하지 않는다. 그룹원 누구나 개설·해당 레이드 공대장 관리가 확정 기준이며, Backend는 기존 제안 항목을 교체하고 독립 범위의 명세/구현 인계를 진행한다. G-RECOVERY의 실제 자격상실/후임 없음은 별도 미결정이다. [Issue16 권한 정정 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464943488) 게시·재조회 완료, Backend 제안 교체/구현 인계는 대기다.

## 3. 기능별 상태·담당·완료 기준

그룹 탭·관리 기능의 현재 일반 Flutter 연결과 신규 Backend 실기기 인수는 미완료다. 기존 모집의 그룹 레이드 생성·검색은 이미 연결돼 있으며 아래 표의 해당 행은 새 그룹 membership/갱신과의 추가 연계를 뜻한다. 서버 제공은 위 고정 소스 확인 수준이다. 상세 제품 정책은 제품 문서에만 두며 이 표는 남은 구현을 관리한다.

| 기능 | 기존 부품/흐름 | 현재 Backend | 담당·다음 행동 / 완료 기준 |
|---|---|---|---|
| 내 그룹·공개 검색·상세 | 탭/검색/상세·ReadRepository | G1 제공 | Flutter / HTTP·페이지·권한 연결, 실제 Router→조회→표시 및 복귀 갱신 |
| 생성·이름 변경 | 생성 VM·정규화, 수정은 화면 연결 대조 필요 | POST/PATCH 제공 | Flutter / 현재 소유/활동 선택·버전·한도 소비, 생성 후 상세·목록/사용량 갱신 |
| 멤버 카드·활동 캐릭터 펼침 | 카드/표시 DTO·기존 계정 조회 의존 | G1은 membership/역할/이름/직업/가입일/is_me만 제공 | Backend 계약 확인→Flutter / 기존 스펙·활동 캐릭터 공개 범위/일괄조회 대응 확정·카드 유지 |
| 직접 초대 | 정확 이름 검색→대상 확인→전송 | G2 제공 | Flutter / 전역 user ID 대신 target_character_id·현재 버전, 일반 멤버 초대·충돌 기존관계 안내 |
| 신청·요청관리 | 신청·수신초대·보낸신청·그룹장 관리 | G2 제공 | Flutter / kind/state/permissions·만료·cursor 소비, 승인/거절/철회 후 관련 목록 갱신 |
| 신청금지·해제 | 그룹장 관리 | G2 제공, 표시 스펙 일부 부족 | Flutter·Backend / subject_id·누적·차단 소비, 부족한 카드 자료는 기존 계약에서 보완 대조 |
| 초대코드 | 생성/공개/복사·입력확인/즉시가입 | G2 제공 | Flutter / 원문조회·재생성10분·폐기·OFF 의미 동기화, 현재권한 재조회 |
| 그룹장 이전·일반 탈퇴 | 상세 확인→이전, 별도 탈퇴 | G3 제공 | Flutter / membership UUID/CAS·최소 ACK·현재 GET·이전 후 새 revision 탈퇴 |
| 조건부 해산 | 1인·pending·활성 전용방 검사 | write 미제공·현재 거절 reason | Backend Issue16 / 현재 실제 모집 원본을 사용하는 검사/원자 해산 계약 제공 후 Flutter 연결 |
| 멤버 추방 | 권한/목록·후속 요구 | API 미제공 | Backend Issue16 / 그룹장 권한·관계종료·초대/한도·기존 레이드 보존 계약→Flutter 연결 |
| 그룹 대표 변경 | 대표 needs_update·별도 선택 요구 | status만 제공·변경 API 없음 | Backend Issue16 / 새 대표 소유/활동·revision·기존 그룹 정체성 보존→Flutter 연결 |
| 자격 상실 정리·그룹장 복구승계 | 과거 별도 정책/부품 | 대응 공개 계약 미확인 | Backend Issue16 / 계정 자격 상실과 단순 그룹탈퇴 구분·후임 없음 경로 확정. 임의 승계 금지 |
| 그룹 레이드 생성·검색 | 현재 모집 기능의 그룹 연결 | 모집37 경로/원장 사용 | Flutter / 새 그룹 membership 갱신을 현재 모집의 context/후보·캐시와 연결, 기존 C/N·원ACK 유지 |
| 그룹 레이드 조회·공대장 관리 | 일반 모집 생성/상세 재사용 | 그룹장 별도 변경 권한 제안은 최신 사용자 기준과 불일치 | Backend Issue16 / 그룹원 누구나 생성·해당 레이드 공대장만 기존 관리, 해산검사/방 안내·기존 참가보존 계약 정정 후 Flutter |
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

기존 `/groups`와 하위 화면 진입점을 유지한다. 그룹별 상세·초대·신청관리·코드 화면도 BackendApp DI에 명시적으로 연결한다. 기존 AccountRepository의 구 Player/정수 로컬ID 조회로 canonical 자료를 우회하지 않고 현재 scoped 계정 읽기 계약을 사용한다. 기존 normalizer/표현 로직은 재사용하되 document ID 검사만으로 UUID/서버 자격을 검증했다고 보지 않는다. 50개 고정 문구는 서버 유효 한도 기반 안내로 교체 대상이다.

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
| G-DISPLAY | 서버 계약 보완 | 기존 멤버 스펙/활동 캐릭터 펼침·금지목록 스펙·활동시각·요청배지 총수와 현재 DTO 차이 | Issue12 / 기존 허용 공개범위 안의 일괄 DTO 또는 재사용 endpoint/식별자·cursor·수명 제시. 모집용 후보토큰을 일반 그룹열람 권한으로 재사용하지 않음 |
| G-MANAGE | 서버 미구현 | 현재 해산 write 없음, 추방/대표변경/복구승계 없음 | Issue16 / 기존 정책의 권한·CAS·ACK·한도회복·새 관계 보호와 실제 모집 검사 계약/구현 인계 |
| G-RAID | 최신 사용자 기준으로 제안 정정 필요 | 그룹장 별도 context/make-public/end 제안 제외. 그룹원 누구나 개설·해당 레이드 공대장 관리, 실제 방/주차 상태 및 그룹 소멸 후 기존 참가보존·신규 접근 차단 | Issue16 / 기존 모집 권한 재사용·해산검사/방 안내 계약 정정·인계. 마지막1인/다인방 그룹장 강제종료 선택은 폐기한 질문이며 제품 결정 대기가 아님 |
| G-RECOVERY | 제품 결정이 필요할 수 있는 후속 | 계정자격 상실 후 유효 후임이 없는 그룹의 운영 복구 | Backend가 현재 lifecycle 보장/기존 정책과의 차이를 먼저 제시한 뒤 필요한 사용자 결정만 질문. 임의 그룹삭제/승격 금지 |
| G-OPS | 별도 운영 후속 | §17 보관·정리 요구와 현재 감사/이력 원장 대응 | 운영 파트에서 정책/개인정보·보관 차이 검토, 이번에 자동삭제/DB변환 안 함 |

위 계약 확인은 기술 질문이며 이미 확정된15/5·즉시 이전·기존 레이드 유지·코드 정책을 다시 사용자 결정 대기로 두지 않는다. 기존 UX 변경이 필요하다는 답변이 오면 변경 전후·효과를 사용자와 협의한다. 현재 1차 개발 요청은 [Issue12](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6464116834)·[Issue16](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6464117245)이며 인계/회신 대기는 NEXT_WORK에서 관리한다. 이전 계약질문은 당시 경과다. 기존 API 재개발·운영배포·자료초기화는 요청하지 않았다.

## 6. 구현 단계·회귀와 인수

1차 Penpot 러프디자인은03의 기존 그룹 메인 보드(0f0035d1-2d8f-8071-8008-dbabf5c8d408)에8개 흐름 섹션/16개 화면과 공통 상태 가이드로 작성했다. 제품의 새 확정 정책/구현 완료가 아니라 사용자 검토 대상이다. 화면별 API 제공/미제공 경계는 이 문서의 표를 따르고, 메인/섹션에 사용자 흐름·결과/권한과 구현 의도를 표시한다. 실제 보드 링크·현재 다음 행동은 NEXT_WORK, 디자인 운영은 기존 공통 지침을 따른다.


현재 승인된 문서 파트와 미래 구현을 구분한다. 이후 구현 착수 시 최신 서버 SHA/실행계약·회신을 확인하고 아래 단계별 연결/자동검증/사용자 인수를 구분해 기록한다.

1. 조회·생성·이름/멤버 표시: G1 HTTP/계정 scope/DTO, 탭·하위 Router/DI, 사용량과 생성 성공 갱신. G-DISPLAY 미해소 기능은 연결 대기이며 전체 상세 완료로 보고하지 않는다.
2. 관계·코드: G2·권한/요청 수명·Relation와GroupDetail·코드 원문 수명, 기존 카드·확인 동작 연결.
3. 이전·탈퇴: G3·새 membership/최소 ACK·새 revision, 관련 사용량/모집 context 갱신.
4. 관리 미제공 기능·그룹 레이드: G-MANAGE/G-RAID 계약 인계 후 해산·추방·대표/승계·그룹 모집 조회와 기존 공대장 관리 연결. 단순 서버 모드 변경이나 미지원 경로 호출로 완료하지 않는다.
5. 일반 main→DI/Router→조회/명령→ACK→갱신까지 최종 검증하고 기능별 사용자 기기 인수 후 통합 판단. 소분류 문서 파트 종료는 dev/main 병합 조건이 아니다.

자동검증은 private 비회원/역할 위조·마지막 자리/동시 수락·초대/신청 충돌·24시간 만료·차단 우회·코드 OFF/재발급10분/폐기·원요청/ACK/rollback·탈퇴/재가입/과거 ACK·권한 변경·회원 전환/늦은 응답·cursor·조회실패 갱신에 집중한다. 서버가 이미 검증한 동일 코드 결과를 반복 요청하지 않고 새 구현/계약 변경의 직접 경계를 검증한다.

회귀는 기존 계정 카드/대표·활동/로그인, 일반/그룹 단일·묶음/C/N 모집·검색후보/참가·권한·완료·기록·원요청 복구다. DI/공용 계약 영향이 표적 범위로 설명되지 않으면 최종 상태에서 전체 flutter test/analyze로 확대한다. 이번 문서만으로 Flutter 시험을 반복하지 않는다.

실기기는 구현과 서버 준비 뒤 사용자가 생성→상세, 초대/신청/코드의3경로, 요청·차단, 이전→별도탈퇴, 해산 조건 안내·그룹 레이드 연결을 소수 항목으로 확인한다. 기존 로그인/첫 인증과 완료한 모집 전체 시험을 반복 요구하지 않는다. 지금 실회원 명령·설치/조작·신규 기기 시험을 실행하거나 통과로 기록하지 않는다.

설계 문서 완료는 전체 기능의 근거·현재상태·담당·다음행동·완료조건과 기술/제품 미결정 구분을 갖춘 상태다. 서버 답변이 필요한 상세 계약을 구현 확정 또는 기능 완료로 주장하지 않는다.
