# 기존 서비스 발췌 — docs/README.md

원본 문서: docs/README.md ([현재 문서](../../../../docs/README.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 156f109e1f5c818bd76b720197f371eca3f4b26b8af733ba72af6c2c4a4e4515.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 이번 변경과 테스트 안내

출처: docs/README.md · 원본 11~11행 · 원문 절: ## 이번 변경과 테스트 안내.

- [원정대 재인증 변경 안내](../../../../docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md): 사용자 관점의 새 기능과 Rules 변경 근거. 테스트 목록은 채팅에서 안내.

<a id="source-0002"></a>

## 발췌 2: ## 문서 읽는 순서

출처: docs/README.md · 원본 24~24행 · 원문 절: ## 문서 읽는 순서.

위 문서는 선택 참고가 아니라 수정 전 필수 확인 순서다. 저장소 루트의 `AGENTS.md`가 이 순서를 자동 작업 절차로 규정한다. Firestore Rules 변경 시에는 `project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md`와 관련 Rules 계약 테스트까지 확인하고, 실제 기능 브랜치가 생성됐는지 `git branch --show-current`로 검증한 뒤 작업한다.

<a id="source-0003"></a>

## 발췌 3: ## Architecture

출처: docs/README.md · 원본 46~46행 · 원문 절: ## Architecture.

- [운영 Rules 전체 구조 재설계](../../docs/architecture/RULES_PRODUCTION_RESTRUCTURE_DESIGN.md): §14 B1+A2 전체 기능본 테스트 게시 성공·활성SHA일치. 그룹 표시 검증 로컬 이전/중복 분기 통합 완료, 운영 lost-party도 14:17 KST 게시 성공·활성SHA일치. 실기기 인수 대기.

<a id="source-0004"></a>

## 발췌 4: ## Architecture

출처: docs/README.md · 원본 48~48행 · 원문 절: ## Architecture.

- [전체 Rules 세 방향 간소화 설계](../../docs/architecture/RULES_SIMPLIFICATION_THREE_TRACK_DESIGN.md): 최신 후속 설계. 중복 검사·표시 로컬 이전·호출 단순화, 기존 기능/부작용/회귀와 구간별 범위. 사용자 요청으로 구간별 수정 중단·보존. 게시 정상화 미완료; 중단 체크포인트 참조.

<a id="source-0005"></a>

## 발췌 5: ## Architecture

출처: docs/README.md · 원본 50~50행 · 원문 절: ## Architecture.

- [Rules 책임 축소·로컬 이전 실행 계획](../../docs/architecture/RULES_LOCALIZATION_EXECUTION_PLAN.md): 현재 실행 기준. 감소율 목표 없이 작은 단위별로 진행한다. 3-2 로컬 완료. 운영 게시1회는 컴파일 성공 후 활성화400/CLI fallback409로 실패, 기존 활성본 유지. 현재 순서는 NEXT_WORK를 따른다.

<a id="source-0006"></a>

## 발췌 6: ## Architecture

출처: docs/README.md · 원본 52~52행 · 원문 절: ## Architecture.

- [Firestore Rules 대폭 축소 설계](../../docs/architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md): Spark 무료 유지와 양·복잡도·깊이 축소. C1 로컬 기준, D 조건부 후보는 누적4.35% 감소로 목표 미달. 단일 명단 설계(§36), 완료(§37), 생성·참가(§38), 캐릭터/역할 변경(§39), 재배치 호환(§40). 개인완료/마지막1인 통합(§41). 전체완료 상태 통합(§42), 준비 변경 기본 경계331건 검증(§43), 준비 배치 추가25건(§44), 인증/advance414건 검증(§45), 인증 stub 참가 교체463건 검증(§46), Claim 결합 후보520건 검증·동시 요청1건 미완료(§47), 원인 분리 조사 완료·운영 동시성 미확인(§48), 일반 변경 대상 stub 교체572건 검증(§49), active 개인완료 인증 보존39건·누적611건(§50), 파티 밖 stub 수동완료681건 검증(§51), 다음 일반 수동완료 생성·이전 소유 차수 교체, 전체 D-X1 진행 중. 운영 게시·최종 인수 미완료.

<a id="source-0007"></a>

## 발췌 7: ## Architecture

출처: docs/README.md · 원본 54~54행 · 원문 절: ## Architecture.

- [완료 반복방의 다음 주 캐릭터 변경 설계](../../docs/architecture/RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md): BUG-024 원인·완료 기록 보존·준비 변경/전환 경계. Spark C 제한 회귀 통과 후 원격 활성화400으로 운영 반영 보류.

<a id="source-0008"></a>

## 발췌 8: ## Architecture

출처: docs/README.md · 원본 55~55행 · 원문 절: ## Architecture.

- [반복방 서버 트랜잭션 후속 설계](../../docs/architecture/RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md): 준비 변경·주차 전환의 서버 권한, 원자성, 재진입과 전환 순서. Spark 무료 유지 결정으로 중단한 대안.

<a id="source-0009"></a>

## 발췌 9: ## Architecture

출처: docs/README.md · 원본 57~57행 · 원문 절: ## Architecture.

- [반복방 Spark 무료 대안 재설계](../../docs/architecture/RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md): 현재 실행 기준. C 상태 확장 상세 설계·격리된 8인 선행 검증25/25 통과. 앱 호환 구현·운영 도입은 남음.

<a id="source-0010"></a>

## 발췌 10: ## Architecture

출처: docs/README.md · 원본 59~59행 · 원문 절: ## Architecture.

데이터 관계, Firebase 전환 및 백엔드 구조를 관리한다.

<a id="source-0011"></a>

## 발췌 11: ## Architecture

출처: docs/README.md · 원본 61~61행 · 원문 절: ## Architecture.

- [`architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`](../../docs/architecture/FIREBASE_PARTY_PRODUCT_FLOW.md): Firebase 파티 제품 흐름의 최신 통합 기준

<a id="source-0012"></a>

## 발췌 12: ## Architecture

출처: docs/README.md · 원본 62~62행 · 원문 절: ## Architecture.

- [`architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../../docs/architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md): 인증 게임 계정·Character 서버 ID와 최소 정보 동기화 계약

<a id="source-0013"></a>

## 발췌 13: ## Architecture

출처: docs/README.md · 원본 68~68행 · 원문 절: ## Architecture.

- [`architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md`](../../docs/architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md): Player 식별자와 Firebase 전환 영향 검토

<a id="source-0014"></a>

## 발췌 14: ## Architecture

출처: docs/README.md · 원본 69~69행 · 원문 절: ## Architecture.

- [`architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../../docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md): 파티 목록·현황 읽기와 오프라인 상태 계약

<a id="source-0015"></a>

## 발췌 15: ## Architecture

출처: docs/README.md · 원본 70~70행 · 원문 절: ## Architecture.

- [`architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../../docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md): Spark Firestore 파티 명령과 Rules 계약

<a id="source-0016"></a>

## 발췌 16: ## Architecture

출처: docs/README.md · 원본 71~71행 · 원문 절: ## Architecture.

- [`architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md`](../../docs/architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md): Player 이벤트와 Drift 로컬 히스토리 계약

<a id="source-0017"></a>

## 발췌 17: ## Architecture

출처: docs/README.md · 원본 72~72행 · 원문 절: ## Architecture.

- [`architecture/PARTY_NOTIFICATION_CONTRACT.md`](../../../../docs/architecture/PARTY_NOTIFICATION_CONTRACT.md): Spark 앱 내부 알림과 향후 FCM의 공통 파티 이벤트 계약

<a id="source-0018"></a>

## 발췌 18: ## Architecture

출처: docs/README.md · 원본 75~75행 · 원문 절: ## Architecture.

- [`architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../../docs/architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md): Task-11 그룹 생성·Player 단위 가입·초대코드와 Rules 계약

<a id="source-0019"></a>

## 발췌 19: ## Architecture

출처: docs/README.md · 원본 79~79행 · 원문 절: ## Architecture.

- [`architecture/BUG_022_REMAINING_FIX_DESIGN.md`](../../docs/architecture/BUG_022_REMAINING_FIX_DESIGN.md): BUG-022 미완료 재가입·재설치 복구·원정대 이전을 Spark 범위에서 분리한 실행 설계

<a id="source-0020"></a>

## 발췌 20: ## Integrations

출처: docs/README.md · 원본 86~86행 · 원문 절: ## Integrations.

- [`integrations/FIREBASE_INITIAL_SETUP_REVIEW.md`](../../docs/integrations/FIREBASE_INITIAL_SETUP_REVIEW.md): Firebase 프로젝트와 플랫폼 초기 연결 확인
