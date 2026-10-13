# 기존 서비스 발췌 — docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md

원본 문서: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md ([현재 문서](../../../../../docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md)). 분리일: 2026-10-13.
원본 전체 SHA256: dbecc40ea0f2442650b9f5673d283a28e0b674daa79a3df49beb3250275e0db4.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: ## 1. 목적과 범위

출처: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md · 원본 7~9행 · 원문 절: ## 1. 목적과 범위.

현재 초기 운영 단계에서는 Firebase Spark 무료 범위만 사용한다. 사용자별 Lost Ark
API 토큰은 기기의 secure storage에만 저장하며, Flutter 앱이 장비 challenge 생성과
판정을 수행한 뒤 Firestore 클라이언트 transaction으로 소유권을 갱신한다.

<a id="source-0002"></a>

## 발췌 2: ## 5. 로컬 인증 요청

출처: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md · 원본 49~49행 · 원문 절: ## 5. 로컬 인증 요청.

현재 challenge는 앱 메모리에만 보관한다. 같은 앱 프로세스 안에서 화면을 나갔다 돌아오는 경우에는 복원하지만, 앱 프로세스가 종료되면 남은 시간과 관계없이 현재 인증 시도도 종료한다. 다시 인증을 누르면 새 기준 장비와 무작위 지정 부위로 새 challenge를 시작한다. 기기 저장소 또는 Firestore에 challenge를 복원하는 기능은 추가하지 않는다.

<a id="source-0003"></a>

## 발췌 3: ### 향후 서버 전환 시 참고할 문서

출처: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md · 원본 79~80행 · 원문 절: ### 향후 서버 전환 시 참고할 문서.

아래 문서 형식은 향후 서버 검증이 실제로 필요해질 경우의 참고 계약이며 현재
Firestore에는 생성하지 않는다.

<a id="source-0004"></a>

## 발췌 4: ## 6. 초기 Spark 구현과 향후 Callable 경계

출처: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md · 원본 82~120행 · 원문 절: ## 6. 초기 Spark 구현과 향후 Callable 경계.

## 6. 초기 Spark 구현과 향후 Callable 경계

현재 앱은 아래 명령과 동일한 입출력 경계를 로컬 Gateway로 구현한다. Firebase
Functions와 Secret Manager는 앱 런타임 및 배포 설정에서 사용하지 않는다.

### `startGameAccountVerification`

입력:

- `characterName`
- `source`
- `localAccountId` — 선택형

서버 처리:

1. Auth binding에서 active `PlayerId`를 확인한다.
2. 캐릭터명 정규화 후 최신 siblings와 종합 상세 API를 조회한다.
3. 6개 대상 부위가 모두 장착됐는지 확인한다.
4. 기존 pending 요청을 만료시키고 새 challenge를 만든다.
5. 1~3개 부위를 서버에서 무작위 선택한다.
6. 기준 장비, siblings, 시작·만료 시각을 저장한다.

### `confirmGameAccountVerification`

입력은 `challengeId` 하나다.

서버 처리:

1. 호출 AuthUid와 challenge의 PlayerId binding을 확인한다.
2. 완료된 요청은 기존 결과를 반환해 멱등성을 보장한다.
3. 서버 시각으로 만료 여부를 확인한다.
4. 최신 종합 상세 API를 조회하고 순수 판정 로직을 실행한다.
5. 성공 시 GameAccount 소유권과 Character 목록을 Transaction으로 반영한다.
6. challenge를 `verified`로 변경하고 서버 ID 매핑을 반환한다.

성공 응답은 `serverGameAccountId`와 각 캐릭터의 `serverName`,
`characterName`, `serverCharacterId`를 반환한다. 클라이언트는 서버명과 캐릭터명으로
가등록 행을 대응시킨 뒤 로컬 Drift 매핑을 한 transaction으로 적용한다.


<a id="source-0005"></a>

## 발췌 5: ## 10. Security Rules 원칙

출처: docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md · 원본 151~157행 · 원문 절: ## 10. Security Rules 원칙.

## 10. Security Rules 원칙

- challenge, GameAccount와 Character의 클라이언트 직접 create/update/delete를 차단한다.
- 기준 장비 Snapshot과 다른 Player의 인증 상태를 클라이언트가 읽지 못하게 한다.
- 현재 초기 구현에서는 인증 시작·확인과 소유권 이전을 Flutter 앱이 수행한다.
- 향후 악용 방어가 필요해질 때만 별도 합의 후 서버 명령으로 이전한다.
- 이후 모든 파티 명령은 요청 Character의 active 소유자와 호출 Player가 같은지 서버에서 다시 검증한다.
