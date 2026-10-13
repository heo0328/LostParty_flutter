# 기존 서비스 발췌 — docs/product/DETAIL_IMPROVEMENTS.md

원본 문서: docs/product/DETAIL_IMPROVEMENTS.md ([현재 문서](../../../../../docs/product/DETAIL_IMPROVEMENTS.md)). 분리일: 2026-10-13.
원본 전체 SHA256: c63a9c5e55a6a32ef61254193cb0fe7fc0d196eabed78efc579c563302f28418.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 앞으로의 기능 우선순위

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 29~29행 · 원문 절: ## 앞으로의 기능 우선순위.

- 현재 파티 이벤트는 향후 앱 내부 알림함과 FCM 발송의 공통 원본으로 사용할 수 있게 유지한다.

<a id="source-0002"></a>

## 발췌 2: ## 앞으로의 기능 우선순위

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 30~30행 · 원문 절: ## 앞으로의 기능 우선순위.

- Spark 환경에서 공통 파티 이벤트 기반 앱 내부 알림을 먼저 구현하고, 향후 신뢰할 수 있는 서버가 같은 이벤트를 소비하여 FCM을 발송할 수 있게 확장한다.

<a id="source-0003"></a>

## 발췌 3: ## 앞으로의 기능 우선순위

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 31~31행 · 원문 절: ## 앞으로의 기능 우선순위.

- 앱 내부 알림과 FCM에 별도 메시지 원본을 만들지 않으며 상세 계약은 [`../architecture/PARTY_NOTIFICATION_CONTRACT.md`](../../../../../docs/architecture/PARTY_NOTIFICATION_CONTRACT.md)를 따른다.

<a id="source-0004"></a>

## 발췌 4: ## 앞으로의 기능 우선순위

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 36~36행 · 원문 절: ## 앞으로의 기능 우선순위.

- 진행 중 현황과 레이드 모집에는 참가 인원/남은 자리의 적은 순·많은 순 로컬 정렬을 제공한다. 기존 필터 요약 아래에 정렬 전용 행을 두고 Firestore query·필드·Rules·Indexes는 추가하지 않는다.

<a id="source-0005"></a>

## 발췌 5: ## 완료 참가자 평가와 한마디

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 49~49행 · 원문 절: ## 완료 참가자 평가와 한마디.

- 초기 Firebase 전환에서는 구현하지 않고 별도 제품 설계 후 범위를 확정한다.

<a id="source-0006"></a>

## 발췌 6: ## 파티 구성과 가입 조건

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 71~71행 · 원문 절: ## 파티 구성과 가입 조건.

- 현재 Firestore membership의 `partyIndex`는 파티 번호이며 파티 내부 자리 번호가 아니다. 상세 UI가 이를 전체 위치처럼 계산해 같은 1파티 멤버가 모두 `1자리`로 보이는 문제가 있다.

<a id="source-0007"></a>

## 발췌 7: ## 파티 상세 조율 채팅

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 89~89행 · 원문 절: ## 파티 상세 조율 채팅.

- 이미지, 파일, 음성, 읽음 상태, 전체 채팅 목록 미리보기와 FCM 알림은 초기 범위에서 제외한다.

<a id="source-0008"></a>

## 발췌 8: ## 파티 상세 조율 채팅

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 93~93행 · 원문 절: ## 파티 상세 조율 채팅.

- 파티 완료·해산 뒤 읽기 전용 유지 여부와 보관·삭제 정책은 TTL·Functions 없이 Spark 범위에서 구현 가능한 방식으로 채팅 작업 시작 전에 확정한다.

<a id="source-0009"></a>

## 발췌 9: ## 참가자 수동 알림

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 111~111행 · 원문 절: ## 참가자 수동 알림.

- 실제 전송은 향후 Firebase 연결 시 인증된 서버 명령이 모집 참가 권한과 수신 대상을 검증한 뒤 FCM으로 처리한다.

<a id="source-0010"></a>

## 발췌 10: ## 레이드 현황 공통 필터

출처: docs/product/DETAIL_IMPROVEMENTS.md · 원본 164~164행 · 원문 절: ## 레이드 현황 공통 필터.

- 공개 파티 목록과 같은 필터 컴포넌트 및 값 객체를 재사용할 수 있도록 설계하되 서로 다른 Firestore query와 Drift 완료 기록 조회를 하나의 Repository로 합치지 않는다.
