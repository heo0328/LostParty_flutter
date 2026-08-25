# GameAccountId · CharacterId Firebase 계약

## 범위

이 문서는 `PlayerId -> GameAccountId -> CharacterId`의 서버 식별자와 로컬 Drift 행 사이의 첫 연결 계약을 정의한다. 파티 저장 모델, 계정 등록 UI, Lost Ark API 기반 소유 인증 명령 구현은 후속 작업이다.

## 식별자와 소유권

- `GameAccountId`와 `CharacterId`는 서버가 발급하는 불투명 Firestore 문서 ID다.
- 클라이언트는 ID를 생성하거나 기존 ID를 다른 로컬 행에 재연결하지 않는다.
- `gameAccounts/{gameAccountId}.ownerPlayerId`가 게임 계정의 단일 소유자를 나타낸다.
- `characters/{characterId}.gameAccountId`와 `ownerPlayerId`를 함께 저장한다. `ownerPlayerId`는 파티 명령의 소유 검증을 위한 서버 관리 역정규화 값이다.
- 캐릭터명은 변경 가능한 속성이다. 동일 캐릭터 판정에 캐릭터명을 영속 ID로 사용하지 않는다.

## 최소 서버 문서

`gameAccounts/{gameAccountId}`:

- `schemaVersion: 1`
- `ownerPlayerId: string`
- `status: active | archived`
- `label: string`
- `lookupCharacterName: string`
- `createdAt`, `updatedAt`: server timestamp

`characters/{characterId}`:

- `schemaVersion: 1`
- `ownerPlayerId: string`
- `gameAccountId: string`
- `status: active | archived`
- `rosterStatus: confirmed | missingFromLatestRoster`
- `serverName`, `characterName`, `characterClassName`: string
- `characterLevel: number`
- `itemLevel`, `combatPower`: nullable number
- `lastSummaryFetchedAt`, `createdAt`, `updatedAt`: server timestamp

## 명령과 검증 경계

- 생성·동기화는 Callable Function에서 현재 Auth binding의 `PlayerId`를 구한 뒤 처리한다.
- 서버는 대상 게임 계정의 `ownerPlayerId`, 모든 캐릭터의 `gameAccountId`와 `ownerPlayerId`, 요청 내 중복을 검증한다.
- 계정과 캐릭터 문서 갱신은 하나의 원자 작업으로 처리한다.
- 이름 변경은 같은 `CharacterId` 문서의 현재 이름을 갱신하고, 이름만으로 다른 Character에 병합하지 않는다.
- 클라이언트의 직접 create/update/delete는 허용하지 않는다. 본인 소유 문서의 단건/목록 읽기만 후속 Rules 작업에서 허용한다.

## Drift 매핑

- `game_accounts.id`, `account_characters.id` 정수 PK는 로컬 참조용으로 유지한다.
- `server_game_account_id`, `server_character_id`는 nullable unique 문자열이다. null은 아직 서버에 등록되지 않은 기존 로컬 행을 뜻한다.
- 서버 응답을 적용할 때 계정과 포함된 캐릭터 매핑을 한 Drift transaction에서 저장한다.
- 같은 값의 재적용은 허용하지만, 이미 연결된 행을 다른 서버 ID로 재매핑하거나 같은 서버 ID를 두 로컬 행에 연결하는 것은 거부한다.
- 서버 ID가 없는 기존 v3 데이터는 v4 migration 후에도 그대로 사용 가능하며 자동 업로드하지 않는다.
- 앱의 동기화 서비스는 Gateway 응답의 로컬 계정 ID가 요청과 같고 모든 요청 캐릭터가 정확히 한 번 포함됐는지 확인한 후에만 Drift transaction을 호출한다.
- 실제 Callable 구현은 `AccountIdentityGateway` 뒤에 위치하며, 응답 검증과 로컬 매핑은 Firebase SDK에 의존하지 않는다.

## 이번 작업 제외 범위

- Callable Function 구현과 배포
- 게임 계정 소유 인증 방식 및 충돌 복구 UX
- Firestore 읽기 Repository와 오프라인 동기화
- 파티·신청 문서의 CharacterId 전환
- 삭제·보관·다른 Player로의 소유권 이전
