# 원정대 Rules 게시 실패 분석 — 2026-10-03

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
