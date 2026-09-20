# Task-11 Firestore Rules 복잡도 차단 — 종료된 진단 이력

## 2026-09-20 F6-D5 신청 state 최종 차단 검증

- application create/reapply의 기존 완료 검사를 exact `raidState` 부재와 legacy Claim 부재로 분리했다. state가 남은 요청은 상태 내용을 반복 검사하지 않고 단건 `existsAfter`에서 먼저 거절하므로 부모 모집 N+1 조회, 인원수 비례 검증과 Player 이벤트 fan-out을 추가하지 않는다.
- 신청 create와 철회 후 reapply 모두 state 잔존 거절, state 제거 후 기존 정상 흐름 성공을 demo 시나리오로 고정했다. 즉시 가입은 기존 `raidState` create 계약이 최종 점유 경쟁을 거절하며 중복 Rules 조회를 추가하지 않았다.
- JS 문법, 정적 Rules 계약, 관련 Flutter 표적 테스트와 변경 파일 분석이 통과했다. 작업 브랜치 Actions `35494192803`에서 전체 추적 Rules 및 기존 그룹 이전·탈퇴·해산 회귀가 통과했다. Actions의 Node/setup-java 주석은 Rules 컴파일 경고가 아니다.
- 추적 Rules SHA-256은 `9228699FEB79F2F41AC782B8E4F98FF6AEE1F94248354B954CEF503AB2B65B0C`다. 운영 `lost-party`에 Rules만 1회 게시 시도했으나 원격 컴파일 `projects/lost-party:test`가 HTTP 503 `UNAVAILABLE`을 반환했다. `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않아 운영 Rules는 갱신되지 않았으며 같은 명령을 반복하지 않는다.

## 2026-09-20 F6-D 단건 고아 참가 기록 정리 검증

- 기존 `validAtomicStaleRaidStateDelete`를 유지하고 구 `activeRaidAssignments`에는 현재 바인딩 Player 본인, 정확한 문서 ID, active 상태, 연결 모집 없음 또는 기존 stale 모집일 때만 허용하는 delete 분기 하나를 추가했다. 생성·수정, 타인 정리, 정상 활성 모집 정리는 계속 닫혀 있다.
- demo Rules 시나리오는 모집 원본 없음인 본인 `raidState`+구 assignment 원자 삭제 성공, 타인 삭제 거절, 정상 활성 모집 삭제 거절의 대표 사례만 추가했다. 인원수별 반복이나 Player 이벤트 fan-out은 추가하지 않았다.
- JS 문법, Rules 문자열 계약, 관련 ViewModel 테스트 9건과 변경 Dart 파일 정적 분석이 통과했다. 로컬 Emulator는 이미 확인된 Windows Rules 로딩 503을 반복하지 않았으며, 작업 브랜치 Actions `35454451057`의 demo Emulator에서 전체 추적 Rules와 기존 그룹 이전·탈퇴·해산 회귀까지 통과했다. Actions의 Node/setup-java 주석은 Rules 컴파일 경고가 아니다.
- 변경 Rules SHA-256은 `716402EF95051F6F07B799F275431B9A89718E7BA713A07EEEFB147FDCDCCC94`다. 이후 사용자가 Firebase 콘솔에서 Rules를 한 차례 게시했다고 확인했으나 AI가 활성 소스 해시를 직접 대조하지 않았다. 이전 주차 고아와 신청 create/reapply 최종 차단 설계가 추가됐으므로 후속 Rules 변경이 생기면 같은 검증 게이트 뒤 다시 게시해야 하며, 실기기 확인 전에는 F6-D 완료로 판정하지 않는다.

## 2026-09-19 F6-B2-A 본인 주간 상태 list 검증

- `players/{playerId}/raidStates`와 구 `activeRaidAssignments`의 list를 현재 바인딩 Player 본인에게만 열고 구 assignment 쓰기는 계속 닫았다.
- demo Rules Emulator 시나리오에 본인 현재 주차 list 성공과 타 Player list 거절을 추가했다. Android Studio JBR 21로 Emulator는 기동했으나 추적 `firestore.rules` 로딩이 기존 Windows 환경과 같은 `503 Network closed for unknown reason`로 중단돼 시나리오 평가에 도달하지 못했다.
- 문자열 계약·JS 문법·Flutter 표적 테스트에 더해 작업 브랜치 GitHub Actions `35412398666`의 demo Emulator에서 전체 추적 Rules 회귀와 본인 현재 주차 list 허용·타 Player list 거절이 통과했다.
- 승인 후 SHA-256 `51146C8DF8B12493AE5B3DACAD47D533A74D242C25F57930FAAA49BF2E0280CC`의 `firestore.rules`만 운영 `lost-party`에 1회 게시 시도했다. 원격 컴파일 `projects/lost-party:test`가 HTTP 503 `UNAVAILABLE`을 반환해 `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않았다. 운영 Rules는 갱신되지 않은 상태로 판정하며 같은 명령을 반복하지 않는다.
- 이후 사용자가 Firebase 콘솔에서 Rules를 별도로 게시했다고 확인했다. AI는 활성 게시 소스와 로컬 SHA-256을 직접 대조하지 않았으므로 내용 일치는 단정하지 않는다. 게시 후 실기기에서 확인된 다인 전체 완료 권한 실패는 Rules 컴파일 실패가 아니라 앱이 타인 private `raidState`를 선조회하는 구조와 일치하며, 완료 기록 누락·체크박스 비활성은 각각 이벤트 Payload와 UI 명령 연결 문제로 분리한다.

