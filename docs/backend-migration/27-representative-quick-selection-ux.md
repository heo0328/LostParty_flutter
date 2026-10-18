# 내 계정 대표 캐릭터 빠른 선택 UI/UX

> 2026-10-17 사용자 시각 조정: 내 계정의 비선택 왕관 윤곽은 기존 대비 불투명도50%로 흐리게 표시한다. 선택된 대표의 파스텔 노랑/윤곽과 처리 중 표시, 터치 영역/툴팁/접근성·확인/변경은 유지한다. 관리 화면 등 다른 왕관에는 이번 조정을 확장하지 않는다.

> 2026-10-16 최신 연결 결과: 기존 관리 UI의 현재 서버 연결·최초 최고 후보 draft/명시 전체설정 저장을 완료했다. 기존 대표 유지, 활동집합 내 초기 후보, 공통1700/finite 검사와 기존 개인설정 저장을 사용한다. 별도 선택/복구 화면 없음. 왕관 확인은 취소좌/변경우. 전체1560PASS·분석0, 실제 소유/기기 미확인. 앱 수명 내 불확실 전체설정 동일 key/body 재확인과 기존 E1의 모든 원 PUT 종결 증명은 구분한다. [인계](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6209931176)·[현재 작업](../project/NEXT_WORK.md).

> 최신 사용자 정정(2026-10-16): 대표가 이미 있으면 유지, 없을 때만1700이상 사용 가능한 대상 중 아이템 레벨 최고를 초기1회 대표로 선정. 변경 성공 전 기존 표시 유지·확정 실패 시 기존 값 그대로. 별도 복구 화면/새 사용자 단계는 신설하지 않고 기존 관리 화면/확인창을 재사용한다. 응답 유실을 원 PUT 실패로 오인하거나 기존 대표 조회 실패를 대표 없음으로 오인하지 않는 내부 서버 일관성은 유지한다. 기존 ‘활동/표시/대표/표시수’ 관리 화면의 현재 서버 연결을 우선하며 별도 평행 화면을 만들지 않는다. 실제 단계는 NEXT_WORK.

> 재검토 정정(2026-10-16): E1의 GET revision 변화 기반 미확정 명령 해제·넓은 명확 실패 분류·세션/재실행 미보존은 복구 보완 대기다. 아래 E1 결과를 원 PUT 완료/commit 불가 보장으로 해석하지 않는다. [코드 대조 회신](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6208744179)·[현재 보완 범위](../project/NEXT_WORK.md).

## Flutter E1 연결 완료 (2026-10-16)

P2 7027f0b 대표 GET/PUT 전용 client·엄격 DTO·고정 멱등 명령과 실제 MemberAccountPage/ViewModel 왕관/확인/쓰기/복구를 연결했다. 메인 원정대 표시 목록에서 현재 대표는 파스텔 노랑 채움, 다른 후보는 윤곽 왕관이며 활동/confirmed/active/usable·회원/환경/세션·4종 revision을 확인한다. 취소좌/변경우, 알럿 중 회원 변경과 중복 알럿/요청 차단, 서버 GET 확인 후 표시/정렬을 반영한다.

응답 유실은 앱 수명 동안 같은 key/body로 재시도하며 Retry-After 남은 시간과 현재 상태 확인을 제공한다. GET으로 settings/소유/등록/roster revision 진전이 확인되면 오래된 명령을 해소한다. 재실행은 새 GET과 서버 CAS로 최신 상태를 확인한다. 왕관 변경은 활동 목록/표시/선호역할/빌드·파티 참가를 쓰지 않는다. 캐시만 있거나 GET/자격 미확인 시 변경 불가다.

활동 전체 편집은 다음 E2다. 기본 기능 flag OFF 유지, 현재 환경·DB/키 유지. 실소유/canonical을 fixture나 이름으로 생성하지 않는다. 서버/실기기 변경 인수는 미확인이며, 자동 결과는 DEV_LOG를 따른다. 아래 선행/미연결 문구는 당시 이력이다.


