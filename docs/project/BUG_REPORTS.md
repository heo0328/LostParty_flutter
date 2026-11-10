# 버그 리포트

## BUG-035. 출발 전 모집 마감 무렵 기존 참가 조작 전체 비활성·빈 일정 (2026-11-10)

상태: 사용자 원요청 복구 성공 보고를 받은 뒤 승인된 UI/오류 수명 개선을 Native 일반 경로에 구현했다. 최종 전체2,913PASS·분석0, 직접80개는 전체 수에 포함한다. 카드 디자인은 사용자 결정으로 차후 Penpot에서 확인하며 실제 새 카드의 기기 동작은 미확인이다. 이 확인을 위한 장애 재현/미리보기 개발은 요청하지 않는다. [Issue48](https://github.com/heo0328/lostparty-backend/issues/48)은 Backend가2026-11-10 completed로 종료했으며 상태 재조회를 확인했다. Penpot 디자인은 별도 차후 확인으로 남긴다. 사용자 지시로 이번 누적 구현·시험·문서를 목적 브랜치에 커밋하고 로컬 dev에 통합하는 보관 범위다. 원격 push와 main 반영·배포는 별도다.

원인: 이전 batch pending의 공용 canAct=false가 다른 방/양 주차 조작과 일정 표시 조회까지 막았다. 복구 이름 표시용 plan 조회는 이미 탈퇴한 원방에서403을 받으면 공용 failure/feedback을 바꿔 성공 뒤에도 오류를 표시했다. 사용자 request_id 8f48831f-22b3-40c6-b071-f50e273e2fd5는20:49:11 KST GET plan403이다. 직전20:49:09 batch 개인 완료POST200과20:49:10 weekly-summary200, 새 원완료 결과0건은 기존 ACK 재생 및 사용자 조작 회복 보고와 일치한다. 다른 방 원장이 합쳐졌다는 근거는 없다. 최초19:30/19:50 발생 시각의 정확한 마감 인과관계는 미확정이다.

수정: 정상/축약/조회 실패 상세·계정의 주간 참가 영역·현황/빈 목록에 붉은 공통 카드와 채워진 해결 버튼을 제공한다. 원대상·종류·선택 개수, 미확정/조회 실패/성공 후 갱신 실패/저장 실패를 구분하며 자동 팝업은 없다. 일정 표시 조회는 화면 소유 오류/회원·환경·세대 검증을 유지해 pending 중에도 실행한다. 복구 이름 전용 조회를 제거하고 기존 단건/batch 원문·키/선택·ACK 및 단일 journal을 보존한다. 카드 복구는 현재 화면·선택 주차를 유지하며 ACK 뒤에는 조회만 재시도한다.

정책/상태: 설계37의 기본출발30분 전 신규 모집 마감과 기존 참가자의 완료/탈퇴/해산·조회는 구분한다. [Backend6767569951](https://github.com/heo0328/lostparty-backend/issues/48#issuecomment-6767569951)로 시간/주차·상태/탈퇴 후 plan403 정책 확인이 완료됐고 Native가 수용했다. 취소된 본인 참가의 plan403은 성공 ACK를 무효화하지 않는다. Native 담당 현황/실제 연결 위치도6767533595 요청에 맞춰 #48 본문에 보완했다. 추가 서버 계약/수정 대기는 없다. 서버/DB 쓰기·자료 초기화/자동 기기 조작·배포는 없으며 기존 정상화/계정 복구와 이번 UI 인수를 구분한다. 이미 회복한 장애를 다시 재현할 필요는 없다. 조사 경과·검증 로그는 DEV_LOG, 현재 실행/인수는 NEXT_WORK를 따른다.

## BUG-034. 묶음 개인 완료·공대장 승계 후 INVALID_RESPONSE (2026-11-10)

상태: Native 수정·최종 전체2,911PASS/분석0 완료 후 2026-11-10 사용자가 수정 앱의 내 계정 표시 정상화를 확인했다. 보고된 계정 회색 표시 복구는 해소됐으며 모든 미보고 경계의 기기 재시험까지 통과했다고 확대하지 않는다. 사용자는 다른 일반 흐름 대부분 정상과 계정의 묶음 영향 안내 정상도 보고했다. A 캐릭터로 묶음 생성→1번 완료→남은 참가를 B로 변경→2번 개인 완료·탈퇴 시 승계 안내 후 INVALID_RESPONSE다. 승계는 반영됐으며 계정에는 A의1/2번 회색 표시와 현황의 이전 참가 목록/상세 진입 이상이 관찰됐다. 이후 목록 재조회에서는 사라졌으나 회색 표시는 남았다. 후계자의 마지막 참가 종료는 정상이다. 확인한 종료 참가의 assignment는 completed/ended·주간 활성 점유 없음이었으며, 해당 회원의 다른 참가가 있어 전체 점유0으로 보고하지 않는다. 사용자 A/B와 읽은 원ACK의 정확한 식별자 대조는 하지 않았으므로 전체 계정 원장 정상으로 확대하지 않는다. 계정 표시는 후속 사용자 정상화 보고를 반영한다. 이전 목록의 모든 상세 상태까지 별도 보고된 것으로 추정하지 않는다.

직접 근거: dev HTTP19:46:19/19:46:29 KST batch-personal-completion-departures는200(요청0ad18fda-e476-4b9d-b4ff-541aea53e41e/c05fc5c5-5e22-4a71-832e-cf26d62b9ebd)이며 뒤의 계정 갱신은 없다.19:50:39 마지막 참가 종료200 뒤에는 weekly-summary200이 있다. READ ONLY 서버 내부 schema 검사에서 첫 원ACK는 automatic_successor·actor cancelled·history1/합계 일치·group_policy_effect 존재다. public→public/before.revision1/after.revision=null이며 같은 ACK의 group_policy에 실제 revision이 있다. Native CycleGroupEffect.validateAck는 after.revision 양수를 요구한다. 원ACK 원문/실제 회원·방·캐릭터 ID·토큰은 문서/댓글에 보관하지 않는다.

원ACK 반출은 자동 승인 검토가 민감정보 위험으로 거절했다. 안전한 대안으로 서버 안에서 schema/필드 검사를 수행하고 enum·건수·revision·판정만 출력했다. 서버/DB 쓰기·재실행·자료 정리는 하지 않았다. 합성 회귀에서 CycleGroupEffect.validateAck→rolePositive(null)의 정확한 실패를 재현했다. 신규 batch 개인 승계에만 같은 원ACK의 known group_policy를 동일 방/T/cycle/세대·after state·before 대비 유지/+1 revision과 결합해 검증한다. 원ACK/원요청은 그대로 두고 일반 그룹 ACK 검사는 유지한다. 근거 누락·다른 대상·revision/state 위조는 거절한다. 레이드 현황에 batch pending 전용 ‘완료 요청 결과 확인’을 연결해 방 목록/읽기 권한이 사라져도 기존 잠긴 확인창에서 명시 재시도한다. 복구 후 중복 계정 조회도 제거했다. 최종 검증/사용자 인수 상태는 NEXT_WORK를 따른다.

## BUG-033. 계정 완료 해제 CLIENT_UPGRADE_REQUIRED 및 재조회/저장 재시도 반복 (2026-11-09)

상태: 신규 옵션 누락 수정에 이어 Backend6742169727의 기존 원무옵션 v3 현재 거절→대상 GET→명시적 현재 정보로 화면갱신를 Native에 연결했다. 최종 전체 Flutter2,856PASS·분석0이며 [결과6742522210](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6742522210)으로 인계했다. 서버 완료 기록/과거 결과를 바꾸지 않고 로컬 활성 대기만 정리한다. 2026-11-10 사용자가 문구 수정 전 계정 복구 완료 및 디바이스 테스트 통과를 확인했다. 이 구간의 사용자 인수 완료이며 GitHub Issue 종료는 수행하지 않는다. 서버/DB·실자료 변경 없음.

증상: 공대 완료한 레이드를 내 계정에서 체크 해제하면 ‘주간 레이드 저장 확인 필요’가 남는다. 다시 불러오기는 안내가 남고, 저장 재시도는 일반 불러오기/저장 실패로 돌아간다. Native 신규 요청 수정 후에도 사용자는 테스트 계정이 막혀 사용하지 못한다고 재보고했다. 코드상 이력 불명 보존 상태는 재시도/현재 정보로 화면갱신가 모두 불가하고 주차 전환·다른 레이드 완료/해제 제한을 지속한다. 기존 계정 사용 복구 인수는 실패이며 추가 시험을 중단했다. [Backend6742169727](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6742169727)로 현재 원무옵션409 거절·대상 GET 성공·명시적 현재 정보로 화면갱신의 계약은 확정됐으며 과거 전체 이력 증명은 필수가 아니다. 이후 Native 복구 연결·자동 검증을 마쳤고 2026-11-10 사용자가 기존 계정 복구와 이번 기기 테스트 통과를 확인했다. 앞선 실패는 당시 이력이다. 앱 전체의 차단 범위/현재 문구 세부는 미확인이다.

근거: 2026-11-09 21:26:25/26 KST 정정 context GET200 이후, 21:26:27부터21:28:27까지 POST5회가 모두409 CLIENT_UPGRADE_REQUIRED다. 첫 request_id는0ed2d5f2-6ac1-445a-8bd2-536ded3e2755, 마지막은97e9259b-6840-4a53-93d9-4830f9bb1fe8이다. 인증/본문/회원 식별 자료는 게시하지 않았다.

- 원인은 MemberRaidClient.correction/correct의 group_policy_version 누락이다. Backend cycles.execute는 원ACK 재생 뒤 group_policy.require_client의 업무 전 검사에서 DB0036의 무옵션 요청을 거절한다. 새 정정 GET/POST·수동 PUT은 group_policy_version만 사용하도록 수정했다. 이전 ‘계정3개 대칭 무옵션 유지’ 판단은 이 검사 적용을 놓친 것으로 정정한다.
- MemberWeeklyViewModel.refresh는 조회만 하고 pending을 지우지 않는다. 조회 성공 때 failure는 사라져도 hasPending 안내는 유지된다. 따라서 화면을 다시 그렸다는 것만으로 이전 저장 문제가 해결되지 않는다.
- CLIENT_UPGRADE_REQUIRED에 별도 문구를 연결했다. 기존 원무옵션 v3는 현재 실제409와 정확한 대상 GET 확인 뒤 명시적 현재 정보로 화면갱신으로 정리할 수 있다. 과거 전체 이력 증명이나 실패 확정은 요구하지 않는다. 조회 뒤에도 검토 상태 안내를 유지한다. 임의 성공 처리나 전체409 삭제는 없다.

저장은 기존 단일 슬롯 schema4에 query·결과불명 여부·재시도 불가 거절 코드만 추가한다. 과거 query/본문/키/token/ACK는 바꾸지 않는다. 검증과 다음 행동은 NEXT_WORK를 따른다. 공용 복구 큐·새 API·DB 변경은 요청하지 않았다. 자동 시험을 기존 기기 요청의 복구 성공으로 확대하지 않는다.

## BUG-032. 레이드 완료 CONTEXT_INVALID와 오류 원인 안내 부족 (2026-11-09)

상태: 사용자 승인 UX와 보정864de38b 계약을 Native에 연결했다. [Backend 최종6738491069](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6738491069)으로 협의 대기는 해소됐다. 확정 문구·접힌 오류 정보·첫 오류 취소·확인창 수명, 동일 작업 재진입/원요청 복구·ACK 후 조회만 복구를 연결했다. 최종 전체 Flutter2,840PASS·전체 분석0이다. 2026-11-10 사용자가 이번 완료 오류/안내 구간의 기기 테스트 통과를 보고했다. 서버 내부의 과거 개별 오류 분기 입증과 사용자 인수는 구분한다.

범위: [계약26](../backend-migration/26-roster-character-lifecycle-design.md#완료-오류-안내-ux--사용자-협의-정리-2026-11-09). 새 서버 API/code·복구 큐·다중 저장·DB 변경 없음. 단일 슬롯의 다른 작업 제한/장기 미해결 안전 종료는 이번 해결 범위가 아니다. 실제 사용자 실패와 서버 로그의 상관관계는 미확인으로 유지한다.
증상: 레이드 완료 처리 시 ‘확인 정보가 유효하지 않습니다. 최신 내용을 다시 확인해 주세요.’가 표시된다. Native 공통 recruitmentFailureMessage의 CONTEXT_INVALID 문구이며 실제 HTTP/request_id·서버 세부 분기는 아직 확보하지 않았다.

확인 근거: Native7a165ac1의 BetaInteractionApi→BetaContract.query는 실제 지원 목록에 따라 GET `/v2/raid-rooms/{room_id}/command-context`에 participation_profile=remaining-active-1을 추가한다. 고정 Backend caffaf340의 실제 two-cycle OpenAPI2aeca907…는 POST `/v2/raid-rounds/{round_id}/completion`과 `/personal-completion`에는 해당 query를 정의하지 않는다. Native가 이 POST에 profile을 붙이지 않는 것은 계약과 일치한다. 서버 cycle_lifecycle.sign/command_context.seal은 GET의 profile을 토큰에 넣고 unseal/roster_participation.check_marker는 POST와 profile이 다르면 CONTEXT_INVALID/400을 반환한다. 따라서 현재 조회/완료 조합의 확정적인 불일치 경로를 확인했다. weekly-incomplete-closures는 GET/POST 모두 profile을 지원하며 앱 비활성 정책은 유지한다. 실제 사용자 실패 분기가 이 검사였다는 서버 로그 입증과 다른 토큰 해독 실패 가능성은 구분한다.

안내 보완: CONTEXT_INVALID의 내부 분기는 추측하지 않고 검증 실패로 안내한다. 실제 Dio sender→AccountReadException→controller에 code/status/requestId를 보존하고 완료 오류 영역에 ‘오류 정보’ 펼침/복사를 연결했다. 안전한 코드/HTTP 상태/UUID만 표시하며 토큰/인증/본문은 포함하지 않는다. 새 오류/회원 전환에서 과거 진단을 정리한다. 만료·상태 변경·주차 변경·권한·서버 준비·결과불명을 완료 전용 문구로 구분하며 비완료 공용 문구는 변경하지 않았다.

완료 전용 분류의 기술 기반(최신 문구/버튼은 계약26을 우선):

| 구분 | 기존 코드/판별 근거 | 안내 방향 |
|---|---|---|
| 확인 시간 만료 | COMMAND_CONTEXT_EXPIRED 등 | ‘확인 시간이 지났습니다. 완료할 레이드를 다시 확인해 주세요.’ |
| 대상/참가/주차 변경 | TARGET_CONTEXT_STALE·REVISION_CONFLICT·CYCLE_CHANGED 등 | 변경된 내용을 다시 확인하도록 안내. 주차 변경은 별도 표현 |
| 권한 제한 | TARGET_LEADER_REQUIRED·PERMISSION_DENIED 등 | 완료 가능한 담당자/권한 안내 |
| 이미 완료/대상 없음 | ROUND_NOT_ACTIVE 등, 실제 상태 근거 필요 | 이미 완료와 진행 대상 없음을 근거 없이 단정하지 않고 구분 |
| 확인 정보 검증 불가 | CONTEXT_INVALID | ‘완료 요청을 확인하지 못했습니다. 다시 확인한 뒤에도 같으면 오류 정보를 알려 주세요.’ 내부 원인을 단정하지 않음 |
| 연결 실패/결과불명 | 통신 오류·pending/ACK 상태 | 연결 안내와 결과 확인을 구분. 새 완료 명령 자동 실행 금지 |

오류의 쉬운 설명/다음 행동과 안전한 원코드·request_id를 함께 추적할 방식을 검토한다. 서버 키/토큰 내부정보는 노출하지 않는다. [Issue17 조사·분류 요청6732895692](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6732895692)에 대한 [Backend6733182655](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6733182655)·[Native 수신6733447639](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6733447639)를 확인했다. 권장안은 새 wire code/필드 없이 기존 code+status+request_id 활용이다. details.reason은 extra-forbid 계약에 임의 추가하지 않으며 CONTEXT_PROFILE_MISMATCH는 미확정 제안일 뿐이다. 일반503/응답 유실은 결과불명, 기능 준비 거절은 해당 시도 미실행, 성공ACK 뒤 GET 실패는 완료 성공 유지로 구분한다. 현재 오류가 이전 시도의 미반영까지 보증하지 않는다.

Backend 원인/보정: 실제 CycleRoute가 허용하는 완료 POST의 participation_profile이 경로 필터 누락으로 공개 선언에서 빠졌다. 원인 진단8PASS에 이어16c9cd4b에서 선택 query10개를 보정하고 영향114PASS·도구63PASS, 개발image101cd82d…/DB0036·새 계약864de38b… 반영을 보고했다. Native도 실제 새 계약 hash와 이전 계약 대비 전체 객체에서10개 선택 query만 달라짐을 읽기 확인했다. 추가8개(일정5·개인 주간 상태3)는 동일한 완료 오류로 단정하지 않는다. Native 검증 projection은10개 모두 지원하도록 갱신하되 실제 Beta 호출7개만 신규 query에 자동 반영하고 별도 계정3개는 현재 대칭 무옵션/주간 pending을 유지하는 설계다. 기존 dev400로그3건의 내부 분기/제보 기기 상관관계는 여전히 미확정이다. Native 연결·검증/기기 확인 전까지 해결 완료로 닫지 않는다.

기존2,826PASS는 실제 서버의 조회→완료 POST 간 profile 표식 연계를 포착하지 못했다. 이번에는 Native 안내/진단·실제 앱의 ACK 후 주간 조회 실패 전달을 보완했으며 서버/DB/자료 변경과 실제 회원 완료 명령은 실행하지 않았다. ACK가 있으면 완료 성공을 유지하고 조회만 재시도하며 pending 결과불명 안내는 특정 거절 문구보다 우선한다. 새 계약 소비 후 profile 연계와 완료 기록/주차/권한·원요청/ACK 복구를 직접 검증해야 한다. 현재 검증 수치는 NEXT_WORK/DEV_LOG를 따른다.

## 레이드 모집 현재 판정 — 2026-10-27

BUG-026의 후보/집계/일정 표시, BUG-027 완료 후 복귀, BUG-028 시간 입력/계정 완료/편성 잠금, BUG-029 해산 로그, BUG-030 가독성/재신청은 각각 아래 근거의 수정과 사용자가 보고한 정상 흐름 통과를 반영했다. 원 제보의 미확인 ACK를 새로 입증했다는 뜻은 아니며, 재현 없는 배너를 추가 필수 시험으로 남기지 않는다. 다음주 개방 알럿의 유사 로그는 사용자 보류로 별도 원인 조사 전이고, 제안 정밀도 경계1건/UX 개선은 [NEXT_WORK](NEXT_WORK.md)·[인수표](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#recruitment-status-20261027)에서 관리한다. 이후의 과거 원인·검증 설명을 새 대기로 재사용하지 않는다. BUG-025는 별도 계정 흐름 조사로 유지한다.

## BUG-031. 활동 재선택 후에도 모집 주차 검토 상태·축약 상세가 남음 (2026-11-03)

상태: 예방 수정·변경 구간 사용자 로컬 실기기 인수 통과(2026-11-03). [Issue42 결과](https://github.com/heo0328/lostparty-backend/issues/42#issuecomment-6607158974): 활동해제 후 기존방 데이터/정상사용 유지·신규생성/변경 후보 제외·다른활동캐릭터 참가변경 및 제외캐릭터 재노출 없음·그룹원 활동목록 제외 전부 확인. Backend0207d0f6/57PASS 보고·Flutter관련321PASS/변경분석0 완료. 기존 dev 방 복구는 사용자 최종 범위에서 제외하며 필수 후속 아님. 이하 조사 기록은 당시 원인 근거다. 사용자 제보의 이슈아이B/금주4막은 개발 DB 읽기 전용 확인에서 방 ended_at null·Assignment active·CycleMember participating·점유/WeeklyState가 보존되어 삭제가 아니다. 주차/세대 review_required와 ACTIVITY_SELECTION_REQUIRED 근거가 11/02 21:41 KST에 기록됐다. 활동 선택은 11/03 17:27 KST에 다시 존재하지만 검토 상태가 남아 있다. 현재 worker는 현재 주차 review_required를 건너뛰고, 상세 reader는 content=null·주간 reader는 confirmed에서 제외해 축약 상세/빨간 경고와 일치한다. 이번 batch 성능 구현 이전 상태이며 원래 활동 해제의 사용자 행동/직접 호출은 이 기록만으로 확정하지 않는다. SQL 강제 정상화·탈퇴/재가입·자료 변경 없음. 예방 수정과 보고된 변경구간 인수를 완료했고 이미 제한된 dev 방은 복구 대상에서 제외한다.

별도 표시: 다음주 비활성 체크박스의 진회색 채움은 app_theme.dart의 disabled fillColor가 selected 여부 없이 textSecondary를 적용하기 때문이다. 기존 cf75ea75(10/27) 변경으로 이번 batch 수정이 아니다. 기능 비활성/값 false와 색상을 구분하며 사용자 승인 전 스타일 수정 없음. 2/5 성능 비교는 조사·후속 판단까지 보류. 로컬 식별자·이력 포함 Issue41 게시 시도는 자동 승인 검토에서 외부 민감정보 공유로 거절됐고 게시되지 않았다. 협업 전달은 비식별 코드 근거 또는 사용자 승인 범위로 별도 판단한다.

후속 제품·기술 대조: 사용자 제안은 기존 ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT §6.3의 기존 참가 유지/새 선택 제외와 일치한다. 실제 방은 활성 참가2명이며 공용 RoomCycle/Generation 제한이라 한 명의 활동해제가 다른 공대원의 상세/일정에도 영향을 주는 구조다(타 계정 실기기 미확인). 서버 qualify가 신규용 admission_context.selection→groups.admission_core.selected_character의 활동조건을 기존 참가 재검증에도 재사용하는 것이 원인 경계다. worker뿐 아니라 상세 build/일정/관리 등의 기존 참가 검증을 함께 분리해야 한다. 기존참가 ID/주차/소유·생명주기/원장·권한 검증은 유지하고 활동선택만 신규 생성/가입/신청/교체 대상에 적용하는 최소 변경을 권고한다. 초기에는 기존 review 안전회복을 권고했으나 사용자 최종 결정으로 기존 dev 방 복구는 제외했고 필수 후속으로 남기지 않는다. 소유권상실/캐릭터삭제를 활동해제와 동일 취급하지 않는다. 그룹 활동목록 제외와 회원가입·대표 표시 Snapshot은 별도이며 표시명 전체삭제로 확대하지 않는다. 2026-11-03 사용자가 흐름과 현재 성능 브랜치 유지를 확인했고 NEXT_WORK/활동계약 §6.4에 설계를 기록했다. 예방 구현·변경구간 인수를 완료했으며 자료 복구는 제외 범위다.

## BUG-030. 폴드 확인창 오류라벨 잘림·완료탈퇴 후 다른캐릭터 재신청 차단 (2026-10-27)

해결·기기 통과. 라벨은 Native 수정/111개직접검증 후 사용자가 작은 오류 화면도 제대로 표시됨을 확인했다. Text의 접근성 굵게/간격 적용과 기존측정 차이를 재현해 같은측정/12~24범위·2줄ellipsis·전체원문 의미정보로 수정했다. 재신청 TARGET_CONTEXT_STALE은 Backend의 과거완료Assignment/현재참가 판정 차이 원인후보를 [Issue13](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6435522815)에 익명절차로 인계했고 Backend c1f86d89/DB0033 개발반영 후 사용자가 과거기록유지·다른캐릭터 신청/가입완료를 보고해 해당재신청은 기기통과/해결이다. Native권한우회/기록삭제/새키재송은 하지 않는다. 별도 기능은잠기지않으며 denied조회POST0을 확인했다. 사용자보고의 편성잠금/계정완료·추방/CN개별관리는 통과로 반영한다. 설계37 §37.88/NEXT_WORK.

## BUG-029. 해산 확인창 첫 build에서 공용 Controller 알림 예외 (2026-10-27)

상태: 재현/수정·고유103개 직접검증 후 사용자 기기에서 해산 시 과도한 setState 로그가 사라짐을 확인, 해결. 다음주 개방 알럿의 유사 로그는 별도 후속이며 해산 결함의 재발로 합치지 않는다. _MembershipDialog.initState→load→membershipContext→_read의 동기 busy notify가 build 중 전역/보관 ListenableBuilder를 갱신했다. 최초 조회만 첫프레임 후 시작하고 무효 화면은 조회 없이 로딩을 종료한다. 수정 전 동일 assertion→수정 후 통과, 열기 POST0/확인POST1·대상주차별 갱신1회·취소/무효화쓰기0을 확인했다. 사용자 원HTTP횟수는 로그에 없어 실제 중복명령으로 단정하지 않는다. 기존 명령/원키/ACK/모달종료/목록복귀·복구는 보존한다. 설계37 §37.87·[Issue13](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6422980400).

## BUG-028. 2차 기기 피드백: 시간 필터 예외·계정 참가 중 완료·편성 거절 잠금 (2026-10-27)

상태: 일반 앱 수정·직접 영향243개 검증 후 사용자 기기에서 시간 필터 입력·계정 완료/탈퇴·편성 거절 잠금 해소를 확인, 해결. 후속 오류 라벨 가독성도 BUG-030에서 통과했다. 시간 입력의 작은 글자 배율0.8에서216≤h≤189.6 예외를 재현해 해당 picker 배율만 보완했다. 계정의 참가 중 체크는 수동 PUT 대신 기존 개인 완료 후 탈퇴로 연결했다. 편성 적용 전409 ROOM_COMPOSITION_CONFLICT가 확정 거절 집합에서 누락돼 원요청 잠금을 유지하던 원인을 수정했다. 기존 잠긴 요청은 같은 키 재확인으로 거절을 저장/정리하며 새 요청이나 강제 삭제로 처리하지 않는다. 오류 카드·빨간 글씨24를 적용했다. 상세/회귀/기기 항목은 설계37 §37.84·NEXT_WORK 참조. 서버/웹소켓 문제로 분류하지 않는다.

## BUG-027. 개인 완료 후 탈퇴 성공에도 확인창 잔류 (2026-10-26)

상태: ef4f424c 후 기기 재발. 이전 직접 URL 진입 시험이 실제 목록→상세 push를 누락했다. root 확인창 소유권 수정만으로는 부족했고 종료 가드의 routeInformationProvider URI가 push 전 /raid-status인 탓에 이동이 막혔다. 유효 ACK가 도착해도 이후 재조회가 기록 상세를 보여줬다. §37.83에서 전역 활성 router.state.uri/pageKey와 현재 route로 판정하도록 최소 수정했다. 실제 StatefulShellRoute push+Controller 유효 ACK에서 수정 전 실패→후 통과, 계정 갱신 보류/실패와 화면/회원 변경을 포함한 직접156개 통과. 명시 기록·반대 주차·복원/다른 화면 무이동과 기존 root 모달/원요청/갱신은 유지한다. 8a31853e 이후 사용자가 '레이드 현황으로 페이지 이동이후 갱신까지 정상작동'을 보고해 목록 복귀/갱신 기기 통과·해결로 반영했다. 별도 후속의 인수까지 확대하지 않는다. NEXT_WORK/설계37 §37.83.

## BUG-026. 1차 모집 기기 점검의 후보·한도·일정 갱신 차이 (2026-10-26)

상태: native 일정 ACK/UI/오류·join 후보·조율 안내·사용량 배지 연결과 자동검증 완료. Backend172의 집계/선택조회 개발반영도 인계 수신. 후보·가입/조율·개인표/그래프는 사용자 기기 통과. 과거 제보 원ACK동일키 자체는 입증되지 않았지만 사용자 뜻대로 재현 없는 배너를 강제 기기 과제로 남기지 않는다. 상세 근거/영향은 설계37 §37.77, 현재 순서/담당은 NEXT_WORK, 협업은 [Issue13 요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6409130575).

- 후보: 모집번호5/4막하드 기대1720에1704 소울이터가 노출, 실제 신청은 차단. 당시 apply/change_character는 서버 후보 원본, join은 기존 목록 경로였다. Backend164/170에서 direct_join 일반목록 경로 차이로 확인하고 join 후보 source690f36f를 개발반영했다. §37.81에서 native 시트도 연결했으며 사용자 기기에서 레벨 미달 후보 제외를 확인했다. 직업중복/완료 후보 제외는 사용자 통과.
- 한도: Backend164는 활성3방(C/N표시4건)+과거10/14 미종료7관계로10을 집계했다. 사용자는 현재 참가중 목록에서 확인·이용 가능한 활성방만10개의 대상이라고 명확히 했다. 과거 관계만 남은 방을 포함한 집계는 제품 의도와 다르며 [정정요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6410274718)에 따라 Backend169의 현재목록 공통판정은6412692643에서 소비수용했으며 실제 현재 참가가 유지되는 확인 필요 상태는 포함한다. Backend172/1800160d 구현·개발반영을 수신했고 native 서버 사용량 배지도 연결했다. 사용자가6/10은 같은방 C/N1개 정책임을 확인하고 현행 유지를 선택했다. 과거 자료 삭제/강제탈퇴로 해결하지 않는다.
- 일정 갱신: 공대원 '내 일정 갱신' 뒤 공통 오류와 현황의 미확인 배너(첨부11.jpg). 서버 beta 복사 revision+1과 앱의 같은 개인표 no-op 기대 차이를 코드/합성 응답으로 재현·수정했다. 기존 원요청 보존 복구 시험은 통과, 제보 원ACK/기기는 미확인.
- 자동조율: 인원 충족 뒤 빠른 시간 확정이 안 되는 것 같다는 제보. 인원 충족+전원 표/예약·진행시간에 맞는 공통후보 필요, 없으면 기본 약속 유지가 정책이다. Backend164 현재 snapshot에서 번호3/5는 공통후보0, 번호4는 인원미달/worker성공을 확인했다. 승인된 한 줄 안내는6412692643에서 선택조회 계약을 수용했으며 Backend172 구현/개발반영과 native 연결은 완료, 대기 문구와 조기 자동확정은 사용자 기기에서 확인했다.

내 참가 캐릭터명은 사용자가 계정 혼동으로 정정했으므로 결함으로 등록하지 않는다. 웹소켓 자동갱신과 BUG-025는 이 제보의 원인으로 묶지 않는다. 사용자가 보고한 일정·승계/1인탈퇴·주차 독립은 통과로 유지하며 개인/주차 완료 후 목록 복귀만 BUG027에서 재확인한다.

## BUG-025. 최초 자동 빌드 갱신 완료 후 캐릭터 카드 전투력 미표시 (2026-10-24, 후속 조사·UX 검증 대기)

**상태:** 사용자 관찰 접수·코드 경로 정적 확인. 실제 원인은 미확정이며 수정/재현 테스트는 미실행이다. 사용자는 당장 코드 변경이 아니라 후속 작업 등록을 요청했다. 담당은 Flutter의 재현·표시/저장 흐름 대조이며, 서버 계약·응답의 실제 차이가 확인될 때만 Backend와 협업한다.

**사용자 관찰:** 여러 디바이스의 모집 참가·인원별 출발 시간 조율 테스트를 위해 로그인된 미인증 원정대를 Backend에서 인증 상태로 변경했다. 앱을 재실행한 후 자동 빌드 갱신 결과는 정상 완료로 표시됐지만, 이전에 캐릭터 카드에서 수동 전투력 갱신을 하지 않은 캐릭터는 데이터 없음으로 표시됐다. 서버에 값이 있거나 다른 기능에 사용 가능하더라도 사용자에게는 갱신 실패처럼 보였다는 보고다. 인증 상태 변경 자체를 원인으로 단정하지 않는다.

**확인한 코드와 가설 구분:**

- 자동 대상 분류에는 기존 전투력의 수동 저장 이력 조건이 없다. `domain/scoped_startup_refresh.dart::projectScopedRefreshTargets`는 활동 선택·사용 가능 상태·나이스단 정책을 사용한다. `StoredRoleSummary`는 초기 version=1/summary=null을 허용하며 빈 역할 레코드도 생성한다.
- `data/scoped_startup_refresh_source.dart::refresh`는 prepareRoleBuild → Armory 조회/분석 → 로컬 saveRoleBuild → onLocalSaved/서버 sync 순서다. 로컬 저장 완료와 서버 저장 대기는 별도 상태다. 성공 건수만으로 카드가 최신 상태인지 판정할 수 없다.
- `presentation/viewmodels/member_account_view_model.dart::_runnerChanged`는 자동 작업 종료 후 전체 refresh를 비동기로 요청한다. 그 완료는 자동 작업의 completed 표시와 별도이며, 카드의 새 역할 요약을 직접 반영하는 수동 `refreshCharacter`의 readCachedRoleBuild → _setCharacter 경로와 다르다. 자동 후속 재조회 지연/실패·이전 표시 잔존은 **가능한 가설**이며 이 사용자 사례의 확정 원인은 아니다.
- 카드 표시는 `member_account_page.dart::memberDisplayRole/_character`와 `ScopedRoleState.displaySummary`를 사용한다. 자동 판정한 역할과 선호/표시 역할, 로컬 pending/서버 확정 요약, 초기 빈 캐시·bootstrap 재조회 결과가 무엇을 표시했는지 대조해야 한다. 원인 확인 없이 서버 저장 실패나 특정 역할 문제로 단정하지 않는다.

위 파일 경로는 `lib/features/account/` 기준이다.

**후속 작업 순서:**

1. 수동 저장 이력이 없는 최초 빈 캐릭터와 기존 저장 캐릭터를 같은 조건에서 비교한다. 보고된 인증 상태 전환→재실행을 재현하되 정상 인증 등록 후 최초 갱신도 함께 구분한다. 새 UI나 재시도 정책을 먼저 정하지 않는다.
2. 대상 포함/제외 → 조회·분석 → 역할별 로컬 저장 → 서버 동기화/원ACK → 캐시·화면 모델 반영 → 카드 수치와 완료 안내까지 한 흐름으로 추적한다. 어느 화면 단계에서 값/역할/표시가 달라지는지 확인한다.
3. ‘갱신 완료’가 의미하는 범위, 화면 반영 대기/실패와 서버 저장 대기의 표현·재시도 동작을 실제 UX와 함께 정의한다. 저장 성공을 실패로 뒤집거나, 화면 미반영을 아무 안내 없이 성공으로 끝내지 않는 기준을 정한다. 즉시 카드 반영·일부 재조회·전체 재조회 중 무엇을 쓸지는 데이터 소유/수명·기존 비동기 보호를 확인한 뒤 선택한다.
4. 재현 원인과 합의된 완료 기준을 근거로 필요한 최소 수정/추가를 설계한다. 기존 자동 1회·활동/나이스단 제외·역할별 저장·회원/환경 격리·원pending/ACK를 회귀 보호하며 별도 전면 리팩토링으로 확대하지 않는다.

**테스트/완료 조건:** 최초 빈 데이터·기존 데이터, 딜러/서포터 자동 판정과 표시 역할, 로컬 성공/서버 대기, 저장 후 재조회 지연·실패, 부분 성공, 화면 재진입·앱 재실행·다중 디바이스, 도중 로그아웃/회원 변경을 영향 범위로 확인한다. 정상 UI는 사용자 실기기로, 비동기 경합·지연/실패·다른 회원 응답 덮어쓰기 등 경계는 필요한 표적 자동 테스트로 보완한다. 사용자가 추가 수동 갱신을 하지 않아도 완료 안내에 맞는 카드 상태를 확인할 수 있어야 하며, 미확인/일부 실패는 그 의미와 다음 행동이 구분돼야 한다. 서버 값 존재/API 성공만으로 완료 판정하지 않는다.

**일정/범위:** 후속 조사·기능 정의/테스트 대상으로 등록하며 이번에는 기능 코드를 수정하지 않는다. [개발 품질·UX 기준 §6](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md#6-서비스-복구-릴리즈-이후-최적화-검토)의 흐름별 점검에서도 참조한다. 다만 알려진 UX 결함의 필수 수정 여부는 서비스 복구 릴리즈 인수 전에 판단하며, 무조건 릴리즈 후 최적화로 미룬다는 결정은 아니다. Issue25 B 작업과 별도 구간으로 관리한다.

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## BUG-024. 완료 반복방 다음 주 참가 캐릭터 변경 실패 (2026-10-07, 실제 앱 도입·활성화400으로 운영 반영 보류)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0001)로 이동했다.

## BUG-023. 캐릭터 변경 후 반복 모집 전체 완료 실패 (2026-10-06 완료)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0002)로 이동했다.

## 이전 완료 판정 (2026-10-05, 1.1.0 공개 이후 — BUG-023 발생 전)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0003)로 이동했다.

## 아래는 과거 조사 이력

## 2026-10-04 후속 확인 — 일반 추방 후보와 거절 경계 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0004)로 이동했다.

## 2026-10-04 Rules 감사에서 분리한 미해결 항목

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0005)로 이동했다.

## 최신 판정 요약 (2026-09-29)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0006)로 이동했다.

## BUG-009. 신규 그룹의 멤버 목록·상세 전투력 누락

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0007)로 이동했다.

## BUG-022. 앱 재설치·동일 원정대 재인증 후 그룹 모집 관리 권한 오류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0008)로 이동했다.

## BUG-021. 그룹 가입 신청 승인이 Rules 평가 한도로 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0009)로 이동했다.

## BUG-001. 모집 생성 후 상세가 다른 방(A)을 보여 줌

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 (수정됨) |
| 보고일 | 2026-08-26 |

상세 `recruitmentId` 변경 시 State·구독이 따라가지 않아, 방 A 상세 후 방 B 생성 시 A가 남을 수 있었다. `ValueKey`·`didUpdateWidget`/`restart`로 수정했고, 정상 스텝 실기기에서 통과 확인 후 종료.

---

## BUG-002. 목록은 4인 노말인데 상세·구성은 8인 공격대처럼 보임

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0010)로 이동했다.

## BUG-003. 회차 완료 후 완료 기록이 비어 보임 / 진행 중에서 사라져 해산 불가

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0011)로 이동했다.

## BUG-004. 하단 탭 전환 시 이전 상세 스택이 남음

| 항목 | 내용 |
| --- | --- |
| 상태 | 패치됨 |
| 보고일 | 2026-08-26 |

모집 탭 갔다가 현황으로 돌아오면 해산·종료로 비었어야 할 상세가 다시 열렸다. 탭 전환 시 브랜치 스택을 유지했기 때문이다.

패치: 탭 터치마다 `goBranch(..., initialLocation: true)`로 해당 탭 루트로 이동.

---

## BUG-005. 같은 레이드 회차 완료 후 재생성·재완료가 막히지 않음

| 항목 | 내용 |
| --- | --- |
| 상태 | Task-074~075 주간 Claim 작업에 흡수 |
| 보고일 | 2026-08-26 |

완료 → (해산) → 같은 레이드 재생성 → 다시 완료를 같은 주차에 반복할 수 있다. 원인은 서버 개인 주간 완료 Claim이 없는 것이다. 별도 임시 패치 대신 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)와 Task-075 이후 단계에서 생성·신청·가입·교체를 함께 차단한다.

---

## BUG-006. 회차 완료·해산이 처음 1~2회 실패하다 이후 성공

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 간주 (현재 재현 없음, 재발 시 재개) |
| 보고일 | 2026-08-26 |

권한 확인 실패 후 재시도하면 성공하는 경우가 있었다. 이후 Transaction 읽기 후 쓰기 순서 수정과 실기기 검증 뒤 같은 증상이 재현되지 않았다. 재발 시 명령·방 상태·오류 코드를 새로 기록해 다시 연다.

---

## BUG-007. 반복 파티 완료·다음주 캐릭 변경·취소 반복 시 Claim/취소 꼬임

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0012)로 이동했다.

