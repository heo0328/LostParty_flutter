# 기존 서비스 발췌 — docs/product/BUILD_MEMO_SHARING.md

원본 문서: docs/product/BUILD_MEMO_SHARING.md ([현재 문서](../../../../../docs/product/BUILD_MEMO_SHARING.md)). 분리일: 2026-10-13.
원본 전체 SHA256: b79c24d4c42f87ac90bcb9de021e5586552fae414bc13e964e360a3331b78e8e.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 5. 파티 카드에 필요한 최소 Build Snapshot

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 112~112행 · 원문 절: ## 5. 파티 카드에 필요한 최소 Build Snapshot.

- Firestore Rules 필드 allowlist와 타입 검증

<a id="source-0002"></a>

## 발췌 2: ## 5. 파티 카드에 필요한 최소 Build Snapshot

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 116~116행 · 원문 절: ## 5. 파티 카드에 필요한 최소 Build Snapshot.

실제 변경량을 먼저 산정한다. Rules 복잡도 또는 생성·가입 명령 위험이 크면 Build Snapshot과 타인 카드 메모는 보류하고 로컬 내 계정 기능만 제공한다.

<a id="source-0003"></a>

## 발췌 3: ## 8. 공유 2차 후보 — 서버 공유 코드

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 174~174행 · 원문 절: ## 8. 공유 2차 후보 — 서버 공유 코드.

- 공개 팩 삭제, 신고, 악성 문구, 소유권, 코드 충돌, 읽기 권한과 Rules를 함께 설계해야 한다.

<a id="source-0004"></a>

## 발췌 4: ## 8. 공유 2차 후보 — 서버 공유 코드

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 176~176행 · 원문 절: ## 8. 공유 2차 후보 — 서버 공유 코드.

Firestore 문서 하나의 최대 크기는 1 MiB이므로 팩 전체를 무제한 단일 문서에 넣지 않는다. 실제 크기 측정 후 메타데이터 문서와 규칙 chunk/subcollection으로 분리할지 결정한다. 공식 기준: <https://firebase.google.com/docs/firestore/quotas>

<a id="source-0005"></a>

## 발췌 5: ## 8. 공유 2차 후보 — 서버 공유 코드

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 178~178행 · 원문 절: ## 8. 공유 2차 후보 — 서버 공유 코드.

서버 공유의 핵심은 저장 용량보다 공개 쓰기·읽기 Rules, 악성 콘텐츠와 버전 관리다. 이 운영 범위를 감당하지 않기로 하면 JSON 공유만 유지한다.

<a id="source-0006"></a>

## 발췌 6: ## 9. 권장 단계

출처: docs/product/BUILD_MEMO_SHARING.md · 원본 187~187행 · 원문 절: ## 9. 권장 단계.

6. 최소 Build Snapshot의 서버·Rules 변경량을 검토하고 허용되는 경우 타인 카드 매칭을 연결한다.
