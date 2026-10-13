# 기존 서비스 발췌 — docs/product/GROUP_PRODUCT_FLOW.md

원본 문서: docs/product/GROUP_PRODUCT_FLOW.md ([현재 문서](../../../../../docs/product/GROUP_PRODUCT_FLOW.md)). 분리일: 2026-10-13.
원본 전체 SHA256: d5a3d65b41cdda1edfc2340dc3fd57fd81aa578791cce797646f0d8a416ed67c.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 문서 상태

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 8~8행 · 원문 절: ## 1. 문서 상태.

- 제품 정책은 이 문서에서 관리하고 Task-11 구현 계약은 [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../../../docs/architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md)를 따른다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 문서 상태

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 13~13행 · 원문 절: ## 1. 문서 상태.

- 실기기(2026-09-01): 생성 후 파티장 `그룹만 공개` 전환. 비그룹 계정 모집에서 그룹 전용은 안 보이고, 해제하면 보이며, 다시 켜면 숨는다. Rules는 사용자가 배포했다.

<a id="source-0003"></a>

## 발췌 3: ### 7.2 요청 현황

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 160~160행 · 원문 절: ### 7.2 요청 현황.

이 숫자 배지는 별도 알림 기능이 아니라 현재 Firestore 요청 상태를 직접 표시한다.

<a id="source-0004"></a>

## 발췌 4: ### 9.2 단일 그룹 매칭 확정

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 241~241행 · 원문 절: ### 9.2 단일 그룹 매칭 확정.

- 2026-09-01 사용자 합의: `raidListings`는 원본 모집과 별도로 뒤늦게 맞추지 않고, 원본을 바꾸는 같은 Firestore Transaction에서 원자적으로 동기화한다. 그룹 전용 모집이 목록에 다시 나타날 수 있는 만석·회차 완료·다음 주 대기 상태라면 listing을 삭제하지 않고 최신 인원·자리·회차·상태 스냅샷을 유지한다. 방 해산처럼 되돌릴 수 없는 종료 또는 전체 공개 전환이면 listing을 삭제한다.

<a id="source-0005"></a>

## 발췌 5: ## 14. 그룹장 자격 상실과 승계

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 344~344행 · 원문 절: ## 14. 그룹장 자격 상실과 승계.

- 상세 Transaction·Rules·해산 조건은 [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../../../../../docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md)를 따른다.

<a id="source-0006"></a>

## 발췌 6: ## 16. 설계 원칙

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 364~364행 · 원문 절: ## 16. 설계 원칙.

- 그룹 기능 추가가 Firebase Rules나 기존 레이드 데이터 권한을 암묵적으로 확장하지 않도록 한다.

<a id="source-0007"></a>

## 발췌 7: ## 16. 설계 원칙

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 365~365행 · 원문 절: ## 16. 설계 원칙.

- Task-11 데이터 구조와 권한 정책은 분리된 기술 계약을 구현 기준으로 사용한다. 후속 그룹 관리 기능은 해당 범위의 계약을 작성하기 전에 기존 Rules 권한을 확장하지 않는다.

<a id="source-0008"></a>

## 발췌 8: ### 18.8 운영과 안전

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 462~462행 · 원문 절: ### 18.8 운영과 안전.

- Firebase Rules에서 필요한 최소 읽기·쓰기 권한

<a id="source-0009"></a>

## 발췌 9: ### 포함

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 471~471행 · 원문 절: ### 포함.

- 내 그룹 목록·그룹 검색·기본 상세 조회(공개 필드). **그룹원 목록 카드 UI는 Task-11에 포함하지 않음**(Rules상 그룹원 list만 허용, 화면은 후속)

<a id="source-0010"></a>

## 발췌 10: ## 20. 기능별 구현 전 필수 산출물

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 493~493행 · 원문 절: ## 20. 기능별 구현 전 필수 산출물.

각 그룹 기능 구현을 시작하기 전에 해당 범위에 필요한 문서를 이 초안에서 분리하거나 연결한다. Task-11에서는 사용자 흐름·역할표·그룹 생성/가입 Firestore 및 Rules 계약·자동/다중 기기 검증 시나리오를 먼저 작성한다. 그룹 레이드 연결과 탈퇴·추방·해산 계약은 후속 작업에서 분리한다.

<a id="source-0011"></a>

## 발췌 11: ## 20. 기능별 구현 전 필수 산출물

출처: docs/product/GROUP_PRODUCT_FLOW.md · 원본 497~497행 · 원문 절: ## 20. 기능별 구현 전 필수 산출물.

- Firestore 데이터 모델 및 Rules 계약