## 최신 인계 상태 (2026-10-15)

[Backend 완료 회신6184483999](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184483999)을 확인했다. 구현/원본 OpenAPI는 cd3e003eb058ee5de761563d25c418d0e45ac526, feat/representative-selection commit/push·개발 API 적용 완료, dev/main 미통합이다. [게시 구현 안내](https://github.com/heo0328/lostparty-backend/blob/cd3e003eb058ee5de761563d25c418d0e45ac526/docs/ISSUE_8_REPRESENTATIVE_DEVELOPMENT.md)에서도 같은 제공 범위를 확인했다. 대표 GET/PUT·기존 전체설정 PUT의 5분 제한 제거, 과거 전체설정 replay의 next_change_at만 null 투영을 포함한다. Backend 보고 검증은 별도 실행 75 PASS와 보완 후 37 PASS/OpenAPI 일치다. 실제 장비/사용자 인수나 Flutter 연동 검증은 아니다. 아래 미구현/미회신 문구는 당시 설계 이력이며 이 절이 현재 기준이다.

Flutter는 사용자 승인에 따라 [인증 화면·상태 관리28](28-verification-client-preparation.md)을 먼저 연결한다. 인증·활동 선택·회원/환경에 안전한 ID 연결과 대표 계약 소비는 별도 단계이며, 현재 대표 API 제공만으로 소유/활동 자격을 우회하지 않는다. lifecycle/NameClaim/V2/자동삭제·장비증거 보류 해제·Issue 종료는 미완료다.

2026-10-15. 사용자 직접 제안의 확정 UI와 이를 연결할 상태/계약 요구를 정리한다. 설계 단계이며 앱 코드·OpenAPI·DB/기존 자료·배포는 변경하지 않았다. Backend 요청은 Issue8 댓글6183888735, 추가 계약 맥락은6183941103이다. 원정대 생명주기 전체 수용/구현과 분리한다.

## 1. 사용자 확정 UI와 범위

- 내 계정에서 사용자가 보이도록 선택한 캐릭터 목록을 그대로 사용한다. 메인 계정 원정대의 현재 대표는 작은 왕관에 노란 파스텔톤 채움을 적용한다. 다른 표시 캐릭터는 속이 빈 왕관을 제공한다.
- 이번 빠른 선택은 메인 원정대 안의 대표1명 변경이다. 회원 전체의 여러 원정대를 합쳐 대표1명을 고르는 기능이나 부계정 간 대표 이동으로 확대하지 않는다. 기존 부계정별 대표/관리 흐름은 보존하고 빠른 선택 확대는 별도다.
- 빈 왕관 터치 → `대표 캐릭터 변경` 확인 알럿. 본문은 대상 이름을 포함해 `‘{캐릭터명}’ 캐릭터로 대표 캐릭터를 변경하시겠습니까?`로 안내한다. 왼쪽 `취소`, 오른쪽 `변경`. 취소·뒤로가기는 쓰기0, 확인한 뒤에만 요청한다.
- 앱 공통 버튼 배치는 취소/부정은 왼쪽, 동의/긍정은 오른쪽이다. 이번에는 계약에 반영하며 관련 없는 기존 알럿 전체를 함께 수정하지 않는다.
- Backend가 사용자 결정으로 전달한 대표 변경5분 제한 폐지는 이번 빠른 선택 설계에서 대기시간 없는 변경으로 반영한다. 요청 진행 중 중복 방지는 cooldown과 별개다. 전용 API뿐 아니라 기존 전체설정 저장 경로도 같은 정책으로 맞춰야 하며 실제 구현 인계 전 기존 코드가 바뀌었다고 표시하지 않는다.

## 2. 왕관 표현과 카드 상호작용

현재 AccountCharacterCard는 이름 오른쪽에 대표 별표18을 표시한다. 메인 원정대 빠른 선택을 연결할 때 해당 자리에 같은 크기의 채움/윤곽 왕관을 사용하고 별표와 중복 표시하지 않는 안이다. 흰 카드·라벤더 테마·캐릭터 정보·주간 표시·상세 진입은 유지한다. 채움색 제안은 부드러운 노랑 #F5DEA0, 윤곽/세부색은 식별 가능한 황갈색이며 최종 토큰은 구현 시 기존 Theme에 맞춘다. 오류 상태의 노란 경고 아이콘과 구분한다.

시각 아이콘은 작게 유지하되 터치 영역은 투명 여백으로 확보한다. 왕관 터치는 카드 상세 진입/다른 체크 동작을 함께 실행하지 않는다. 대표 상태는 채움/윤곽과 접근성 설명으로 함께 전달한다. 현재 대표 Tooltip/semantics는 `대표 캐릭터`, 빈 왕관은 `{이름}을 대표 캐릭터로 변경`, 서버 미확인/사용불가는 상태 설명을 제공한다. 현재 대표 왕관을 다시 눌러 대표 해제/빈 상태를 만들거나 같은 저장 요청을 보내지 않는다.

현재 visibleCharacters는 표시 선택·개수/순서와 대표 우선 정렬을 반영한다. 새 왕관 때문에 추가 캐릭터를 노출하거나 표시 개수를 변경하지 않는다. 대표 변경 성공 후 기존 대표 우선 정렬이 바뀌는 것은 기존 정렬 규칙이며 서버 확인 전에는 카드를 이동하지 않는다.

## 3. 선택 자격과 준비 상태

표시돼 있다는 사실만으로 서버 대표 자격이 생기지 않는다. 같은 메인 원정대의 현재 본인 소유·사용 선택(활동)·유효한 canonical ID와 최신 서버 settings/ownership/roster 상태가 필요하다. API는 이 상태를 재검증하며 이름이나 로컬 정수PK를 식별자로 전송하지 않는다.

- 로그인/서버 목록·대표 상태 확인/안전한 ID 연결이 끝난 경우에만 빈 왕관을 활성화한다. GET 실패를 대표 없음이나 임의 첫 캐릭터 대표로 확정하지 않는다.
- guest/미인증 preview/로컬 전용·ID미연결은 새 서버 변경 버튼을 비활성화하고 로그인/확인 필요 안내를 제공한다. 기존 기기 자료/대표 표시를 서버 확정 상태로 자동 승격하거나 이름으로 ID를 연결하지 않는다.
- suspect/retired/소유 상실/비활동 대상은 선택 불가다. 현재 대표가 사용불가라면 유효한 표시 후보 중 새 대표를 고를 수 있게 하되 자동 대체하지 않는다. 유효 후보가 없으면 캐릭터 관리/서버 확인으로 안내한다.
- 대표 전용 변경은 활동 캐릭터 추가/제거·표시 순서/개수·선호 역할/빌드·파티 참가 캐릭터를 변경하지 않는다. 파티 자동 교체 동작도 없다.

## 4. 저장·실패·동시 변경

| 상태 | 표시/조작 | 서버·로컬 처리 |
|---|---|---|
| 확인 알럿 | 대상 이름·취소/변경 | 알럿 중 회원/메인 원정대/대상 자격 변경 시 닫거나 변경 불가 처리. stale 대상에 요청하지 않음 |
| 저장 중 | 대상 왕관 자리에 작은 진행 표시, 해당 원정대의 다른 왕관 비활성화 | 변경1건만 진행, 같은 클릭/중복 알럿 차단. 기존 대표 표시는 서버 확인 전 유지 |
| 성공 | 새 대표만 채운 왕관, 기존 대표는 윤곽. 간단한 `대표 캐릭터를 변경했습니다.` 안내 | 응답/현재 GET으로 최신 대표·settings version을 확인하고 공유 상태 및 검증된 로컬 mapping에 반영 |
| 명확한 실패 | 기존 대표 유지·원인과 재시도 안내 | 서버 미변경을 성공으로 표시하지 않음. 자격 상실은 최신 목록 확인 후 후보 비활성화 |
| 응답 유실/처리 불명확 | `변경 결과 확인이 필요합니다.`와 상태 확인/동일 요청 재시도 | 새 대상을 덮어쓰는 명령 금지. 같은 key/body/revision으로 복구, Retry-After 준수. 서버 성공·기기 반영 실패는 서버 상태 재조회/기기 반영만 재시도 |
| 다른 기기/전체 설정과 충돌 | 서버 최신 대표를 확인하고 변경 내용을 안내 | expected settings/ownership/roster version을 재검증. 충돌GET 후 자동 덮어쓰기 없이 다시 명시 선택 |
| 로그아웃/회원 변경/늦은 응답 | 이전 회원의 알럿·대기UI 정리 | 이전 scope 응답이 현재 화면/로컬 대표를 덮지 않게 회원/환경/세션·요청 세대 검사. 이전 서버 완료 가능성은 다음 GET으로 확인 |

성공 안내는 요청 시 선택값을 낙관적으로 칠한 것이 아니라 서버가 확인한 상태에 근거한다. 예전 멱등 성공 뒤 다른 기기에서 다시 변경됐으면 현재 GET의 대표를 표시한다. 동일 원정대의 전체 설정 저장과 빠른 선택은 공통 settings_version으로 경합을 처리하며 서로의 활동 목록을 이전 값으로 되돌리지 않는다.

캐릭터 관리 화면에 미저장 draft가 있을 때 빠른 대표 변경의 최신 version을 공유한다. draft의 활동/순서 변경을 임의로 버리거나 자동 저장하지 않는다. 새 대표를 draft가 활동에서 제외했거나 구version 전체저장으로 덮을 상황은 충돌/재확인으로 처리한다. 정확한 UI 연결은 새 API와 기존 관리 draft 구조를 대조해 구현 단위에서 확정한다.

## 5. Backend에 필요한 대표 전용 API 계약

이번에는 endpoint·method·DTO를 Flutter가 임의 확정하지 않는다. 필요한 논리 계약은 본인 등록/원정대와 새 canonical character ID, expected settings/ownership/roster revision, UUIDv4 멱등key 및 최신 대표/설정 version 확인 수단이다. 대표만 변경하고 활동 목록·다른 설정은 쓰지 않는다. no-op/동일 대표·응답유실/replay·충돌·사용불가·비인증·재시도 기한/Retry-After를 기존 규칙으로 최소화한다.

성공은 새 대표와 settings_version을 반환하거나 기존 GET으로 현재 상태를 확인할 수 있어야 한다. 활동 목록 동시 편집과 같은 version을 쓰며 변경 전에 대표 포함/자격을 다시 검사한다. 기존 V1 character-settings PUT도 cooldown을 제거하고 next_change_at의 required nullable null 호환 방향을 대조한다. 새 mandatory field/enum은 원본 OpenAPI와 정확한 SHA로 인계한다. lifecycle 전체성/퇴역 기능과 독립 제공 가능성은6183941103 제안을 검토한다.

## 6. 현재 구현과 구현 전 완료 조건

현재 BackendApp은 공유 MemberSettings/서버 계정 read·write VM을 연결하지만 대표 전용 API/빠른 선택 공유 VM은 없다. MyAccountPage의 카드 representativeId는 로컬 계정이며, 기존 RepresentativeCharacterSyncService는 BackendApp에 주입되지 않는다. 이 경로를 재활성화하거나 Firebase용 gateway를 재연결하지 않는다. 전용 계약을 받은 뒤 Router/DI·공유 대표 상태와 서버ID/로컬ID mapping을 설계한다.

보존할 흐름: 카드 상세/주간 조작·표시 개수/정렬, 본/부계정 구분, 로컬/guest 자료, 활동·대표 최소 조건, 기존 설정 저장과 선호역할 Snapshot, 서버 등록/키/수동 전투력.

최소 자동 검증 후보: 자격/ID·원정대/회원 범위, 동일 요청·응답유실/replay, expected revision 충돌과 활동목록 불변, 회원전환/늦은응답·기기 반영 실패. 정상 왕관/알럿/저장 결과·취소 좌/변경 우·카드 별도 터치는 기능 연결/자동검증 후 사용자 실기기 확인으로 묶는다. 이번은 설계만이므로 테스트를 새로 만들거나 반복 실행하지 않는다.

이 UX는 [Issue8 Flutter 회신6183971014](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6183971014)에 인계했고 [Backend API 제안6184022477](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184022477)을 받았다. 아래는 제안 대조 결과이며 기능 구현·서버/DDL/기기 조작·commit/push는 아직 수행하지 않는다.

### 대표 API 제안 대조 (2026-10-15)

- 신규 GET/PUT /v1/me/game-accounts/{registration_id}/representative. 외부 Lost Ark 호출/키 복호화0, 키 미등록과 무관하게 저장자료의 본인 소유/활동/자격을 검증한다. PUT은 현재 메인 등록만, GET은 본인 소유 비메인도 조회해 범위 전환을 확인할 수 있다.
- PUT body는 character_id와 expected_registration_version/expected_settings_version/expected_ownership_revision/expected_roster_revision의 필수5필드, UUIDv4 멱등key다. 입력의 엄격정수/추가필드 금지와 등록ID·원정대ID 구분을 새 DTO에 반영해야 한다.
- 성공 GET/PUT 공통10필드는 registration_id/game_account_id/is_main과 네 revision, representative_character_id(nullable), configuration_state, next_change_at(항상필수null)이다. 대표만 바뀌면 settings_version만 증가, 활동/타설정·needs_reconfiguration은 유지한다. 기존 전체설정 PUT에서도 cooldown 제거/next_change_at=null 제안이다.
- MAIN_REGISTRATION_CHANGED/REVISION_CONFLICT/SETTINGS_NOT_CONFIGURED/CHARACTER_NOT_ACTIVE/CHARACTER_UNUSABLE 등과 현재 상태 복구가 명시돼 있다. 신규 API이므로 기존 모델에 임의필드를 허용하지 않고 원본 OpenAPI/정확한 SHA 인계 후 strict DTO를 추가한다.
- 200/replay는 과거 commit 결과일 수 있어 현재 representative GET/필요한 등록·캐릭터GET으로 확인한다. GET이 예전 값을 보여도 원래 명령 완료/미완료를 단정하지 않고 같은key/body 복구 전 다른 명령을 보내지 않는다. 등록/전체활동과 새 대표GET의 version이 다르면 일관된 현재 snapshot을 다시 준비해야 한다.
- 대표 전용 계약은 UX와 방향이 일치한다. 다만 현재 live 장비 proof 보류/활동 설정 미연결·서버ID mapping 없는 기기 행에서는 변경을 열 수 없다. 전용 API 제공이 소유/활동 준비나 원정대 생명주기 전체 제공을 뜻하지 않는다. 기존 대표가 사용불가일 때 유효한 다른 활동 후보로 교체 가능하고 초기/빈 활동은 기존 설정 경로가 선행한다.
- Backend는 아직 docs/character-lifecycle 미커밋·미push 제안이며 구현/OpenAPI/DB·자동검증/새SHA 없음이라고 회신했다. 이번 사용자 지시는 답변 확인이므로 이 문서 검토를 구현 착수 요청으로 전달하지 않는다. 다음은 API 계약 대조 결과 회신과 독립 Backend 구현 단위 확정이며 lifecycle 전체 수용/배포·자료삭제와 분리한다.

### 계약 수용·독립 구현 요청 (2026-10-15)

사용자가 고착 해소를 위한 단계 진행을 승인했다. [Flutter 수용/착수 요청6184322765](https://github.com/heo0328/lostparty-backend/issues/8#issuecomment-6184322765)을 게시하고 본문 일치를 재조회했다. 앞선 답변 확인 단계의 미수용/미요청 상태는 이 회신으로 대체한다. 수용 범위는6184022477의 대표 GET/PUT·필수5입력/10응답·네revision/메인한정/활동보존·멱등/현재GET복구와 기존 character-settings PUT 포함5분 제한 제거다.

Backend는 Flutter 왕관 코드나 원정대 인증/활동 연결 완료를 기다리지 않고 이 독립 단위의 구현·PostgreSQL 표적검증/OpenAPI 게시를 진행하도록 요청했다. 실제 착수/완료 회신은 아직 미수신이며 구현됐다고 표시하지 않는다. 인계 완료 조건은 구현SHA/원본OpenAPI SHA·브랜치/commit/push/dev반영·검증/미확인live 범위다. 생명주기 전체/NameClaim·자동삭제/V2/증거보류해제·운영배포/migration적용/실자료삭제·Issue종료는 수용 범위가 아니다.

### Flutter 선행 연결 조사·작업 순서

| 구간 | 현재 사실 | Flutter 다음 행동/완료 기준 |
|---|---|---|
| 서버 등록/전체 캐릭터 읽기 | ServerAccountReadRepository/VM에 전체페이지·세revision/회원세대검증과 canonical ID/설정 읽기 존재 | 준비된 서버 읽기 결과를 사용하고 preview를 소유/활동 자격으로 승격하지 않음. 새 대표 DTO는 게시된 원본계약 후 추가 |
| 원정대 소유 인증 | BackendApp의 /account/verify는 pending, 서버 장비proof/누락증거도 보류 | ACCOUNT-01/02 기존 계약으로 인증 시작/조회/confirm/cancel의 독립 연결 범위를 설계. 실제 증거보류를 Flutter UI로 우회하지 않음. 이 설계는 대표API완료를 기다릴 이유가 없음 |
| 서버/로컬 ID 연결 | AccountRepositoryImpl은 AccountIdentityMappingRepository와 DB.bindServerIdentity를 제공하지만 현재 BackendApp에 검증된 연결을 만드는 실행흐름이 없음. 로컬계정은회원/origin별자료가아님 | 인증된 원정대/세션·서버조회 revision에 근거한 명시 연결을 설계. 서버 원정대/캐릭터 UUID와 로컬PK 구분, 이름만으로자동연결/재매핑·과거빌드삭제금지. 회원/origin소유검증과재진입보호를연결단위에서명시 |
| 서버 활동/전체설정 | CharacterManagementPage/VM은 optional ActivityCharactersRepository/대표gateway가 있지만 BackendApp은 이들을 주입하지 않음. 현재 save는로컬 visibility/순서/대표 저장 | ACCOUNT-03 기존 원정대별 character-settings PUT/GET에 맞는 adapter와 공유settings_version을설계. 옛playerId전역계약/Firebase gateway를그대로재연결하지않음. 전체활동선택/대표일관성과draft충돌보호 |
| 왕관/대표 전용 명령 | 현재카드는로컬대표별표, 전용Backend명령과공유VM없음 | Backend게시계약을고정한뒤GET/PUT/오류·pending복구공유VM→안전한mapping/활동준비표시→왕관/알럿·관리draft연결순으로구현. 자격미준비는비활성/안내이며가짜성공금지 |

작업 순서는 (A) Backend 대표 API 독립 구현과 별개로 Flutter 인증/ID/활동 연결의 설계 구간을 먼저 확정, (B) 서버 인증·ID/활동 준비가 실사용 가능한 근거로 갖춰지면 그 연결 단위 구현/검증, (C) 게시된 대표API 연결·왕관 기능 완료/사용자 인수다. B가 실provider 증거로 막히더라도 Backend API 계약/구현·격리검증과 Flutter DTO/상태설계는 진행 가능하며, 실제 왕관 사용 인수 완료와 구분한다. 현재 승인된 것은 계약수용/Backend착수요청과Flutter선행조사이며 미확정 인증 UX/DB구조를 임의 구현하지 않는다.
