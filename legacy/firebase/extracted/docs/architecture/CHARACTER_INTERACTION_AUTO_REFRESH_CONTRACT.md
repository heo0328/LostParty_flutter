# 기존 서비스 발췌 — docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md

원본 문서: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md ([현재 문서](../../../../../docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: f4af88cc4356ced9b2ead977cf56a3e009f79e8d8d37a90c42ac1b0d9546e7ea.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 0. 2026-09-05 앱 실행 1회 갱신으로 방향 전환 (A~E 반영)

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 14~14행 · 원문 절: ## 0. 2026-09-05 앱 실행 1회 갱신으로 방향 전환 (A~E 반영).

- 앱 실행 갱신은 Firebase·Player 세션·로컬 DB 초기화 후에도 첫 화면과 동시에 시작하지 않는다. 초기 경로인 내 레이드 현황의 진행 중·신청 중 첫 Snapshot(성공 또는 오류), 완료 기록 초기화와 알림 수 조회가 끝나고 첫 화면이 렌더링된 뒤 시작한다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 목적과 현재 결정

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 33~33행 · 원문 절: ## 1. 목적과 현재 결정.

LOSTPARTY에서 사용하는 활동 Character가 그룹·파티 등 다른 사용자와 교류하기 직전에 최신 Lost Ark Armory 정보를 확보한다. 기존 로컬 Build Snapshot, Firestore Character 최소 표시값, 그룹 membership Snapshot, 파티 신청·참가 Snapshot 구조는 유지한다.

<a id="source-0003"></a>

## 발췌 3: ## 1. 목적과 현재 결정

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 35~35행 · 원문 절: ## 1. 목적과 현재 결정.

이 작업의 주목적은 Firestore 조회 절감이 아니라 사용자가 Character 상세에 하나씩 들어가 `정보 가져오기`와 저장을 반복하는 불편을 줄이고, 교류 시점의 전투력·아이템 레벨·세팅 정확도를 높이는 것이다.

<a id="source-0004"></a>

## 발췌 4: ## 2. 데이터 책임 경계

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 53~61행 · 원문 절: ## 2. 데이터 책임 경계.

| 데이터 | 기준과 책임 |
|---|---|
| 원정대 목록 요약 | Lost Ark siblings API → 로컬 Drift. 기존 자동 요약 갱신 유지 |
| 일반 Character 현재 Build | 교류 시 Armory API 자동 조회 → 메모리 분석 → 역할별 로컬 Build Snapshot |
| 나이스단 Build | 사용자가 정상 세팅에서 저장한 역할별 로컬 Build Snapshot |
| Firestore Character | 소유권·활동 검증과 다른 사용자 표시를 위한 최소 최신값. 원본 Armory 저장소가 아님 |
| 그룹 membership | 가입·표시 갱신 시점 Snapshot |
| 파티 application/membership | 신청·가입·변경 명령 시점 Snapshot |
| 타 사용자 화면 | 상대방이 게시한 서버 Snapshot. 조회자가 상대 Character API를 호출하지 않음 |

<a id="source-0005"></a>

## 발췌 5: ## 5. 나이스단 정책

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 120~120행 · 원문 절: ## 5. 나이스단 정책.

- 이 설정은 사용자 개인 동작 정책이며 다른 사용자에게 필요하지 않으므로 로컬 DB에만 저장하고 Firestore에는 보내지 않는다.

<a id="source-0006"></a>

## 발췌 6: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 212~212행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

상태: 2026-09-04 구현·자동 검증 완료. 명령 직전 동기화 실패는 차단하고, 동일값 쓰기는 생략한다. Rules·스키마는 변경하지 않았다.

<a id="source-0007"></a>

## 발췌 7: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 214~214행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

- 값이 실제로 달라졌을 때만 Firestore Character 최소 필드 갱신

<a id="source-0008"></a>

## 발췌 8: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 216~216행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

- 기존 Character·membership·application 최소 필드를 우선 재사용하고 역할·출처·마지막 성공 시각을 위한 신규 서버 필드나 Rules 변경을 기본 전제로 두지 않음

<a id="source-0009"></a>

## 발췌 9: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 218~218행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

- 기존 Rules 읽기·Transaction 수와 변경 후 비용 비교

<a id="source-0010"></a>

## 발췌 10: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 220~220행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

완료 조건: Firestore를 Armory 원문 저장소로 확대하지 않고 타 사용자 표시와 명령 검증에 필요한 최소 책임만 유지한다.

<a id="source-0011"></a>

## 발췌 11: ### F — 서버 최소 Snapshot 정합성·비용 제어

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 222~222행 · 원문 절: ### F — 서버 최소 Snapshot 정합성·비용 제어.

단계 검증: 동일값 쓰기 생략, 서버 동기화 실패 시 명령 차단, 기존 Rules·Transaction 허용 범위, read/write 횟수 비교와 관련 Repository 테스트.

<a id="source-0012"></a>

## 발췌 12: ### G — 회귀·실기기 검증과 문서 종료

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 231~231행 · 원문 절: ### G — 회귀·실기기 검증과 문서 종료.

- 요청 횟수와 Firestore read/write 변화 기록

<a id="source-0013"></a>

## 발췌 13: ## 8. 단계별 실행 규칙

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 263~263행 · 원문 절: ## 8. 단계별 실행 규칙.

- 기존 API·로컬 Snapshot·Firestore 명령 계약을 재사용할 수 있으면 새 저장소나 서버 필드를 만들지 않는다.

<a id="source-0014"></a>

## 발췌 14: ## 9. 구현 중 계측 후 조정 가능한 값

출처: docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md · 원본 272~272행 · 원문 절: ## 9. 구현 중 계측 후 조정 가능한 값.

- 서버 신규 필드는 현재 요구사항이 아니다. 기존 필드만으로 타 사용자 표시나 Transaction 정합성을 충족할 수 없다는 코드·Rules 근거가 확인될 때만 F에서 최소안을 제안한다.
