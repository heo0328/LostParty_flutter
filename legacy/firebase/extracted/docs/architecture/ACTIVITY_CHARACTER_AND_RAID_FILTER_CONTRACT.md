# 기존 서비스 발췌 — docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md

원본 문서: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md ([현재 문서](../../../../../docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 5f2047be0892df732c604367a7b6aa428872ceb88ec9d0db352efa108ecd4327.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ### 4.1 저장 위치와 소유 경계

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 51~51행 · 원문 절: ### 4.1 저장 위치와 소유 경계.

- 확정 저장 위치는 `players/{playerId}/characterActivity/{characterId}`다. 활동 Character마다 문서가 하나씩 있다. 가변 ID 목록을 한 문서에 넣지 않는다. Firestore Rules는 재귀와 가변 길이 목록 순회를 허용하지 않기 때문이다.

<a id="source-0002"></a>

## 발췌 2: ### 4.1 저장 위치와 소유 경계

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 55~55행 · 원문 절: ### 4.1 저장 위치와 소유 경계.

- Repository는 최종 선택 전체를 먼저 검증한 뒤 Firestore Rules 문서 접근 한도보다 작은 묶음으로 차이만 저장한다. 대표 포함 추가, 나머지 추가·갱신, 비활성 삭제 순서를 지켜 부분 실패가 기존 활동·대표 상태를 먼저 훼손하지 않게 하며, 재시도로 같은 최종 상태에 수렴한다. 클라이언트 Repository는 보안 경계가 아니므로 각 묶음의 Rules 소유권 검증은 유지한다.

<a id="source-0003"></a>

## 발췌 3: ### 4.1 저장 위치와 소유 경계

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 57~57행 · 원문 절: ### 4.1 저장 위치와 소유 경계.

- 다른 그룹원 화면의 활동 Character 후보는 `characterActivity` ID 목록과 기존 `characters/{characterId}` 표시 필드를 조합한다. Rules 복잡도 한도 때문에 별도 Projection 컬렉션과 그룹 교집합 검사는 쓰지 않는다.

<a id="source-0004"></a>

## 발췌 4: ### 4.2 서버 불변조건

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 68~68행 · 원문 절: ### 4.2 서버 불변조건.

- 복수 선택 저장은 최종 상태 전체를 먼저 검증한다. 임의 개수 전체를 단일 Transaction으로 쓰면 Rules 접근 20회 한도를 넘으므로 작은 묶음으로 반영하며, 추가를 삭제보다 먼저 수행해 중간 상태에서도 0명이나 비활동 대표가 관찰되지 않게 한다. 일부 묶음 실패 시 성공으로 확정하지 않고 재시도로 수렴한다.

<a id="source-0005"></a>

## 발췌 5: ### 4.3 기존 데이터 처리

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 75~75행 · 원문 절: ### 4.3 기존 데이터 처리.

- 실제 테스트 데이터 삭제와 Rules 배포는 이 저장 단위에서 하지 않는다.

<a id="source-0006"></a>

## 발췌 6: ### 5.2 대표 Character와 최소 1명

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 103~103행 · 원문 절: ### 5.2 대표 Character와 최소 1명.

- Repository는 빈 선택과 대표 누락 저장 명령을 거절한다. Rules는 각 캐릭터 쓰기에서 소유권과 해당 계정 대표 활동 문서 존재를 확인하고, 대표 활동 문서 삭제를 거절한다.

<a id="source-0007"></a>

## 발췌 7: ### A. 계약·저장 기반

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 250~250행 · 원문 절: ### A. 계약·저장 기반.

- 실제 Character 문서와 Rules를 대조해 `players/{playerId}/characterActivity/{characterId}`에 캐릭터별 활동 문서를 저장한다

<a id="source-0008"></a>

## 발췌 8: ### A. 계약·저장 기반

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 252~252행 · 원문 절: ### A. 계약·저장 기반.

- 소유권·대표 활동 존재·대표 삭제 거절 Rules와 Firebase Emulator 실제 요청 테스트

<a id="source-0009"></a>

## 발췌 9: ### A. 계약·저장 기반

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 253~253행 · 원문 절: ### A. 계약·저장 기반.

- 테스트 데이터 재설정 절차 문서화. 실제 삭제·Rules 배포는 이 단계에서 하지 않는다

<a id="source-0010"></a>

## 발췌 10: ## 11. 완료 조건

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 279~279행 · 원문 절: ## 11. 완료 조건.

- 최소 1명과 대표 포함 불변조건이 UI·Repository·Rules에서 모두 보장된다.

<a id="source-0011"></a>

## 발췌 11: ### 13.4 원본 데이터와 조회 권한

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 329~329행 · 원문 절: ### 13.4 원본 데이터와 조회 권한.

- 기존 Rules는 활성 Player 연결 사용자에게 공개 파티 membership 읽기를, 해당 그룹원에게 그룹 전용 파티 membership 읽기를 허용한다. 레이드 가입 자체는 선행조건이 아니다.

<a id="source-0012"></a>

## 발췌 12: ### 13.4 원본 데이터와 조회 권한

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 330~330행 · 원문 절: ### 13.4 원본 데이터와 조회 권한.

- 위 권한을 재사용하며 읽기 범위를 확대하거나 비가입 그룹의 비공개 파티를 우회 조회하지 않는다. 실제 배포 Rules 차이가 있으면 권한 오류로 보고한다.

<a id="source-0013"></a>

## 발췌 13: ### 14.2 로컬 우선 처리

출처: docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md · 원본 376~376행 · 원문 절: ### 14.2 로컬 우선 처리.

- Firestore query, 문서 필드, Rules와 Indexes를 변경하지 않는다. 서버에서 이미 받은 원본 목록만 필터·정렬한다.