## BUG-008. Task-086 운영자 승인·분쟁·강제 인증 permission-denied

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0013)로 이동했다.

## BUG-010. 정상 특수 보석 대상이 스킬 미확인으로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **수정·자동 검증·주요 실기기 확인 완료** |
| 보고일 | 2026-09-08 |
| 심각도 | 중간 — 표기 오류 및 Build 검증 신뢰도 저하 |
| 기준 문서 | [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md) |

### 재현과 실제 결과

- 발키리 support의 `신앙 스킬`과 바드 dealer의 `템페스트 스킬`이 `보석의 대상 스킬을 확인할 수 없습니다`로 표시됐다.
- 실제 API 진단을 확대해 홀리나이트 support `신앙 스킬`, dealer `심판자 스킬`, 도화가 support `음양 스킬`에서도 같은 카탈로그 공백을 확인했다.
- 바드 support `세레나데 스킬`, 발키리 dealer `종언의 빛`, 도화가 dealer `떠오르는 달`은 현재 카탈로그에서 정상 분류됐다.

### 확인된 원인

- 기존 4직업 fixture는 실제 API 실측이 아닌 사용자 제공 계약값이었고 `신앙`, `심판자`, `음양`처럼 실제 대상명의 `스킬` 접미사가 빠져 있었다.
- 바드 실제 fixture의 `템페스트 스킬`은 카탈로그 없는 호출에서 아이콘 fallback으로 통과했지만, 알려진 직업은 타 직업 오판 방지를 위해 fallback을 차단하므로 현재 카탈로그에서 unknown이 된다.
- 보석 대상명만으로는 발키리와 홀리나이트의 동일한 `신앙 스킬`을 구분할 수 있다. 실제 보석 Tooltip의 `[직업]`을 현재 Character 직업과 함께 비교해야 한다.