## 2026-09-19 F6-B2-R2 공용 완료 이벤트 검증

- lifecycle event schemaVersion 2의 완료·완료 취소 Payload에 공통 `raidId/difficultyId/cycleKey`와 최대 8개 `completionTargets`를 추가했다. Rules는 한 번 읽은 변경 후 모집의 `partySlots`와 audience·Player·Character를 인덱스별로 비교하며, 대상별 추가 문서 조회나 Player 이벤트 fan-out은 추가하지 않았다.
- schemaVersion 1 lifecycle event create는 구 앱 호환을 위해 기존 필드 계약으로 유지하고, 새 schemaVersion 2 완료 이벤트의 대상 누락·Character 위조는 거절하도록 demo 시나리오를 추가했다.
- Dart 표적·정적 계약과 JS 문법은 통과했다. 기존 Android Studio JBR로 실행한 로컬 demo Emulator는 Rules 로딩 단계에서 `503 Network closed for unknown reason`가 발생했지만, 작업 브랜치 GitHub Actions `35417265039`의 격리 Emulator에서는 Rules 컴파일·로딩과 1·2·4·8인 lifecycle, 완료 대상 누락·Character 위조 거절이 모두 통과했다. Actions의 Node 20/setup-java v4 deprecation 표시는 Rules 경고가 아니다. 운영 Rules는 게시하지 않았다.

## 2026-09-13 파티 통합 오류 Snapshot allowlist 배포 시도

- 작업 브랜치 `codex/plan-release-stabilization-fixes`의 추적 커밋 `8b4d5ce`는 파티 Character 변경의 `affectedKeys`에 표시용 `buildIntegritySnapshot` 1개만 추가한다. 관련 문자열 계약 테스트 2건은 통과했다.
- `firebase.json`의 배포 원본 `firestore.rules`와 대상 `lost-party`를 확인한 뒤 실제 배포를 한 번 실행했다.
- Firebase Rules 원격 컴파일 `projects/lost-party:test` 단계에서 HTTP 503이 발생했다. `/rulesets` 업로드와 `/releases` 반영에는 도달하지 않았으므로 운영 Rules는 갱신되지 않은 상태로 판정한다.
- 컴파일 성공과 경고 0개도 확인하지 못했다. 기존 장애 대응 원칙에 따라 같은 명령을 즉시 재시도하지 않으며, 사용자에게 실패 단계를 공유한 뒤 새 지시가 있을 때만 재시도한다.
- 후속 확인에서 동일 조건의 테스트 프로젝트는 콘솔 게시에 성공했고, 운영 프로젝트로 돌아오자 오류 문구가 사라졌다. 로컬 Rules를 다시 붙여 넣었을 때 변경점이 없어 게시 버튼이 비활성화됐으며 실기기 기능도 정상 동작했다.
- 이 간헐적 503에는 앱 코드·Rules 축소 같은 1차 대응을 하지 않는다. 같은 현상이 재발하면 동일 조건 테스트 프로젝트 게시 성공 여부를 먼저 대조한 뒤 `/test`, `/rulesets`, `/releases` 실패 단계를 분리한다.

