# 기존 서비스 발췌 — docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md

원본 문서: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md ([현재 문서](../../../../../docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md)). 분리일: 2026-10-13.
원본 전체 SHA256: 57b0971cb131017767d3e0ed0351919eb20ddeee4fa883fb024e77b1aa6bdc1c.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ### 2.1 관계

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 26~34행 · 원문 절: ### 2.1 관계.

```text
Firebase AuthUid
  -> Auth binding
LOSTPARTY PlayerId
  -> 소유
GameAccountId (게임 계정 / 원정대)
  -> 포함
CharacterId (실제 레이드 참가 단위)
```

<a id="source-0002"></a>

## 발췌 2: ### 2.1 관계

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 36~42행 · 원문 절: ### 2.1 관계.

| 식별자 | 의미 | 주 사용처 |
|---|---|---|
| `AuthUid` | 현재 Firebase 인증 주체 | 로그인 상태와 Player binding 확인 |
| `PlayerId` | LOSTPARTY에서 한 사람을 나타내는 영속 사용자 ID | 파티장·공대장·그룹장 권한, 신청자·멤버 중복 판정 |
| `GameAccountId` | 등록·인증한 하나의 로스트아크 원정대 | 원정대 소유 관계와 Character 묶음 |
| `CharacterId` | 원정대에 속한 실제 Character | 모집 생성·신청·참가·완료 단위 |
| 로컬 Character 행 ID | 현재 기기의 Drift 데이터 식별자 | 화면 표시와 로컬 데이터 연결만 담당 |

<a id="source-0003"></a>

## 발췌 3: ### 5.5 그룹 해산

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 339~339행 · 원문 절: ### 5.5 그룹 해산.

현재 Spark 클라이언트 Transaction은 최대 50명의 데이터를 한 번에 순회 정리하지 않는다. 1차 그룹 해산은 다음 조건을 모두 만족할 때만 허용한다.

<a id="source-0004"></a>

## 발췌 4: ### 10.2 BUG-022 작업 브랜치 상태

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 525~529행 · 원문 절: ### 10.2 BUG-022 작업 브랜치 상태.

| 문제 | 상태 |
|---|---|
| 모집 생성 당시 그룹 인원수 Snapshot 때문에 오래된 그룹방 해산이 거절됨 | 현재 그룹 count의 `N -> N-1`을 검증하도록 수정, CI 근거 확보 |
| 그룹방 추방·탈퇴 때 `raidListings` 갱신이 거절됨 | 참가자 제거용 listing 검증 추가, CI 근거 확보 |
| 그룹방에서 추방·탈퇴 후 같은 방 재가입 | Firestore Rules 1,000 표현식 한도로 미해결 |

<a id="source-0005"></a>

## 발췌 5: ## 11. 기존 문서와의 정합성 주의

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 545~545행 · 원문 절: ## 11. 기존 문서와의 정합성 주의.

- 과거 `FIREBASE_PARTY_PRODUCT_FLOW.md`에는 하단 네 번째 탭이 설정으로 남아 있지만 현재 앱은 그룹 탭을 사용한다. 설정은 내 계정에서 진입한다.

<a id="source-0006"></a>

## 발췌 6: ## 11. 기존 문서와의 정합성 주의

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 548~548행 · 원문 절: ## 11. 기존 문서와의 정합성 주의.

- 구현 완료, 자동 검증, 운영 Rules 게시와 실기기 확인은 서로 다른 상태다. 이 문서는 이를 같은 의미로 사용하지 않는다.

<a id="source-0007"></a>

## 발췌 7: ## 12. 관련 상세 계약

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 552~552행 · 원문 절: ## 12. 관련 상세 계약.

- [`GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../../../docs/architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md): GameAccount·Character 식별자와 소유 관계

<a id="source-0008"></a>

## 발췌 8: ## 12. 관련 상세 계약

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 555~555행 · 원문 절: ## 12. 관련 상세 계약.

- [`FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../../../docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md): 파티 원자 명령과 권한

<a id="source-0009"></a>

## 발췌 9: ## 12. 관련 상세 계약

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 556~556행 · 원문 절: ## 12. 관련 상세 계약.

- [`FIRESTORE_PARTY_READ_MODEL_CONTRACT.md`](../../../docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md): 모집·진행 중·신청 중 읽기

<a id="source-0010"></a>

## 발췌 10: ## 12. 관련 상세 계약

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 558~558행 · 원문 절: ## 12. 관련 상세 계약.

- [`FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../../../docs/architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md): 그룹 생성·가입·membership 계약

<a id="source-0011"></a>

## 발췌 11: ## 12. 관련 상세 계약

출처: docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md · 원본 560~560행 · 원문 절: ## 12. 관련 상세 계약.

- [`FIREBASE_PARTY_PRODUCT_FLOW.md`](../../../docs/architecture/FIREBASE_PARTY_PRODUCT_FLOW.md): 반복방·완료·이벤트를 포함한 파티 제품 흐름
