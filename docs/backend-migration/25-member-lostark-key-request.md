# Lost Ark API 키·서버 처리 전환 계약

## 개발자 단일 키·공통 UI 전환 설계 (2026-11-16)

상태: **공동설계/Backend B1·B2 구현 게시 완료 / Native 일반 앱 연결·로컬 dev0037 반영 완료 / 사용자 전체 정상 동작 확인(2026-11-17)**. 서버 처리 최초 게시 소스는 작업브랜치 `b95cff51f6eaf74d341115b2cc7868cc625ce626`의 [구현기록](https://github.com/heo0328/lostparty-backend/blob/b95cff51f6eaf74d341115b2cc7868cc625ce626/docs/features/rosters/power-and-profiles/server-processing-implementation.md)·[OpenAPI](https://github.com/heo0328/lostparty-backend/blob/b95cff51f6eaf74d341115b2cc7868cc625ce626/openapi/openapi.yaml)이며 [게시회신6914931822](https://github.com/heo0328/lostparty-backend/issues/55#issuecomment-6914931822)를 확인했다. 합의 후 wire delta 없음. 고정 구현기록 안의 미커밋 문구는 게시 전 작성시점이며 후행 게시회신이 현재 Git 상태다. 2026-11-17 [Backend dev 전환 회신](https://github.com/heo0328/lostparty-backend/issues/55#issuecomment-6921019988)으로 사용자 별도 승인 후 로컬 DB 초기화/0037·새 API/서버 token 준비 완료를 확인했다. 현재 명세 소비 기준은 Backend5172c753이며 개인 가능시간1분 확장을 포함한다. 사용자가 이번 작업 전체 정상 동작을 확인했다. 모든 기종/외부 장애 주입 검증으로 확대하지 않으며 운영배포는 이전 상태다. Native 코드 연결/합성 검증 결과는 NEXT_WORK·DEV_LOG를 따른다. 이전 cda4db3/Flutter302243fb는 조사 기준이다. 아래 개인키 계약은 전환 전 근거다.

<a id="roster-refresh-ux-design"></a>
## 원정대 갱신 UX·선택 및 신규1700 대상 설계 (2026-11-17)

**상태: 정책/기술계약 확정·Backend dev지원 및 Native 일반연결/자동검증 완료 / 사용자10개테스트·실패결과표시정상확인.** 기존 구현과 아래 변경안을 구분한다. 브랜치 feature/roster-refresh-ux, 기준 dev d3e700ed. API100회 초과 등 오류코드 대응 테스트 전체·진단 전송·활동 자동추가 Issue18은 별도 후속이다.

### 제품 목적과 확정 범위

원정대 전체 목록은 유지하되 상세 수집을 줄이고, 갱신 중/완료/실패 대상을 한 공통 카드로 이해하도록 한다. 사용자 수용 방향은 앱 실행 갱신에서 **사용 선택 캐릭터 ∪ 신규 발견/첫1700 도달 캐릭터**다. 목록1회로 이름/아이템 레벨을 확인하고 합집합을 UUID로 중복 제거해 대상만 서버 상세 분석·저장한다. 사용 선택/대표/참가 자격을 자동 변경하지 않는다. 원정대 카드 수동 버튼은 앞선 사용자 확정대로 해당 원정대 사용 선택 캐릭터만 분석한다.

### 대상과 진입 경로

| 진입 | 목록 확인 | 상세 분석 대상 | 정책 경계 |
|---|---|---|---|
| 앱 실행1회 | 소유 원정대별 siblings 요약 갱신 | 기존 선택 + 서버가 판별한 신규/첫1700 후보 | 같은 UUID1회, 신규에도 나이스단OFF 자동 제외 적용 |
| 인증 후 계정 복귀1회 | 인증 과정의 유효 관찰 재사용 가능 여부를 Backend와 확인 | 인증 성공 원정대의 같은 합집합 적용 | 전체 상세 대신 첫1700 후보 포함 |
| 원정대 카드 수동 전체 갱신 | 기존 서버 목록GET 재사용(추가provider조회없음) | 해당 원정대 사용 선택만 | 선택0명은 상세0회, 신규 후보는 안내/별도 확인 대상으로 보존 |
| 캐릭터 개별 갱신 | 기존 소유/사용 가능 확인 | 사용자가 요청한1캐릭터 |1700 조건 새 강제 없음 |
| 미완료 재시도/결과 확인 | 기존 실행 snapshot/원명령부터 확인 | 실패/미완료만 | 성공 재수집0, 결과불명은 동일ID/본문 복구 |

사용자 확정: 신규도1700 이상만 상세 분석하며 신규 저레벨은 목록만 저장한다. 기존 사용 선택은1700 미만도 유지한다. null/파싱불가 레벨은0/적격으로 추정하지 않는다. 최초 등록·인증 원정대의1700 이상은 최초 후보로1회 분석한다. 과거 미선택 캐릭터는 일괄 부활시키지 않고 현재 의도를 보존하는 기준선을 Backend와 설계한다. 자료 이전/복원 리허설·DB초기화를 선행하지 않는다.

실패한 신규 후보는 결과 카드에서 명시 재시도한다. 앱 재실행/같은 목록 재조회로 새 상세 명령을 반복 발급하지 않고 실패 후보/안내를 보존한다. 결과불명은 기존 원ID/본문 복구, saved 경고는 저장 성공으로 소비한다. 기존 선택 캐릭터의 앱 실행1회 갱신은 유지한다. 신규에도 나이스단OFF 자동 제외를 적용하고 실패로 집계하지 않으며 개별 수동 갱신은 가능하다. 이 네 항목은 사용자 수용으로 확정됐다.

### 서버 관찰·명령·결과 소유

- 목록/아이템 레벨과 canonical UUID·소유/lifecycle 세대는 서버 원본이다. Native 캐시·캐릭터명 비교만으로 신규/첫도달을 확정하지 않는다. 정상 owned 목록 적용 트랜잭션에서 최초 관찰/첫1700·분석 필요 근거를 최소 영속 상태로 보관하고, 매 GET/앱 재실행 때 신규를 재생성하지 않는다. 회원 변경·소유 이전 시 타인 후보를 승계하지 않는다. 같은 UUID의 개명은 신규가 아니며 이름 재사용은 UUID로 구분한다.
- 새 후보 여부와 분석 실행 완료는 별개다. 정상 목록이 왔다는 이유로 상세 저장 완료로 소비하지 않는다. 분석 saved 확정 시 후보 상세수집 완료를 반영하며 integrity warning/error도 ‘저장 성공+경고’이지 끝없는 재수집 조건이 아니다. definitive 실패는 실패로 보관하고 결과 카드의 사용자 명시 재시도로 처리한다. 결과불명은 기존 명령을 먼저 복구한다. 실패 신규 후보에 다음 실행의 새 자동 상세 명령을 반복 발급하지 않는다.
- 기존 분석 batch와 UUID/expected ownership·lifecycle·양역할 version/원ID·원본문·24시간 복구를 재사용한다. 현재 automatic은 Activity만 허용하므로 미선택 신규 후보용 최소 서버 검증 확장이 필요하다. manual로 위장하거나 활동을 먼저 등록하는 우회는 하지 않는다. 구체 profile/필드·선정 응답·원자 소비 방식은 Backend 계약 회신 후 고정한다. 서버가 현재 후보/소유/사용 자격을 다시 검증하며 클라이언트 supplied 신규/level 값만 신뢰하지 않는다.
- 사용 선택과 신규 분석은 별개다. 과거 Issue18의 활동 자동추가/명시 제외 영속정책을 이번에 자동 구현하지 않는다. 현재 미선택만으로 ‘사용자가 직접 제외’인지 알 수 없으므로 기존 관찰 기준선·신규 후보·분석 완료를 구분한다. 명시 제외가 별도 필요한 경우 최소 계약을 협의하며 설정 UI/별도 관리단계를 선제 추가하지 않는다.
- 시작 시 사용 선택/설정·후보/목록 revision을 고정한다. 도중 명시 선택/해제·소유 변경은 서버 최신 검증이 우선이며 전체 오래된 snapshot으로 설정을 덮지 않는다. 관찰 실패/누락을 새 후보 소비·소멸/퇴역 근거로 사용하지 않는다. 선택되지 않은 캐릭터의 목록·기존 저장 빌드도 삭제하지 않는다.
- 외부 호출 일반량은 소유 원정대당 siblings1+선정 armory N이다. 최초 인증 장비 조회·404 anchor 대체최대3·현재 명령 복구/실패 등 예외는 구분한다. 앱↔서버 GET 수를 외부 provider 호출 수와 혼동하지 않는다. 목록 성공/상세 일부 실패는 각각 표시한다.

### 하나의 진행·결과 카드 재사용

기존 _progress의 표현을 최소 공통 컴포넌트로 분리하고 자동 controller/원정대 수동 실행 상태를 전달한다. 같은 화면/runner를 복제하거나 앱 실행1회 제한을 초기화해 수동 갱신을 실행하지 않는다. 실행별 source(자동/인증/원정대 수동), 원정대 라벨·UUID, stage, targets/items, 대기/오류·허용 행동을 보존한다. 수동 결과의 건수 문자열 축약은 항목 결과 보관으로 교체한다.

- 버튼은 원정대 안에 유지한다. 진행 중 ‘갱신 중’, 새 전체 명령은30초 대기와 더 긴 서버대기·중복 방지를 존중한다. 재시도/결과확인에도 서버 명령 규칙과 중복 방지를 적용하며30초 의미를 새 전체 갱신과 구분한다.
- 상단 카드 제목은 ‘자동 갱신’/‘원정대명 갱신’으로 대상 범위를 명확히 한다. 목록 확인→대상 준비→분석→완료를 표시한다. batch 응답 전 모르는 세부 진행률은 만들지 않고 ‘N명 갱신 중’으로 표현한다. 실제 항목 결과가 왔을 때만 처리 수를 올린다.
- 완료는 저장/경고/실패/결과확인 대기/정책제외를 구분한다. 캐릭터명+서버/원정대+사유를 표시하며 같은 이름도 UUID/원정대로 식별한다. 저레벨 미대상은 실패로 집계하지 않는다. 선택 없음/대상 없음/목록 확인 실패도 성공0과 구분한다. 신규 후보는 ‘신규1700 확인’으로 별도 식별하되 자동 사용 등록을 암시하지 않는다.
- 추천안: 완료 후 ‘닫기’는 표시만 접는다. 해당 원정대 ‘갱신 결과 보기’에서 API호출 없이 다시 연다. 상단은 최신 시작 실행을 표시하고 다른 자동/원정대 결과는 각 진입으로 재열 수 있게 보관한다. 진행 중에는 강제 취소/동작 변경을 추가하지 않으며 현재 완료 후 닫기 정책을 유지한다.
- 실패 다시 시도는 실패/미완료 대상만, ‘갱신 결과 확인’은 pending 원요청 복구다. 성공 항목/원정대 전체를 다시 분석하지 않는다. 새 작업이 조용히 과거 자동 결과를 삭제하지 않도록 표시 선택과 실제 실행 상태를 분리한다. UI 결과는 기존 앱/회원 세션 수명, 서버 후보/명령 근거는 영속이다. 로그아웃/회원·환경 전환/소유 세대 변경시 이전 개인 결과를 표시하지 않는다. 전체 결과 이력 DB/새 조회 화면은 추가하지 않는다.

### Backend B1 설계 회신 대조 (2026-11-17)

[Issue18 B1 6942884206](https://github.com/heo0328/lostparty-backend/issues/18#issuecomment-6942884206) 수신. 확정4개 정책은 모두 수용됐으며 다시 제품 질문으로 돌리지 않는다. Backend는 dev4c2cff0 정적 대조/문서검증만 수행했고 feat/roster-refresh-policy·설계 미커밋/미push, 코드/DDL/OpenAPI/dev실행 변경 없음이다.

- 수용 가능한 기술 방향: 기존 Activity/summary·AnalysisFetch·24h ACK만으로 후보 이력을 대체할 수 없다. 정상 owned 목록 반영 트랜잭션에서 소유세대/UUID별 기준선·신규/첫1700 후보를 최소 영속 보관한다. 활동 자동추가 상태와 분석 후보는 구분한다. 임대/실행 fencing과 원명령을 연결하고, 저장 summary+후보 성공+ACK를 한 transaction으로 처리하는 방향이다. 두기기 동시/선택경로·후보중복/개별manual성공도1회 완료로 합친다.
- Native 소비 방향: 기존 분석 POST·50개/20초/동시2를 재사용한다. 새 후보 명령만 candidate_id/generation·expected_policy_version 등 합의된 검증 근거를 넣으며 기존 pending은 원본문 그대로 복구한다. 기존 bootstrap의 opt-in projection 또는 범위 profile 중1개로 후보/blocked·미해결 command를 조회하는 안을 Backend와 최종 고정한다. GET은 읽기 전용/no-store이고 현재 후보 상태와 과거 ACK를 구분한다. DTO·상한/페이지·profile명은 아직 미확정이다.
- 복구: terminal 실패 신규후보는 blocked 보관·명시 재시도. unknown/in_progress는 원ID/본문 복구, 원ACK 정리 이후에는 성공 후보의 현재 저장정보를 읽고 상세를 재호출하지 않는다. 미해결은 서버 실행세대/임대 대조 후 재개하며 임의 새ID로 우회하지 않는다. 기존 원장 완료ACK24h/미완료48h 수명을 후보 영속 성공/실패 수명과 혼동하지 않는다.
- 제품 추가2개 사용자 확정: 앞으로 사용자가 명시 해제한 캐릭터는 신규/첫1700 자동 분석도 제외하되 개별 수동은 허용한다. 과거 미선택만으로 명시해제를 소급 추정하지 않는다. 같은회원·동일account·소유세대 삭제/재등록은 제외/후보완료를 재사용하고 소유자가 바뀌면 승계하지 않는다. 실제 삭제/재등록 명령의 자료 수명은 이 확정 경계 안에서 구체화한다.
- 추가 질문 중 첫 인증/미설정: 사용설정 unconfigured에서도 정상 소유인증·사용자격을 통과한1700 최초후보 분석은 이미 확정된 첫등록/인증1회 정책에 맞춰 허용하는 안이다. 대표/configured를 자동 생성하지 않는다. needs_reconfiguration은 그 상태만으로 일괄 허용하지 않고 해당 캐릭터의 서버 소유/usable·설정변경 충돌을 검증한다.
- null→1700: 정책 도입 후 신규/정상관찰 캐릭터의 첫 유효1700이면 최초 후보, 도입 전부터 미선택/관찰불명인 자료는 기존 기준선 보존 제안이다. null을0으로 취급하거나 모든legacy1700을 신규로 발급하지 않는다.
- 상세분석 후보는 활동자동추가와 완료 조건이 달라 구현 계약 고정 시 별도 Issue로 분리하고 #18은 공통 관찰/제외 설계 출처로 연결하는 제안을 수용할 수 있다. 사용자 추가2경계 수용·진행 지시로 [Issue58](https://github.com/heo0328/lostparty-backend/issues/58)을 분리했다. 기존 분석명령 재사용·최소 후보읽기profile/DTO·manual명시retry·제외delta/삭제재등록 수명 계약 고정과 구현 인계를 요청했다. 기술계약 회신 전 guessed DTO/권한 우회 구현은 하지 않는다.

### Issue58 B1 기술계약 소비 대조 (2026-11-17)

[Backend B1 6943318871](https://github.com/heo0328/lostparty-backend/issues/58#issuecomment-6943318871) 수신. 실행 API 지원완료가 아닌 구체 계약안이며 Backend 미커밋/미push·코드/명세/dev 변경 전이다. 제품정책 차이는 확인되지 않았다.

- 후보 읽기는 GET /v2/me/account-bootstrap?include_analysis_candidates=true, include_roster_presence와 병용. 기본false는 새키생략, true는 registrations[].analysis_candidates(현재소유 아닌 경우null). scope/policy/baseline·candidate id/generation/reason/state/eligibility·대기/last_error/미해결원본문/완료근거를 제공한다. 원정대당 최대200 전체·페이지없음/정렬candidate_id이며 초과409는 빈목록으로 숨기지 않는다.
- 기존 POST /v2/me/character-analysis/refresh item에 후보 신규명령만 candidate_context(id/expected_generation/expected_policy_revision/expected_settings_version/purpose). purpose automatic_candidate 또는 manual_retry는 trigger와 일치해야 한다. blocked명시retry만 generation CAS/+1, 같은ID replay는 원ACK. 기존pending 원본문은 새필드를 끼우지 않는다.
- 기존 설정 PUT management-2에 새명령 expected_analysis_policy_revision을 추가하고 과거body 생략허용. 서버 실제A-B만 명시제외, B-A 재선택시해제, 둘다미선택은제외추정금지. 같은소유세대 보존/타소유승계금지. Native 실제gateway writer와 기존V1 경로의 동일delta/CAS까지 구현시 대조한다.
- automatic Activity선택과 검증후보를 함께 허용하며 나이스단OFF/명시제외·blocked자동재개금지를 서버에서도 검증한다. 저장/후보성공/ACK 원자성·두기기임대/fencing·선택중복/단건manual성공소모를 유지한다.
- 추가기술확인2개: recovery=reconcile_required의 정확 복구POST/ID/본문·원장정리 뒤 응답 예시, 새코드별 state/status/retry enum 및 다른명령임대복구·정책제외blocked의 명시manual_retry 허용 예시. Native _parse는 현재 skipped를 AUTOMATIC_TARGET_EXCLUDED만허용하므로 신명세 strict/버튼동작을 같이 확장해야 한다. 계약문의는 제품결정 재요청이 아니다.

확정된 나머지 계약은 수용하고 Backend에 예시/명세 보완과 구현·표적검증·게시 인계를 요청했다. 실제소스/OpenAPI가 게시되기 전 추측DTO를 작성하지 않는다. 사용자인수/서버반영은 아직 미실행이다.

### Issue58 B2/B3 고정 계약·dev 지원 수신 (2026-11-17)

[B2 6944474148](https://github.com/heo0328/lostparty-backend/issues/58#issuecomment-6944474148)·[B3 6944629650](https://github.com/heo0328/lostparty-backend/issues/58#issuecomment-6944629650)을 수신했다. 앞선 기술확인2개는 해소됐다. WSL 로컬 OpenAPI SHA256 12634daa64a8c4cbdfecfdb53bc7c1aca3bdb721c5ea555d098aea51544b9665를 직접 대조했다. Backend feat/roster-refresh-policy는 기준4c2cff08 위 미커밋/미push이므로 이SHA를 구현게시SHA로 취급하지 않는다. 현재 로컬 명세·합성예시를 고정해 소비할 수 있으며 원격게시와 구분한다.

- reconcile_required: 별도 endpoint 없이 기존 분석 POST에 items=[unresolved_command.command] 원ID/원본문 그대로 전달. 현재세션/소유/usable/ownership→저장원본문→원장/후보실행세대→복구 순서. 만료된 원장/ACK24h/미완료48h·정리후 미해결은 외부호출 없이 blocked로 정리하고 ANALYSIS_CANDIDATE_RECONCILED/failed409/new_command. projection 재조회 후 사용자 manual_retry 새ID만 허용한다. 정리에 한해 옛 lifecycle/policy/settings를 허용하며 새 수집을 하지 않는다. 원ACK유효는 replay, 실행중은 REQUEST_IN_PROGRESS, 성공후보는 COMPLETED skipped/저장읽기. 소유자격 상실은 원권한오류.
- 코드 확정: NOT_FOUND=failed404/none, CANDIDATE_IN_PROGRESS=failed409/none(거절ID반복 금지·projection의 owner원명령복구), RETRY_REQUIRED/COMPLETED=skipped200/none, RECONCILED/REVISION_CONFLICT=failed409/new_command. new_command는 자동루프 허용이 아니다. blocked+나이스단OFF/명시제외도 현재소유/usable의 개별manual_retry는 허용하며 새ID/최신context로 실행한다.
- policy_revision은 명시선택/제외 CAS이며 후보state변경마다 증가하지 않는다. 같은원정대 독립후보는 generation/command/lease로 경합 검증한다. 기존 pending 본문은 변조하지 않는다.
- Backend 검증 보고: current131PASS/하위13, bootstrap/management86PASS, 최종후보/예시/migration17PASS, 격리이미지OpenAPI191경로일치·JSON Schema/DTO·문서diff PASS. 마지막 복구/48h보완은 최종17검증에 포함되며 앞선회귀를 최종후 반복한 것으로 확대하지 않는다.
- 사용자 별도 승인 후 실제 dev0037→0038 migration/API healthy·전체명세 일치, 실행image9740bd51…f8ea018. 기존114테이블/794행 지문·키5개/환경 보존은 Backend 보고다. legacy정책3/fact47 기준선, 미선택후보부활없음. 실제미로그인bootstrap401/서비스읽기opt-in·roster_presence병용/GET무쓰기 확인은 보고이며 회원 실제HTTP분석저장/Native·기기인수는 아니다. 운영/provider/자료초기화/삭제 없음.

Native 소비 결과: 고정 OpenAPI/예시로 strict DTO/context·후보조회/원본문복구·선택delta·결과카드 일반연결/자동검증을 마쳤고 사용자10항목/실패 결과 표시를 확인했다. 기존 기술확인2개를 다시 요청하거나 migration/서버교체를 반복하지 않는다. 신규/삭제 실제 사례와 전체 오류 대응 시험은 아래 후속으로 구분한다.

현재 게시 근거: [Backend B7](https://github.com/heo0328/lostparty-backend/issues/58#issuecomment-6947695749)의 dev 2e78854ef9644a02fd7a00b4c247c79f89e25f25에 후보 구현8f29271d와 0038 모집/현황 복구08212c3·문서b6105ef가 통합·push됐다. 기존 계약 해시/실행dev0038은 유지하며 사용자가 오류화면 해소를 확인했다. 앞선미게시표현은B2/B3수신당시이력이다. 사용자정상인수이후확인필요카드문구는공통정보파랑·명백한오류는기존테마빨강으로보완한다.

### 작업 순서·역할·완료 조건

1. Native 조사 근거·사용자 수용/미결정을 이 설계에 기록. Backend는 기존 Issue18과 자동 후보 권한/영속모델 재사용 가능성만 협의하며 아직 구현하지 않는다.
2. 확정 제품 경계(신규1700·첫등록/인증·실패 명시 재시도·나이스단OFF)에 Backend DTO/권한·원자성·회신을 대조해 기술 계약을 확정한다. 범위를 임의 확대하지 않는다.
3. Backend 후보 판정/최소 명세 확장·직접 경계 검증/게시·dev 준비 → Native strict 소비/대상 snapshot·공유 결과 카드/원정대 runner 연결. 기존 자동·수동 공통 executor/명령 journal 재사용.
4. 경계 자동검증:1699→1700/신규1700·신규저레벨·null·사용선택저레벨, 과거 미선택·재실행/두기기 중복/동시 선택해제·UUID/소유 변경,0대상·부분성공/경고·원요청 복구/24시간·대기/중복·완료닫기 비수집·실패만재시도. 기존 자동/인증1회·설정/대표/나이스단·카드/주간/그룹 소비를 보호한다. 상태 로직이 같으면 인원별 시험을 복제하지 않는다.
5. 웹/Android 일반 DI→원정대 버튼/자동→서버 저장→카드/상세 재조회 연결 후 사용자에게 실제 갱신·실패명·닫기/재열기·선택/신규 발견 확인을 안내한다. 합성 시험은 실서버/실기기 인수를 대신하지 않는다. 포맷/diffcheck·변경 분석, 공용/명세/DI 영향에 따라 최종 전체 Flutter검증을 판단한다.

완료는 제품 합의·서버 게시/dev·Native 일반 연결·자동검증·사용자 확인을 각각 기록한다. Native는 후보opt-in/strict스키마·원본문복구/관리CAS·원정대선택대상/인증후합집합·공통결과카드를일반앱에연결했다. 전체2873PASS·최종직접49PASS/분석0이며 사용자가안내10개테스트/실패결과표시를통과확인했다. 신규/삭제실제사례는운영피드백으로이관하고인수조건으로반복요구하지않는다. 색상보완/검증은NEXT_WORK·DEV_LOG를따른다. 사용자 지시로 Native 누적 구현·문서를 커밋하고 로컬 dev에 통합한다. 원격 push/main/서버/DB/키/배포 추가 변경은 없다. 최신 보관 결과는 Git/Issue58 인계를 따른다.

<a id="native-implementation-design"></a>

### Native 구현 기획·설계 (2026-11-16)

아래 설계에 따른 **Native 일반 앱 경로 연결을 완료**했다. 게시된 Backend `b95cff51`의 `character-analysis-refresh-1`의 소비 기준이며, 설계 완료를 Flutter 기능 연결·새 개발서버 연동 완료로 취급하지 않는다. 웹과 Android는 같은 Domain/API/상태 흐름을 사용한다. 실제 진행·검증과 다음 행동은 NEXT_WORK에서 관리한다.

#### 1. 사용자에게 제공할 화면과 행동

| 영역 | 비로그인 | 로그인 | 공통으로 보존할 표현·동작 |
|---|---|---|---|
| 내 계정 | 처음부터 명확한 ‘예시 데이터’ 표시와 가상 원정대·캐릭터 카드/주간표/가능시간·예약 표시. 보기·펼치기·주차 탐색만 가능 | 실제 회원의 로딩/빈 상태/등록 원정대·활동 캐릭터·역할/주간/시간 자료. 등록·갱신·설정은 기존 권한 적용 | 최신 카드/상세/표현 부품을 공유. 예시 전용 전체 페이지나 가짜 Repository/회원 세션을 만들지 않음 |
| 레이드 모집 | 실제 공개 discovery 목록·최신 필터·정렬·페이지·현재/다음주 탐색, 공개 카드 요약 확인 | 기존 공개/권한 있는 그룹 검색과 개인 후보·생성/참가/신청/관리 | `CycleRecruitmentListPage` 경로 하나. 기존 필터 초안/주차·스크롤·탭복귀·반응형 유지 |
| 그룹 | 같은 최신 화면에서 공개 그룹 검색·summary와 기능 안내 | 기존 내 그룹/요청/활동·가입/생성/관리 | 공개 summary만으로 내부 회원·활동 캐릭터를 꾸미지 않음. 회원의 기존 홈/검색 동선 유지 |
| 레이드 현황·개인 설정 | 최신 화면 틀과 기능/로그인 안내. 개인 목록이나 완료 기록은 만들지 않음 | 기존 개인 현황·완료/가능시간·설정·복구 | 계정 예시를 다른 기능의 가상 업무 자료로 확대하지 않음 |

예시 이름은 `예시 원정대`, `예시 딜러`, `예시 서포터` 등 가상임을 알아볼 수 있는 고정 자료를 쓰고 실제 캐릭터 조회 입력으로 넘기지 않는다. 주간 완료/예정/시간 블록은 화면 구조 설명만 하며 서버 시각·실제 예약으로 주장하지 않는다. 예시의 외부 API/DB 접근/명령 실행은 0이다. ‘캐릭터 불러오기’·‘API 토큰 등록됨’ 같은 종료 대상 안내는 제거한다.

개인 행동을 누르면 ‘로그인하면 원정대 관리와 모집·그룹 참여를 이용할 수 있습니다’처럼 해당 기능을 설명하고 로그인/취소를 제공한다. 로그인은 시그니처 FilledButton, 취소는 OutlinedButton으로 표현한다. 성공 후 안전한 원래 화면으로 돌아오되 생성/참가/갱신/저장을 자동 실행하지 않는다. 직접 URL도 동일한 gate를 적용한다. 인증 복원 중에는 중립 로딩을 표시하고 회원 자료와 예시가 잠깐 섞이지 않게 한다.

#### 2. 앱 연결과 데이터 소유

일반 실행은 `main → BackendApp → 공통 화면 → VM → 기존 업무 client / 새 분석 client → Backend`다. 서버가 키·외부 수집·역할/무결성 분석·최종 저장·참가 자격의 원본을 소유한다. Flutter는 화면 상태·현재 세션별 읽기 캐시·입력·명령 결과 복구만 소유한다. 표시 역할 변경은 기존 preferences 저장이고 분석 역할 지정이 아니다.

| 수정 지점 | 구체 작업 |
|---|---|
| `lib/app/backend_app.dart`, `backend_member_account.dart`, `account_session_view.dart` | 개인 키 조립/restore와 직접 transport 주입을 제거. 동일한 최신 계정/모집 화면에 세션별 데이터·허용 행동을 연결. 위젯 전체를 guest/member로 복제하는 분기는 종료하되 공통 인증 수명 처리는 유지 |
| `member_account_page.dart`, `member_account_view_model.dart` | 최신 원정대·캐릭터/상세·주간표·시간표의 실제/예시가 공유할 표시 자료와 부품만 추출. 기존 회원 명령을 예시 VM에 흉내 내지 않음. `analysis()`의 로컬 raw 재분석은 서버 detail 읽기로 대체 |
| `CycleSearchViewModel`, `cycle_interaction_repository.dart` | 공개 탐색과 개인 context/후보의 접근 조건 분리. 일반 필터·목록은 guest도 작동하며 개인 조건/그룹 권한 자료·command는 기존 회원 gate 유지 |
| `GroupRepository`, `BackendGroupViewModel/Page` | 공개 검색/summary의 익명 읽기만 허용하고 `/me`, 전체 상세/관리·명령은 인증 유지. guest 홈에 공개 탐색 진입/기능 안내를 연결하고 회원 홈 동작은 유지 |
| `DioBackendAccountReadApi`, `MemberRaidClient` | 기존 공개 GET transport 방식에 맞춰 허용한 공개 요청만 무토큰으로 보냄. 분석 POST는 60초 timeout·현재 세션/환경 검사·인증 만료 1회 갱신을 유지. 코드/요청ID/대기 시각을 VM까지 보존 |
| `role_summary.dart`, `account_bootstrap.dart`, `ScopedAccountRuntime`·role 읽기 저장소 | `server_analysis` 요약·full detail과 bootstrap 요약형을 구분. raw/클라이언트 분석·업로드 상태 대신 서버 head와 현재 명령 결과를 읽음 |
| `admission_candidates.dart`, `application_display.dart`, 그룹 DTO·내장 wire/schema 및 관련 소비 | 최신 head의 단일 version/source/trust/시각·무결성으로 전환. 생성/입장·교체/재참가·신청·일정 context/snapshot 소비까지 대조 |

새 범용 상태 프레임워크/Repository 계층을 추가하지 않는다. 서버 head의 요약 공통 자료를 공유하고 detail 유무만 DTO에서 구분한다. 캐릭터 ID는 canonical UUID이며 로컬 표시용 정수 ID를 서버 식별자로 쓰지 않는다. 캐시 키와 적용 검사는 환경·회원·세션/읽기 세대·UUID·소유/수명·역할/head version에 결합한다. bootstrap은 상세 없음이 정상이며 detail 조회 실패를 미저장 역할로 처리하지 않는다.

**공개 transport와 주차의 실제 차이:** 공개 모집 POST는 읽기 요청이다. `POST /v2/raid-rooms/search?response_profile=discovery-1`, `GET /v2/raid-rooms/{id}`, `GET /v1/groups`, `GET /v1/groups/{id}`, `GET /v1/raid-catalog`, `GET /v1/raid-cycle`만 지정된 공개 입력/응답으로 연결한다. guest는 Bearer/accessToken/refresh를 사용하지 않는다. 기존 회원 API의 인증검사를 일괄 완화하지 않는다. `GET /v2/raid-cycles`는 실제 Backend `weekly_summary_router.py`에서 **Principal 필수**다. guest가 이를 호출하거나 회원 permissions를 위조하지 않는다. 공개 `/v1/raid-cycle`의 서버 기준 현재 주차/시작·종료에 기존 7일 주차 규칙을 적용해 현재/다음 탐색 대상만 표시하고, 실제 검색 허용은 서버가 판단한다. 회원은 기존 `/v2/raid-cycles`의 권한 자료를 계속 쓴다. 이 표시 투영을 위해 새 endpoint/가짜 MemberCycles를 만들지 않는다.

로그인/로그아웃·회원/환경/세션 전환 때 이전 개인 자료·후보·권한 토큰·cursor/페이지와 진행 결과 적용을 무효화한다. 공개 레이드/난도/시간/정렬 같은 일반 필터만 유지해 현재 권한으로 다시 조회한다. 진행 중 HTTP 취소 여부와 별개로 늦은 응답은 적용하지 않는다. 새 로그인에 이전 쓰기를 자동 재생하지 않는다. 일반 GET·카드 펼치기·필터/참가 조작에는 로아 수집을 추가하지 않는다.

#### 3. 서버 분석 요청·부분 결과와 복구

2026-11-17 사용자 확정: 원정대 인증 성공 후 계정 복귀 시 성공한 원정대만1회 갱신한다. 각 소유 원정대 이름 옆 ‘전체 갱신’은 해당 원정대의 active·usable·차단 없는 캐릭터 전체를 기존 서버 분석 batch로 수집/저장한다. 활동선택·나이스단 자동 제외와 별개인 사용자 원정대 단위 명령으로 manual trigger를 사용하며 다른 원정대 수집은 하지 않는다. 앱 회원 세션 내 원정대별30초 대기를 적용하고 서버 공유 대기가 더 길면 존중한다. 진행·저장/실패/결과확인 건수를 표시하고 원요청 복구를 재사용한다. 성공 복귀 작업은 기존 runner/read/write가 끝난 뒤 실행하고 일반 계정 재진입/새로고침으로 재실행하지 않는다. 최초 자동 갱신과 개별 캐릭터 갱신 정책은 유지한다. 서버 전역 rate limit/운영 환경 변경은 아니다.

기존 자동 갱신 시점과 원정대 목록 갱신 후 대상 선정, 수동 단건 갱신을 유지한다. `RuntimeStartupRefreshSource`와 기존 runner를 새 서버 명령 실행에 맞춰 교체한다. 자동 대상은 현재 usable/활동/소유·수명이 맞는 캐릭터이며 나이스단 기준·설정은 기존 정책을 재사용하고 서버가 최종 검증한다. 한 캐릭터의 중복 실행을 막고 자동/수동이 겹쳐도 별도 원본 분석을 만들지 않는다.

요청은 위 고정 명세의 items1..50·항목 command_id/character_id·소유/수명 revision·dealer/support expected version·automatic/manual만 보낸다. UTF-8 524,288byte·중복ID 금지/strict 형식을 지킨다. 최대50개 단위로 순차 처리하고 외부 동시2/20초 예산은 서버가 소유한다. Flutter가 Armory별 병렬 수집기/서버 작업 큐를 다시 만들지 않는다. 실행 전 대상·양역할 version을 읽고 원 항목을 고정하며, 충돌 때 원 요청 version을 조용히 바꾸지 않는다.

| 서버 결과 | 앱 반영·다음 동작 |
|---|---|
| `saved` / retry none | 반환된 감지 역할의 head를 즉시 반영. 낮은 수치·null·integrity error도 저장 성공이며 경고와 성공을 함께 표시. 반대 역할/표시 선호는 유지 |
| `skipped` / none | 자동 대상 제외로 종결. 기존 head/시각을 갱신하지 않음 |
| `failed` / none 또는 new_command | 이번 명령은 확정 실패. 이전 head/확인시각 유지. 재시도가 허용되면 대기·현재 대상/권한 확인 후 사용자 명시 행동으로 새 command_id 생성 |
| `not_processed` / same_command | 서버 예산상 미시도. 원ID/원본문으로 남은 항목만 후속 처리. 같은 실행 안에서 진전이 있고 대기/오류가 없을 때만 순차 자동 후속, 연속 진전 없음·공유 대기·통신오류·세션 변경 때 중지하고 안내 |
| `in_progress`, `unknown` / same_command | ‘처리 결과 확인 필요/처리 중’으로 표시. 서버 retry_at/seconds 준수 후 원ID/원본문으로 결과 확인. 실패로 단정하거나 새ID로 수집하지 않음 |
| HTTP 응답 유실/불완전 envelope·형식/상관관계 오류 | 보낸 항목의 저장 여부는 미확정으로 유지하고 복구 가능한 원 항목을 보존. 검증되지 않은 결과를 부분 성공으로 적용하지 않음 |

HTTP200을 전체 성공으로 보지 않는다. 개수·순서·command/character ID·state/status/retry·감지 역할/result.role/detail.detection·소유/수명/version·catalog·숫자/시각 null쌍을 검사한다. 최신 head가 더 앞서 있거나 수명이 달라졌으면 과거 ACK로 화면/캐시를 역행시키지 않고 현재 GET으로 확인한다. 저장 ACK 후 현재 GET 실패는 저장 실패나 새 수집 재시도 사유로 바꾸지 않는다. 진행 표시는 성공/실패/제외/미시도/결과확인 대상을 구분하고 옛 ‘로컬 분석/서버 업로드 대기’ 문구를 없앤다.

새 분석 명령의 응답 유실 복구는 기존 명령 journal 방식에 맞춰 **별도 operation/namespace**로 둔다. 환경/회원·생성/전송시각·원 항목과 상태/대기 근거만 보존하며 키/raw/가공 summary를 저장하지 않는다. 디스크 기록 실패 시 새 수집을 시작하지 않거나 이미 보낸 명령의 불명 상태를 그대로 알린다. 재시작 후에는 현재 접근·소유/수명을 확인하고 원 요청 결과 확인 동작을 제공한다. 완료24시간/생성48시간 이후 및 멱등 충돌/만료는 blind replay를 중단하고 현재 GET/명시 새 갱신으로 전환한다. 옛 summary upload pending은 새 명령으로 변환하지 않는다. 회원 전환으로 예전 pending을 다른 회원에게 표시/재생하지 않는다.

역할 캐시는 서버 projection 전용으로 바꾸며 기존 캐시의 raw/로컬 pending을 신뢰하지 않는다. 새 strict DTO와 맞지 않는 옛 분석 payload는 서버 읽기 cache miss로 취급하고 재조회한다. 옛 parser/fallback/출처 이름 변환은 추가하지 않는다. 원정대/캐릭터 cache와 preferences/presentation·대표/캐릭터 관리/모집/그룹의 현재 명령 journal은 유지한다. 실제 기기 DB/보안저장 키·옛 행 일괄 삭제는 별도 범위 확인 후 실행하며 DB 전체 삭제를 전환 수단으로 삼지 않는다.

#### 4. 상세 읽기와 오류 안내

bootstrap은 요약으로 초기 카드를 표시한다. 상세 펼치기에는 personal-profile 단건/필요한 배치 GET의 **저장된 detail**을 사용한다. 동일 UUID/역할/head version의 상세가 있으면 재사용하고 요약 version이 바뀌면 옛 상세를 새 값과 섞지 않는다. 서버 saved 결과의 summary/detail은 바로 재사용해 불필요한 재조회와 신규 기기 raw 누락 안내를 없앤다. 숫자 반올림/시각·반응형/문구 표현만 Flutter가 담당하며 룬·보석·역할·아크그리드 판정을 다시 계산하지 않는다.

현재 전환에서 등록/preview/원정대 refresh·전투력·인증/분쟁·새 분석의 기존 안내/버튼을 함께 대조한다. 공용 `ApiCooldown`의 `/refresh` 일괄 차단은 새 수집과 원 명령 결과 복구를 구분하도록 수정한다. 새 수집은 공유 대기를 지키되 저장 GET/공개 읽기를 막지 않는다. 결과 복구는 서버 retry 지시를 따르고, 복구가 fresh 처리를 재개할 수 있다는 이유로 대기 중 자동 반복하지 않는다. 한 항목 대기를 batch 전체 실패/로그아웃으로 번역하지 않는다.

| 오류 분류 | 안내·기존 버튼 처리 |
|---|---|
| 서버 키 미설정/거절/교체 | ‘현재 로스트아크 정보를 갱신할 수 없습니다’와 기존 저장값 안내. 개인 키 입력/Google 로그아웃으로 유도하지 않음 |
| RATE_LIMITED / UPSTREAM_RATE_LIMITED | 서버 retry_at/seconds로 대기 표시, 해당 수집 버튼 연타 차단. 재호출 성공을 보장하거나 앱에서 30/60초를 새 정책으로 하드코딩하지 않음 |
| UPSTREAM_BUSY/UNAVAILABLE·불량/과대 응답·분석/역할 판정 실패 | 외부 정보 일시불가 또는 분석 불가를 구분하고 재시도 가능 여부를 표시. 503만으로 ‘로아 점검 중’이라 확정하지 않음 |
| 본인 인증/이용제한 | 기존 앱 세션 복구/로그인·권한 안내 유지. provider 401/403을 앱 회원 인증 실패와 섞지 않음 |
| 소유/수명/정합성·revision 충돌 | 대상 재조회·현재 상태 확인/명시 조치. 삭제·소유상실을 임의 확정하지 않음 |
| 결과불명/진행 중·전송 유실 | 새 실행 ‘재시도’와 원 요청 ‘결과 확인’을 구분. 위 상태표로 복구하며 확인/취소가 이미 전송한 서버 쓰기를 취소한다고 표현하지 않음 |

영향받는 VM에서 예외를 code 문자열로만 축약하지 않고 안전한 `code/status/requestId/retryAfter/retryAt`를 상태까지 전달한다. 사용자 문구는 앱이 관리하며 raw 오류/함수명/비밀값을 표시하지 않는다. 앱 전체 오류 리디자인·개발자전송 버튼/서버 진단 저장/30일 삭제는 별도 후속을 유지한다.

#### 5. 제거 범위와 회귀 보호

새 흐름 연결 후 `MemberLostArkKey`·회원/기기 키 페이지/라우트·키 readiness/version·직접 `LostArkApiClient`/remote, guest 로컬 계정 조회/저장, `scoped_role_sync`와 summary PUT/batch writer·업로드 pending 전용 복구, raw 분석/저장·툴팁 파서를 참조 대조해 제거한다. 구 `MyAccountPage`/`RecruitmentListPage` 및 미연결 `CharacterDetailPage`·장비 preview 등은 lib/test/tool의 소비를 확인하고 전용 VM/Repository/시험도 함께 제거·전환한다. 공유 카드·아이콘/시너지 catalog·나이스단·권한/정책·현재 명령 복구는 유지한다. 직접 로아 진단 tool의 token 의존도 검사하되 tool을 이유로 앱의 비밀값 경로를 남기지 않는다. 과거 migration/동결 계약/Git 이력은 재작성하지 않는다.

내장 `beta_wire_schema.g.dart`, `beta_original_wire_schema.g.dart`, `group_wire_schema.g.dart`와 관련 추출 tool/DTO/합성 fixture를 실제 게시 전체 OpenAPI 기준으로 대조한다. ‘original’도 현재 명령 복구의 계약이므로 옛 source/success 필드 계약을 그대로 남기지 않는다. 현재 새 명령의 원본문 복구는 유지하고 옛 자료 승계를 위한 다중 reader는 만들지 않는다. 일부 strict 검사를 풀어 새 응답을 통과시키는 방식은 쓰지 않는다.

회귀 보호는 ①Google 복원·등록/소유 인증/분쟁·누락/동일UUID 복구 ②활동/대표·표시 역할/정렬·가능시간·두 주차/완료/예약 ③기존 자동/수동 갱신·나이스단·부분 실패/제한 ④모집 생성/참가/신청·교체/재참가·일정/완료·그룹 명령/권한·원요청 복구 ⑤필터/스크롤/페이지/탭·로그인 전후 수명이다. 서버 분석 규칙 자체의 Python 재구현 시험을 Flutter에 복제하지 않고 게시 결과 소비/현재 흐름을 검증한다.

자동 검증은 exact DTO·숫자0/null/낮은값/error 저장·양역할 독립, 항목 상태/명령ID/미시도/불명/ACK·대기 경계, guest private 요청0/예시 무부수효과·회원/수명 변경/늦은 응답·cache version 일치에 집중한다. 최종 공용/저장/DI/다기능 변경 후 `flutter test`, `flutter analyze`, 포맷/diffcheck와 잔여 참조를 확인한다. 정상 화면의 중복 자동 UI 시나리오를 늘리지 않는다.

수동 확인은 사용자 담당이다. 웹은 URL/F5/뒤로가기·인증 복원/로그아웃·공개 검색/필터·키보드/넓은 화면, Android는 실행/복귀·로그인·자동/수동 갱신·폰/접힘·펼침 폴드/큰 글자와 같은 기능을 확인한다. 새 개발서버 버전/DB0037·키 공급·준비 자료가 확인되기 전 합성 검증을 실연동 통과로 부르지 않는다. Backend 환경 준비·자료정리·운영 배포/APK 게시·리전/BM·Penpot은 별도 실행 범위다.

### 공식 API 오류 대조·B1 보완 (2026-11-16)

작업 분리(사용자 확정): 이번 전환은 변경되는 오류의 서버→Native 안내·재시도/결과확인/대기 등 **기존 복구 UI와 정보 전달**을 함께 점검한다. 503만의 전용 기능이 아니다. 앱 전체 오류 UI 점검과 사용자 선택 진단 저장·전송/30일 삭제는 [별도 후속](../product/DETAIL_IMPROVEMENTS.md#app-error-review-and-diagnostic-reporting)이며 이번 API 전환의 선행/완료 조건으로 추가하지 않는다.

[공식API Errors/maintenance](https://developer-lostark.game.onstove.com/usage-guide#api-errors)·[Throttling](https://developer-lostark.game.onstove.com/getting-started/#throttling)을다시확인했다. 공식표는기본HTTP오류이며200/401/403/404/415/429/500/502/503/504다. 현재provider는401/403·429별도/그외공통오류와http_status를보존하고,service.lookup의provider_not_found·owned_refresh anchor처리및공유rate_limits가있다. 그러나415·5xx각각의안내/추가수집억제와공식전상태합성검증은완료근거가없다. [Native6910971244](https://github.com/heo0328/lostparty-backend/issues/55#issuecomment-6910971244)에B1보완을요청했다. 새오류enum/작업시스템을미리추가하지않고기존업무오류+안전한진단분류를재사용한다.

| 로아상태 | 구현·검증대응 |
|---|---|
| 200 | 형식/크기/JSON/대상검증후성공. Remaining0은현재성공유지·추가수집제한 |
| 401/403 | 서버키/접근문제,후보503키거절·개인키입력/Google로그아웃0. 같은고장키추가수집억제 |
| 404 | 대상조회실패,우리UUID404와분리. 기존anchor fallback조건만유지·캐릭터삭제/소유상실판정금지 |
| 415 | 서버요청형식점검,사용자자료오류/무한재시도금지 |
| 429 | 전사용자공유한도/Reset·Retry-After·retry_at,자체429와구분·추가수집중지 |
| 500/502 | 제공자내부/게이트웨이장애,저장불변·즉시반복금지 |
| 503 | 점검또는일시불가. 점검확정표시금지. 공식권고대로추가요청자제/간격조정·미시도자동후속의장애우회반복금지 |
| 504/timeout/connection | 외부응답지연/통신실패와우리DB commit결과불명unknown을분리·원명령복구 |
| 기타비200/redirect/불량본문 | 성공fallback금지·원문/키비노출·저장값/관찰시각불변 |

Backend는 [오류 보완6911910416](https://github.com/heo0328/lostparty-backend/issues/55#issuecomment-6911910416)과 B1/B2 구현·게시 회신으로 배치/worker 공유 수집 억제·상태/retry와 합성 검증 완료를 보고했다. 저장 GET/공개 읽기는 차단하지 않는다. 키 거절·415의 60초/5xx·통신의 30초 억제, 300초 Reset 검증/60초 fallback은 프로젝트 정책이며 공식 보장 시간이 아니다. 유효한 더 긴 Retry-After는 존중한다. 실제 provider 장애/한도 소진 시험은 하지 않았으며 Native 안내·복구는 위 계약으로 연결했고 실제 provider·새 dev 실행서버 확인은 남아 있다.

### character-analysis-refresh-1 후보1 검수·수용

요청은 items1..50의 command_id/character_id·소유/수명 revision·양역할 summary version·automatic/manual trigger이며 항목ID가 명령키다. 감지역할만 CAS·저장, 낮은값/error/확실한source-null도 최신head로 반영하고 별도 마지막nonnull성공값 fallback을 제거한다. 결과는 saved/skipped/failed/not_processed/in_progress/unknown, retry none/same_command/new_command다. 미시도는 reserve0·원명령 후속, 진행/불명은 원명령복구, 확정실패 뒤 새수집은 명시새명령이다. envelope와 항목status를 구분한다. 제안60초 Native timeout·20초서버예산·동시2를 수용한다.

StoredRole은 version/saved_at/summary/detail, bootstrap은detail없는요약형이다. 같은headversion·UUID/role/관찰시각/lifecycle·catalog를 검사하고 상세GET은provider0이다. PowerComparison과 그룹/후보 수치도 같은head를 사용하며 actual=null은 과거고수치로 대체하지 않는다. 역사snapshot은 당시값으로만 보존한다. 정확JSON/오류/Schema는 위고정댓글 원본을 따른다.

실제 소비영향: `role_summary.dart`의source/StoredRole strict형태, `admission_candidates.dart`·`application_display.dart`의success/current 이중필드와 마지막성공문구, `beta_original_wire_schema.g.dart` 등 내장exact wire의source/trust/성공값필드를 새전체명세 기준으로 교체해야 한다. 일부필드만 허용하거나 옛parser를 병행하지 않는다. 그룹/생성/입장·교체/재참가·신청/일정context도 함께 대조한다.

독립 메모리 구조대조23/23PASS: 정상request/response2·형식/상태거절18·ID상관1·저수치error저장1·source-null저장1. 사용Schema키워드 기반의 제한된 구조검사이며 Draft2020-12범용준수·실제API/DB·분석golden/기기시험이 아니다. code/state/retry·입출력순서/ID·역할/수명/catalog·null/시각과중복/byte제한은 구현semantic검증으로 유지한다. Native 추가재설계요청은 없고 Backend에 수용확인·공동고정/구현담당·실제소비명세 인계를 요청했다. 새fresh합류lease의현재세대/CAS/완료후재활용금지 역시 구현검증대상이다.

### 사용자 확정 목표와 작업 경계

- 개발자 JWT 하나는 Backend에만 보관한다. 웹·Android의 일반 실행에서 사용자 개인 키 입력·복원·직접 Lost Ark 호출을 끝낸다. 실제 비밀값 등록·운영 배포는 이번 조사에서 하지 않는다.
- 서버에 저장할 수집·분석 결과는 서버가 조회→가공→필요 자료 저장 후 반환한다. 원본을 Flutter에 보내 분석·업로드하게 하는 왕복을 유지하는 단순 프록시 전환은 목표가 아니다. 전체 Armory 영구 저장·무조건 전체 재조회는 승인하지 않았다.
- 로그인 여부로 구형 페이지를 선택하지 않고 최신 UI를 공유한다. 공개 모집·필터는 비로그인도 둘러보고, 개인 자료·설정 변경·생성/참가/관리는 로그인과 기존 권한으로 보호한다.
- 비로그인 개인 키 등록·로컬 원정대 저장·캐릭터 카드 생성은 종료 대상이다. 내 계정에는 최신 표현을 공유한 고정 가상 예시를 첫 진입부터 보여준다. 예시 표시·둘러보기와 실제 명령을 구분하고 예시는 DB/외부 API/가짜 회원 세션을 만들지 않는다.
- 예시임을 명확히 표시한다. 개인 행동은 로그인 안내로 연결하고 로그인 후 쓰기를 자동 재실행하지 않는다. 로그인하면 실제 회원 자료/로딩/빈 상태로, 로그아웃하면 예시로 전환한다. 이전 회원 자료를 예시로 재사용하지 않는다.
- 기존 역할 분류·표시 선택·나이스단·활동/대표·소유/식별자/누락 복구를 보존한다. **수집·역할 판정 성공은 수치 하락/세팅 오류도 최신값으로 저장**하고, 통신/응답/역할 판정 실패 때만 기존 저장값·관찰 시각을 보존한다. 새 현재 명령의 CAS/멱등/ACK를 유지하되 구버전·옛 raw/summary pending 승계용 shim·이중 writer/reader·전환 flag는 만들지 않는다. 임시 베타 자료는 필요 시 초기화/재수집 가능한 단일 구조를 우선하며 실제 삭제·초기화는 대상/영향 별도 결정이다. 새 BM·리전 이전·무관한 리팩터링은 제외한다.

### 승인된 Native 설계 — 갱신·역할·실패

- 자동은 기존 회원/앱 수명당 실행과 원정대 목록 갱신→현재 유효 활동 대상 선정 순서를 유지한다. 탭 이동·화면 열기·모집 참가/필터 조작에 provider 조회를 추가하지 않는다.
- 나이스단은 현재 전체 소유 원정대의 active 캐릭터에서 공통 기준1700 이상 동일 직업2명 이상으로 판정하고 해당 직업군 자동 갱신 허용 설정을 적용한다. 실제 갱신 후보는 활동/usable/current lifecycle이다. 레벨 기준을 별도 중복 구현하거나 수동 저레벨 활동 선택을 금지하지 않는다. 명시 단건 갱신은 현재처럼 나이스단도 가능하다.
- 회원 일반 경로는 `RuntimeStartupRefreshSource`→`analyzeScopedRoleBuild`가 감지한 역할로 저장한다. 서포터 겸용4직업은 카탈로그 감지+관련4티어 근거가 필요하며 기타 직업은 dealer다. unsupported/불명/복수 계열은 자동 저장하지 않는다.
- 현재 회원 상세의 역할 선택은 `savePreferences(preferredRole)`로 표시/선호 역할만 바꾼다. 미연결 `CharacterDetailViewModel`의 미리보기/저장역할 선택 흐름을 복원하지 않는다. Backend 제안의 요청 역할 강제 저장·명시 역할 선택 후 재수집은 도입하지 않는다.
- 사용자 확정: 빌린 보석의 높은 수치를 유지하지 않도록 **provider 성공+역할 확정이면 낮아진 전투력·보석 부족/타직업/아크그리드 오류도 당시 값과 integrity/issue로 해당 역할에 저장**한다. clean/review/error는 갱신 성공 여부와 별개다. 반대 역할은 덮지 않는다.
- 통신 실패·형식/대상 불일치·역할 불명은 덮지 않고 실패 사유·마지막 확인을 표시한다. 실패를 최신 성공/새 관찰 시각·0으로 바꾸지 않는다. 확실한 원본 미제공(null)과 전송/파싱 실패는 구분하고 숫자/관찰 시각의 null쌍 계약을 명시한다.

### 서버 분석 이전 묶음과 참조 자료

고정 원격 `302243fb7474e548c4eb722a1a40759274528322`의 아래 생산 소스/규칙을 Backend에 이전한다. Flutter에는 숫자/문구/반응형과 DTO→표시 변환을 남기며 같은 분석 writer를 병행하지 않는다.

| 묶음 | 고정 소스 위치·역할 |
|---|---|
| 분석 | `lib/features/account/data/mappers/character_build_analysis_mapper.dart`, `gem_tooltip_class_extractor.dart`: 룬·보석/직업·특수스킬·아크패시브·아크그리드 파싱/검사 |
| 판정·저장 요약 | `lib/features/account/domain/services/character_build_role_policy.dart`, `build_integrity_snapshot_mapper.dart`, `lib/features/account/data/mappers/scoped_role_build_mapper.dart`: 역할·integrity/issue·십진 문자열/시각/lifecycle |
| 분석 카탈로그 | `assets/game_catalog/game_catalog.v1.json`, 해당 mapper/entity/validator. raid_catalog와 구분. Flutter는 아이콘/시너지 등 표현에 필요한 정적 자료만 유지 가능 |
| 대상 선정 | `NiceGroupPolicy`, `projectScopedRefreshTargets`, 현재 startup roster/runner 정책. Native는 기존 트리거, 서버는 권한/현재 대상·나이스단 설정의 최종 적용을 담당 |

공통 대조 자료는 실사용자 원본 배포가 아니라 합성 입력/기대 의미를 사용한다. `test/fixtures/lost_ark/support_hybrid_builds_user_reference.json`은 확인 결과 직업4종×양역할의 계열/노드/보석 대상 문자열8행으로, 캐릭터명·계정·키·실사용자 raw가 없다. 이 정의와 `character_build_analysis_mapper_test.dart`의 `_hybridBuildFixture` 합성 builder를 재사용한다. 원본 전체 `character_armory_full.json`과 live foreign-class 표본은 인계 대상에서 제외한다.

추가 합성 경계는 같은 테스트의 보석11개/부족, 동일직업미확인/타직업/특수대상, source없음/명시빈목록, 룬8/누락, 아크그리드 해·달14/17P/조건누락, 역할불명/복수/unsupported와 수치0·null·쉼표/소수 문자열이다. 기대 결과는 현재 mapper/정책으로 산출해 Python 결과와 대조하되 `source`만 새 서버 출처로 변경한다. 캐릭터/서버는 가상 식별자, 시각은 고정 UTC를 사용한다. 이 절은 검증자료 범위 확정이며 Python 이식/동등성 검증 통과 보고가 아니다.

### 요청·반환·상세 저장 설계

단건/배치는 공동 확정·게시된 `POST /v2/me/character-analysis/refresh` 하나를 사용한다. 정확 JSON/오류/미시도 재호출 규칙은 Backend `b95cff51`의 분석 계약/Schema를 따르며 전체 실행 OpenAPI 대조는 Native 구현 첫 단계다.

| 경계 | Native 요구 |
|---|---|
| 입력 | 항목별 command_id·canonical character_id·ownership/lifecycle revision·양역할 summary expected version·자동/수동 갱신 의도. 강제 요청 역할/raw/클라이언트 summary/키를 받지 않음 |
| 저장 | 실제 감지 역할의 version으로 CAS. source=server_analysis/모집 trust=server_computed 제안을 수용하고 rules/catalog version·관찰 시각·역할 독립을 보존. 기존 flutter_analysis 값을 이름만 바꿔 서버 분석으로 위장하지 않음 |
| 결과 | 항목 식별/명령ID·결과/사유·수집/미시도/결과불명 구분·감지 역할·저장 version/시각·최신 summary·retry 시각. 수집성공/세팅error와 업무실패를 분리 |
| 예산 | 최대50항목/20초 제안 수용. 항목 독립 저장. 시간예산 미시도만 같은 갱신 실행의 후속 요청으로 이어가되 quota/통신실패 자동 반복 금지. 미시도·명령종결 여부와 ID 재사용은 최종 계약에 명시 |
| 최신성 | 새로운 수동 갱신을 오래된 cache만으로 성공 처리하지 않음. 실제 동시 fresh 관찰 합류와 동일 명령 ACK복구는 허용. 실패의 explicit retry는 결과불명 복구와 새 수집을 구분 |

| 화면/조회 | 서버가 제공할 최소 데이터 |
|---|---|
| 기존 카드/bootstrap | UUID·원정대/소유/수명·활동/대표/표시 설정, 이름/서버/직업/레벨, 역할별 수치·integrity/issue·확인시각. 주간/예약/가능시간은 기존 계약 |
| 역할 summary | 역할·item_level/combat_power 십진 문자열과 각각의 관찰시각(nullable쌍), 분석시각·lifecycle·rules/catalog version·integrity/진단 코드·저장version |
| 펼친 상세 | 계열판정 status/id/표시명·감지역할·1티어/관련노드, 룬수·보석수/source가용성, 보석별 슬롯/레벨/대상/설명/분류/검증, 아크그리드 이름/등급/point/최소·권장/조건·필요/누락노드, notice code/severity/표시자료 |
| 진행 | 대상/성공/실패/제외/미시도 수·항목사유·retry근거. 로컬 raw저장/서버업로드 대기 문구는 새 서버 명령 상태로 대체 |

personal-profile(단건/배치)를 역할 읽기 원본으로 확장하고 bootstrap은 첫 화면 요약만 제공한다. 펼친 상세는 필요할 때 **저장된** 구조화 projection을 조회한다. 같은 캐릭터/역할/version/관찰 시각의 summary와 detail을 연결하고 새 기기도 읽을 수 있어야 한다. raw/tooltip 전체를 내려 Flutter가 재분석·재업로드/영구 저장하지 않는다. 표시용 반올림·한국어 문구·시각 초 단위 형식은 Flutter 책임이다.

### 공개 UI·예시·제거와 구현 순서

- Backend 회신의 기존 공개 discovery-1·그룹 summary·raid-catalog/cycle를 재사용한다. guest에는 `/me` context·개인후보·실제 `/detail`/plan·신청/내그룹·비공개 자료를 요청하지 않는다. 공개 요약을 펼쳐 보여주며 생성/참가/관리 실행은 로그인 안내다.
- 최신 UI는 공유하되 인증에 따라 reader/허용행동/자료를 선택한다. 로그인 전후 cursor/개인 조건은 재사용하지 않고 일반 필터만 유지해 현재 권한으로 조회한다. 별도 guest 전체 페이지/가짜 업무 writer를 복제하지 않는다.
- 계정 예시는 고정 가상 원정대·캐릭터·가능시간/예약으로 최신 카드/주간표/시간표를 공유한다. 상단 예시 표시, DB/외부API/실명령0, 보기/펼치기/주차 탐색만 허용, 개인 행동은 로그인. 인증 복원 중에는 이전 회원/예시를 실제값처럼 섞지 않으며 로그인 실제 로딩/빈상태·로그아웃 예시로 전환하고 늦은 응답을 무시한다.
- 서버는 개인키 CRUD/restore·회원 암복호화 readiness·클라이언트 summary PUT/배치 writer를 종료하고 기존 업무 GET/설정/권한·공유 quota·현재 명령 CAS/ACK는 유지한다. Native는 직접 호출/키store/readiness·로컬 raw분석/옛 upload명령·구형 페이지와 전용 참조/시험을 제거한다. 현재 다른 기능 writer를 함께 삭제하지 않는다.
- 순서는 Native 대조 회신→Backend 최종 API/저장/제거 영향표→양측 계약 고정→공통 UI·공개 탐색→서버 분석+새 Native 요청→옛 경로 제거/통합검증이다. 작업별 이중 실행/임시 호환 플래그를 남기지 않는다. 분석·응답이 미확정인 상태에서 endpoint/DTO를 추측 구현하지 않는다.

### Flutter 실제 실행 경로 조사 결과

경로는 저장소 루트 기준이다. 테스트 전용과 일반 앱 실행을 구분한다.

| 사용처 | 현재 경로·책임 | 전환 판단 |
|---|---|---|
| 앱 조립·직접 transport | `lib/main.dart`→`BackendApp`; `lib/app/backend_app.dart`의 `LostArkApiClient`→`LostArkCharacterRemoteDataSource`. siblings와 종합 Armory를 직접 호출. profile도 종합 Armory에서 추출 | 개발자 키를 앱에 주입하지 않는다. 실제 업무 요청을 서버 경로로 바꾼 뒤 이 직접 transport의 잔여 참조를 제거 |
| 회원 키·게스트 키 | `member_lostark_key.dart`: metadata/restore, 회원·서버별 secure storage, guest store. `/settings/api-token`, `/settings/device-api-token` 라우트 | 키 관리 UI/복원·키 readiness/version 의존 종료. 기존 키/암호화 자료의 실제 폐기와 API 종료 시점은 양측 계약 후 결정 |
| 비로그인 계정 검색 | `MyAccountPage(basicOnly:true)`→`MyAccountViewModel.fetchCharacters`→`AccountRepositoryImpl.fetchCharacters/addAccount`→siblings→`LocalAccountDataSource`의 메인/부계정 snapshot→기본 카드 | 제외한 로컬 기능이 일반 guest 경로에 남음. 키만 서버 프록시로 교체해 유지하지 않고 예시 공통 표현으로 대체 |
| 비로그인 저장 복원·갱신 | `MyAccountViewModel.initialize`가 로컬 계정 읽기와 키가 있을 때 summary sync 실행. `BackendApp`의 summary는 `syncGateway:null` | 재진입 카드·불필요한 로아 조회 원인 경로. 새 guest에서는 저장·조회 모두 시작하지 않음. 사용자 제보의 빈 화면 원인은 별도 미확정 |
| 회원 자동/단건 갱신 | `BackendMemberAccount`→`RuntimeStartupRefreshSource.refreshBatch/refreshCharacter`→Armory 직접 수집→`analyzeScopedRoleBuild`→`runtime.saveRoleBuild`→`syncRoleBuildBatch` | 사용자 지적 왕복을 확인. 서버 수집·분석·저장 업무로 이동. Flutter에는 진행/부분결과·기존 조회 캐시 반영을 남김 |
| 분석 요약 업로드 | `scoped_role_build_mapper.dart`→역할·무결성·issue·카탈로그 판정; `ScopedRoleRepository`의 raw/summary/pending→`RoleSummaryClient`·`RoleBatchClient` | PUT `/v2/me/characters/{id}/role-summaries/{role}` 및 배치 업로드는 클라이언트 분석 결과를 전송. 새 source/규칙 버전·서버 검증·원 ACK 처리 계약이 필요 |
| 원정대 목록 갱신 | `StartupRosterRefresh`→POST `/v1/me/game-accounts/{id}/refresh`→서버 자료 재조회 | 이미 서버 경유. 개인 키 선택 의존만 제거할지 기존 업무 변경도 필요한지 Backend 조사로 확정 |
| 회원 등록·인증·전투력 | Backend 등록·소유 인증/분쟁·전투력 클라이언트→기존 업무 API | Google 인증과 원정대 소유 증거는 유지. 서버 provider 키 선택 변경·기존 오류 계약 영향 대조 |
| 구 상세/빌드·장비 preview | `CharacterDetailPage/ViewModel`, `CharacterAutoRefreshCoordinator`, `EquipmentVerificationPreview`, `GameAccountVerificationPage`에도 직접 호출 코드 존재 | lib 참조 검색에서 현재 일반 Router의 생성 연결을 확인하지 못함. 이를 회원 일반 기능으로 보고하지 않으며 공유 분석기·테스트 참조 확인 후 제거 후보 분류 |

### 로그인/비로그인 UI와 중복 조사 결과

| 영역 | 현재 연결 | 합의 목표·주의 |
|---|---|---|
| 내 계정 | `AccountSessionView`: guest=`MyAccountPage`, member=`MemberAccountPage` | 최신 원정대 카드·주간표·개인 시간표 표현 공유. 예시용 전체 화면·가짜 Repository/writer 복제 금지 |
| 모집 | 같은 분기가 guest=`RecruitmentListPage`+`PendingBackendPartyReadRepository`, member=`CycleRecruitmentListPage` 선택 | 준비용 Repository는 실제 HTTP 없이 unavailable 반환. 구형 화면을 숨기는 데 그치지 말고 의존·테스트까지 추적해 제거/통합 |
| 최신 탐색 상태 | `CycleSearchViewModel.load/search` 및 접근 변경 처리에 인증 guard. group/candidate/member context도 함께 참조 | 최신 화면만 guest에 꽂으면 동작 안 함. 공개 검색/주차·카탈로그와 회원 전용 필터·후보·명령을 분리하고 필터 초안/페이지/스크롤 보존 |
| 그룹 | `BackendGroupPage`의 최신 chrome은 존재하나 body는 비회원에 로그인 버튼만 표시. `BackendGroupViewModel.load`도 인증 guard | 기능 구성은 볼 수 있게 하되 내 그룹/요청·멤버 개인정보는 조회하지 않음. 실제 공개 검색/요약 범위는 Backend 확인. 모집의 가상 목록을 그룹에 확대 생성하지 않음 |
| 현황·설정·직접 URL | 현황은 본인 weekly/membership reader 의존; 설정에 개인·기기 키 라우트 잔존 | 최신 틀·로그인 안내와 개인 데이터 guard를 설계. 직접 URL/F5/세션 복원중/만료/로그아웃·뒤로가기에도 private 호출/이전 자료 노출 금지 |

### Backend 고정 소스에서 확인한 범위

원격 dev의 위 고정 SHA를 connector로 읽었다. Backend 담당자의 전체 조사·실행 검증을 대신하지 않는다.

- `app/game_accounts/provider_io/provider.py`: siblings/armory/profile transport는 주입 token 사용, 동시2·timeout/size 제한·리다이렉트 금지·민감정보 없는 오류 경계를 갖는다. 공통 transport 재사용을 우선한다.
- `app/lostark_keys/service.py`: 회원 credential capture/check, 복원 token 반환, fingerprint별 rate budget과 회원/키버전 fencing이 실제 존재한다. 단일 키로 바꿀 때 업무 권한 fencing까지 삭제하면 안 된다.
- `app/game_accounts/power/power_service.py`: 회원 권한·현재 roster 검사 후 개인 key snapshot으로 profile 조회, 버전 기반 cache/lease와 부분 결과 저장을 수행한다. 새 키의 공유 예산과 회원별 결과/권한 범위를 구분해야 한다.
- `app/game_accounts/rosters/observations.py`: token을 받아 siblings/선택 Armory 관찰. owned refresh는 기존 service lookup을 사용한다.
- `app/raid_rooms/api/cycle_router.py`: POST `/v2/raid-rooms/search`와 GET `/v2/raid-rooms`, GET `/v2/raid-rooms/{id}`는 `OptionalPrincipal`이다. 반면 `/detail`·후보·본인 filter context는 `Principal`이다. 공개 검색 API를 새로 만들기로 선결정하지 않으며 discovery-1·필터·기본 카드/상세의 실제 guest 허용 응답/표시 필드를 확인한다.
- Backend 현행 역할 요약 문서는 source=`flutter_analysis`로 명시한다. 서버가 현재 Flutter의 빌드 분석기와 카탈로그를 이미 갖췄다고 가정하지 않는다.

### 공동 조사 당시 확인 목록

아래는 최초 조사에서 상대 측에 확인한 범위다. 현재 계약은 공동 확정·B1/B2 게시 상태이며, 남은 질문/구현 대기로 취급하지 않는다. 정확 wire와 현재 Native 작업은 위 구현 설계 및 NEXT_WORK를 따른다.

1. 전체 provider 호출자 목록과 키 선택/권한/저장/캐시 소유, 개발자 secret 주입·교체/미설정·거절 오류. 키값은 요청하지 않는다.
2. 기존 등록·인증·전투력 업무 재사용, 서버 상세 projection의 최소 반환 모델. 현재 감지 역할 자동 저장과 표시 역할 설정을 분리하고 명시 역할 강제 저장은 추가하지 않는다. source/rules·숫자/시각/무결성을 위 승인 설계대로 명시한다.
3. 현재 새 명령의 멱등/응답유실·미시도/부분결과·재시도/실행 시간과 옛 writer/전용 의존 제거 범위. 옛 raw/summary pending을 계승하거나 새 명령으로 변환하지 않는다. 실제 자료 삭제는 별도 결정이다. 일반 GET은 저장 읽기다.
4. 전체 사용자 공유 quota/cache/중복 요청·429 대기와 회원·소유·UUID/수명 검증 분리. 수집 성공이면 최신 수치/세팅error도 저장하고 실제 수집/역할판정 실패 때만 저장값/관찰시각을 유지한다. 제한으로 저장 GET을 막지 않는다.
5. 기존 공개 모집 discovery의 실제 지원 범위, 공개 상세와 그룹 둘러보기 최소 필드. 민감한 후보·일정 원문·회원별 참가/신청·내 그룹 정보를 guest에 반환하지 않는다.
6. 개인정보 키 API/restore 종료·비밀값 정리·구버전 앱 영향과 로컬 cache 반영 계약. 개발자료 호환 운영·초기화/마이그레이션 리허설을 새 완료 조건으로 만들지 않는다. 운영 전환은 별도 지시다.

### 검증 설계와 완료 판단

- 서버 자동 경계: 위조 대상/타회원/소유변경·수명·키비노출, 동시 명령·공유 한도·중복 합류, timeout/429/부분 실패·응답유실/동일 명령 재시도. 실제 키·한도 소진으로 테스트하지 않는다.
- 분석 이전은 기존 fixture·카탈로그와 감지 역할/경고/정상값의 동등성을 대조한다. 불명확한 역할·보석/스킬 예외를 추정해 정상화하지 않는다.
- Flutter 경계: 예시의 DB/외부 호출/명령0, guest private 요청0, 로그인·로그아웃·늦은 응답 격리, 키 readiness 제거, 최신 filter 초안/캐시·페이징·상세/탭 복귀 보존, 새 현재 명령 ACK/멱등 복구. 구버전 pending 승계는 제외한다.
- 일반 DI의 각 실제 경로로 연결된 뒤 전체 flutter test/analyze 필요 범위를 확정한다. 웹(URL/F5/뒤로가기·브라우저 저장)과 Android(실행/복귀·세션/기기 저장), 좁은 폰/폴드/넓은 웹·큰 글자·키보드는 사용자 수동 확인표로 구분한다.
- 조사 문서·협업 요청 완료는 기능 완료가 아니다. Backend 회신을 대조해 공통 계약/양측 구현 순서를 확정한 뒤 기능 구현 단계로 진행한다.

### 공식 정책 확인의 범위

2026-11-16 확인: [Getting started](https://developer-lostark.game.onstove.com/getting-started/)는 JWT의 신뢰할 수 있는 서버 보관을 권장하고 client당100/min을 안내한다. [Usage guide](https://developer-lostark.game.onstove.com/usage-guide)는 캐싱·rate headers를, [FAQ](https://developer-lostark.game.onstove.com/faq)는 증액 신청을 설명한다. 서버 단일 키 방식 자체를 금지하는 조항은 확인하지 못했으나 특정 서비스에 대한 운영사의 개별 승인으로 확대하지 않는다. [약관](https://developer-lostark.game.onstove.com/agreement)의 수익화 사전 승인·콘텐츠 보관/재제공 문구는 별도 범위이며 이번에 무제한 원본 저장·BM을 승인한 것으로 해석하지 않는다.

## 이전 개인 키 구현 계약 (2026-10-15, 전환 전 실행 근거)

2026-10-15. 사용자 승인: 모바일에서 한 번 등록해 서버와 현재 기기에 저장하고, 모바일에서 가능한 조회는 직접 호출한다. 재설치·다른 기기 로그인은 본인 서버 키를 가져와 보안 저장소에 저장한다. Firebase/테스터 자료이관·기존 기기 키 자동 업로드·공용 키 자동 배정은 없다.

## 소비 계약과 협업 근거

Backend `9e1a255b87b430bca314e8f718fb4176bfe322c8`, feat/member-settings push·dev/main 미병합. [구현/로컬0006·API 인계6172992882](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172992882). 공용 JWT 설정/실행 제거와 독립 암호화 설정은 Backend 보고로 확인했다. Flutter에서 서버 내부/실키를 독립 시험한 것으로 확대하지 않는다.

[고정 OpenAPI](contracts/issue7-9e1a255.openapi.json), 저장 파일 SHA256 `5217dcedeca895c96ed014b8df13b80be291165871a013f2cbaaf3f16030aded`. API/DDL 원본은 Backend 소유다. [초기 요구Issue7](https://github.com/heo0328/lostparty-backend/issues/7),[초기계약수용6172158382](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172158382),[UX/제한/복원요청6172594991](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172594991),[추가계약수용6172746952](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6172746952),[인계확인6173015145](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6173015145). 이전 원문 다운로드 없음/서버·기기 별도 관리 추천은 사용자 최신 방향으로 대체했다.

## API·상태

| 요청 | 입력·성공 |
|---|---|
| GET /v1/me/lostark-api-key | metadata configured/version/updated_at. 미등록 초기false/1/null |
| PUT 같은 경로 | token/expected_version, UUIDv4 Idempotency-Key →200 metadata |
| DELETE 같은 경로 | query expected_version·body없음, UUIDv4 key →200 metadata |
| POST 같은 경로/restore | expected_version 한필드·멱등키없음 → token/version |

앱 Bearer로 본인 회원/세션 확인, no-store. PUT는 strict compact JWT형식/16KiB·공백/접두사 거절과 암호화 저장만 수행하며 서명/실제 provider 유효성 검증이 아니다. 앱은 `API 키를 등록했습니다.`로 안내한다. 기존 서버 키 원문은 입력창에 표시하지 않는다.

metadata·restore는 정확한 필드/엄격 정수/버전 일치를 검사한다. 복원은 실제 Lost Ark 호출이나 키 버전 변경을 하지 않는다. LOSTARK_KEY_NOT_CONFIGURED/REJECTED/CHANGED/UNAVAILABLE는 앱 자체401과 구분한다. 키미등록/거절/변경은 키 관리 진입을 제공하고 앱 로그아웃으로 처리하지 않는다.

## Flutter 실행·저장 흐름

MemberLostArkKey는 현재 회원 키의 단일 상태/기기 토큰 소스다. BackendApp의 기존 설정 /settings/api-token에서 MemberKeyPage를 연결한다. 내 계정 캐릭터 중심 배치는 유지하며 앱 시작에 등록 알럿을 강제하지 않는다.

1. 로그인/자동로그인: metadata→configured면restore→현재 회원/서버별 FlutterSecureStorage에 token/version 저장. 회원/서버/세션 세대가 바뀐 늦은 복원은 무시한다. 시작 진행 복원은 직접 API 키 read가 기다린다.
2. 명시 등록/교체: PUT→현재metadataGET→현재버전restore→기기 저장. 과거 멱등 성공을 현재 키로 오인하지 않는다. 저장 후 화면 유지·입력 정리, 별도 외부 검증/원래 기능 자동 재실행 없음.
3. 명시 삭제: 확인 알럿→DELETE→현재metadata/필요복원으로 기기 상태 동기화. 기존 캐릭터/원정대/역할Snapshot은 삭제하지 않는다.
4. 서버 성공·기기 저장 실패는 서버 성공 안내와 기기 저장 오류를 따로 표시한다. `키 다시 불러오기`는 restore로 복구하며 PUT를 다시 만들지 않는다.
5. 응답 유실은 화면 메모리의 같은 UUIDv4/body/version으로 명시 재시도. REQUEST_IN_PROGRESS 대기 준수, 24시간 기한·충돌/만료 제외. 버전 충돌은 pending을 해제하고 현재 키 확인 후 새 명시 결정. 화면 종료/회원 변경에 미완료 입력을 정리하며 원문 대기 명령을 디스크에 저장하지 않는다.
6. 페이지 진입/앱 foreground 복귀에도 metadata/restore로 현재 상태를 확인한다. 조회 실패는 알 수 없음이며 이전 버전으로 새 키 저장을 진행하지 않는다. 전 기기 실시간 동기화는 보장하지 않는다.
7. 로그아웃/회원·세션 전환은 메모리/대기 요청 정리 및 이전 회원 기기 키 삭제를 직렬화한다. 서버 키는 유지한다. 회원 기기 키를 guest 저장소에 복사하지 않는다. guest의 기존 직접 조회·기기용 등록은 별도 게스트 저장소/진입점으로 유지한다.

일반 직접 조회는 복원된 메모리 키를 사용하며 매 Lost Ark 요청마다 Backend를 경유하지 않는다. 로컬 HTTP 결과는 회원/세션/키버전이 바뀌면 반환하지 않는다. 키를 일반 설정/로그/오류/Issue에 남기지 않는다. 회원별 키 소유권과 로컬 캐릭터 DB의 기존 기기 공용 저장은 다른 책임이며 이번에 DB 복원 범위를 확대하지 않는다.

## 호출 제한·재시도

[공식 가이드](https://developer-lostark.game.onstove.com/usage-guide): client당100/min,429 및 X-RateLimit-Limit/Remaining/Reset. Reset은 UNIX epoch초다. Backend의 자체token80/min 예산과 provider 한도를 구분한다.

- 직접 호출에서429 또는 성공 Remaining0을 관찰하면 유효한 미래300초 이내 Reset을 사용한다. 누락/비정상/과거/ms모양/과도미래는60초 fallback. 현재200 응답은 성공 유지, 추가 호출만 차단한다.
- ApiCooldown은 관찰 deadline을 max로 유지한다. 같은 키는 대기 유지, 다른 키/회원은 분리한다. 로컬 차단만으로 대기를 계속 연장하지 않으며 기한 종료 후 명시 재시도한다. 자동sleep/retry나 전체기기 호출량 동기화 서비스는 없다.
- 단건 오류의 error.retry_after_seconds/retry_at은 optional nullable, 제한일 때 두값. HTTP429 RATE_LIMITED/HTTP503 UPSTREAM_RATE_LIMITED·Retry-After를 처리한다. 앱은 upstream 대기를 직접/서버 외부 호출에 공유한다.
- PowerResult에는 required nullable 두 시간 필드를 추가해 strict DTO를 새 계약으로 갱신했다. 제한 failed/deferred는 두값·그외null쌍. 부분결과에서도 deadline을 안내·보류한다. 과거 멱등 replay의 시각이 지났으면 새 명시 명령으로 진행한다. 이미 저장된 숫자/시각과 GET은 유지한다.
- 내 계정 조회·캐릭터 상세 갱신·서버 등록/전투력 영역에 남은 초와 키 관리 안내를 연결했다. 제한을 키 교체/Google 로그아웃으로 처리하지 않는다. 다른 기기 추가 사용으로 재시도 시 다시 제한될 수 있다.

## 검증·현재 상태

feature/member-lostark-key에서 Flutter 구현·자동 검증과 현재 기능 사용자 정상 보고를 마쳤다. 사용자 지시로 이 완료 단위를 dev에 통합·push하며 적용 SHA는 Git 이력/Issue7 최종 인계에서 추적한다. 기존 문서 변경/사용자 Rules·tools 보존. 전체1246테스트 통과 후 metadata 재조회 실패의 이전버전 조작 방지 국소 보완·관련12개통과,최종lib/test분석0. 표적58개도 통과했고 실패mock의 JSON content-type 누락을 고친 후 최종 전체를 수행했다. 로그는 .dart_tool/member-key-final-tests.log/member-key-metadata-final.log/member-key-final-analyze.log. 이후 문구 정리의 관련46개 통과·최종 분석0/debugAPK15.5초 성공은 DEV_LOG에 기록했다.

회귀보존:Google세션/설정·원정대CRUD/이름/전투력·선호역할Snapshot·guest로컬조회. 신규 mock 경계:형식/버전·응답유실동일명령·로그아웃중복원/저장·기기저장부분실패·제한epoch/fallback/Remaining0·늦은응답/새DTO. 사용자는 키 등록/삭제와 캐릭터 검색 등 현재 구현 구간 정상 동작을 보고했고 [6173934017](https://github.com/heo0328/lostparty-backend/issues/7#issuecomment-6173934017)에회신했다. 내부키저장위치구분은사용자시험으로요구하지않는다. 재설치/다른기기·provider헤더/한도상세는별도미확인이다.

아래는 완료 구간의 수동 안내 이력이며 현재 정상 흐름을 다시 대기시키지 않는다. 당시 안내는 새 빌드에서①로그인→설정의API키직접등록→기기저장표시→내계정직접조회/서버원정대미리보기②로그아웃·재로그인/재실행시재입력없이복원·조회③명시키교체/삭제후저장캐릭터유지·새조회차단·재등록 복구. 한도는mock으로검증하며 실제100회소진을요구하지않는다. 재설치/별도디바이스는가능한경우추가인수이며일반재로그인통과를그인수로확대하지않는다.

전체빌드자동갱신/역할저장API·장비증거보류해제·DB고아정리·Firebase자료이관·운영배포/Issue종료는이번범위가아니다.