## 2026-09-10 Rules 게시 경고 재점검

### 2026-09-14 다인 해산 수정본의 교차 프로젝트 `/rulesets` 503

- 커밋 `a5a28d6`의 Rules는 운영 `/test`에서 HTTP 200·컴파일 성공·경고 0건을 확인했지만 `/rulesets` POST가 HTTP 503으로 실패했다. Release 갱신에는 도달하지 않았다.
- 동일 소스를 별도 테스트 프로젝트 Firebase 콘솔에 게시해도 반복적으로 503이 발생했다. 운영 프로젝트 IAM·데이터·Auth 상태보다 현재 Rules 소스 형태 또는 Firebase Ruleset 저장 서비스의 공통 처리 문제를 우선한다.
- 직전 콘솔 게시 성공 기준 `c4344e6`과 현재 Rules의 기능 diff는 `validPlayerEvent` 한 곳이다. 함수 수는 199개로 같고, dispatcher의 type guard 목록 확장으로 소스가 약 578자 증가했다. 공개되지 않은 컴파일 산출물 크기를 측정한 값은 아니므로 단순 파일 용량 한계로 확정하지 않는다.
- 1차 대응은 권한·validator를 제거하지 않고 dispatcher를 짧은 우선순위 OR로 축소한다. `partyDisbanded` lifecycle을 cycle보다 먼저 두고 수동 인증 validator는 명시 type guard 뒤에 호출해 무관한 문서 조회를 막는다.
- compact 소스는 테스트 프로젝트에 먼저 게시한다. 실패하면 같은 시점에 직전 성공 기준 `c4344e6`을 A/B 대조한다. 둘 다 실패하면 외부 서비스 장애로 분류하고 추가 축소·반복 게시를 멈춘다. 기준본만 성공하면 R4 이벤트 Rules 중복 축소를 별도 작업으로 연다.
- compact dispatcher는 6행으로 구현했고 함수 수 199개를 유지했다. 직전 성공 기준과의 기능 diff는 dispatcher 1곳의 4행 추가·3행 삭제뿐이다. 표적 18건, 경고 계약 3건과 전체 Rules 로컬 Emulator 컴파일·기동이 통과했으며 원격 Ruleset 저장은 테스트 프로젝트 게시 전이라 미확인이다.