### 해결 결과

- 모든 직업의 전체 Build를 선행 수기 입력하지 않는다.
- 실제 확인된 특수 대상명을 교정하고 동일 직업·대상 미확인과 다른 직업 보석을 분리했다.
- 깨달음·아크그리드 기본 조건과 해·달 존재/14P 검사를 구현하고 자동·주요 실계정 검증을 완료했다.
- 파티 신청자와 membership 카드의 최소 보석 검증 Snapshot 전파를 완료했다. 그룹 membership 전파는 현재 `NEXT_WORK.md`의 별도 작업 그룹으로 진행한다.

---

## BUG-011. 주차 경계 후 미완료 종료·반복방 전환 상태 불일치

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0014)로 이동했다.

## BUG-012. 동일 레이드 다른 난이도 신청 후보에 확정 참가 Character가 노출됨

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0015)로 이동했다.

## BUG-013. 4인 파티에서 방장과 동일한 딜러 직업이 신청 후보에 노출됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 실기기 확인·`dev` 반영 완료** |
| 보고일 | 2026-09-10 |
| 심각도 | 높음 — 파티별 동일 딜러 직업 제한의 신청 사전 차단 누락 |
| 기준 문서 | [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md) |

### 원인

- 카탈로그와 `PartyCompositionPolicy`는 4인 1파티의 동일 딜러 직업 상한을 1명으로 올바르게 정의한다.
- 모집 상세 신청 팝업은 현재 membership·파티 구성 없이 생성용 `RecruitmentLeaderCandidateService`를 호출해 방장과 신청 Character의 직업 중복을 판정할 수 없다.
- 최종 즉시 가입·승인 배치는 다시 검증하지만 승인 대기 신청 후보 단계에는 누락돼 있다. 이 경로는 최근 assignment 수정에서 제한을 제거한 것이 아니라 기존 신청 화면 연결의 검증 공백이다.

