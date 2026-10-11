# 원정대 Rules 게시 실패 분석 — 2026-10-03

## 2026-10-08 11:16 KST — 기존 성공본 복원 성공

사용자 `1회 진행` 승인 후 사전 전체거절ecf30f94와 성공ruleset36b5920e를 확인했다.
기존ruleset26621a37-ae16-45c4-9858-f10380439e28으로 release PATCH1회200.
사후GET200/source SHA36b5920e 일치,134301bytes,updateTime2026-10-08T02:16:46.593197Z.
test/create/fallback/자동재시도/자료쓰기0. 승인1/1소진. BUG-024 후보 활성화 성공과 구분한다.
근거: ignored coverage/bug024/restore-approved-once-result.json.

## 2026-10-08 첫 구간 실조회 — 의도하지 않은 전체 차단 확인

10:24 KST 운영GET에서 기존 성공본이 아니라 전체read/write false인163bytes/ecf30f94를 확인했다.
release 갱신은10월7일22:42 KST, ruleset62ddc2ca-e98e-460f-85eb-70f1a7a8533d다.
로컬 firestore2.rules와 일치하며 추적 firestore.rules(408f163f)는 바뀌지 않았다.
사용자는 의도한 상태가 아니라고 확인했다. 변경 주체는 알 수 없다. 이번 작업의 원격 쓰기0회다.
현재 앱 접근 거절과 이전 큰 기능본의PATCH400/후속409 문제를 분리한다.
기존 성공ruleset26621a37-ae16-45c4-9858-f10380439e28은10:27 GET200/36b5920e/134301bytes로 확인.
새 실행 지시 후 기존ruleset 복원PATCH최대1회·사후SHA확인으로 복구를 먼저 판단한다.
새test/create·자동retry·CLI fallback·자료쓰기0. BUG-024 해결 게시와 다르다.
[전체 근거와 복구 명세](../architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md#16-첫-구간--기준-확정-조사-2026-10-08).

## 2026-10-08 재검토

새 게시 시도 없이 [축소 설계](../architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md) §9~15에
전체 기능 영향,단계별 게시 실패 대응,구버전/이행/복구와 미확인 사항을 보완했다.
409 후속오류·400/503 내부원인미확정이라는 기존 진단은 유지한다. 전환용Rules조차 게시 실패하면
이행에 착수하지 않으며,이행 후 최종활성화가 실패하면 옛Rules만 되돌려 쓰기를 열지 않는다.
이번 사용자 지시는 문서 커밋/작업브랜치push까지이며 Firebase 요청·구현 승인은 아니다.

## 2026-10-07 후속 — 구조 축소 설계로 전환

사용자 최신 지시로 [Rules 대폭 축소 설계](../architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md)를 작성했다.
Spark 무료 유지·앱 업데이트/데이터 이행 허용 조건이다. listing의 저장 형식 통일, legacy 원장 이행과
구버전 쓰기 종료, 원본/파생 명령 검증 책임 통합을 순차 검토한다. 구현·이행·추가 게시 없음.
아래 실험 결과는 유효한 과거 근거이며, 보류/다음 변환 지시는 최신 NEXT_WORK로 대체한다.

## 2026-10-07 현재 — BUG-024 게시 차단 해결 설계

상태: 기획·설계, 로컬 비교, 격리2회 대조 및 별도 제한 스코프 후보 구현 완료.
후보 정적 검증7/7 및 로컬5개 권한 회귀 묶음 통과. 후속승인격리후보1회는활성화400으로실패했다.
추적 Rules/실제 생성 pipeline 불변·후보 추가 게시1/1회·운영 lost-party 변경 없음.
후보는17개 함수의 선언 위치만 이동하며 본문/allow 조건/기존 함수 범위를 보존한다.
SHA256 e892c33e21181a7c0d5e1f0a31a2ca418b8c6a32bed26eab35ddf2cb6c80c37d,
151429bytes·함수296개·allow118개. 실행 코드 감소와 게시 성공은 미확인이다.
도구: tools/rules_bug024_scope_candidate.mjs. 현재는 사용자 지시에 따라 결과 기록 후 보류한다.
다음 변환은 제안만 남기며 추가 구현·테스트·게시와 커밋·푸시를 진행하지 않는다.

### 제한 스코프 후보의 격리 게시 결과 — 2026-10-07 22:22~22:23 KST

사용자 `진행` 승인으로rules-test-1-81e31/(default)/cloud.firestore에e892c33e를정확히1회시도했다.

| 단계 | 결과 |
|---|---|
| 사전 활성 GET/source | 200, 기준36b5920e |
| test | 200, issues없음/경고0 |
| ruleset create | 200, 응답소스e892c33e일치 |
| release PATCH | 400 INVALID_ARGUMENT, Request contains an invalid argument. |
| 사후 활성 GET/source | 200, 기준36b5920e 및updateTime유지 |

생성Ruleset a8100528-fe72-4375-b2f4-83c7a94c9e70. 원시근거는
coverage/bug024/publish-scope/isolated-candidate-result.json과isolated-candidate-publish.log다.
fetch각1회·자동재시도0·create fallback0·운영쓰기0. 실패후추가변경/원복요청없음.
실패후활성SHA조회는진단읽기이며추가게시가아니다. executable는미활성이므로조회하지않았다.
판정: helper17개선언스코프만좁히는변환으로는해결되지않았다. 소스크기2bytes증가를
compiled개선이라고해석하지않으며 용량초과/특정함수원인확정근거도없다. 후보승격보류.
다음 로컬 검토는기존408f163f를기준으로함수별local식별자재사용변환을분리하는것이다.
동일scope후보의재게시와권한조건삭제/완화는제외한다. 추가원격승인예산0회.

### 앞선 로컬 진단 이력
후속 로컬 대조에서 Emulator 없는 Node 서버도HTTP/1 정상·HTTP/2 실패를 재현했다.
따라서 후보 Rules 평가 이전의 통신 장애를 먼저 분리한다. 차단 주체/런타임 버전 의존성은 미확인,
사용자 일반 PowerShell 대조 결과가 필요하다. 이 로컬 장애를 운영 게시400과 동일 원인으로 단정하지 않는다.
후속 사용자PowerShell에서도HTTP/1 정상·HTTP/2 Protocol error 재현. 읽기전용조사에서AdGuard8.0.2
서비스/프로세스실행을확인해localhost필터대조를제안했다. 해당옵션현재값/원인확정은미확인,
에이전트가보호나설정을변경하지않았다. [공식 옵션 설명](https://adguard.com/kb/adguard-for-windows/settings/app-settings/advanced-settings/#filter-localhost).
권한 검증 전에는 후보를 실제 pipeline에 승격하거나 추가 원격 게시하지 않는다.
사용자 후속 출력에서 HTTP/1 임의포트/8080·HTTP/2 임의포트/8080 모두ok이다.
최소/후보 Rules 로드200 확인 후 첫 runtime 묶음은 fixture 생성의 잠금 timeout으로 중단했다.
최초 Java 로그에는 한국어 JValidationMessages 리소스 누락 예외가 먼저 있었다. 직접 실행 도구에
CLI 기본 영어 JVM 옵션이 빠졌음을 확인했다. 같은1.22.0에 영어 옵션을 넣자 기존/후보의
생성·신청·승인·8인 준비가 모두 통과했다. 잠금 오류를 후보 권한 결함으로 판정하지 않는다.
별도1.21.0도 대조했으나 한국어 리소스 예외로 실패했다. 공식 SHA 검증한 JAR를ignored 폴더에만
두었고 전역 CLI/Java/Emulator 설치는 변경하지 않았다. 원격 활성화400과 이 로컬 장애는 구분한다.
최종1.22.0/영어 옵션 실행: runtime30·완료역할27·8인캐릭터배치·수동22·개인15 모두통과,
5개 suite exit0. coverage 내보내기만100MiB 응답 전송 한도429로 미확보다. 이는 권한 검사
접근/평가 한도와 다른 엔드포인트의 진단 결과이며 회귀 assertion은 한도 거절을 인정하지 않는다.
근거: coverage/bug024/publish-scope/{suites.json,validated-run-en.log,validated-emulator-en.log,runtime/}.
격리 후보1회 명세를isolated-publish-plan.json에 고정했다. 대상rules-test-1-81e31의cloud.firestore,
SHAe892c33e/151429bytes. 자동재시도0·운영쓰기0. 추가 승인 전 원격 요청을 수행하지 않는다.
10월5일 게시 차단 해소는 당시 성공본에 대한 결론이다. 현재 BUG-024 후보는 활성화가 실패한다.
기존 목적 브랜치 `fix/recurring-next-week-character-change`를 재사용한다. 이번 설계는 해당 기능의
운영 도입 차단 해소에 종속되며, 별도 기능·데이터 구조 개편을 포함하지 않는다.

### 목표와 완료 정의

기존 권한·원자성·최대8인·과거 데이터 호환을 보존하면서 BUG-024 전체 Rules를 게시할 수 있게 한다.
검사200·Ruleset 저장200·콘솔 최신 시간만으로 성공을 판단하지 않는다. 운영 release가 후보를
참조하고, 그 Ruleset의 source SHA256이 승인한 로컬 후보와 일치해야 게시 완료다.
BUG-024 전체 종료는 그 뒤 두 실제 방의 사용자 실기기 인수까지 별도 확인한다.

### 확정 근거와 미확정 사항

| 항목 | 확인한 사실 | 해석 범위 |
|---|---|---|
| 마지막 성공본 | SHA36b5920e, source134301bytes, 함수272개 | 운영 활성본, BUG-024 추가 기능 없음 |
| 현재 후보 | SHA408f163f, source151427bytes, 함수296개 | 로컬·업로드 응답 바이트 일치 |
| 10월7일18:48 CLI1회 | test200/경고0, create200, PATCH400, fallback POST409 | 최초 실패는 활성화400 |
| 사후 활성API | 기존26621a37…/36b5920e, updateTime10월6일 유지 | 이번 후보 미적용 |
| 기존 V1 executable | base64 해제242981bytes | 참고 측정값이며 실패 후보 크기·정확한 한도 여유를 뜻하지 않음 |
| 콘솔503 | 사용자 보고 | CLI400과 같은 내부 원인인지는 미확정 |

원시 근거는 `coverage/rules-debug-20261007/result.json`과 같은 디렉터리의 로그다.
Firebase CLI15.32.1의 `lib/gcp/rules.js`는 update 실패를 모두catch해create를 시도한다.
이 동작이 마지막409를 설명하지만 최초400을 고치지는 않는다.
들여쓰기 제거는 문법상 허용되며 현재 원격 검사도 통과했다. 같은 내용 재게시나 공백 복원은
원인 분리 실험으로 채택하지 않는다. 실패 후보의 compiled 크기는 현재 확보하지 못했다.

### 조사 가설과 판정 방법

| 가설 | 현재 근거 | 다음에 필요한 구분 근거 |
|---|---|---|
| 요청 형식·대상 문제 | CLI의 PATCH 본문은release.name/rulesetName이며 공식 계약과 부합 | 성공 당시 payload와 동일 항목 비교, 격리 프로젝트에서 동일 요청 방식으로 성공본 대조 |
| 실행 코드 규모·구조 부담 | 성공본보다 후보가 커졌고 과거 식별자 축약으로 활성화 성공한 이력 | 같은 환경의 성공본/실패본 대조, 단일 변환 후보의 활성화 및 가능한 executable 측정 |
| 후보 특정 구문·변환 문제 | 원격test 통과로 문법 오류 근거는 약함 | 가독본·역치환 토큰·함수 호출/스코프/조건 diff와 진단용 최소 차이 대조 |
| 프로젝트·서비스 상태 문제 | test/create 성공, release만 실패 | 격리 프로젝트의 기준 성공 여부, 기존 release 조회와 공식 장애/지원 근거 |

공식 PATCH 계약은 rulesetName 갱신을 지원하고 updateMask 필드를 제공한다. 현 CLI는mask를
생략하지만 그 사실만으로 오류라고 판단하지 않는다. 임의 인수 변경을 반복하지 않고, 성공 요청과
문서 비교에서 차이가 확인될 때만 요청 보정 후보로 삼는다.
출처: [PATCH 계약](https://firebase.google.com/docs/reference/rules/rest/v1/projects.releases/patch).

공식 한도는 source256KB와 backend compiled250KB를 구분한다. source 감소율을compiled 감소율로
환산하지 않는다. getExecutable은release가 참조하는Ruleset의 실행물을 반환하므로 활성화되지 않은
후보 크기를 운영release에서 읽었다고 해석하지 않는다. V1 반환 바이트가 한도 계산의 정확한 값과
동일하다고도 단정하지 않는다.
출처: [Rules 한도](https://firebase.google.com/docs/firestore/quotas),
[getExecutable](https://firebase.google.com/docs/reference/rules/rest/v1/projects.releases/getExecutable).

### 1단계 — 원격 쓰기 없는 기준 정리

다음 실행 작업의 첫 단위다. 기존 로그·Git·생성 도구와 저장된 활성본을 먼저 재사용한다.

1. 성공36b5920e와 실패408f163f의 해시·전체 소스·요청/응답·검증 manifest를 고정한다.
   활성본/후보/가독본/이름표를 구분하고 콘솔에서 복사한 자료를배포 원본으로 쓰지 않는다.
2. `tools/integrate_roster_rules.mjs --check --review`로 추적본과 생성 일치를 확인한다.
   가독본의 함수/호출/스코프·allow/get/list/write·조건과 데이터 경로를 비교해 BUG-024 추가분을 지도화한다.
   함수명 번호가 밀린 compact diff만으로 의미 변경량을 판단하지 않는다.
3. 기존 공개 Router/DI·writer와 새 guard/stub 경로에 연결된 validator를 대조한다.
   seal 인증, 준비 변경, advance, 정상참가/개인완료의 읽기·쓰기를 각각 기록한다.
4. 현재 pipeline은 scopeFunctions 다음에 completionRoleCompatibility/nextWeekPreparation/
   availabilityRuntime을 적용하고 마지막에compact한다. 따라서 추가 helper의 최종 스코프/호출자를
   조사할 가치가 있다. 현재 순서가 결함이라는 뜻은 아니며 단순 재배치부터 수행하지 않는다.
5. 결과는 원인 후보 순위·관련 함수·변경하지 않을 보호 검사·격리 실험 manifest다.
   실제 후보 생성/코드 수정은 후속 구현 승인 후 수행한다.

### 2단계 — 격리 프로젝트에서 요청과 내용 분리

#### 실행 결과 — 2026-10-07 19:05~19:06 KST

사용자가 `rules-test-1-81e31` 조회와 성공본1회→성공 시 실패본1회, 최대2회 게시를 명시 승인했다.
사전 GET으로 프로젝트 ACTIVE·(default) Native/asia-northeast3·기존23702cbc 활성본을 확인했다.
이전 자동 승인 검토의 대상 승인 부족 조건은 이번 새 사용자 지시로 해소했다.

| 전체본 | test | create/응답source | PATCH | 사후 활성 |
|---|---|---|---|---|
| 성공36b5920e/134301bytes | 200·경고0 | 200·해시 일치 | 200 | 36b5920e 일치 |
| 실패408f163f/151427bytes | 200·경고0 | 200·해시 일치 | 400 INVALID_ARGUMENT | 직전36b5920e 유지 |

성공Ruleset:36f81396-b9eb-4efb-9210-b5fdcfce7dff, 실패Ruleset:16ba19b6-418f-4da6-af91-645a9580dd48.
성공본V1 executable GET200/242981bytes, Ruleset ID도 일치했다. 실패 후보 실행 크기는 미확인이다.
두 요청은 동일release·동일payload 형식으로 수행했다. fetch1회씩·자동재시도0회·create fallback0회.
최대2회 예산 소진. test/create/PATCH 결과와 활성화 성공 여부를 각각 기록했다.
근거: `coverage/rules-debug-20261007/isolated-result.json`, `test-project-preflight.json`.

판정: 운영프로젝트/CLI만의 문제는 아니며 현재 후보 내용에 따라 활성화400이 격리 환경에서도
재현된다. 요청 형식 가설보다 후보 실행 코드 규모/구조 가설을 우선한다. compiled 용량 초과나
특정17함수의 배치가 확정 원인이라는 뜻은 아니다. 후보를 보정하기 전 같은408f163f 재게시 금지.
다음 권고는 3단계의 단일 기능 helper17개 제한 스코프 보정 후보이며 기능 동등 로컬 검증이 먼저다.
추가 테스트 게시와 운영 게시 승인 횟수는0회다. 테스트프로젝트는 기준36b5920e 활성 상태로 남겼고
추가 원복/삭제를 실행하지 않았다. 아래 실험 설계·최초 미승인 문구는 실행 전 계획 이력이다.

1단계 실행 결과: 성공/실패 재생성본이 각각 보존 활성본/추적 파일과 바이트 일치했다.
추가25개·제거1개·기존 함수 본문 변경3개·allow 변경7개이며 기존 함수 스코프 변경은 없다.
추가21개가 공통 상위에 있고 그중17개는 transitive allow 이용 범위가 하나여서 제한된 스코프
보정 후보로 좁혔다. 기존 scopeFunctions는 전함수 root 입력을 요구하므로 최종본에 그대로
재호출하는 구현은 사용할 수 없다. 동등성·컴파일 효과는 아직 미검증이다.
과거 운영 성공 도구도 같은 CLI updateRelease를 호출해 성공했으므로 mask 생략만을 원인으로
삼을 근거는 약하다. 실제 Router/DI와 guard writer/validator 연결을 확인했다.
근거: ignored `coverage/rules-debug-20261007/phase1-report.md`, `comparison.json`,
`baseline-readable.rules`, `candidate-readable.rules`, `experiment-manifest.json`.
테스트 프로젝트 사전 조회는 구체적인 대상 사용자 승인 부재로 자동 승인 검토에서 실행 전 차단됐다.
조회·게시0회이며 우회·재시도하지 않았다. 아래 대상/횟수 승인 후 대조한다.

권고 실험 장소는 과거 사용한 `rules-test-1-81e31`이다. 현재 존재·Firestore 대상·운영 앱 미연결·
데이터 용도를 먼저 확인하고, 이 프로젝트에 대한 새 명시 승인 없이는 쓰지 않는다.
새 프로젝트·결제·API 활성화·운영 임시release 생성은 기본 절차에 포함하지 않는다.

최초 요청 예산 제안은 기준본1회+실패본1회, 최대2회다. 이는 아직 승인된 예산이 아니다.
각각 동일한 서비스release/동일한 요청 도구/동일한 실험 세션으로 비교하고, 후보의명세·SHA를 고정한다.
운영 규칙을 기준본으로 되돌리는 실험은 하지 않는다.

- 기준본: 승인된 성공36b5920e 전체 소스를 테스트 프로젝트에만 제출한다.
- 기준 성공 시: 실패408f163f 전체본을 같은 절차로1회 제출한다.
- 기준도 실패하면: 후보 규칙의 크기 보정을 시작하지 않고 요청 형식·환경·서비스 상태 분기로 전환한다.
  실패본의 다음 실험은 생략하고 지원 문의용 자료를 정리한다.
- 기준 성공/후보 실패면: 후보 내용·컴파일 구조 관련 가설이 강화된다. compiled 용량 초과의 확정 증거는 아니다.
- 둘 다 성공하면: 운영 대상/환경/시점 차이를 조사한다. 이것만으로 운영 재게시를 자동 실행하지 않는다.

진단 요청 도구의 후속 구현 계약: test→경고0 확인→create→응답source해시 확인→PATCH1회→사후GET.
실패하면 즉시 중단하고 최초status/body를 보존한다. SDK/HTTP 자동재시도와CLI create fallback을
진단 요청 도구에서는 끄며, 기존release를삭제하거나 이름을바꿔 우회하지 않는다.
release 사전·사후 정보, 후보SHA, UTC/KST, endpoint/status/body를manifest에 남긴다.
같은source의dry-run+실배포 중복은 하지 않는다. 토큰·쿠키를제거한 요약만 문서/외부자료에 쓴다.

### 3단계 — 근거에 따라 기능 동등 후보 한 개 선정

후속 구현 승인 시 아래 우선순위로 최소 한 후보만 만들고 이전 후보와 동시에여러 조건을바꾸지 않는다.

1. 추가 helper의 호출 범위를 확인해 필요한match에만 두는 후보. 이름 해석·캡처변수·호출 가능범위가
   동일해야 하며 공유 helper의복제 증가나호출깊이 증가를점검한다. scope 이동만으로동등성을선언하지 않는다.
2. 함수 인자/let의식별자를함수별로안전하게재사용하거나더짧게하는 생성 변환 후보.
   현재는전역count로 z0… 식별자를만든다. lexical scope/내장명/필드/경로 충돌을막고역치환 토큰일치를
   강제할수있을때만채택한다. 이미적용한축약의단순반복이아니며 compiled 감소효과는실측전미확정이다.
3. 위두변환으로불충분하면BUG-024 추가validator의동일조건/중복구조를한곳에정리하는후보.
   단락평가와missing/null/권한거절/문서접근순서가바뀔수있으므로논리식모양만같다고동등판정하지않는다.

진단용 차이축소/특정기능제외본이필요하면테스트프로젝트의격리자료로만취급한다.
기능이빠진실험본은해결본이나운영게시후보로승격하지않는다. 배포파일을여러개로쪼개순차게시해도
동일서비스의전체규칙이누적병합된다고가정하지않는다. Functions·Blaze전환·권한완화·앱저장구조개편은제외다.

각후보는로컬검증을마친뒤성공기준을설명하고테스트프로젝트추가1회예산을새로승인받는다.
실패하면같은접근미세수정·무제한이분탐색을중단하고결과를판단한다.
구분근거가더이상없으면Firebase지원용최소자료를작성하고사용자검토후전달한다. 자동전송하지않는다.

### 회귀 보호와 후보 채택 조건

- 변환: 생성일치·역치환토큰동등성(이름변환), 경로/필드/문자열/allow계약보존.
- 핵심정책: authBindings→Player소유권차수, 과거/missing자료, 위조인증·일부guard삭제·legacy Claim우회 거절.
- 새동작: 완료상태A→B→C 준비변경, absent/strict stub재선택,8인인증후최종원자advance.
- 기존동작: 생성·신청·승인·즉시참가·진행중캐릭터변경/빈자리이동, 전체완료/role, 개인완료/해제,
  그룹목록·이벤트·완료이력보존, 이전소유자자료,승계/마지막1인해산,중복·경합·중도실패거절.
- 검증: 변경지점별기존Rules 묶음을선정해최종후보에한번실행한다. 최대8인대표와서로다른상태전이만
  최소사례로둔다.1000식/service call/접근한도오류를정상거절로세지않는다.
  Emulator통과를원격활성화성공의대체로삼지않는다. 변경없는Flutter전체검증은반복하지않는다.
- 테스트프로젝트활성화200/후보해시일치/경고0이후가능한executable크기를동일version으로비교한다.
  크기가확보되지않으면미확인으로남긴다. 고정된임의여유수치를새완료조건으로추가하지않는다.

### 4단계 — 검증된 전체본 운영1회와 사후확인

후속명시승인시로컬최종검증본의SHA·Git추적상태·firebase.json·lost-party를재확인한다.
실험후보와바이트일치하는전체본만승격하며운영사전release/source를보존한다.
실제게시1회후release.rulesetName→source SHA일치로판정한다. 필요시getExecutable의rulesetName/
syncTime도확인하되운영데이터를변조하지않는다. API결과와콘솔이충돌하면콘솔표시만으로성공선언하지않는다.
실패하면재시도없이기존활성유지여부를보고한다. 원하지않은활성변경이확인돼도자동rollback게시하지않고
변경사실·영향·복구대상을보고한뒤새지시를받는다.

승인경계: 이번은문서설계만. 1단계조사실행, 후보구현, 테스트프로젝트의정확한대상/횟수,
운영최종1회는각실제범위가확정된후진행한다. 설계승인을원격실험·운영게시승인으로확대하지않는다.
이번설계완료조건은근거/가설/실험분기/기능보존/완료판정이명시된문서와diff검사다.
게시장애해결·BUG-024종료·dev/main통합완료와구분한다.

## 2026-10-05 당시 결론 — 무엇이 문제였고 어떻게 해결했는가

**현재 운영 게시 차단은 해결됐다.** 가장 강하게 뒷받침되는 설명은 전체 Rules 결합 시
컴파일/실행 코드의 크기·구조 부담이다. 특정 함수 문법 오류나 행 수 자체가 원인이라고 확정하지 않는다.
실패본의 내부 실행 크기는 반환받지 못했으므로 '250KB 초과가 모든503의 확정 원인'이라고 기록하지 않는다.

### 비교로 확인한 사실

1. 분할본 각각은 즉시 게시 성공했다고 사용자가 보고했다. 분할본 운영을 해결책으로 채택하지 않았다.
2. 공통 상위에 있던 함수187개를 필요한 match 범위로 이동한 비교에서 기준503/후보컴파일200이
   두 쌍 재현됐다. 최종e7aeb309는 컴파일200/Ruleset생성200이어도 운영 release PATCH503이었다.
   즉 콘솔 이력에 저장본이 생기는 것과 실제 활성화는 별개였다.
3. 표시 스냅샷 대조 축소는1053bytes 감소에 그쳐 독립적인 게시 해결 효과를 입증하지 못했다.
   이는 표시값 일치 요구를 일부 줄인 의도적 계약 변경이며, 이름 축약과 혼동하지 않는다.
4. 주석 제거 후210185bytes인 전체본에서 함수명만 축약한152163bytes 후보는 컴파일/생성200이나
   테스트 프로젝트 활성화400 INVALID_ARGUMENT이었다. 작은 소스만으로 성공을 보장하지 못했다.
5. 함수272개와 인자/지역 바인딩833개 이름까지 축약한134048bytes 후보는 테스트 프로젝트에서
   컴파일/생성/활성화200·활성 해시 일치. 같은 파일이 운영에서도1회 게시 성공했다.
   반환된 V1 실행 코드의 base64 해제 크기는242424bytes다. 실패본과의 내부 크기 차이는 미확인이다.

### 최종 성공본과 보존한 동작

- SHA256: 23702cbcc50542f2ade0004b66a5aad452a809898351ed7260a950360c6a30b5.
- 운영 lost-party 활성 Ruleset: a21d43be-7893-4600-a1b4-47eb44e5ceb3.
- 활성 시각: 2026-10-05 12:03:55 KST. test/create/release 모두200, 컴파일 경고0.
- 마지막 축약 단계는 함수/지역 이름과 공백만 변경했다. 필드·문자열·경로·조건·호출 순서 보존,
  역치환한 비주석 토큰 일치를 생성 시 강제한다. 공유 저장·기기 간 동기화를 로컬로 옮기지 않았다.
- 최종 제한 검증: 정적4건/생성일치, 첫 구간8인 탈퇴·추방·개인완료 통과,
  후속 CI37220260827 성공(82 PASS marker·원시1000식 오류0). 전체 회귀나 모든 실기기 조합 통과는 아님.

### 이후 유지보수 원칙

가독 가능한 생성 입력/변환을 수정하고 tools/integrate_roster_rules.mjs로 실제 firestore.rules를
재생성한다. --check --review로 생성 일치와 coverage/rules-executable/review의 가독본·이름표를 확인한다.
백업 firestore.rules-backup은 게시 성공본과 같은 파일이 아니므로 무심코 덮어쓰거나 배포하지 않는다.
복구할 때는 최종 성공 Git 추적본과 해시를 기준으로 삼는다. 소스 행 수·바이트 감소를 실행 코드 감소로
대체하지 않고, 새 기능 추가 후 원격 컴파일과 활성화를 별개 확인한다. 242424bytes를 무제한 여유로 보지 않는다.
실패 시 /test·/rulesets·/releases 단계/HTTP/body와 활성 소스를 구분한다. 같은 실패 무한 재시도,
권한 완화·정상 기능 삭제로 게시만 통과시키는 방식을 사용하지 않는다.

아래는 시간순 과거 근거다. 과거 '운영 미수행/미해결' 문구는 당시 상태이며 위 최종 결과가 우선한다.

## 2026-10-05 12:03 KST — 운영 활성화 성공

23702cbc 전체본이 lost-party에서도 활성화200·활성 해시 일치. 게시1회, 재시도 없음.
[정확한 요청 결과와 Ruleset](DEV_LOG.md). 이전503의 원인을 모두 확정한 것은 아니나 현재 게시 차단은 해소됐다.


## 2026-10-05 02:10 KST — 전체 Rules 테스트 프로젝트 활성화 성공

사용자가 rules-test-1-81e31에서 최대 2회 비교를 승인했다. 각 후보 1회씩 실행했고
운영 lost-party는 변경하지 않았다. 사전 활성 소스는 coverage/rules-executable/attempt1에 보존했다.

| 후보 | 소스 bytes / SHA 앞8자 | /test | /rulesets | /releases PATCH |
|---|---|---|---|---|
| 함수명만 축약 | 152163 / b23fae9b | 200·경고0 | 200 | 400 INVALID_ARGUMENT |
| 함수명+인자·지역변수 축약 | 134048 / 23702cbc | 200·경고0 | 200 | 200·활성 해시 일치 |

성공 source SHA256: `23702cbcc50542f2ade0004b66a5aad452a809898351ed7260a950360c6a30b5`.
활성 Ruleset: `projects/rules-test-1-81e31/rulesets/f317ab80-911c-45b4-8ece-e6c6f310199f`.
updateTime: 2026-10-04T17:10:18.501319Z. 성공 요청 소요시간 test2777ms/create2425ms/release4827ms.
공식 getExecutable이 반환한 V1의 base64 해제 크기는 242424bytes다. 실패본의 실행 코드 크기는
얻지 못했으므로 정확한 제한 초과 수치나 기존 모든503의 원인을 확정하지 않는다.
조건 변경 없이 식별자를 줄인 전체본이 활성화됐다는 사실은 실행 코드 크기 관련 가설을 강하게 지지한다.

이번 변경은 직전 d7cb4795의 함수272개·인자/let833개 이름 축약과 공백 축소다.
필드·문자열·경로·조건·호출 순서와 공유 저장 계약은 유지하며, 역치환한 비주석 토큰 전체 일치를
생성 시 강제한다. 이전 그룹 표시 대조 축소라는 의도한 계약 변경은 그대로 포함한다.
실제 firestore.rules가 성공 파일과 바이트 일치한다. 생성 도구 --check --review로 가독본과
이름 대응표를 coverage/rules-executable/review에 재생성할 수 있다. 백업과 사용자 초기화 설정 보존.

정적 변환 테스트4건/생성 일치/diff 검사 통과. 실제 축약본 제한 검증은 DEV_LOG의
첫 구간 통과 및 CI37220260827 성공으로 완료했다. 후속82 PASS marker/원시1000식 오류0건.
CI manifest의 SHA256도 활성 성공본과 일치한다. 전체 Flutter/회귀/실기기는 미수행. 성공 범위는 테스트 프로젝트이며 운영 적용은 아직 미수행.
추가 게시 예산은 0회(2/2 소진). 운영 게시 또는 추가 테스트 게시에는 새 승인이 필요하다.
fix/roster-reauth-isolation 유지, dev/main 미반영. 요청/응답 근거는 coverage/rules-executable/attempt{1,2}/result.json.


## 2026-10-05 01:15 KST — 배치 수정본 운영 게시1회, 활성화 실패

사용자 새 명시 승인으로7f1fdf4의 firestore.rules e7aeb309/223488bytes를 lost-party에1회 게시했다.
/test200(body {}, 경고0), /rulesets POST200. 저장 Ruleset bfa3bd58-584d-41fa-80b4-e5f1ad988f60,
업로드 응답 소스 SHAe7aeb30935287c5bea18d18ee6dc520f59fb0ac35a782bc6b2cd93d61d9d8545로 원본 일치.
Release PATCH503 UNAVAILABLE, CLI 내부 create fallback POST409 ALREADY_EXISTS, CLI exit1.
재실행 없음. 사전/사후 활성 e46f131e/해시e8baa2e4/updateTime2026-09-29T09:26:45.388946Z 동일.
즉 컴파일 성공과 소스 업로드까지 확인했으나 운영 적용 실패. 함수 배치의 test 개선과
활성화 실패를 분리한다. 서버 내부 크기/Release503 근본 원인은 아직 미확정이다.
근거: coverage/roster-publish-scope-approved의 deploy-once.log, before/after.json·rules.
다음은 활성화 실패 원인 분리이며 새 지시 전 재게시하지 않는다. 코드/백업/사용자 설정 유지,
전용 브랜치 유지·dev/main 미반영. 기존 제한 검증 재사용·문서 diff 검사 수행.


## 2026-10-05 최신 — 함수 배치 변경 서버 비교 성공

187함수 scope 이동만으로 기준본503/후보200이2쌍 재현됐다. 조건 삭제/allow 완화 없음.
최종 firestore.rules e7aeb309, CI37215585491 제한 통과·1000식0건. 실기기 미확인.
운영 배포는 자동 승인 검토가 이전1회 승인 소진으로 실행 전 차단했다. 이번 deploy0회.
다음은 사용자 재승인 후 검증된 전체본 게시1회와 활성 소스 확인이다. 추측 추가 수정은 하지 않는다.
[비교와 변경 행](RULES_SCOPE_EXPERIMENT.md), [검증/차단 기록](DEV_LOG.md).
아래는 이전 기록이다.


## 2026-10-05 00:58 KST — 정리 공통화본 게시1회 실패

사용자의 새 게시 지시로 a86179b의 firestore.rules(cd04e69e/223114bytes)를 lost-party에
Rules만 정확히1회 게시했다. /test503·CLI exit2, /rulesets 업로드와 /releases 활성화 미도달.
원격 컴파일 완료/경고0은 이번 요청에서 확인되지 않았다. 이전 제한 CI 결과는 유지한다.
사전/사후 활성 Ruleset e46f131e-920a-4773-bc25-2ef4b7ff9169 및 SHAe8baa2e4 동일,
활성 updateTime2026-09-29T09:26:45.388946Z. 수정본 운영 미적용, 재시도 없음.
근거: coverage/roster-publish-aggregate의 before/after.json·rules 및 deploy-once.log.
수동 게시도 실패했다는 사용자 보고와 별도로 이번 CLI 실패 단계를 확인했다.
이번503만으로 컴파일 용량 초과를 확정할 수 없다. 다음은 실패 단계 원인 분리이며
새 지시 없이 반복 게시/추측 기능 삭제를 하지 않는다. 코드·백업·사용자 설정 보존,
전용 브랜치 유지·dev/main 미반영. 기존 검증 재사용, 문서 diff 검사 수행.


## 2026-10-04 17:21 KST 검증본 게시 1회 — 업로드 성공·활성화 실패

- 전용 브랜치05499c8의 firestore.rules, SHA3b0f492ba48fe6e7e2f68949239bb64bb52739d41013a1c448a1c69dd5a5663f,
  224316bytes를 lost-party에 Rules만 정확히1회 CLI 게시했다. dry-run/재시도 없음.
- /test200·컴파일 issues[]로 경고0, /rulesets POST200. 저장된 Ruleset
  f18499bf-b3ef-472c-9cd4-9f68c71162ac의 응답 소스 해시는 로컬 원본과 일치한다.
- /releases/cloud.firestore PATCH503. CLI 자동 create fallback POST409, 종료코드1.
  CLI 내부 fallback과 별개로 에이전트가 재게시한 횟수는0이다.
- 사전/사후 활성 Ruleset e46f131e-920a-4773-bc25-2ef4b7ff9169,
  해시e8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5 동일.
  운영 활성본은2026-09-29 유지. 이번 수정본은 운영 적용되지 않았다.
- 근거: coverage/roster-publish-removal의 before/after.json·rules, deploy-once.log, result.json.
  소스 손실은 이번 응답 대조에서 배제했으나 컴파일 결과 크기/활성화503의 근본 원인은 미확정.
- 제한 기능·권한 검증과 거절 한도 수정은 완료, 운영 활성화·사용자 실기기는 미완료다.
  정상 기능을 추가 삭제/완화하지 않는다. 다음은 실패한 활성화 단계의 원인 분리이며
  새 지시 전 반복 게시하지 않는다. dev/main 미반영, 사용자 파일 보존.


## 2026-10-04 00:38 KST — 개인 완료 중복 제거본 게시1회 실패

사용자 승인으로6742123의 firestore.rules(223746bytes,
SHA6a4a4b52cf566f9c119d9de3c3876c411c336da24ee62b9bca5fd1be97bd1da9)를
lost-party에 정확히1회 deploy --only firestore:rules 했다. 경로/생성 일치/diff 확인 후 진행.
00:38:41 KST POST /projects/lost-party:test가503 UNAVAILABLE, CLI exit2.
원격 컴파일 결과·경고는 미확정이며 Ruleset 업로드/Release 활성화 미도달이다.
사전/사후 활성 Ruleset e46f131e-920a-4773-bc25-2ef4b7ff9169,
updateTime2026-09-29T09:26:45.388946Z,
SHAe8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5 동일.
근거 coverage/roster-publish-6742123의 deploy-once.log와 before/after 백업.
재시도 없음. 로컬 제한 검증 완료와 원격 게시 실패를 구분하며503 원인은 여전히 미확정.
새 운영 흐름 활성화 없음. 기존 운영본 보존 확인. 실기기/전체 회귀/dev·main 병합 미실행.
사용자 초기화 설정·백업·분할본 보존. 전용 브랜치에서 결과 문서만 커밋·push한다.


## 2026-10-04 — 분할 성공 보고와 전체 무손실 축소 실패

사용자는 백업 분할 두 파일이 테스트 프로젝트에서 각각 즉시 게시됐다고 확인했다.
검증된 전체본39a7b731의 주석/공백/내부 함수명만 줄인 후보는224266→153208bytes,
SHA772dd42fc5b26b376b0f4f3d0a5787a0dfc4d393f6471f4a4787f5f84567f128이다.
역매핑 의미 토큰 일치는 통과했으나 10월3일23:38 KST 테스트 프로젝트1회 게시가
/test503으로 실패했다. Ruleset/Release 미도달, 후보 미채택, 자동 재시도 없음.
테스트 사전/사후 활성 Ruleset f9ab3c5d-e3df-471e-b24b-3077c195b246,
SHA64d6a696f3421eca090ace9f4abf2d3e9f1f125060b289a073f0a06907f65866 동일.
사용자의 분할본 게시 이후이므로 아래 과거의 테스트 최소 거절 상태는 현재 상태가 아니다.
근거는 coverage/rules-source-compact의 manifest/deploy-once.log/before·after 파일이다.
전체 규모/구조 가설은 유력하지만 컴파일250KB 초과나503의 정확한 원인은 미확정이다.
운영/배포 원본/사용자 백업/분할 파일/초기화 설정은 보존했다.


## 최신 시도 — 2026-10-03 21:57 KST

사용자 승인으로 48bb6f3/224266bytes/SHA39a7b73168a6c236340bb91dffb58682fde5c9f85bdcb452c42ddc7637ad838b
운영 lost-party Rules만 정확히1회 CLI deploy. /test503 UNAVAILABLE(exit2)로
Ruleset 업로드와 Release 활성화에 도달하지 못했다. 원격 컴파일 결과/경고는 미확정.
사전/사후 active e46f131e, updateTime2026-09-29T09:26:45.388946Z,
SHAe8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5 동일.
기존 캐릭터 이동의 평가 비용 수정은 게시503 해결을 보장하지 않으며 원인은 여전히 미확정.
동일 명령 재시도 없음. 근거 coverage/roster-publish-48bb6f3의 로그 및 활성 소스 백업.


## 최신 비교 결과 — 2026-10-03 20:52–20:53 KST

사용자가 추천 비교안을 승인하고 테스트 프로젝트 표시명 `rules-test-1`을 확인했다.
Firebase 목록에서 ID `rules-test-1-81e31`과 일치 확인 후 해당 프로젝트만 변경했다.
운영 `lost-party`에는 쓰기 요청을 하지 않았다. 원본 Rules/앱/초기화 설정은 변경하지 않았다.

| 입력/단계 | 결과 | 활성 소스 확인 |
|---|---|---|
| 최소 거절 규칙 148 bytes | test/createRuleset/updateRelease 모두 성공 | 최소본 해시 일치 |
| 운영 과거 성공본 185937 bytes, e8baa2e… | test 503, 저장/적용 미도달 | 최소본 유지 |
| 현재 검증본 224418 bytes, f43ea68c… | test 503, 저장/적용 미도달 | 최소본 유지 |
| 테스트 사전 Ruleset 직접 복원 | updateRelease 503 | 최소본 유지, 복원 미완료 |

**테스트 프로젝트는 현재 모든 클라이언트 읽기·쓰기를 거절하는 최소 규칙 상태다.**
사전 Ruleset `db415c0d-4e2f-4357-82f8-189798c9d4d2`와 소스 백업은 보존했다.
사전 해시 cf bf로 시작하는 전체 값은
`cfbf6686b01dfb53c5e090ad63acb302409af011d54a274ecfd5769ffd7b44d2`다.
현재 활성 Ruleset `211d86f8-e0d1-46db-8952-1e674fe8e1a4`, 해시
`61d45e2c79ed7b5c1c7de15e36fce3efbfae1ba71d67dd4a2da24b22bbb2231c`.
각 입력은 1회만 시도했고 실패 후 같은 입력을 반복하지 않았다. CLI의 PATCH 실패 후
CreateRelease 대체 호출을 피하기 위해 기존 Firebase CLI 라이브러리의 단계별 API를 사용했다.
컴파일 성공 최소본은 응답 `{}`로 경고 없음. 두 큰 소스는 컴파일 결과 미확정이다.

기존 운영 감사 로그도 대조했다. 9월29일 16:25 성공 UpdateRelease와 10월3일 14:14
INVALID_ARGUMENT 요청은 프로젝트/Release/요청 구조 및 granted:true가 같고 Ruleset만 달랐다.
감사 로그의 가장 최근 성공 기록이 현재 활성본의 마지막 게시 시각과 같지는 않으므로
전체 요청 이력이 완전하다고 주장하지 않는다. INVALID_ARGUMENT의 세부 인수는 제공되지 않았다.

판단: 최소 규칙으로 프로젝트/인증/기본 적용 경로는 동작한다. 과거 성공 소스 및 이미 저장된
테스트 Ruleset 재적용도 실패하므로 새 원정대 기능만의 회귀로 단정할 수 없다.
대형 Rules 처리/원격 서비스/현재 실행 환경의 통신 문제를 아직 구분하지 못했다.
소스 크기와 복잡도 중 원인, 컴파일된 크기 초과 여부도 미확정이다.
다음 권고는 다른 실행 환경에서 동일 소스를 제한 비교해 통신 변수를 분리하고,
테스트 원래 Ruleset 복원을 우선 확인하는 것이다. 추가 원격 쓰기는 새 지시 후 수행한다.
코드 축소/권한 완화/운영 게시/문의 전송/전체 회귀는 하지 않았다.

근거: ignored `coverage/rules-publish-isolation/`의 프로젝트별 before-source/releases,
release-audit.json, minimal/previous/current/restore-result.json 및 compare-stage.cjs.

## 이전 결론 (14:37 시도 기준)

현재 Rules는 업로드 내용이 손실된 상태가 아니다. 운영 프로젝트에 저장된 최근 5개 Ruleset은
모두 로컬 통합본과 내용 해시가 같다. 그러나 활성 Release는 9월 29일 Ruleset을 가리킨다.
확인된 직접 실패 지점은 **새 Ruleset을 운영에 연결하는 Release 갱신**이다.
서버 내부 503의 근본 원인(서비스 장애/소스별 백엔드 처리 문제)은 아직 확정하지 못했다.

## 이번 승인된 1회 시도

대상 `lost-party`, 기본 Firestore, CLI 15.32.1 / Node 24.19.0.
브랜치 fix/roster-reauth-isolation. 검증된 firestore.rules는 수정 없이 재사용했다.
2026-10-03 14:37 KST에 deploy 명령을 정확히 한 번 실행했다.

| 단계 | 결과 |
|---|---|
| POST /projects/lost-party:test | 200, 컴파일 성공, 응답 `{}`로 Rules 경고 없음 |
| POST /projects/lost-party/rulesets | 200, 신규 Ruleset 생성 성공 |
| PATCH /projects/lost-party/releases/cloud.firestore | 503 UNAVAILABLE |
| CLI의 자동 대체 POST /projects/lost-party/releases | 409 ALREADY_EXISTS |
| 게시 후 활성 Release 조회 | 기존 Ruleset/게시 시각/해시 유지 |

CLI의 `lib/gcp/rules.js:updateOrCreateRelease()`는 PATCH 실패 종류를 구분하지 않고
catch에서 createRelease를 호출한다. 기존 Release가 있으므로 409가 뒤따른다.
마지막 409는 최초 503을 덮어 보이는 후속 오류이며, Rules 문법 오류를 의미하지 않는다.
에이전트가 별도 게시 명령을 반복하거나 CLI를 수정하지 않았다.

## 서버 저장본 대조

- 로컬/최근 저장본 SHA256(LF): `11ef3dde97ac202f488d1a12d861c2cf20c13e50ef9c5c3e1dc45e1fdc3af151`.
- 이번 생성 Ruleset: `4fedbc05-ca37-4b7e-8ba6-4a2c8eba70f3`, 생성 `2026-10-03T05:37:31.924575Z`.
- 사용자 첨부 로그는 14:35:01 KST `/rulesets` 503으로 끝났으나,
  `b7e83ac5-69b2-4354-85c3-9ea1b5e6b949`가 14:35:02 KST에 생성되어 같은 소스를 보존한다.
  이 시도와 시간상 부합하지만 요청 ID 연결 자료는 없으므로 동일 요청이라고 단정하지 않는다.
- 같은 통합본 저장 시각: 13:49:32, 14:14:06, 14:16:23, 14:35:02, 14:37:31 KST.
- 활성 Ruleset: `e46f131e-920a-4773-bc25-2ef4b7ff9169`.
- 활성 updateTime: `2026-09-29T09:26:45.388946Z`.
- 활성 SHA256: `e8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5`.

따라서 이력 생성 시각이 새로 생겨도 현재 적용 소스가 옛 내용인 현상을 설명할 수 있다.
사용자가 본 정확한 콘솔 선택 항목은 직접 대조하지 않았으므로 UI 표시 오류라고 확정하지 않는다.
공식 API도 Ruleset 저장과 Release 적용을 별개로 정의한다:
https://firebase.google.com/docs/rules/manage-deploy

## 배제 가능한 원인과 남은 가설

- 잘못된 파일/프로젝트: 이번 요청은 프로젝트·설정 경로·서버 저장 해시로 일치 확인.
- 단순 문법 오류: 이번 원격 컴파일 성공, Ruleset 생성 성공. 해당 오류 근거 없음.
- 소스 크기: 227,459 bytes, source JSON 232,551 bytes로 256 KiB 미만.
- Ruleset 개수: 조회 당시 180개로 공식 2,500개 미만. 과거 이력 삭제는 불필요.
- 컴파일된 크기의 별도 250 KB 한도는 실제 수치를 확보하지 못했다. 원본 크기만으로
  준수/초과를 단정하지 않는다. 원격 생성 성공도 Firestore 활성화 전체 성공을 보장하지 않는다.
- IAM/토큰: 읽기·원격 컴파일·Ruleset 생성은 성공했고 401/403은 없음. 활성화 권한 문제라는
  근거는 없으나 서버가 왜 503을 반환하는지는 백엔드 진단이 필요하다.
- Firebase 공개 상태 페이지에 당시 공지된 장애는 없었지만, 이것만으로 부분 장애를 배제하지 않는다.
- 사용자 테스트 프로젝트 실패는 보고 사실이며 프로젝트 ID·동일 단계 로그는 아직 미대조다.

공식 제한: https://firebase.google.com/docs/firestore/quotas#security_rules
상태 페이지: https://status.firebase.google.com/

## 다음 조사 방향

1. 새 Ruleset을 반복 생성하는 전체 deploy 대신 이미 저장된 위 Ruleset의 Release 갱신만
   대상으로 삼는 진단을 우선한다. 이는 운영 쓰기이므로 현재 1회 승인으로 추가 실행하지 않는다.
2. 재현 시각·프로젝트·Ruleset ID·PATCH 503/후속409·해시를 Firebase 지원에 제공해
   활성화 백엔드의 원인/컴파일 크기/요청 추적을 확인한다. 지원 문의는 아직 전송하지 않았다.
3. 소스 특정 문제를 분리해야 한다면 별도 테스트 프로젝트 ID와 실험 범위를 먼저 확정하고,
   기존 활성 소스와 통합 소스의 동일 API 단계 결과를 비교한다. 운영 Rules를 축소·완화하지 않는다.
4. 운영 활성 해시가 통합본과 같아진 뒤 실기기 테스트를 시작한다. 이번 작업에서 Rules/앱은 무수정,
   전체 회귀는 사용자 생략 지시 유지. 로컬 상세 로그·소스 대조는 coverage/roster-publish-retry에 보존했다.
# 최신 추가 시도: 2026-10-03 18:10 KST

사용자 승인으로 최종 수정본(4453f53,224418bytes,
SHA256 f43ea68c10658121206581b10730706f68f5cf524e4dc8543840352242ee0500)을
lost-party에 정확히1회 게시했다. /test200(컴파일 성공,경고없음), /rulesets POST503,
Release 요청 미도달로 종료했다. 이전14:37의 Release PATCH503과 실패 단계가 다르다.
원인 미확정. 구조 개선 후에도 게시 실패는 남아 있으며 같은 명령은 반복하지 않았다.

사전/사후 활성 Rules는 e46f131e-920a-4773-bc25-2ef4b7ff9169,
2026-09-29T09:26:45.388946Z, SHAe8baa2e4824d9200ab8a76fe07d7155578ba6982ca9b29941b9b7f55a6b3b1a5로
동일했다. 저장 이력은 이번에 조회하지 않아 실패 요청의 저장본 생성 여부는 미확인이다.
로컬 근거: coverage/roster-publish-final/deploy-once.log 및 before/after.json,.rules.
새 지시 전 추가 게시하지 않는다. 아래는 이전 시도 이력이다.