- 사용자가 Firebase 콘솔에 게시된 소스를 `firestore-web.rules`로 복사해 로컬 원본과 대조했다. 두 파일은 모두 3,785행이며 차이는 `groups/{groupId}` update에서 `validGroupDisbandUpdate`의 평가 순서 8행뿐이다. 콘솔본은 해산 판정이 마지막인 이전 게시본이고, 로컬 원본은 실제 1인 그룹 해산 오류를 보완해 가입·승인보다 앞에 둔 버전이다.
- 콘솔과 CLI에 표시된 경고 9개는 두 소스에 공통으로 존재한다. 따라서 최근 해산 순서 변경이나 주차 전환 기능이 새로 만든 경고가 아니다.
- 경고 원인은 미사용 `validRecruitmentJoin` 인자 1개, `null`과 string을 섞은 대표 Character·수동 인증 판정 3개, 생성 시 map 인자에 `null`을 전달한 membership·그룹 join relation·applicant stats 경로 5개다.
- 동일 소스가 원격 `projects/lost-party:test`에서 503을 반환하다가 컴파일에 성공했고, 콘솔 게시도 장시간 뒤 성공했다. 그러므로 이 사건에서 503을 경고의 직접 결과나 특정 기능의 오류로 확정하지 않는다. `compiled successfully`와 게시 성공은 문법 유효성을 뜻하지만, 경고를 방치할 근거로도 사용하지 않는다.
- 수정 원칙은 기능·스키마·허용/거절 조건을 삭제하지 않는 타입 명확화다. 생성 경로는 빈 목록·0·`request.time`을, 수정 경로는 기존 문서 값을 전달한다. nullable 계정 ID 반환은 존재·활성·소유 여부의 boolean 판정으로 바꾸고, 미사용 인자는 호출부와 함께 제거한다.
- `firestore-web.rules`는 게시본 증거로 수정하지 않고 Git 제외한다. 유일한 배포 원본은 `firebase.json`의 `firestore.rules`다.
- 로컬 검증: 그룹·활동 Character·운영자 인증·주차 전환 계약 테스트 43개와 경고 재발 방지 테스트 3개가 통과했다. 게시본 Snapshot의 정규화 SHA-256 `F9F3792E692DCC8E5DE5063E25842629E1CBFF58805FB815C74173E7C799538A`가 대조 전후 동일함을 확인했다.
- 원격 검증: 2026-09-10 사용자가 `firebase deploy --only firestore:rules --project lost-party --dry-run`을 실행해 `rules file firestore.rules compiled successfully`와 `Dry run complete`를 확인했다. 기존 미사용 인자·nullable string/map 경고 9개는 다시 출력되지 않았고 503도 재현되지 않았다. 실제 Ruleset 업로드·Release 반영은 아직 수행하지 않았다.
- 완료 조건은 관련 계약 테스트 통과, `git diff --check`, 원격 컴파일 경고 0개, 사용자가 수행한 Rules 배포의 `released rules ... to cloud.firestore`와 `Deploy complete` 확인이다. 배포 전에는 운영 반영 또는 503 해결 완료로 기록하지 않는다.
- 2026-09-10 운영 반영 후 실기기에서 그룹·레이드의 주요 쓰기와 이전 주차 점유 교체가 통과해 게시본이 실제 적용된 것을 기능 동작으로도 확인했다. 단, 1인 그룹 해산은 판정 순서를 앞당긴 뒤에도 permission-denied가 재현됐다. 따라서 이 실패를 Rules 전체 게시 실패나 503의 결과로 취급하지 않으며, 해산 전용 네 문서 Transaction의 조건 불일치로 별도 진단한다.
- 같은 날 현재 Rules 재배포를 한 번 실행했을 때 CLI는 컴파일 성공 후 Ruleset 생성 API에서 503으로 종료됐으나, Firebase 콘솔 최신 게시 시각은 요청 시각인 14:20으로 갱신됐다. Ruleset 생성이 서버에서 완료된 뒤 CLI 응답만 실패한 사례로 기록한다. 이후 동일 현상은 즉시 반복 배포하지 않고 콘솔의 활성 게시 시각과 소스 일치 여부를 먼저 확인한다.
- 후속 1인 해산 수정본은 해산 판정을 `groups` update의 첫 분기로 이동했고 표적 테스트 43건이 통과했다. 이 수정본의 배포 시도는 Ruleset 생성이 아니라 원격 컴파일 `/test` 단계에서 503으로 끝났으므로 운영 반영되지 않은 상태로 분리 기록한다. 503의 발생 위치를 무시하고 콘솔 시각만으로 동일하게 판정하지 않는다.
- 콘솔에 새 게시 기록이 없음을 확인한 뒤 동일 수정본을 재시도했고, 이번에는 원격 컴파일·Ruleset 업로드·Cloud Firestore Release가 모두 성공해 `Deploy complete`로 종료됐다. 1인 해산 우선순위 수정본의 운영 반영은 이 성공 로그를 기준으로 확정한다.
- 운영 반영 후 신규 1인 그룹 해산이 실기기에서 정상 완료됐다. 해산 update를 첫 분기로 평가한 수정의 운영 회귀 검증을 통과했으며, 이 해산 permission-denied 이슈는 종료한다.

> 현재 상태 정정(2026-09-01): 아래 프로브는 503 원인 확인을 위한 1회성 테스트였다. 이후 원복한 Rules에 추가 수정 작업을 진행해 정상 배포했고, 레이드 모집·탈퇴·완료 체크와 그룹 생성·초대·탈퇴·초대코드·가입·그룹 전용 모집 목록을 실기기에서 확인했다. 프로브 Rules가 현재 운영에 남아 있거나 Rules 배포가 현재 차단된 것으로 취급하지 않는다. 아래 내용은 당시 진단 이력으로만 보존한다.

> 2026-08-31 사용자 지시: 그룹 레이드 Rules 업로드가 복잡도 한도로 막히는 것으로 보고 최적화를 재개한다. 운영 프로브 배포는 하지 않는다. 원격 보존 브랜치: codex/rules-complexity-reduction @ ed02b31.

## 상태

