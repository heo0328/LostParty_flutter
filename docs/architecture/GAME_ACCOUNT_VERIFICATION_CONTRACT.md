# 게임 계정 장비 인증 계약

## 1. 목적과 범위

이 문서는 가등록 또는 직접 입력한 캐릭터를 이용해 게임 계정 소유권을 확인하는 현재 로컬 구현과 향후 서버 계약을 정의한다. 인증 성공 후 `GameAccountId`·`CharacterId`를 생성하거나 현재 Player에게 이전한다.

현재 초기 운영 단계에서는 Firebase Spark 무료 범위만 사용한다. 사용자별 Lost Ark
API 토큰은 기기의 secure storage에만 저장하며, Flutter 앱이 장비 challenge 생성과
판정을 수행한 뒤 Firestore 클라이언트 transaction으로 소유권을 갱신한다.

## 2. 사용자 진입점

- 설정의 `내 게임계정 인증`에서 가등록 계정의 캐릭터를 선택할 수 있다.
- 가등록 계정 유무와 관계없이 캐릭터명을 직접 입력할 수 있다.
- 두 방식 모두 인증 시작 시 현재 Flutter Gateway가 최신 siblings와 종합 상세 API를 다시 조회한다.
- 직접 입력한 캐릭터의 정상 API 응답은 앱에서 가등록 계정으로 저장할 수 있다.
- Drift의 과거 장비 Snapshot은 인증 기준으로 사용하지 않는다.

## 3. 인증 장비 규칙

대상 부위는 다음 6개다.

- `weapon`: 무기
- `head`: 투구
- `shoulders`: 어깨
- `chest`: 상의
- `legs`: 하의
- `hands`: 장갑

인증 시작 시 6개 부위가 모두 장착된 상태여야 한다. 현재 Flutter Gateway는 `Random.secure()`를 사용해 이 중 중복 없는 1~3개를 무작위로 지정하고 시작 시점의 `Type + Name + Grade`를 메모리 기준 Snapshot으로 저장한다. Tooltip은 내구도 등 가변 정보가 있으므로 비교하지 않는다.

확인 성공 조건:

- 지정된 모든 부위가 API 응답에서 사라진다.
- 지정되지 않은 부위의 `Type + Name + Grade`는 기준 Snapshot과 같다.
- 액세서리, 어빌리티 스톤, 팔찌 등 대상 밖 장비 변화는 판정하지 않는다.
- 성공 후 장비 복구 여부는 확인하지 않는다.

## 4. 시간과 재확인

- 현재 로컬 구현의 유효시간은 Gateway가 기록한 시작 시각부터 10분이다.
- `expiresAt`과 같거나 지난 현재 시각의 확인은 `expired`다. 향후 서버 구현에서는 서버 시각을 신뢰 기준으로 사용한다.
- 유효시간 안에서는 확인 횟수를 제한하지 않는다.
- 안내 문구에 장비 변경 후 캐릭터 선택 화면으로 이동하거나 접속을 한 번 종료해야 API가 갱신된다고 표시한다.
- 지정 부위가 남아 있거나 API 갱신이 지연된 경우 요청을 종료하지 않고 다시 확인할 수 있다.

## 5. 로컬 인증 요청

현재 challenge는 앱 메모리에만 보관한다. 같은 앱 프로세스 안에서 화면을 나갔다 돌아오는 경우에는 복원하지만, 앱 프로세스가 종료되면 남은 시간과 관계없이 현재 인증 시도도 종료한다. 다시 인증을 누르면 새 기준 장비와 무작위 지정 부위로 새 challenge를 시작한다. 기기 저장소 또는 Firestore에 challenge를 복원하는 기능은 추가하지 않는다.

인증 진행 안내에는 다음 주의 문구를 함께 표시한다.

> 앱이 종료되면 남은 시간과 관계없이 현재 인증 시도가 종료됩니다. 원정대 인증은 인게임에서 장비를 바로 조작할 수 있는 상황에서 진행하는 것을 권장합니다.

인증 시작 시 무기와 5개 방어구, 총 6부위 중 하나라도 장착되어 있지 않으면 challenge를 만들지 않는다. 이 경우 API 장애나 응답 파싱 실패에 사용하는 일반 문구와 구분해 다음과 같이 안내한다.

