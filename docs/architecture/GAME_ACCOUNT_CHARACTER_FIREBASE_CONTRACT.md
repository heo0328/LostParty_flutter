# GameAccountId · CharacterId Firebase 계약

## 2026-09-11 Character Build 무결성 최소 표시 계약

- Character 문서의 선택 필드 `buildIntegritySnapshot: map`은 성공한 계정 데이터 갱신의 로컬 Build Snapshot에서 만든 최소 통합 상태다. `clean/review/error/unavailable`, 복수 issue code, 역할, 원본 시각과 카탈로그 버전만 포함하며 전체 Armory·보석명·Tooltip·스킬·상세 포인트는 포함하지 않는다.
- 보석과 아크그리드가 동시에 잘못될 수 있으므로 `ERRORCHECK: GEM | ARKGRID` 같은 단일 값으로 축약하지 않는다. UI는 짧은 상태를 표시하되 서버는 `issueCodes` 목록으로 두 오류를 함께 보존한다.
- 기존 `CharacterMinimumDisplaySyncService`가 성공한 앱 실행 1회 갱신·내 계정 수동 갱신 결과를 아이템 레벨·전투력과 같은 Character별 Transaction으로 반영한다. 그룹 상세 진입이나 타인 조회는 쓰기와 API 호출을 만들지 않는다.
- Transaction은 active Auth binding·Player·Character 소유자·GameAccount 관계를 기존대로 확인한다. null·동기화 실패·더 오래된 `checkedAt`은 기존 상태를 덮지 않고, 전체 값이 같으면 `updatedAt`도 쓰지 않는다.
- 그룹원 활동 Character 목록은 기존대로 대상 Player의 `characterActivity` ID와 `characters` owner/status query 결과의 교집합만 표시한다. 통합 상태의 유무가 활동 여부를 바꾸거나 비활동 Character를 노출하지 않는다.
- 필드 부재·null·불완전 map·알 수 없는 값은 무결성 정보 없음으로 읽고 기존 Character 표시를 유지한다. 별도 projection 컬렉션·새 쿼리·인덱스·백필은 추가하지 않는다.
- 일반 인증과 수동 인증의 Character 전체 `set`은 재인증 시 기존 `combatPower`와 유효한 `buildIntegritySnapshot`을 보존해야 한다. 신규 문서와 손상된 선택 필드는 정상적으로 분리 처리한다.
- 이 상태는 표시 정보이며 소유권·인증·가입·참가 자격의 근거가 아니다. 현재 Character Rules의 광범위한 `signedIn()` 권한은 기존 기술 부채로 남기고 이번 기능과 섞지 않는다.

## 2026-08-31 그룹 표시 전투력 연결

- Character 문서의 선택 필드 `combatPower: number`는 소유자가 로컬에 저장한 표시 전투력이다. 없으면 미확인으로 표시하며 0을 임의로 채우지 않는다. API 검증값·소유권·레이드 참가 자격의 근거로 사용하지 않는다.
- 그룹 상세 진입/새로고침에서 소유 계정의 활동 Character만 전투력 서버 보강 대상으로 쓴다. active 소유권·서버 ID 연결·원정대 누락 아님도 함께 적용한다. 기존 프로필 값이 없으면 가장 최근 유효한 저장 역할 세팅의 전투력을 사용한다. 추가 Lost Ark API 조회는 하지 않는다. 활동에서 빠진 Character의 기존 membership Snapshot은 지우지 않는다.
- CharacterCombatPowerSyncGateway는 캐릭터별 Transaction에서 active Auth binding·Player·Character 소유자·playerGameAccounts 소유 관계를 읽어 확인하고 `combatPower`와 `updatedAt`만 갱신한다. 값이 같으면 쓰지 않고 값 없는 캐릭터는 보내지 않는다. Character 생성, 식별자·소유권 변경, 일괄 데이터 이행은 하지 않는다.
- 기존 원정대 최소 정보 동기화와 분리하여 요약 정보가 변하지 않았어도 전투력을 보강한다. `lastSummaryFetchedAt`은 바꾸지 않는다. 전투력은 현재 기기에 저장된 표시값이며 서버가 최신 API 값임을 보증하는 것은 아니다.
- 소유자의 갱신된 앱이 그룹에 진입해야 해당 캐릭터 정보가 공유된다. 타인의 기기에서 타인 로컬 DB를 읽거나 타인 Character를 대신 갱신하지 않는다. 조회 화면은 재진입/새로고침으로 갱신한다.
- 비용: 로컬 값이 있는 캐릭터마다 작은 Transaction 1회(기본 binding/Player/Character/소유관계 4회 읽기, 값이 다를 때 1회 쓰기). 없는 값에 대한 원격 요청은 없다. 조회 중 중복 새로고침은 막는다.
- 현재 Character Rules의 광범위한 signedIn 쓰기 허용은 기존 기술 부채이며 이번에 강화되었다고 주장하지 않는다. 위 소유 검증은 Repository 동작이다. Rules·배포 설정 변경 없이 표시 필드만 연결한다.

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

