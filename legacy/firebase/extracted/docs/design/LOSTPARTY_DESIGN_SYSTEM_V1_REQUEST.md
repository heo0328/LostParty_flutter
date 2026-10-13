# 기존 서비스 발췌 — docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md

원본 문서: docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md ([현재 문서](../../../../../docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md)). 분리일: 2026-10-13.
원본 전체 SHA256: de6803796b481f892118910e839e046eca3dd85935fbef1d548d6f28c0eb082c.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 적용 상태와 확정 기준

출처: docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md · 원본 17~17행 · 원문 절: ## 적용 상태와 확정 기준.

- 공개 모집 목록에서 사용하는 Firestore `PublicRecruitmentSummary` 기반 카드를 대표 RecruitmentCard로 삼는다.

<a id="source-0002"></a>

## 발췌 2: ### v1 시범 적용 범위

출처: docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md · 원본 28~28행 · 원문 절: ### v1 시범 적용 범위.

전체 화면으로 자동 확장하지 않는다. 시범 적용을 사용자가 확인한 뒤 다음 화면 적용 여부를 결정한다. 공개 모집 Firestore 페이징은 이 시범 디자인 완료 후 확정된 Card를 사용해 구현한다.
