# 기존 서비스 발췌 — docs/product/PARTY_PARTICIPATION_RULES.md

원본 문서: docs/product/PARTY_PARTICIPATION_RULES.md ([현재 문서](../../../../../docs/product/PARTY_PARTICIPATION_RULES.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 1ac3bdbb9dbe3eb51b89bd4fc6bd7a8a8765d1ad38babfb67326ae7d4a7691d4.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 목적과 용어

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 7~7행 · 원문 절: ## 1. 목적과 용어.

반복 파티, 회차 완료·취소·해산, 알림 및 개인 레이드 히스토리의 최신 기준은 `../architecture/FIREBASE_PARTY_PRODUCT_FLOW.md`를 따른다. 개인 주간 완료와 참가 제한의 최종 계약은 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../../../../../docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)가 우선한다.

<a id="source-0002"></a>

## 발췌 2: #### 스왑

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 143~143행 · 원문 절: #### 스왑.

초기 구현 권장은 `pending 취소 후 변경`을 먼저 제공하고, 확정 파티 간 `이동`과 `스왑`은 Firebase 트랜잭션과 탈퇴 정책이 준비된 뒤 별도 작업으로 구현하는 것이다.

<a id="source-0003"></a>

## 발췌 3: ## 7. 테스트 원칙

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 182~182행 · 원문 절: ## 7. 테스트 원칙.

- Firebase 연결 전 로컬 테스트는 Domain, Repository 및 Widget 자동화 테스트로 검증한다.

<a id="source-0004"></a>

## 발췌 4: ## 7. 테스트 원칙

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 183~183행 · 원문 절: ## 7. 테스트 원칙.

- 승인 화면의 실제 다중 사용자 실기기 검증은 Firebase Authentication과 서버 명령 연결 후 진행한다.

<a id="source-0005"></a>

## 발췌 5: ## 8. 로컬 Domain 구현 상태

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 203~203행 · 원문 절: ## 8. 로컬 Domain 구현 상태.

- 로컬 저장 충돌 시 먼저 획득한 점유를 해제하는 보상 처리를 사용하며 Firebase에서는 Aggregate, 점유 및 pending 종료를 하나의 서버 트랜잭션으로 처리해야 함

<a id="source-0006"></a>

## 발췌 6: ## 8. 로컬 Domain 구현 상태

출처: docs/product/PARTY_PARTICIPATION_RULES.md · 원본 213~213행 · 원문 절: ## 8. 로컬 Domain 구현 상태.

- 다른 확정 파티 사이의 이동·스왑은 Firebase 서버 트랜잭션 단계에서 구현