`players/{playerId}/characterActivity/{characterId}`:

- `schemaVersion: 1`
- `playerId: string`
- `characterId: string` — 문서 ID와 같아야 한다
- `gameAccountId: string` — 해당 Character의 active 소유 GameAccount
- `updatedAt`: server timestamp
- 문서가 있으면 해당 Character는 활동 상태다. 가변 ID 목록을 한 문서에 저장하지 않는다
- 활동 설정은 이 하위 컬렉션만 쓰며 Character 인증·소유권 필드는 변경하지 않는다
- 각 쓰기는 `characters/{characterId}`와 `playerGameAccounts/{playerId}_{gameAccountId}` 소유권을 확인하고, 같은 계정의 대표 Character 활동 문서가 있어야 한다
- 대표 Character의 활동 문서는 삭제할 수 없다
- 활성 Auth binding이 있는 사용자는 다른 Player의 활동 문서 목록을 읽을 수 있다. 별도 Projection 컬렉션은 두지 않는다

## 명령과 검증 경계

- 현재 초기 구현은 Flutter Firestore transaction에서 Auth binding의 `PlayerId`를
  구한 뒤 생성·동기화한다.
- 서버는 대상 게임 계정의 `ownerPlayerId`, 모든 캐릭터의 `gameAccountId`와 `ownerPlayerId`, 요청 내 중복을 검증한다.
- 계정과 캐릭터 문서 갱신은 하나의 원자 작업으로 처리한다.
- 이름 변경은 같은 `CharacterId` 문서의 현재 이름을 갱신하고, 이름만으로 다른 Character에 병합하지 않는다.
- 클라이언트의 직접 create/update/delete는 허용하지 않는다. 본인 소유 문서의 단건/목록 읽기만 후속 Rules 작업에서 허용한다.

## 인증 이후 최소 정보 동기화

