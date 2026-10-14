## 제안 목적

요청 출처: Flutter Codex / 사용자 승인. 다음 Flutter 작업인 **서버 계정 등록 관리 연결**을 시작하기 전에, 해당 구간의 Backend 준비·실제 API 검증·발견된 차이 보완·인계를 별도 이슈로 추적할 것을 제안합니다.

선행 이슈: https://github.com/heo0328/lostparty-backend/issues/3
기존 준비 요청: https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6161970774
최신 구현 인계: https://github.com/heo0328/lostparty-backend/issues/3#issuecomment-6162243552

## 이미 완료된 기준

- Backend 계약 SHA: `254cb5de125ab1bcb2aa084e091eae976e9a078a`.
- Backend 보완 구현 SHA: `db0f3ae438021b4f5fa3738b76fd926687871b0d`, 게시 기록 `f5b4a2a`, 작업 브랜치 `feat/3-account-restoration`. lease 만료/generation 인계 거절의 `409 REQUEST_IN_PROGRESS`에도 `Retry-After: 2`를 반환하는 보완은 완료됐습니다. 이 수정을 다시 요청하지 않습니다.
- 기존 계약 경로/DTO는 유지됐으며 준비·대상 회귀 10개 통과/106개 미실행과 로컬 적용은 Backend 보고입니다. 이전 전체 114개 통과 결과와 구분합니다.
- 최신 Backend 보고상 DB revision은 `0002_game_accounts`, 서버 키는 미설정입니다. health 성공을 외부 API 키 유효성이나 실제 등록 인수 완료로 해석하지 않습니다.
- Flutter `heo0328/LostParty_flutter` dev `69d3aaa8df63b7db19b1660d0fe6b2a6295fa1bc`: Google 로그인·서버 등록/캐릭터 GET 연결 완료, 사용자 로그인 빈 목록/로그아웃 안내·로컬 화면 보존 확인. 메인 계정 → 부계정 → 계정 도구 디자인 유지 확정. 서버 등록 쓰기 UI는 아직 미연결입니다.

## 다음 Flutter 연결 범위

| 흐름 | 재사용할 기존 API |
|---|---|
| 캐릭터 검색·미리보기 | `POST /v1/game-accounts/preview` |
| 메인/부계정 등록 | `POST /v1/me/game-accounts` |
| 등록 목록·캐릭터 확인 | `GET /v1/me/game-accounts`, `GET /v1/me/game-accounts/{registration_id}/characters` |
| 표시명·본계정 변경 | `PATCH /v1/me/game-accounts/{registration_id}` |
| 요약 갱신 | `POST /v1/me/game-accounts/{registration_id}/refresh` |
| 등록 제거 | `DELETE /v1/me/game-accounts/{registration_id}` |

기존 API 재개발이나 새 endpoint 추가를 기본 요구로 두지 않습니다. 원본 OpenAPI의 body·Idempotency-Key·expected_version·DELETE query·refresh 빈 object 규칙을 소비합니다. preview/등록은 게임 계정 소유 인증이나 활동 자격 생성이 아닙니다.

## Backend 후속 작업 제안

1. **현재 준비 상태 인계**: 계약/구현/실행 버전과 migration 상태, 즉시 시험 가능한 API와 제한을 정리해 주세요. #3에서 이미 확보한 근거를 재사용하며 버전이나 환경이 바뀌었을 때만 추가 확인합니다. 공개 계약의 변경 유무를 명시해 주세요.
2. **서버 키의 안전한 로컬 준비 지원**: `LOSTARK_API_TOKEN`은 사용자가 Backend 로컬 환경에서 설정합니다. 기존 `docs/ISSUE_3_REGISTRATION_FOLLOWUP_PLAN.md`의 설정·API 환경 적용 절차를 인계하고 준비 여부만 값 없이 기록해 주세요. 키·Bearer·Google proof·`.env` 본문은 게시하지 않습니다. 키 미준비의 외부 조회 `503 UPSTREAM_UNAVAILABLE`는 예상 제한이며 Flutter UI 구현을 막는 사유로 두지 않습니다.
3. **실제 캐릭터 응답 검증**: 키 준비와 사용자의 시험 대상 준비 후 실제 siblings/summary의 필드/타입·nullable 수치·중복·입력 캐릭터 존재·상한을 기존 adapter와 대조해 주세요. 실제명·개인정보/raw 응답을 게시하지 않고 식별정보를 제거한 필드 형태와 기대/실제 결과만 인계해 주세요. 근거가 일치하면 변경 없이 통과 처리하고 차이가 발견된 parser/오류 처리만 보완합니다.
4. **등록 관리 공동 인수 지원**: Flutter UI 연결 후 사용자 명시 동작으로 검색 → 등록 → 두 조회 → 표시명/본계정 전환 → refresh → 등록 제거 → 재조회를 확인합니다. 같은 key/payload 재전송과 DELETE204 replay·version409·진행중409/Retry-After·429/503·응답 유실 복구는 기존 격리 테스트 근거와 실제 관찰을 구분합니다. 정상 화면 인수를 위해 개발 DB에 등록/소유권 fixture를 삽입하지 않습니다.
5. **재현된 차이 보완·게시 인계**: 동작/기대·실제/HTTP status/error.code/request_id를 근거로 해당 등록·조회 흐름에 직접 필요한 부분만 수정합니다. 변경 시 구현 SHA·원본 OpenAPI/계약 유지 또는 변경 요약·실행한 대상 회귀를 게시해 주세요. 오류가 없다면 추가 구현 없이 준비/실검증 결과를 인계하면 됩니다. 기존 Google 인증6API와 두 조회 API를 보존합니다.

## 역할과 완료 조건

- Flutter: 승인된 디자인을 유지하며 등록 관리 UI/Repository와 동일 요청 복구·회원/세션 격리를 연결합니다. 이번 이슈 제안에서는 기능 구현을 시작하지 않습니다.
- Backend: 위 준비와 실제 provider 관찰, 재현된 서버 차이의 최소 보완 및 계약 인계를 담당합니다.
- 사용자: 서버 키를 로컬에서 준비하고 에뮬레이터/기기에서 명시적으로 등록·변경·제거를 시험합니다. 원격 데이터나 기기를 에이전트가 임의 조작하지 않습니다.
- 완료 조건: 버전/실행 환경과 키 준비 상태(값 제외), 실검증 결과와 미확인 제한이 기록되고, 사용자 등록 계정이 서버 GET에 나타나며 수정·갱신·제거 결과를 재조회로 확인합니다. Flutter 로컬 캐릭터/빌드 자료 보존 결과는 Flutter 인수로 별도 기록합니다. 키/사용자 시험이 미준비면 Backend 독립 작업 완료와 실제 공동 인수 대기를 구분합니다.

## 제외·선행 이슈 관계

장비 challenge/소유권 이전과 활동·대표 저장 연결은 이후 별도 그룹입니다. `PROVIDER_EVIDENCE_PENDING`, `ROSTER_EVIDENCE_PENDING`, refresh 누락 suspect 보류는 유지합니다. 공개 mock/증거 우회·Firebase/테스터 자료 이관·개발 DB 초기화·운영 배포·dev/main 임의 병합은 제안 범위에 포함하지 않습니다.

이 이슈는 #3의 기존 등록 준비 요청을 다음 등록 구간의 추적 단위로 분리한 것입니다. 기존 준비/보완 완료 근거는 #3을 참조하고, 이후 해당 구간의 진행·결과는 새 이슈에 기록해 중복 작업을 피합니다. #3은 변경하거나 자동 종료하지 않습니다.