| 항목 | 내용 |
| --- | --- |
| 발견일 | 2026-08-31 |
| 차단 범위 | **전체 `firestore.rules` 정상 배포** |
| 현재 단계 | **종료된 진단 이력**. 이후 원복·추가 수정·정상 배포·실기기 확인 완료 |
| Task-11·11a 코드 | **`main`에 1차 병합 완료** (Rules 운영 반영과는 별개) |
| 운영 영향 | 프로브는 1회성 테스트였고 이후 원복·추가 수정·정상 배포됨. 현재 영향 없음 |
| 다음 | 현재 실행 작업 없음. 아래 계획은 당시 기록으로만 보존 |

## 현재 작업 시작점과 최신 배포 결과

- 기준 코드 커밋: **`25f88ff6f8a7be1bdf9ab7f16bbae167ee3bb9ff`** (`refactor(rules): simplify group lookup and snapshot validation`).
- 작업 브랜치: **`codex/rules-complexity-reduction`**. main에 직접 수정하지 않는다.
- 직전 통합 기준: `ea2019a`. 25f88ff에는 native 탈퇴 그룹 탐색과 Snapshot 중복 비교 제거가 포함돼 있다.
- 기준 Rules 소스 크기: **143,799 bytes**. 원본 백업 158,836 bytes와 구분한다. 소스 크기는 컴파일 복잡도의 대리 지표일 뿐 성공 기준이 아니다.
- 사용자 지시에 따라 25f88ff의 전체 Rules를 `lost-party`에 배포 시도했으나 `projects/lost-party:test` 컴파일 검사에서 **503 UNAVAILABLE**로 실패했다. 새 release는 적용되지 않았다.
- 운영의 마지막 성공 Rules 내용은 별도로 조회 확인하지 않았다. 로컬 복원과 운영 복원을 같은 상태로 기록하지 않는다.
- 로컬 Emulator는 전체 Rules뿐 아니라 최소 deny-all Rules 로딩도 `503 / Network closed for unknown reason`으로 실패했다. 운영 API 실패와 로컬 검증 환경 실패를 구분한다.
- 기준 검증: 표적 Flutter 테스트 33개, 변경 테스트 파일 analyze, JS 문법 검사 통과. 실제 Rules 허용/거절 동작과 배포 성공은 미확인이다.
- `legacy/firestore - 복사본.rules`, `legacy/firestore.before-complexity-20260831.rules.bak`는 로컬 백업으로 보존하며 배포 대상에 넣지 않는다.

## 단계별 추가 개선 계획

이번 커밋은 **작업 시작점과 실행 계획만 기록하는 문서 커밋**이다. 아래 구현을 완료했다고 간주하지 않는다. 각 단계는 변경 전에 범위를 확인하고 별도 커밋으로 남긴다.

