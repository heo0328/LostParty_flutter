# 원정대 Rules 게시 실패 분석 — 2026-10-03

## 현재 결론

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