- 인증은 Character 소유권과 `serverCharacterId`를 확정하지만 이후 강화로 바뀐 아이템 레벨을 자동으로 최신 상태로 보장하지 않는다.
- `내 계정` 진입 시 대표 캐릭터명으로 Lost Ark siblings API를 조회하고 캐릭터명·아이템 레벨·캐릭터 레벨만 기존 Drift 요약과 비교한다.
- 화면은 기존 Drift 데이터를 먼저 표시하며 자동 조회 완료를 기다려 진입을 막지 않는다.
- 자동 조회는 마지막 성공 시각 기준 **1분**이 지나지 않으면 생략한다. 사용자가 실행하는 수동 새로고침은 이 제한과 무관하다.
- 값이 바뀐 Character만 Drift에서 갱신한다. 앱 서버에는 active 소유 상태이고 `serverCharacterId`가 연결된 Character의 같은 최소 필드만 갱신한다.
- 값이 같으면 Drift와 Firestore 쓰기를 모두 생략한다. 변경이 없으면 Lost Ark 조회만 하고 앱 서버로 전송하지 않는다.
- 수동 새로고침 등 네트워크 요청 버튼은 진행 중 재탭으로 중복 요청이 나가지 않게 막는다.
- 서버 동기화는 캐릭터명이 아니라 기존 `serverCharacterId`로 대상을 정한다. 이름 변경은 같은 Character 문서의 표시 속성 변경으로만 처리하며 이름만으로 병합하거나 서버 ID를 재매핑하지 않는다.
- `lastSummaryFetchedAt`은 실제 API 조회 결과의 신선도와 순서 역전을 판정하는 기준이다. 더 오래된 응답은 최신 Snapshot을 덮어쓰지 않는다.
- API 조회 실패 시 기존 로컬·서버 값을 유지한다. API 조회와 로컬 저장은 성공했지만 서버 반영이 실패하면 부분 성공을 사용자에게 알리고 재시도할 수 있어야 한다.
- 모집 생성·신청 등 파티 명령은 서버 Character Snapshot을 최종 검증한다. 서버 값이 오래됐거나 조건에 미달하면 명령 화면에서 무조건 API를 호출하지 않고 `내 계정 정보 새로고침`을 안내한다.
- 별도 `서버에 저장` 버튼, 제한 없는 화면 진입 조회, 전체 종합 상세·장비 Snapshot 자동 갱신은 초기 범위에서 제외한다.
- Spark 초기 구조에서는 앱이 Lost Ark API 결과를 받아 동기화 명령을 실행한다. Rules는 active binding, Character 소유권, 기존 `serverCharacterId` 고정과 허용 필드만 강제하며 API 응답의 진위를 서버에서 독립 검증하지 못하는 위험은 현재 클라이언트 Transaction 신뢰 경계에 포함한다.

## Drift 매핑

- `game_accounts.id`, `account_characters.id` 정수 PK는 로컬 참조용으로 유지한다.
- `server_game_account_id`, `server_character_id`는 nullable unique 문자열이다. null은 아직 서버에 등록되지 않은 기존 로컬 행을 뜻한다.
- 서버 응답을 적용할 때 계정과 포함된 캐릭터 매핑을 한 Drift transaction에서 저장한다.
- 같은 값의 재적용은 허용하지만, 이미 연결된 행을 다른 서버 ID로 재매핑하거나 같은 서버 ID를 두 로컬 행에 연결하는 것은 거부한다.
- 서버 ID가 없는 기존 v3 데이터는 v4 migration 후에도 그대로 사용 가능하며 자동 업로드하지 않는다.
- Drift v5의 `is_roster_missing`은 최신 원정대 조회에서 사라진 캐릭터를
  자동 삭제하지 않고 보존하기 위한 값이다. 다시 확인되면 false로 복구하고,
  true인 캐릭터만 사용자 확인 후 수동 삭제할 수 있다.
- Drift v6의 `server_ownership_status`는 `playerGameAccounts`의 `active` 또는
  `ownershipLost`를 마지막으로 동기화한 값이다. 네트워크 실패 시 마지막 값을
  유지하며, `ownershipLost` 계정은 재인증 화면에서는 보이지만 파티 모집·신청
  캐릭터 후보에서는 제외한다.
- 앱의 동기화 서비스는 Gateway 응답의 로컬 계정 ID가 요청과 같고 모든 요청 캐릭터가 정확히 한 번 포함됐는지 확인한 후에만 Drift transaction을 호출한다.
- 향후 서버 검증이 필요하면 `AccountIdentityGateway` 경계 뒤 구현만 교체하며,
  응답 검증과 로컬 매핑은 Firebase SDK에 의존하지 않는다.

## 이번 작업 제외 범위

- 유료 서버 검증 도입
- 게임 계정 소유 인증 방식 및 충돌 복구 UX
- Firestore 읽기 Repository와 오프라인 동기화
- 파티·신청 문서의 CharacterId 전환
- 삭제·보관·다른 Player로의 소유권 이전