| 단계 | 변경 대상과 방법 | 앱·데이터 영향 | 검증 및 완료 조건 |
|---|---|---|---|
| R0 검증 환경 | 최소 Rules 로딩 오류를 먼저 분리 조사. 운영을 바꾸지 않는 컴파일 검사와 Emulator 허용/거절 테스트 경로 확보 | 없음 | 최소 대조 검사 성공과 전체 Rules 검사 결과를 각각 기록. 실패 시 수정 효과를 추정해 통과 처리하지 않음 |
| R1 그룹 가입 | `validInitialGroupMember`, `validInvitedGroupMember`, `validApprovedGroupMember`, `validJoinCodeGroupMember`의 필드·타입·초기 시각 검사를 공통 부분으로 정리. 생성자/가입자/승인자, 초대/신청/코드 증명과 차단 조건은 각 경로에 유지 | Rules 중심, 스키마 유지 | 생성·초대 수락·신청 승인·코드 가입 정상 경로 및 다른 경로로 위장·금지·타인·정원 초과 거절 |
| R2 Player 요약·목록 | 본인 가입과 그룹장 승인에서 반복되는 Group ID 1개 추가·중복·50개 제한·revision 검사를 공통화. 목록 Projection의 공통 스키마와 membership 일치 검사 정리 | Rules 중심, 스키마 유지 | 49→50 성공·50→51 실패, 동시 승인, 누락/위조 Projection, 기존 문서 없는 최초 생성 검증 |
| R3 파티·그룹 수정 | `affectedKeys().hasOnly()`와 개별 불변 비교의 중복을 함수별로 검토해 제거. 필수 필드 존재·허용 필드의 값 조건은 유지 | Rules 중심, 스키마 유지 | 허용 수정 성공, 필드 추가/삭제·역할·소유자 변조 거절. 각 함수의 적용 전후 허용 범위 비교 |
| R4 이벤트 | `validPlayerEvent` 및 신청·멤버·회차 이벤트의 공통 필드/시각/revision 검사를 정리. 단순 전달 함수·중복 분류를 축소 | Rules 중심, 이벤트 형식 유지 | 기존 이벤트별 수신자·발신자·연결 상태 검증. 타인 이벤트 삽입·재전송·위조 revision 거절 |
| R5 명령 대상 명시 | 앞 단계로 부족하면 그룹 승인·탈퇴·코드 관리에 명령 종류와 대상 ID를 명시하는 계약 초안 작성. 실제 변경과 원자적 연결 검증을 함께 설계 | Repository·Rules·명령 필드 변경 가능 | **설계 검토 후 별도 착수**. 명령 문자열만으로 권한 허용 금지. 인원만 변경·membership만 변경·요약 누락 등 부분 쓰기 차단 |
| R6 표시/권한 데이터 분리 | R5 이후에도 필요할 때만 membership 권한과 표시 Snapshot, 목록용 Projection 책임 재정의 | 문서 경로·조회·이행 작업 가능 | **설계 검토 후 별도 착수**. 기존 UX·오프라인 표시·조회 비용·기존 데이터 이행 계획 확보 |

### 공통 구현 원칙

- 현재 바로 시작할 단위는 **R0**, 다음은 R1이다. 한 번에 R1~R6을 모두 구현하지 않는다.
- 공통 함수 추출, OR 분기 순서 조정, 코드 줄 수 감소가 컴파일 크기 감소를 보장하지 않는다. 결과를 비교해 효과가 없으면 근거와 함께 해당 변경을 재검토한다.
- 상태·명령 종류·필드 집합으로 경로를 먼저 구분하고 필요한 문서만 읽는 방향을 검토한다. 기존 문서 누락 시 거절 의미와 OR의 다른 정상 경로를 훼손하지 않는다.
- 권한 검사를 클라이언트로 옮기거나 `signedIn()`만 남겨 축소하지 않는다. 파일 분할·주석 제거는 가독성 작업이지 핵심 해법이 아니다.
- UI/UX, Player 단위 그룹 소속, 본·부계정 사용, 50명/50개 제한, 초대·신청·코드 가입, 신청 금지·횟수, 반복 레이드·주간 Claim·운영자 인증 정책을 보존한다.
- 인증/캐릭터의 광범위한 쓰기 권한과 그룹 탈퇴의 변경 전 membership·요약 결합 누락은 별도 보안 보완으로 추적한다. 단순화 과정에서 이 문제를 더 넓히거나 해결됐다고 기록하지 않는다.
- 함수 중복 제거로 접근 한도를 맞추기 위해 원자성 검증을 삭제하지 않는다. 반대로 단순화와 무관한 보안 정책 변경도 같은 커밋에 섞지 않는다.
- 기능을 `false`로 막은 실험 Rules는 로컬 또는 격리된 검사에만 사용한다. 운영 프로브 배포는 금지한다.
- 향후 운영 배포는 해당 시점의 사용자 명시 지시 후 실행한다. 이전 배포 지시를 후속 자동 배포 권한으로 재사용하지 않는다.

### 단계별 작업 기록 양식

각 단계 종료 시 아래 항목을 이 문서 후속 절과 DEV_LOG에 남기고, NEXT_WORK는 다음 단일 작업을 가리키도록 갱신한다.

```text
단계 / 브랜치 / 시작 커밋:
변경 파일·함수:
기존 검증 → 변경 검증 및 동등성 근거:
앱·데이터·UX 영향:
소스 크기 전후 / 컴파일 결과(미측정은 미측정):
정상·거절·경쟁 조건 테스트와 미실행 항목:
배포 여부 / 실패 단계 / 운영 반영 여부:
남은 문제 / 다음 단계 / 결과 커밋:
```