### 수정

- 상세 읽기 모델의 membership과 `PublicRecruitmentSummary.partyRules`를 신청·캐릭터 변경 후보 Query에 전달한다.
- 신청·즉시 가입 후보는 최종 가입과 같은 `PartyCompositionPolicy.assignEmptySlot`으로 판정한다.
- 캐릭터 변경은 자리 유지 `failureForInPlaceReplacement`로 membership 명령과 같은 파티 단위 제한을 적용한다.
- 모집 생성 후보는 membership을 넘기지 않아 기존 생성 흐름을 유지한다.

### 검증

- 표적·영향 자동 테스트와 변경 파일 analyze가 통과했다.
- 실기기: 4인 동일 딜러 직업 후보 미노출, 8인 동일 직업 2명 신청 허용을 확인했다.
- 8인 동일 직업 3번째 차단과 변경 가능 캐릭터 없음 알림은 자동 테스트로 고정했고 실기기 재확인을 남긴다.

---

## BUG-014. 장비 인증의 앱 종료 정책 안내 누락

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0016)로 이동했다.

## BUG-015. 후보의 아크그리드 오류가 신청자·파티원 카드에서 사라짐

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0017)로 이동했다.

## BUG-016. 인증 시작 장비 미착용이 일반 정보 실패로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 자동 수정·실기기 확인 완료** |
| 보고일 | 2026-09-13 |
| 심각도 | 낮음 — 사용자가 필요한 조치를 알 수 없음 |
| 기준 문서 | [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md) |

