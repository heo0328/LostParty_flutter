# 기존 서비스 발췌 — AGENTS.md

원본 문서: AGENTS.md ([현재 문서](../../../AGENTS.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 1c45697e928fb33f624708a3f2da51b9dd27120d915265df6605dd173e0a1958.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 2. 구현 전 설계와 기존 기능 보호

출처: AGENTS.md · 원본 23~23행 · 원문 절: ## 2. 구현 전 설계와 기존 기능 보호.

- 관련 Repository, Domain 정책, Validator, Write Plan과 Rules의 `get/list/write` 순서를 확인한다. 기존 정책을 새 조건문으로 중복 구현하지 않는다.

<a id="source-0002"></a>

## 발췌 2: ## 4. 검증과 완료 판정

출처: AGENTS.md · 원본 68~68행 · 원문 절: ## 4. 검증과 완료 판정.

- 중간 단계마다 전체 테스트를 반복하지 않는다. 기본 확인은 포맷, `git diff --check`와 diff 검토이며 자동 검증은 실기기로 확인하기 어려운 Security Rules 권한·위조 요청·동시성·원자성·최대 인원 경계에 제한한다.

<a id="source-0003"></a>

## 발췌 3: ## 5. Firestore Rules와 배포

출처: AGENTS.md · 원본 76~86행 · 원문 절: ## 5. Firestore Rules와 배포.

## 5. Firestore Rules와 배포

- Rules를 수정할 때만 `legacy/firebase/docs/project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md`, 관련 계약 문서와 Rules 계약 테스트를 추가로 확인한다.
- 배포 전 현재 브랜치, 실제 diff, `firebase.json`의 Rules 경로와 대상 Firebase 프로젝트를 다시 확인한다.
- Rules가 변경된 기능 섹션은 로컬 테스트·정적 분석·Rules 계약 검사를 통과한 최신 추적본만 실제 운영 프로젝트에 정확히 한 번 배포 시도한다. Rules가 바뀌지 않았으면 배포하지 않는다.
- 기본 절차에서 dry-run과 실제 배포를 연속 실행하지 않는다. 사용자가 원격 컴파일만 요청한 경우에만 dry-run 한 번으로 대체한다.
- 첫 배포 실패 시 같은 명령을 즉시 반복하거나 정상 기능을 추측으로 삭제·완화하지 않는다. 실패 단계(`/test`, `/rulesets`, `/releases`), 컴파일 경고, 콘솔 활성 소스, 직전 성공본과 diff를 조사해 보고한다.
- 실패 후 재배포는 사용자가 진단 결과를 확인하고 새로 지시한 경우에만 한 번 수행한다.
- Rules 컴파일 경고 0개를 완료 조건으로 삼고 배포 결과와 활성 소스 확인 상태를 문서에 기록한다.
- Indexes, Functions, Hosting 등 Rules 이외 Firebase 배포는 사용자의 현재 시점 명시 지시가 있을 때만 수행한다.