> 인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.

장비 6부위 누락은 식별 가능한 시작 오류로 전달하고, Character/장비 API 응답 자체가 없거나 구조를 해석할 수 없는 경우에만 일반적인 정보 확인 실패 문구를 사용한다. 서버 challenge 문서는 향후 신뢰 가능한 서버 검증이 필요해질 때 사용할 참고 계약으로 유지한다.

### 향후 서버 전환 시 참고할 문서

`accountVerificationChallenges/{challengeId}`는 서버만 생성·수정한다.

- `schemaVersion: 1`
- `playerId: string`
- `authUid: string` — 명령 호출자 고정 및 감사용이며 사용자 UI에 노출하지 않음
- `characterName: string`
- `source: provisional | directInput`
- `localAccountId: number | null` — 클라이언트 응답 상관관계용이며 서버 소유권 판단에 사용하지 않음
- `status: pending | verified | expired | failed`
- `baselineEquipment: map`
- `requiredUnequippedSlots: string[]`
- `siblingsSnapshot: map[]`
- `attemptCount: number`
- `createdAt`, `expiresAt`, `lastCheckedAt`, `verifiedAt`: server timestamp 또는 null
- `failureCode: string | null`

아래 문서 형식은 향후 서버 검증이 실제로 필요해질 경우의 참고 계약이며 현재
Firestore에는 생성하지 않는다.

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

## 7. 판정 결과

- `verified`: 지정 부위 해제와 나머지 부위 유지 확인
- `requiredSlotsStillEquipped`: 지정 부위 일부 또는 전체가 남아 있음. 재확인 가능
- `unchallengedSlotChanged`: 지정하지 않은 부위가 사라지거나 교체됨. 재확인 가능
- `invalidEquipmentSnapshot`: API 응답 누락·중복·형식 오류. 재확인 가능
- `expired`: 10분 만료. 새 challenge 필요

재확인 가능한 결과는 challenge 상태를 `pending`으로 유지하고 `attemptCount`와 `lastCheckedAt`만 갱신한다.

## 8. 소유권 이전과 사용 제한

- 기존 소유자가 있어도 새 Player가 장비 인증에 성공하면 GameAccount 전체와 소속 Character 소유권을 이전한다.
- `characterIdentityClaims/{sha256(serverName + NUL + characterName)}`는 서버 전용
  역색인이며 기존 GameAccountId와 CharacterId를 재사용하는 데만 사용한다.
- 이전 Player의 로컬 데이터는 삭제하지 않고 서버 계정 상태를 `ownershipLost`로 표시한다.
- 인증된 게임 계정이 하나도 없는 Player는 설정, 로컬 조회와 인증 기능 외의 모든 멀티유저 서버 명령을 사용할 수 없다.
- 소유권을 잃은 Character의 승인 대기 신청은 무효화한다.
- 활성 파티는 구성 점검 필요 상태와 모집 비활성 상태로 전환한다.

## 9. 캐릭터 목록 변경

- 새 siblings 캐릭터는 같은 GameAccount에 새 CharacterId로 추가한다.
- API에서 사라진 기존 Character는 자동 삭제하거나 다른 캐릭터와 자동 병합하지 않는다.
- API에서 사라진 기존 Character도 계정 소유권과 함께 이전하되
  `rosterStatus: missingFromLatestRoster`로 표시한다. 현재 확인된 캐릭터는
  `rosterStatus: confirmed`로 갱신한다.
- 사용자에게 확인되지 않는 캐릭터가 있음을 알리고 수동 삭제 절차를 제공한다.
- 캐릭터명 변경 자동 추적은 초기 범위에서 제외한다.

## 10. Security Rules 원칙

- challenge, GameAccount와 Character의 클라이언트 직접 create/update/delete를 차단한다.
- 기준 장비 Snapshot과 다른 Player의 인증 상태를 클라이언트가 읽지 못하게 한다.
- 현재 초기 구현에서는 인증 시작·확인과 소유권 이전을 Flutter 앱이 수행한다.
- 향후 악용 방어가 필요해질 때만 별도 합의 후 서버 명령으로 이전한다.
- 이후 모든 파티 명령은 요청 Character의 active 소유자와 호출 Player가 같은지 서버에서 다시 검증한다.
