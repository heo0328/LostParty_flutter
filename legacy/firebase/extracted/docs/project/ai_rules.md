# 기존 서비스 발췌 — docs/project/ai_rules.md

원본 문서: docs/project/ai_rules.md ([현재 문서](../../../../../docs/project/ai_rules.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 3cd90340cfd6f268f1e9a46a56e030571aa1224634273df137920bd3c6bc8d52.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 8. Task Execution Rules

출처: docs/project/ai_rules.md · 원본 141~141행 · 원문 절: ## 8. Task Execution Rules.

- Firebase Rules가 변경된 기능 섹션은 로컬 테스트·정적 분석·Rules 계약 검사를 마친 뒤 **AI가 최신 추적본을 실제 운영 프로젝트에 정확히 1회 배포 시도**한다. 배포 전 현재 브랜치, `firebase.json`의 Rules 경로, diff와 대상 프로젝트를 다시 확인한다.

<a id="source-0002"></a>

## 발췌 2: ## 8. Task Execution Rules

출처: docs/project/ai_rules.md · 원본 145~145행 · 원문 절: ## 8. Task Execution Rules.

- Rules가 바뀌지 않은 기능은 배포하지 않는다. Indexes·Functions·Hosting 등 Rules 이외 Firebase 배포는 계속 사용자의 현재 시점 명시 지시가 있을 때만 수행한다.

<a id="source-0003"></a>

## 발췌 3: ## 8. Task Execution Rules

출처: docs/project/ai_rules.md · 원본 146~146행 · 원문 절: ## 8. Task Execution Rules.

- Firebase 콘솔에서 복사한 Rules Snapshot은 배포 원본으로 사용하지 않는다. `firebase.json`이 지정한 추적 파일과 행·내용을 먼저 비교하고 Snapshot은 `.gitignore`된 로컬 대조 자료로만 보존한다.

<a id="source-0004"></a>

## 발췌 4: ## 8. Task Execution Rules

출처: docs/project/ai_rules.md · 원본 147~147행 · 원문 절: ## 8. Task Execution Rules.

- Rules의 `map`·`string` 인자에 문서 부재를 뜻하는 `null` sentinel을 전달하지 않는다. 생성·수정 경로는 이전 목록·revision·시각 등 실제 타입 값을 명시적으로 전달하고, nullable 반환 대신 존재 여부와 소유 여부를 boolean으로 판정한다.

<a id="source-0005"></a>

## 발췌 5: ## 8. Task Execution Rules

출처: docs/project/ai_rules.md · 원본 149~149행 · 원문 절: ## 8. Task Execution Rules.

- 503만으로 특정 기능이나 Rules 복잡도를 원인으로 단정하거나 정상 기능을 제거하지 않는다. 동일 소스의 컴파일 결과, 콘솔 게시본과 로컬 원본 비교, 실패 단계(`test`/`rulesets`/`releases`)를 확보한 뒤 수정한다.

<a id="source-0006"></a>

## 발췌 6: ### 1단계: 구현 전 검토와 작업 분해

출처: docs/project/ai_rules.md · 원본 179~179행 · 원문 절: ### 1단계: 구현 전 검토와 작업 분해.

- 코드·문서 수정 전에 루트 `AGENTS.md`와 `docs/project/ai_rules.md`를 처음부터 끝까지 읽고, `NEXT_WORK.md`, `AI_CONTEXT.md`, `docs/README.md` 및 작업 영역의 제품·아키텍처 계약 문서를 확인한다. Rules를 건드리는 작업은 `TASK-11-FIRESTORE-RULES-COMPLEXITY.md`의 최신 상태와 해당 Rules 계약 테스트도 반드시 확인한다.

<a id="source-0007"></a>

## 발췌 7: ### 기존 기능 회귀 방지 게이트

출처: docs/project/ai_rules.md · 원본 193~193행 · 원문 절: ### 기존 기능 회귀 방지 게이트.

- 실제 앱 연결은 단위 서비스 테스트만으로 완료 처리하지 않는다. 라우터/DI가 운영 Repository와 실제 Player 식별자를 연결하는지, Security Rules가 허용하는 조회 방식인지 함께 확인한다.

<a id="source-0008"></a>

## 발췌 8: ### 3단계: 최종 검증

출처: docs/project/ai_rules.md · 원본 222~222행 · 원문 절: ### 3단계: 최종 검증.

- 실기기에서 같은 결과를 직접 관찰할 수 있는 정상 UI·UX 흐름은 사용자 수동 검증으로 갈음하고 동일 자동 UI·통합 테스트를 중복 실행하지 않는다. 자동 검증은 Security Rules 권한·위조 요청·동시성·원자성·최대 인원처럼 실기기로 재현하기 어렵거나 안전하지 않은 경계에 집중한다.

<a id="source-0009"></a>

## 발췌 9: ### 테스트 실행 최소화 원칙

출처: docs/project/ai_rules.md · 원본 260~292행 · 원문 절: ### 테스트 실행 최소화 원칙.

```text
각 작업 구간 구현 중
→ 테스트 코드는 함께 작성
→ 코드 포맷 + git diff --check + 변경 검토
→ 자동/디바이스 테스트는 실행 대기
→ 기능 브랜치 체크포인트 커밋·푸시

하나의 기능 섹션 구현 완료
→ 실기기로 확인할 수 없는 서버·정책 경계 테스트만 한 번 실행
→ 인원수 확장은 최대 8인 대표 사례 1건만 실행
→ 필요한 경우에만 변경 파일 flutter analyze 1회
→ 영향 범위가 넓을 때만 전체 flutter test 1회

실패 발생
→ 실패 테스트와 직접 영향 테스트만 수정·재실행
→ 전체 묶음 반복 실행 금지

배포·실기기 확인
→ Rules 변경 시 AI가 최신 추적본을 실제 배포로 정확히 1회 시도
→ 첫 실패 시 반복·추측 수정 금지, 실패 단계·콘솔 게시본·diff 조사
→ 재시도는 사용자의 새 지시 후 1회
→ Rules 외 Firebase 배포는 사용자의 명시 지시 필요
→ 기능 섹션 전체 디바이스 체크리스트 1회
→ 실기기로 확인한 정상 UX와 같은 자동 UI·통합 테스트는 생략
→ 동일 코드 상태에서 이미 통과한 검증은 재사용
→ 문서 최신화
→ 단순 작업: 작업 브랜치 로컬 커밋
→ 단계 작업: 완료한 피처 단위마다 작업 브랜치 커밋 및 원격 푸시
→ 현재 구간 최종 테스트·문서 정리 후 dev 직접 병합
→ dev만 원격 푸시
→ 로컬/원격 dev 최신화 확인
→ 페이지·큰 기능 단위 완료 시 dev를 main에 병합하고 main 푸시
```

<a id="source-0010"></a>

## 발췌 10: ### 중간 테스트 실행 예외

출처: docs/project/ai_rules.md · 원본 297~297행 · 원문 절: ### 중간 테스트 실행 예외.

- 인증·소유권·데이터 삭제·Security Rules처럼 잘못된 기반 위에 후속 작업을 쌓으면 복구 비용이 큰 경우
