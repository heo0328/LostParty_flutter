# 기존 서비스 발췌 — docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md

원본 문서: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md ([현재 문서](../../../../../docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 1fe051fc7b88292610e1aa2bd89f636e77b1becf089ea464e305d52b8b4dc48c.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 8. 서버 Snapshot과 경계

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 147~147행 · 원문 절: ## 8. 서버 Snapshot과 경계.

- 보석 요약은 클라이언트가 산출한 표시 정보라 Firestore Rules가 진위를 보장할 수 없다. Rules 복잡도와 Ruleset 저장 실패를 피하기 위해 이 다섯 필드의 스키마 검증을 추가하지 않고, 공식 앱의 쓰기 생성기와 방어적 읽기에서 완결성·타입·상태를 처리한다. 파티 Character 변경과 그룹 본인 Snapshot 갱신 Rules의 `affectedKeys` allowlist에 `gemValidationSnapshot`만 추가한다. 신청 권한·Character 소유권 등 기존 서버 경계는 그대로 유지한다.

<a id="source-0002"></a>

## 발췌 2: ## 8. 서버 Snapshot과 경계

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 157~157행 · 원문 절: ## 8. 서버 Snapshot과 경계.

- Character 변경 Rules는 허용 변경 필드에 `buildIntegritySnapshot`만 추가한다. 생성·신청·승인 경로의 기존 소유권, 활동 Character, 역할, 점유, Claim과 파티 구성 조건은 완화하지 않고 Rules 계약 테스트로 보존한다.

<a id="source-0003"></a>

## 발췌 3: ## 9. 구현 순서

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 162~162행 · 원문 절: ## 9. 구현 순서.

진행 상태: 2026-09-08 1~7단계와 8단계의 파티 신청자 카드 구간을 구현하고 자동·실기기 검증했다. 이후 Rules 경고 제거본도 2026-09-10 정상 배포했다. 2026-09-10 파티 membership·구성원 카드 전파를 구현하고 최신 Rules를 정상 배포했다. 그룹 membership 전파는 2026-09-11 Rules 콘솔 게시·실기기 회귀 후 `dev`에 병합됐다. 그룹원 활동 Character 목록의 통합 Build 무결성 상태(`buildIntegritySnapshot`)는 2026-09-11 구현·자동 검증·실기기 확인 후 `dev`에 병합됐다. 2026-09-12 확정 오류 v2의 아이콘 fallback 제거·오류 전용 표시와 복수 캐릭터 진단 도구를 구현·자동 검증했다. 파티 생성 리더의 보석 Snapshot과 참가 Character 변경 목록의 통합 오류 표시를 보완했고, 사용자가 그룹 레이드 생성 파티장 오류 표시를 실기기에서 확인해 완료 판정했다. 2026-09-13에는 신청·직접 참가·승인·Character 변경 이후에도 통합 오류가 유지되도록 신청·membership dual-write와 방어적 읽기를 구현해 자동 검증했다. 이 마지막 Rules 변경의 운영 배포와 실기기 확인은 남아 있다.

<a id="source-0004"></a>

## 발췌 4: ## 9. 구현 순서

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 170~170행 · 원문 절: ## 9. 구현 순서.

7. 최소 서버 Snapshot과 Rules 변경안을 별도 검토한다. (완료)

<a id="source-0005"></a>

## 발췌 5: ### 현재 데이터 경계와 서버 영향

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 239~239행 · 원문 절: ### 현재 데이터 경계와 서버 영향.

- 이 추가는 Firestore 쓰기 필드 allowlist, Rules, write plan, read model과 구버전 null 호환 수정이 필요하므로 별도 승인 구간이다.

<a id="source-0006"></a>

## 발췌 6: ### 현재 데이터 경계와 서버 영향

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 241~241행 · 원문 절: ### 현재 데이터 경계와 서버 영향.

서버 변경량이 커지거나 기존 파티 명령의 Rules 복잡도를 유의미하게 높이면 타인 카드 별칭 표시는 보류하고 내 계정의 로컬 표시까지만 구현한다.

<a id="source-0007"></a>

## 발췌 7: ### 1차 권장 범위 — 직업 단위 로컬 메모

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 261~261행 · 원문 절: ### 1차 권장 범위 — 직업 단위 로컬 메모.

- Firestore에 업로드하거나 다른 사용자에게 공개하지 않는다.

<a id="source-0008"></a>

## 발췌 8: ### 1차 권장 범위 — 직업 단위 로컬 메모

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 266~266행 · 원문 절: ### 1차 권장 범위 — 직업 단위 로컬 메모.

이 범위는 로컬 테이블·Repository·간단한 편집 UI와 카드 조회 연결만 필요하며 Firestore 스키마·Rules 변경은 필요하지 않다.

<a id="source-0009"></a>

## 발췌 9: ## 12. 차후 확장의 결정 순서

출처: docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md · 원본 282~282행 · 원문 절: ## 12. 차후 확장의 결정 순서.

5. 타인 카드 Build 별칭에 필요한 최소 Snapshot·Rules 변경량을 산정한다.