문서 커밋의 자기 해시는 작성 시점에 확정되지 않으므로 Git 이력으로 식별한다. 첫 구현 단계 시작 시 이 문서 커밋의 실제 HEAD를 기록하고, 기준 코드 25f88ff와 구분한다.

### 검증 게이트와 복구

- 해당 단계의 정상·거절 경로를 Rules Emulator에서 확인하고, 표적 Flutter 테스트·관련 정적 분석·`git diff --check`를 수행한다. 문자열 계약 테스트만으로 Rules 동작 검증을 대체하지 않는다.
- 테스트 환경이 막히면 문서나 검토용 중간 커밋은 가능하지만 **검증 미완료**로 표기하고 다음 대규모 변경·배포 성공 선언을 하지 않는다.
- 기능 보존 완료는 전체 Rules 컴파일, 허가된 배포의 성공, 핵심 다중 사용자 경로 확인까지 필요하다. 503이 사라졌다는 이유만으로 보안 검증을 통과 처리하지 않는다.
- 변경 복구는 단계 커밋 단위로 검토한다. 사용자 작업·백업을 덮어쓰거나 main을 강제 초기화하지 않는다. 운영 복구가 필요하면 마지막 성공 release를 확인하고 별도 승인 후 실행한다.

## 요약

Task-11a(멤버 목록·탈퇴·표시 Snapshot) 코드는 `main`에 보존됐다. 다만 **Rules를 정상 배포할 수 있을 때까지** 해당 Rules·실기기 검증은 열린 부채다.

원인은 Rules 문법 오류가 아니라 **단일 `firestore.rules` 파일의 컴파일/업로드 복잡도 한도**에 가깝다.

- 전체 Rules (~159KB, ~3470줄): `firebase deploy --only firestore:rules` 시 **503** (사용자 재확인)
- 약 **47.9%**로 함수 본문을 `return false` 스텁으로 줄인 프로브 (~76KB): **compile + release 성공** (~13초)

즉, Task-11 leave·Snapshot refresh 등 **최근 Rules 추가분이 문법만 맞다고 배포가 보장되지 않는다.**

## 2026-08-31 검증 절차 (재현)

1. 원본 `firestore.rules` 백업 (`legacy/firestore - 복사본.rules` 등 사용자 로컬 사본 권장)
2. 경로 helper·`match` 블록은 유지, 검증 함수 본문 약 **101개**를 `return false` 스텁으로 축소
3. `firebase deploy --only firestore:rules --project lost-party`
4. **Deploy complete** 확인

프로브는 **운영에 그대로 두면 안 됨**. 정상 Rules 복구 배포 전까지 그룹·파티·Claim 등 쓰기가 대부분 막힌다.

## 정상 복구 시도 (사용자)

로컬 **전체 원본** `firestore.rules`로 되돌린 뒤:

```powershell
firebase deploy --only firestore:rules --project lost-party
```

→ **503 재현**. 업로드 대상은 복원된 전체 파일이 맞으나, 복잡도 한도로 release 실패. 운영은 직전 성공분(프로브)이 유지된다.

## 추정 원인

- 단일 파일에 파티·Claim·운영자·수동 인증·**그룹 membership 전체** Rules가 누적
- 그룹 leave 경로의 `removedActiveGroupId` chunk helper 등 **중첩·분기·OR 평가**가 컴파일 비용을 키움
- Firebase Rules API는 파일 크기·식 복잡도 한도를 공개하지 않으나, **절반 축소 시 성공**으로 복잡도 병목이 거의 확실함

## 수정 방향 (재설계 후 구현)

1. **Rules 분할·중복 제거**
   - 그룹 전용 helper를 최소화하고 OR 체인 순서·중복 `get()` 제거
   - `removedActiveGroupIdChunk*` 등 chunk helper 단순화 또는 데이터 모델 쪽으로 이동 검토
2. **배포 가능 크기 목표**
   - 프로브 성공선(~76KB)보다 여유 있게, **전체 기능을 유지한 채** compile + deploy 성공을 반복 확인
3. **증분 배포 전략**
   - 한 번에 큰 diff를 올리지 않고, 기능 단위로 Rules 변경·배포·실기기 확인
4. **계약 테스트 유지**
   - `test/features/group/data/group_rules_contract_test.dart` 등 문자열 고정 테스트를 리팩터 후에도 갱신