### 원인

- 인증 시작은 무기와 방어구 5부위 중 하나라도 미장착이면 Gateway에서 `FormatException`을 발생시킨다.
- 화면의 공통 실행기는 장비 누락, Character 불일치와 실제 응답 파싱 실패를 모두 같은 `FormatException`으로 받아 `캐릭터 또는 장비 정보를 처리할 수 없습니다.`로 표시한다.

### 해결 방향

- 6부위 미착용을 식별 가능한 인증 시작 오류로 분리하고 `인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.`를 표시한다.
- 실제 API 오류·응답 누락·파싱 실패의 일반 안내는 유지한다.
- challenge 생성, 무작위 부위 선택과 인증 성공 판정은 변경하지 않는다.

### 수정 결과

- 장비 미착용을 문자열 비교가 아닌 `incompleteEquipment` 전용 시작 오류로 분리했다.
- 무기·방어구 5부위 완전 장착 성공, 일부 누락, 손상된 응답을 Gateway 테스트로 분리하고 화면 문구를 Widget 테스트로 고정했다.
- 사용자가 실제 기기에서 장비 미착용 전용 문구가 일반 정보 실패와 분리되는 것을 확인했다.

---

## BUG-017. 8인 Character 변경이 다른 파티 배치 가능성을 보지 않음

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0018)로 이동했다.

## BUG-018. 확정 참가자가 있는 모집 해산이 권한 오류로 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0019)로 이동했다.

## BUG-019. 원자 모집 생성·목록·후보·신청 상태 불일치

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0020)로 이동했다.

## BUG-020. 파티 완료 수명주기의 권한·기록·개인 해제 회귀

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0021)로 이동했다.

## 백로그 연결

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0022)로 이동했다.