## Task-11a와의 관계

| 항목 | 코드 (`main`) | Rules 배포 |
| --- | --- | --- |
| 일반 멤버 탈퇴 | 구현됨 | leave Rules 포함, **전체 deploy 실패로 미반영** |
| 멤버 표시 Snapshot | 구현됨 | create/join + **self refresh update** 포함, 미반영 |
| 그룹원 목록·상세 UI | 구현됨 | 읽기 Rules는 기존 Task-11과 동일 전제 |

재설계 후: **Rules 축소·배포 성공 → Task-11a 실기기 재검증** 순서를 권장한다.

## 2026-08-31 후속 — Rules만 1차 축소, 배포 미실행

- 사용자 지시로 원본을 `legacy/firestore.before-complexity-20260831.rules.bak`에 별도 복사하고 SHA-256 일치를 확인했다. 기존 사용자 사본은 수정하지 않았다.
- `removedActiveGroupId`의 5개 chunk 및 50개 위치 탐색을 Firebase Rules 기본 `List.removeAll()`로 대체했다. 제거 결과가 정확히 하나일 때만 `[0]`에 접근한다.
- 앱 요청·Firestore 저장 스키마·나머지 권한 검사는 변경하지 않았다. 오래된 생성 스크립트와 템플릿도 같은 native helper로 맞춰 재생성 시 복잡도가 돌아오지 않게 했다.
- 실제 파일 크기: 158,836 → 144,042 bytes (약 9.3% 감소). 컴파일 결과 크기 감소를 측정한 값은 아니다.
- 표적 Flutter 테스트 32개 통과. Emulator 테스트에 50개 그룹의 chunk 경계 10개 위치 탈퇴와 두 ID 제거·변경 없음·ID 삽입 거절을 추가했다.
- 전체 Rules의 Emulator 로딩은 `503 / Network closed for unknown reason`으로 실패했다. 최소 deny-all Rules 대조 검사도 동일하게 실패해 로컬 검증 환경 문제를 별도로 남긴다. 동작 테스트는 시작되지 않았으며, 이 실패를 수정 Rules 복잡도의 증거로 사용하지 않는다.
- 서버 배포·운영 데이터 변경·커밋은 하지 않았다. 배포 성공과 실기기 정상 작동은 미확인이다.
- 공식 연산: https://firebase.google.com/docs/reference/rules/rules.List#removeAll

## 2026-08-31 복잡도 개선 브랜치 커밋 범위

- 브랜치: `codex/rules-complexity-reduction` (main과 분리).
- 위 native 탈퇴 탐색 축소와 표시 Snapshot 갱신 중복 제거만 포함한다. 앱 코드·요청·저장 스키마 변경 없음.
- 표시 갱신의 11개 개별 불변 비교를 기존 `affectedKeys().hasOnly()`로 통합했다. `oldData.keys().hasAll()`로 필수 필드 누락도 계속 거절한다. 호출자·Player/Group ID·직업·숫자 타입·서버 시각 검증은 유지한다.
- 최종 Rules 소스: 143,799 bytes. 백업 158,836 bytes 대비 약 9.5% 감소이며 컴파일 결과 크기는 미측정이다.
- 최종 표적 Flutter 테스트 33개 통과. 정적 문자열 계약·쓰기 계획 검증이며 실제 Rules 허용/거절 검증을 대체하지 않는다.
- 보호 필드 변경·삭제, 새로운 권한 필드 삽입, 타인의 Snapshot 갱신 거절 시나리오를 Emulator 스크립트에 추가했다. Emulator 로딩 환경 문제로 실행 통과를 주장하지 않는다.
- 그룹 탈퇴 전 membership 존재 검증, 요약 변경의 원자적 결합 검증, 계정·캐릭터 쓰기 권한 축소는 별도 보안 보완 작업이다. 이번 최적화로 해결됐다고 간주하지 않는다.
- 백업 2개는 로컬 보존하고 커밋 대상에서 제외한다. 배포·main 병합·푸시는 이번 지시에 포함하지 않는다.

### 관련 문서

- 실행 지시: [`NEXT_WORK.md`](NEXT_WORK.md)
- 작업 이력: [`DEV_LOG.md`](DEV_LOG.md) — Task-11a·Rules 프로브 항목
- 그룹 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)
