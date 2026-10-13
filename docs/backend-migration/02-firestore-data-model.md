# 기존 Firestore 데이터 구조와 기능 분석 근거

최신 정책: 기존 데이터 import/export mapping은 하지 않는다. 이 문서는 기존 기능의 상태·소유권·명령 불변식을 파악하는 소스 근거이며 신규 PostgreSQL schema/이관 입력 명세가 아니다. [09](09-migration-decisions.md)를 우선한다.

기준은 [00](00-overview.md). 아래는 소스의 현재 저장/해석 계약이며 운영 export의 실제 schema 선언이 아니다. nullable·missing·legacy 호환은 일괄 정규화하지 않는다. SQL table/관계 구조는 확정하지 않는다.

## 식별자와 자료형

Auth UID는 `authBindings`의 doc ID다. PlayerId는 별도 Firestore 자동 ID이며 사람 단위 영속 관계가 이를 참조한다. gameAccountId/CharacterId/recruitmentId/groupId는 서버 문서 ID와 로컬 Drift int ID를 구분한다. 주차 key는 `YYYY-MM-DD` 문자열, 시각은 Firestore Timestamp이며 Dart에서 DateTime/UTC로 변환한다. token은 Firestore 모델에 저장된 앱 로그인 credential로 확인되지 않았다.

Character identity claim key: `base64Url(UTF8(trim(serverName) + NUL + trim(characterName)))`의 padding 제거. [characterIdentityKey](../../lib/features/account/domain/character_identity_key.dart). Weekly claim ID: `${cycleKey}_${characterId}_${raidId}`, characterId20자 alphanumeric·raidId 소문자/숫자/underscore 검증. [WeeklyRaidClaimDocumentId](../../lib/features/account/data/mappers/weekly_raid_claim_document_id.dart). raidState ID는 `PartyRaidState.documentIdFor`가 Character와 raid로 구성하며 cycle을 body로 보유한다. 숫자 localCharacterId/표시 characterName과 서버 CharacterId를 혼용하지 않는다.

| 표기 | 소스에서 확인 가능한 의미 |
|---|---|
| string/int/bool | Dart cast/Mapper·Rules의 is 조건과 writer value |
| number | Firestore 정수/실수 및 Dart double/num 처리; 실제 저장 precision/export 필요 |
| time/null | serverTimestamp 또는 Timestamp.fromDate, 기존 필드 optional/null/missing 구분 |
| list/map | aggregate slots/targets/IDs/승인 정책/build Snapshot, nested 구조는 Writer/Mapper가 원문 근거 |
| revision/ownershipRevision | 명령 충돌과 소유 차수. 값·증가 여부를 권한 판단과 연결해야 함 |

## 경로별 모델

| 경로/키 | 주요 field와 타입 | 참조/Writer·Reader/수명 |
|---|---|---|
| authBindings/{authUid} | schemaVersion int, playerId/status string, linkedAt/updatedAt time | PlayerBindingStore 생성; Player와 원자 생성, UID→Player active mapping |
| players/{playerId} | schemaVersion int,status string,lastSeenAt time/null,createdAt/updatedAt time | PlayerBindingStore/PlayerActivity/Operator. 익명 bootstrap에서 생성하는 현재 구조 |
| operatorAssignments/{playerId} | status string(active 판정), 기타 권한 필드 전체는 운영 자료 필요 | OperatorAccess와 Rules lookup, client write 금지; 역할 부여 원본 별도 실사 |
| gameAccounts/{id} | ownerPlayerId/status/lookupCharacterName string,ownershipRevision int,characterIds list<string>,representativeCharacterId optional,createdAt/updatedAt time | VerificationGateway/ManualVerification 소유 기록, 이전 owner는 별도 relation ownershipLost |
| characters/{id} | ownerPlayerId/gameAccountId/status/rosterStatus/serverName/characterName/class string,ownershipRevision/characterLevel int,itemAvgLevel number/string 입력 정제,combatPower optional number,시각 | identity claim, summary/대표/activity·모든 파티 소유 검증. 표시값은 Snapshot과 구분 |
| characterIdentityClaims/{identityKey} | gameAccountId/characterId/serverName/characterName string,schemaVersion int,updatedAt time | 장비/수동 인증의 형제 Character mapping. identity rename/충돌 처리 미확정 |
| playerGameAccounts/{playerId_accountId} | playerId/gameAccountId/status string,schemaVersion int,updatedAt time | active/ownershipLost·account ownership 대조, 본인 local account 상태에 사용 |
| players/{p}/characterActivity/{characterId} | playerId/gameAccountId/characterId string,schemaVersion int,updatedAt time (현재 activity 저장은 이 최소 field) | ActivityCharactersRepository+CharacterActivityWritePlan. 대표 포함 검사, 변경4개씩 chunk; 전체 save 하나의 원자 단위 아님. 별도 projection는 아래 미연결 경로 구분 |
| players/{p}/groupMembershipState/current | activeGroupIds list<string>,activeGroupCount/revision/schemaVersion int,playerId string,updatedAt time | GroupCreate/Join/Leave 등 summary, membership/relation 동시 유지; active그룹 최대50 |
| players/{p}/groupRelations/{groupId} | groupId/playerId/relation string,requestStatus string/null,Snapshot string,sourceRevision int,expiresAt time/null,시각 | 내 그룹·초대·신청 목록용 projection. group membership·joinRelation과 결합 |
| recruitments/{r} | schemaVersion1/2 int,recruitmentId(v2),title/leaderPlayerId/raidId/difficultyId/status/visibility/currentCycleKey/targetCycleKey/currentCycleStatus string,groupId optional,memberPlayerIds list<string>,revision/count int,continueTogether/manualRecruitmentEnabled/hasAvailableSlot bool,주차/예약/생성/완료시각 | PartyCreateWritePlan base → AtomicCreateWritePlan v2 확장. public/group, active/completed/incompleteEnded/disbanded |
| recruitments v2 aggregate | partySlots list<map>,nonGroupMemberCount/pendingApplicationCount/pendingNonGroupApplicantCount int,raidStateTargets/commandTargets list<map>,lastCommandId/lastCommandType string/null,groupActiveRecruitmentCountAfter int | 각 slot:playerId/CharacterId/role/classKey,partyIndex/slotIndex,nonGroup bool,ownershipRevision optional. 최대8명 상태가 원본에 있음 |
| recruitments metadata | raidCatalogVersion/raidName/difficultyName/alias string,gateCount/partyCount/membersPerParty/supportsPerParty/maxDealersPerClassPerParty int,minItemLevel/minCombatPower optional number,approvalPolicy map,experience/maxPlayHours optional | catalog와 Snapshot. server에서 공유 카탈로그 버전과 요청 권한 field를 구분 |
| recruitments/{r}/members/{playerId} | Character/player ID,role/dealer-support,partyIndex/slotIndex int,joinedBy string,canApproveApplications bool,ownershipRevision optional int,Character/class/itemLevel/combatPower/gem/buildIntegrity Snapshot,joined/updated/changedAt | membership identity는 Player. Character 교체·리더·권한·aggregate와 원자 consistency |
| recruitments/{r}/applications/{playerId} | applicantPlayerId/characterId/raidId/cycleKey/status,revision int,ownershipRevision int?,build/role/Snapshot,vote 관련 fields,시각 | AtomicApplication/Join 계획. pending/rejected/withdrawn/approved/superseded 등 command 별 enum |
| recruitments/{r}/applications/{p}/votes/{voterPlayerId} | 과거 path,현재 Rules client write 거절 | Rules/read 호환 존재 여부와 실제 데이터 필요; SQL 현재 vote 저장으로 단정하지 않음 |
| recruitments/{r}/slots/{slotId} | legacy path | Rules client write 거절, aggregate slot과 혼재 실사 대상 |
| recruitments/{r}/cycles/{cycleKey} | 완료 회차 membership snapshot/status/완료시각 등 | Rules read와 lifecycle Reader, legacy writer 존재. 실제 v2 존재 비율 미확인 |
| players/{p}/raidStates/{characterId_raidId} | playerId/characterId/raidId/cycleKey/status string,recruitmentId optional,revision/ownershipRevision int?,schemaVersion,시각,availabilityAudit/prepare 관련 map/marker | v2 authoritative 점유/완료 상태 + 다음 주 audit/stub 호환. status active/completed와 계약별 availability 구조를 동일 모델로 축약하지 않음 |
| players/{p}/activeRaidAssignments/{cycle_character_raid} | playerId/characterId/raidId/recruitmentId/cycleKey/role string,시각 | legacy 점유 읽기/정리. 새 v2와 공존하는 현재 reader |
| players/{p}/weeklyRaidClaims/{cycle_character_raid} | characterId/raidId/cycleKey/playerId,source/status/recruitmentId·ownershipRevision optional,시각 | legacy 개인/파티 완료 Claim; 현재 Reader와 compatibility writer 보존 |
| partyEvents/{eventId} | schemaVersion,eventId/type/recruitmentId/cycleKey/raidId/difficultyId,actor/audiencePlayerIds list,targets list<map>,occurredAt/expiresAt time,payload 관련 map | shared event audience 기반 history/notification·명령 감사 연결. command eventId/dedup 관계 조사 |
| players/{p}/events/{eventId} | type/playerId/actorPlayerId,payload map,occurredAt/expiresAt/createdAt | legacy Player event와 manual dispute 알림, claim invalidation 트리거도 소비 |
| groups/{g} | schemaVersion/revision/memberCount/activeRecruitmentCount int,status/name/normalizedName/대표정보/leaderPlayerId string,hasActiveJoinCode/joinCodeVisibleToMembers bool,activeJoinCode string/null,created/updated/lastActivity/deletedAt | GroupCreateWritePlan. active/softDeleted,공개 요약/검색·마지막1인 해산; 최대50인 |
| groups/{g}/members/{playerId} | schemaVersion/revision/joinSequence int,groupId/playerId/role/joinedBy string,displayCharacterId/name/class/itemLevel/combatPower/gemSnapshot,시각 | leader/member,created/invitation/application/joinCode; projection는 actor 권한 근거가 아님 |
| groups/{g}/raidListings/{recruitmentId} | partyRaidListingDocument의 원본 모집 projection | dev에 존재,그룹별 목록·모든 관련 명령·backfill. 현재 source duplication 제거 완료로 기록하지 않음 |
| groups/{g}/joinRelations/{playerId} | groupId/targetPlayerId/requestedByPlayerId/kind/status string,Character Snapshot,applicationAttempt/revision int,created/expires/decided/updatedAt | invitation/application, Player relation과 동시 변경. 승인/거절/취소/차단/만료 |
| groups/{g}/applicantStats/{playerId} | playerId/groupId/schemaVersion/applicationCount,마지막 Character/전투정보 Snapshot,created/updatedAt | 신청 횟수와 joinRelation attempt 동일성 |
| groups/{g}/blockedPlayers/{playerId} | blockedByPlayerId/reason/대상 ID/Character Snapshot,applicationCountSnapshot,created/updatedAt | 운영 그룹장이 신청거절/수동 차단·해제. 전체 backend 관리자와 구분 |
| groupJoinCodes/{code} | schemaVersion,status/groupId/createdByPlayerId string,created/updatedAt | 코드 문서와 그룹 flags 원자 생성/폐기; get only, list 거절 |
| manualVerificationRequests/{requestId} | requesterPlayerId/targetIdentityKey/proofServer/Character/verificationCode/status/reviewedByOperatorPlayerId/previousOwnerPlayerId/defenseOfRequestId string optional,localAccountId int?,attempt counts int,created/expires/dispute/deadline times | pendingProof/approved/cancelled/blocked/awaitingOwnerResponse/defended/transferred/expired,운영자/기존 owner/workflow |
| manualVerificationBlocks/{blockId} | targetIdentityKey/requester 관계·status/reason·operator·시각 fields | Request 반복 제한,운영 해제 정책 필요; doc ID 계산은 Repository/Rules 원문 |
| accountVerificationChallenges/{id},activeAccountVerificationChallenges/{p} | Rules deny-all인 예약 경로 | 현 Gateway는 메모리 challenge; 운영에 실제 문서 있는지 미확인. active 서버 challenge로 오인 금지 |

필드명/타입의 정확한 분기별 전체 원문은 하단 Writer/Mapper field 증거 표로 추적한다. 위 대표 표는 하나의 universal schema로 선언한 것이 아니다. 예를 들어 create base schema1과 Atomic v2 override, optional ownershipRevision·null/missing display,availability 전용 state를 구분해야 한다.

## 저장 준비만 있고 실행 연결이 없는 projection

`players/{p}/activityCharacterProjections/{characterId}`는 loadProjections reader와 projectionDocumentsByCharacterId generator에 존재한다. fields는 Character/display names,itemLevel/combatPower,displayOrder int,isRepresentative bool,updatedAt 등이다. 그러나 현재 save는 documentsByCharacterId(최소 activity membership)만 쓰고 projectionDocumentsByCharacterId를 저장하지 않으며 lib 실행 소비자가 loadProjections를 호출한 위치도 찾지 못했다. 현재 Rules에 이 projection match도 없다. 소스 준비 모델이며 운영 데이터 존재·작동 API로 확정하지 않는다. 신규 서버 요구로 채택할지는 결정 대상이다.

## 관계와 원자 갱신 단위

AuthBinding→Player→gameAccount ownership→Character, identity claim→gameAccount/Character, Player↔group member↔group summary/relation, recruitment→member/aggregate→Player raidState가 핵심 참조다. shared event는 audience/target ID를 통해 이력·알림으로 연결된다. PostgreSQL 관계·제약 후보는 이 관계를 보장하는 요구이며 실제 table schema는 후속 산출이다.

GroupCreate는 group/member/Player membershipState/Player relation 네 문서 동시 생성이다. PartyAtomic command는 original aggregate,member,state,event,group count,listing,guard/revision 등 명령별 동시 갱신이다. 요청 종류별 읽기/쓰기 전체 위치는01에 있다. getAfter 검증을 각 document CRUD 성공으로 치환하면 중간 상태를 허용할 수 있다.

activity save4개씩,stale state cleanup→create 두 Transaction,advance preflight,manual 분쟁 만료·소유권 이전은 다단계다. 데이터 dump만으로 진행 중 command와 local journal을 식별할 수 없으므로 [07](07-migration-risks.md)의 중도 실패 위험을 적용한다.

## 주요 쿼리

공개 recruitments: schemaVersion2/visibility public/status active/manualRecruitmentEnabled true/hasAvailableSlot true/targetCycleKey=current,updatedAt desc + doc ID desc,limit/next page startAfterDocument. 내 active 방은 leader query와 memberPlayerIds arrayContains query를 합친다. 내 신청은 collectionGroup applications에 applicantPlayerId/cycleKey/schemaVersion와 updatedAt desc다.

그룹별 raidListings는 전체 snapshots 후 current/target cycle·본인 방 제외/합치기·정렬을 로컬 처리한다. 그룹 검색은 status active와 normalizedName 또는 normalizedRepresentativeCharacterName prefix 범위,문서 ID 순서/limit; 기본 최근 그룹은 lastActivityAt desc다. exact Character search는 status/name·doc ID,소유 Character 조회는 ownerPlayerId다.

주간 status는 Player 하위 세 경로를 cycleKey로 조회 후 ownership 참조를 합친다. partyEvents는 audiencePlayerIds contains Player + occurredAt asc/desc. manual requests는 requester·previousOwner·status·targetIdentityKey 등 조회 후 일부 상태/만료를 로컬에서 필터한다. 운영 목록은 lastSeenAt 정렬 전 legacy patch 수행.

로컬 index 선언은 하단 전수 표. 배포 여부는 미확인이고 fieldOverrides=[]다. Firestore 자동 single-field index나 query가 실제로 통과한 사실까지 이 파일에서 추론하지 않는다. 신규 SQL index를 그대로 복제하지 말고 API 조회/정렬·동시성 계획을 기반으로 설계한다.

## 로컬 데이터 경계

`AccountDatabase`는 GameAccounts/AccountCharacters/CharacterBuildSnapshots/RaidHistoryEntries/PartyNotificationReceipts와 각 설정 테이블을 가진다. server IDs와 local int IDs를 병행 보관하고 rawJson build/읽음/표시 override는 local-only다. exact table/field는 AccountDatabase 소스,참조 경로는05. Firestore의 group/party Snapshot만으로 local build나 API token을 복원할 수 없다.

## 선언된 복합 인덱스 전수
근거: [firestore.indexes.json](../../firestore.indexes.json). 운영 배포 상태는 미확인.

| 번호 | collectionGroup / scope | field 순서 및 mode |
|---|---|---|
| 1 | recruitments / COLLECTION | visibility:ASCENDING, status:ASCENDING, manualRecruitmentEnabled:ASCENDING, hasAvailableSlot:ASCENDING, targetCycleKey:ASCENDING, schemaVersion:ASCENDING, updatedAt:DESCENDING, __name__:DESCENDING |
| 2 | recruitments / COLLECTION | leaderPlayerId:ASCENDING, status:ASCENDING, schemaVersion:ASCENDING |
| 3 | recruitments / COLLECTION | memberPlayerIds:CONTAINS, status:ASCENDING, schemaVersion:ASCENDING |
| 4 | applications / COLLECTION_GROUP | applicantPlayerId:ASCENDING, cycleKey:ASCENDING, schemaVersion:ASCENDING, updatedAt:DESCENDING |
| 5 | groups / COLLECTION | status:ASCENDING, normalizedName:ASCENDING, __name__:ASCENDING |
| 6 | groups / COLLECTION | status:ASCENDING, normalizedRepresentativeCharacterName:ASCENDING, __name__:ASCENDING |
| 7 | groups / COLLECTION | status:ASCENDING, lastActivityAt:DESCENDING, __name__:DESCENDING |
| 8 | groupRelations / COLLECTION | relation:ASCENDING, updatedAt:DESCENDING |
| 9 | joinRelations / COLLECTION | kind:ASCENDING, status:ASCENDING, createdAt:ASCENDING |
| 10 | characters / COLLECTION | status:ASCENDING, characterName:ASCENDING, __name__:ASCENDING |
| 11 | characters / COLLECTION | status:ASCENDING, ownerPlayerId:ASCENDING, __name__:ASCENDING |
| 12 | partyEvents / COLLECTION | audiencePlayerIds:CONTAINS, occurredAt:ASCENDING |
| 13 | partyEvents / COLLECTION | audiencePlayerIds:CONTAINS, occurredAt:DESCENDING |
| 14 | manualVerificationRequests / COLLECTION | requesterPlayerId:ASCENDING, createdAt:DESCENDING |
| 15 | manualVerificationRequests / COLLECTION | status:ASCENDING, createdAt:ASCENDING |
| 16 | manualVerificationRequests / COLLECTION | requesterPlayerId:ASCENDING, targetIdentityKey:ASCENDING, status:ASCENDING |

## Rules 경로 전수 위치
아래 path는 상대 match 표기이며 부모 scope와 함께 해석한다. match 선언 자체가 문서 존재의 증거는 아니다.

| Rules 행 | 상대 match 선언 |
|---|---|
| 3 | `match /databases/{database}/documents {` |
| 1036 | `match /authBindings/{authUid} {` |
| 1063 | `match /operatorAssignments/{playerId} {` |
| 1067 | `match /players/{playerId} {` |
| 1123 | `match /activeRaidAssignments/{assignmentId} {` |
| 1177 | `match /events/{eventId} {` |
| 1221 | `match /groupMembershipState/{docId} {` |
| 1373 | `match /groupRelations/{groupId} {` |
| 1498 | `match /weeklyRaidClaims/{claimId} {` |
| 1571 | `match /raidStates/{stateId} {` |
| 1862 | `match /characterActivity/{characterId} {` |
| 1944 | `match /accountVerificationChallenges/{challengeId} {` |
| 1947 | `match /activeAccountVerificationChallenges/{playerId} {` |
| 1950 | `match /manualVerificationRequests/{requestId} {` |
| 2213 | `match /manualVerificationBlocks/{blockId} {` |
| 2320 | `match /gameAccounts/{gameAccountId} {` |
| 2334 | `match /characters/{characterId} {` |
| 2350 | `match /characterIdentityClaims/{claimId} {` |
| 2353 | `match /playerGameAccounts/{ownershipId} {` |
| 2428 | `match /partyEvents/{eventId} {` |
| 2460 | `match /recruitments/{recruitmentId} {` |
| 2918 | `match /members/{playerId} {` |
| 3182 | `match /slots/{slotId} {` |
| 3187 | `match /applications/{playerId} {` |
| 3371 | `match /votes/{voterPlayerId} {` |
| 3376 | `match /cycles/{cycleKey} {` |
| 3381 | `match /groups/{groupId} {` |
| 3635 | `match /members/{playerId} {` |
| 3842 | `match /raidListings/{recruitmentId} {` |
| 3884 | `match /joinRelations/{playerId} {` |
| 4004 | `match /applicantStats/{playerId} {` |
| 4049 | `match /blockedPlayers/{playerId} {` |
| 4087 | `match /groupJoinCodes/{code} {` |
| 4130 | `match /{path=**}/applications/{applicantPlayerId} {` |

## 필드별 Writer·Mapper·DTO source 근거
이 표는 정적 literal key 수집이다. 같은 파일에서 field마다 첫 writer expression과 첫 reader/cast 표현을 보존한다. patch/map spread와 helper keys까지 canonical 문서에 합쳐졌다고 가정하지 않는다. 식만으로 타입을 확정할 수 없으면 미확인이다. 위 경로 표의 Writer·Reader와 함께 사용한다. enum 문자열/동적 nested keys는 원문을 확인한다.

### lib/features/account/data/dtos/activity_character_projection_dto.dart
근거: [lib/features/account/data/dtos/activity_character_projection_dto.dart](../../lib/features/account/data/dtos/activity_character_projection_dto.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L42 `characterClassName: data['characterClassName'] as String,` |
| `characterId` | — (이 파일에서 미추출) | L30 `final characterId = data['characterId'] as String;` |
| `characterName` | — (이 파일에서 미추출) | L40 `characterName: data['characterName'] as String,` |
| `combatPower` | — (이 파일에서 미추출) | L46 `combatPower: _asOptionalDouble(data['combatPower']),` |
| `displayOrder` | — (이 파일에서 미추출) | L43 `displayOrder: _asInt(data['displayOrder']),` |
| `isRepresentative` | — (이 파일에서 미추출) | L44 `isRepresentative: data['isRepresentative'] as bool,` |
| `itemLevel` | — (이 파일에서 미추출) | L45 `itemLevel: _asOptionalDouble(data['itemLevel']),` |
| `playerId` | — (이 파일에서 미추출) | L38 `playerId: data['playerId'] as String,` |
| `schemaVersion` | — (이 파일에서 미추출) | L37 `schemaVersion: _asInt(data['schemaVersion']),` |
| `serverName` | — (이 파일에서 미추출) | L41 `serverName: data['serverName'] as String,` |

### lib/features/account/data/dtos/character_activity_document_dto.dart
근거: [lib/features/account/data/dtos/character_activity_document_dto.dart](../../lib/features/account/data/dtos/character_activity_document_dto.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | — (이 파일에서 미추출) | L18 `final characterId = data['characterId'] as String;` |
| `gameAccountId` | — (이 파일에서 미추출) | L26 `gameAccountId: data['gameAccountId'] as String,` |
| `playerId` | — (이 파일에서 미추출) | L24 `playerId: data['playerId'] as String,` |
| `schemaVersion` | — (이 파일에서 미추출) | L23 `schemaVersion: _asInt(data['schemaVersion']),` |

### lib/features/account/data/dtos/character_profile_dto.g.dart
근거: [lib/features/account/data/dtos/character_profile_dto.g.dart](../../lib/features/account/data/dtos/character_profile_dto.g.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `CharacterClassName` | — (이 파일에서 미추출) | L14 `characterClassName: json['CharacterClassName'] as String,` |
| `CharacterLevel` | — (이 파일에서 미추출) | L13 `characterLevel: (json['CharacterLevel'] as num).toInt(),` |
| `CharacterName` | — (이 파일에서 미추출) | L12 `characterName: json['CharacterName'] as String,` |
| `CombatPower` | — (이 파일에서 미추출) | L16 `combatPower: json['CombatPower'] as String?,` |
| `ItemAvgLevel` | — (이 파일에서 미추출) | L15 `itemAvgLevel: json['ItemAvgLevel'] as String?,` |
| `ServerName` | — (이 파일에서 미추출) | L11 `serverName: json['ServerName'] as String,` |

### lib/features/account/data/dtos/sibling_character_dto.g.dart
근거: [lib/features/account/data/dtos/sibling_character_dto.g.dart](../../lib/features/account/data/dtos/sibling_character_dto.g.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `CharacterClassName` | — (이 파일에서 미추출) | L14 `characterClassName: json['CharacterClassName'] as String,` |
| `CharacterLevel` | — (이 파일에서 미추출) | L13 `characterLevel: (json['CharacterLevel'] as num).toInt(),` |
| `CharacterName` | — (이 파일에서 미추출) | L12 `characterName: json['CharacterName'] as String,` |
| `ItemAvgLevel` | — (이 파일에서 미추출) | L15 `itemAvgLevel: json['ItemAvgLevel'] as String?,` |
| `ServerName` | — (이 파일에서 미추출) | L11 `serverName: json['ServerName'] as String,` |

### lib/features/account/data/dtos/weekly_raid_claim_dto.dart
근거: [lib/features/account/data/dtos/weekly_raid_claim_dto.dart](../../lib/features/account/data/dtos/weekly_raid_claim_dto.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | — (이 파일에서 미추출) | L36 `characterId: data['characterId'] as String,` |
| `completedAt` | — (이 파일에서 미추출) | L45 `completedAt: data['completedAt'],` |
| `cycleEndsAt` | — (이 파일에서 미추출) | L48 `cycleEndsAt: data['cycleEndsAt'],` |
| `cycleKey` | — (이 파일에서 미추출) | L38 `cycleKey: data['cycleKey'] as String,` |
| `cycleStartedAt` | — (이 파일에서 미추출) | L47 `cycleStartedAt: data['cycleStartedAt'],` |
| `difficultyId` | — (이 파일에서 미추출) | L39 `difficultyId: data['difficultyId'] as String,` |
| `playerId` | — (이 파일에서 미추출) | L35 `playerId: data['playerId'] as String,` |
| `raidId` | — (이 파일에서 미추출) | L37 `raidId: data['raidId'] as String,` |
| `schemaVersion` | — (이 파일에서 미추출) | L34 `schemaVersion: _asInt(data['schemaVersion']),` |
| `source` | — (이 파일에서 미추출) | L40 `source: data['source'] as String,` |
| `sourceCompletionRevision` | — (이 파일에서 미추출) | L42 `sourceCompletionRevision: data['sourceCompletionRevision'] == null` |
| `sourceRecruitmentId` | — (이 파일에서 미추출) | L41 `sourceRecruitmentId: data['sourceRecruitmentId'] as String?,` |
| `updatedAt` | — (이 파일에서 미추출) | L46 `updatedAt: data['updatedAt'],` |

### lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart
근거: [lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart](../../lib/features/account/data/gateways/firestore_account_ownership_status_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `ownerPlayerId` | — (이 파일에서 미추출) | L83 `return accountData?['ownerPlayerId'] == playerId` |
| `playerId` | — (이 파일에서 미추출) | L30 `final playerId = bindingData?['playerId'];` |
| `status` | — (이 파일에서 미추출) | L32 `bindingData?['status'] != 'active' \|\|` |

### lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `combatPower` | L69 `entry.value,` | L67 `if (data?['combatPower'] == entry.value) return;` |
| `gameAccountId` | — (이 파일에서 미추출) | L52 `final accountId = data?['gameAccountId'];` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L54 `data?['ownerPlayerId'] != playerId \|\|` |
| `playerId` | — (이 파일에서 미추출) | L37 `final playerId = binding.data()?['playerId'];` |
| `status` | — (이 파일에서 미추출) | L38 `if (binding.data()?['status'] != 'active' \|\|` |
| `updatedAt` | L70 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |

### lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `buildIntegritySnapshot` | — (이 파일에서 미추출) | L85 `existingRaw: data?['buildIntegritySnapshot'],` |
| `checkedAt` | — (이 파일에서 미추출) | L118 `fields['checkedAt'] = Timestamp.fromDate(next.checkedAt.toUtc());` |
| `combatPower` | — (이 파일에서 미추출) | L81 `if (combatPower != null && data?['combatPower'] != combatPower) {` |
| `gameAccountId` | — (이 파일에서 미추출) | L58 `final accountId = data?['gameAccountId'];` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L77 `!_sameItemLevel(data?['itemAvgLevel'], itemLevel)) {` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L60 `data?['ownerPlayerId'] != playerId \|\|` |
| `playerId` | — (이 파일에서 미추출) | L43 `final playerId = binding.data()?['playerId'];` |
| `status` | — (이 파일에서 미추출) | L44 `if (binding.data()?['status'] != 'active' \|\|` |
| `updatedAt` | — (이 파일에서 미추출) | L92 `updates['updatedAt'] = FieldValue.serverTimestamp();` |

### lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_character_summary_sync_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterLevel` | L65 `patch.characterLevel,` | — (이 파일에서 미추출) |
| `characterName` | L64 `patch.characterName,` | — (이 파일에서 미추출) |
| `itemAvgLevel` | L66 `patch.itemAvgLevel,` | — (이 파일에서 미추출) |
| `lastSummaryFetchedAt` | L67 `Timestamp.fromDate(patch.fetchedAt.toUtc()),` | L57 `final existingFetchedAt = data?['lastSummaryFetchedAt'];` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L50 `if (data?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L27 `final playerId = binding.data()?['playerId'];` |
| `status` | — (이 파일에서 미추출) | L53 `if (data?['status'] != 'active') {` |
| `updatedAt` | L68 `now,` | — (이 파일에서 미추출) |

### lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart
근거: [lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart](../../lib/features/account/data/gateways/firestore_representative_character_sync_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `gameAccountId` | — (이 파일에서 미추출) | L122 `characterData?['gameAccountId'] != gameAccountId \|\|` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L121 `characterData?['ownerPlayerId'] != playerId \|\|` |
| `playerId` | — (이 파일에서 미추출) | L141 `data['playerId'] != playerId \|\|` |
| `representativeCharacterId` | L66 `characterId,` | L45 `final current = _string(ownershipData?['representativeCharacterId']);` |
| `representativeCharacterUpdatedAt` | L67 `FieldValue.serverTimestamp(),` | L48 `ownershipData?['representativeCharacterUpdatedAt'],` |
| `status` | — (이 파일에서 미추출) | L123 `characterData?['status'] != 'active') {` |

### lib/features/account/data/gateways/local_game_account_verification_gateway.dart
근거: [lib/features/account/data/gateways/local_game_account_verification_gateway.dart](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `ArmoryEquipment` | — (이 파일에서 미추출) | L139 `final rawItems = armory['ArmoryEquipment'];` |
| `Grade` | — (이 파일에서 미추출) | L148 `final grade = raw['Grade'];` |
| `Name` | — (이 파일에서 미추출) | L147 `final name = raw['Name'];` |
| `Type` | — (이 파일에서 미추출) | L144 `final type = raw['Type'];` |
| `characterClassName` | L283 `sibling.characterClassName,` | — (이 파일에서 미추출) |
| `characterId` | L293 `characterRef.id,` | L221 `final characterId = claims[index].data()?['characterId'];` |
| `characterIds` | L263 `allCharacterIds.toList(growable: false),` | L215 `(account?.data()?['characterIds'] as List?)` |
| `characterLevel` | L284 `sibling.characterLevel,` | — (이 파일에서 미추출) |
| `characterName` | L282 `sibling.characterName,` | — (이 파일에서 미추출) |
| `chest` | L33 `'상의',` | — (이 파일에서 미추출) |
| `createdAt` | L264 `account?.data()?['createdAt'] ?? now,` | L264 `'createdAt': account?.data()?['createdAt'] ?? now,` |
| `gameAccountId` | L278 `accountRef.id,` | L194 `.map((snapshot) => snapshot.data()?['gameAccountId'])` |
| `hands` | L35 `'장갑',` | — (이 파일에서 미추출) |
| `head` | L31 `'투구',` | — (이 파일에서 미추출) |
| `itemAvgLevel` | L285 `sibling.itemAvgLevel,` | — (이 파일에서 미추출) |
| `legs` | L34 `'하의',` | — (이 파일에서 미추출) |
| `lookupCharacterName` | L262 `challenge.characterName,` | — (이 파일에서 미추출) |
| `ownerPlayerId` | L250 `playerId,` | L209 `final previousOwner = account?.data()?['ownerPlayerId'];` |
| `ownershipRevision` | L251 `ownership.nextRevision,` | — (이 파일에서 미추출) |
| `playerId` | L312 `playerId,` | L181 `final playerId = binding.data()?['playerId'];` |
| `rosterStatus` | L252 `'missingFromLatestRoster',` | — (이 파일에서 미추출) |
| `schemaVersion` | L258 `1,` | — (이 파일에서 미추출) |
| `serverName` | L281 `sibling.serverName,` | — (이 파일에서 미추출) |
| `shoulders` | L32 `'어깨',` | — (이 파일에서 미추출) |
| `status` | L261 `'active',` | L183 `binding.data()?['status'] != 'active' \|\|` |
| `updatedAt` | L253 `now,` | — (이 파일에서 미추출) |
| `weapon` | L30 `'무기',` | — (이 파일에서 미추출) |

### lib/features/account/data/mappers/character_activity_write_plan.dart
근거: [lib/features/account/data/mappers/character_activity_write_plan.dart](../../lib/features/account/data/mappers/character_activity_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | L96 `character.characterClassName,` | — (이 파일에서 미추출) |
| `characterId` | L51 `characterId,` | — (이 파일에서 미추출) |
| `characterName` | L94 `character.characterName,` | — (이 파일에서 미추출) |
| `combatPower` | L98 `character.combatPower,` | — (이 파일에서 미추출) |
| `displayOrder` | L99 `displayOrder,` | — (이 파일에서 미추출) |
| `gameAccountId` | L52 `byId[characterId]!.gameAccountId,` | — (이 파일에서 미추출) |
| `isRepresentative` | L100 `character.isAccountRepresentative,` | — (이 파일에서 미추출) |
| `itemLevel` | L97 `character.itemLevel,` | — (이 파일에서 미추출) |
| `playerId` | L50 `playerId,` | — (이 파일에서 미추출) |
| `schemaVersion` | L49 `schemaVersion,` | — (이 파일에서 미추출) |
| `serverName` | L95 `character.serverName,` | — (이 파일에서 미추출) |
| `updatedAt` | L53 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/account/data/mappers/character_build_analysis_mapper.dart
근거: [lib/features/account/data/mappers/character_build_analysis_mapper.dart](../../lib/features/account/data/mappers/character_build_analysis_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `ArkGrid` | — (이 파일에서 미추출) | L76 `json['ArkGrid'],` |
| `ArkPassive` | — (이 파일에서 미추출) | L25 `final activePassiveNames = _parseActivePassiveNames(json['ArkPassive']);` |
| `ArmoryGem` | — (이 파일에서 미추출) | L47 `json['ArmoryGem'],` |
| `ArmoryProfile` | — (이 파일에서 미추출) | L27 `_map(json['ArmoryProfile'])?['CharacterClassName'] as String?;` |
| `ArmorySkills` | — (이 파일에서 미추출) | L15 `final skills = _mapList(json['ArmorySkills']);` |
| `CharacterClassName` | — (이 파일에서 미추출) | L27 `_map(json['ArmoryProfile'])?['CharacterClassName'] as String?;` |
| `Description` | — (이 파일에서 미추출) | L361 `final descriptions = _stringList(skill['Description']);` |
| `Effects` | — (이 파일에서 미추출) | L74 `_map(armoryGem?['Effects'])?['Skills'] is List;` |
| `GemSlot` | — (이 파일에서 미추출) | L350 `final slot = skill['GemSlot'];` |
| `Gems` | — (이 파일에서 미추출) | L70 `final equippedGemCount = armoryGem?['Gems'] is List` |
| `Grade` | — (이 파일에서 미추출) | L243 `final grade = slot['Grade'];` |
| `Level` | — (이 파일에서 미추출) | L339 `final level = gem['Level'];` |
| `Name` | — (이 파일에서 미추출) | L17 `.map((skill) => skill['Name'])` |
| `Point` | — (이 파일에서 미추출) | L244 `final point = slot['Point'];` |
| `Rune` | — (이 파일에서 미추출) | L20 `final runeCount = skills.where((skill) => skill['Rune'] is Map).length;` |
| `Skills` | — (이 파일에서 미추출) | L74 `_map(armoryGem?['Effects'])?['Skills'] is List;` |
| `Slot` | — (이 파일에서 미추출) | L338 `final slot = gem['Slot'];` |
| `Slots` | — (이 파일에서 미추출) | L241 `for (final slot in _mapList(gridMap?['Slots'])) {` |
| `Tooltip` | — (이 파일에서 미추출) | L363 `gemsBySlot[slot]?['Tooltip'],` |
| `type` | — (이 파일에서 미추출) | L507 `if (elementMap?['type'] != 'ItemPartBox') {` |
| `value` | — (이 파일에서 미추출) | L510 `final strings = _flattenStrings(elementMap?['value'])` |

### lib/features/account/data/repositories/firestore_activity_characters_repository.dart
근거: [lib/features/account/data/repositories/firestore_activity_characters_repository.dart](../../lib/features/account/data/repositories/firestore_activity_characters_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L310 `characterClassName: data['characterClassName'] as String? ?? '',` |
| `characterId` | — (이 파일에서 미추출) | L162 `existing['characterId'] == target['characterId'] &&` |
| `characterName` | — (이 파일에서 미추출) | L308 `characterName: data['characterName'] as String? ?? '',` |
| `combatPower` | — (이 파일에서 미추출) | L312 `combatPower: _optionalNumber(data['combatPower']),` |
| `gameAccountId` | — (이 파일에서 미추출) | L163 `existing['gameAccountId'] == target['gameAccountId'] &&` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L311 `itemLevel: _optionalNumber(data['itemLevel'] ?? data['itemAvgLevel']),` |
| `itemLevel` | — (이 파일에서 미추출) | L311 `itemLevel: _optionalNumber(data['itemLevel'] ?? data['itemAvgLevel']),` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L301 `ownerPlayerId: data['ownerPlayerId'] as String? ?? '',` |
| `playerId` | — (이 파일에서 미추출) | L161 `existing['playerId'] == target['playerId'] &&` |
| `representativeCharacterId` | — (이 파일에서 미추출) | L296 `final representative = ownership?['representativeCharacterId'];` |
| `schemaVersion` | — (이 파일에서 미추출) | L160 `return existing['schemaVersion'] == target['schemaVersion'] &&` |
| `serverName` | — (이 파일에서 미추출) | L309 `serverName: data['serverName'] as String? ?? '',` |
| `status` | — (이 파일에서 미추출) | L243 `if (binding.data()?['status'] != 'active' \|\|` |
| `updatedAt` | — (이 파일에서 미추출) | L164 `existing['updatedAt'] is Timestamp;` |

### lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `canApproveApplications` | L343 `true, 'updatedAt': now},` | — (이 파일에서 미추출) |
| `characterId` | L378 `command.characterId,` | L261 `memberData?['characterId'] != command.characterId \|\|` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L314 `: nextLeaderData?['characterNameSnapshot'] as String?;` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L317 `: nextLeaderData?['classNameSnapshot'] as String?;` |
| `completedAt` | L385 `now,` | — (이 파일에서 미추출) |
| `cycleEndsAt` | L384 `Timestamp.fromDate(command.cycleEndsAt.toUtc()),` | — (이 파일에서 미추출) |
| `cycleKey` | L381 `command.cycleKey,` | L287 `applicationData?['cycleKey'] == command.cycleKey &&` |
| `cycleStartedAt` | L383 `Timestamp.fromDate(command.cycleStartedAt.toUtc()),` | — (이 파일에서 미추출) |
| `dealerCount` | — (이 파일에서 미추출) | L322 `dealerCount: r['dealerCount'] as int,` |
| `decidedAt` | L371 `now,` | — (이 파일에서 미추출) |
| `difficultyId` | L380 `command.difficultyId,` | L359 `difficultyId: r['difficultyId'] as String?,` |
| `groupId` | — (이 파일에서 미추출) | L297 `groupId: recruitmentData?['groupId'],` |
| `leaderCharacterNameSnapshot` | — (이 파일에서 미추출) | L313 `? r['leaderCharacterNameSnapshot'] as String?` |
| `leaderClassNameSnapshot` | — (이 파일에서 미추출) | L316 `? r['leaderClassNameSnapshot'] as String?` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L270 `if (recruitmentData?['leaderPlayerId'] == command.playerId &&` |
| `maxMemberCount` | — (이 파일에서 미추출) | L325 `maxMemberCount: r['maxMemberCount'] as int,` |
| `memberCount` | — (이 파일에서 미추출) | L321 `memberCount: r['memberCount'] as int,` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L268 `recruitmentData?['memberPlayerIds'] as List,` |
| `partyIndex` | — (이 파일에서 미추출) | L360 `partyIndex: m['partyIndex'] as int?,` |
| `playerId` | L377 `command.playerId,` | — (이 파일에서 미추출) |
| `raidId` | L379 `command.raidId,` | L262 `recruitmentData?['raidId'] != command.raidId) {` |
| `recruitmentId` | — (이 파일에서 미추출) | L246 `final recruitmentId = assignmentData?['recruitmentId'];` |
| `resolutionReason` | L369 `'weeklyRaidCompleted',` | — (이 파일에서 미추출) |
| `revision` | L370 `FieldValue.increment(1),` | L326 `revision: r['revision'] as int,` |
| `role` | — (이 파일에서 미추출) | L324 `targetRole: m['role'] as String,` |
| `schemaVersion` | L376 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | — (이 파일에서 미추출) | L361 `slotIndex: m['slotIndex'] as int?,` |
| `source` | L382 `'manual',` | — (이 파일에서 미추출) |
| `status` | L368 `'superseded',` | L260 `recruitmentData?['status'] != 'active' \|\|` |
| `supportCount` | — (이 파일에서 미추출) | L323 `supportCount: r['supportCount'] as int,` |
| `title` | — (이 파일에서 미추출) | L421 `activeRecruitmentTitle = data?['title'] as String?;` |
| `type` | — (이 파일에서 미추출) | L129 `final type = change.doc.data()?['type'];` |
| `updatedAt` | L372 `now,` | — (이 파일에서 미추출) |

### lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | L606 `groupCountAfter!,` | L499 `final count = group.data()?['activeRecruitmentCount'];` |
| `actorPlayerId` | L552 `command.playerId,` | — (이 파일에서 미추출) |
| `applicantPlayerId` | — (이 파일에서 미추출) | L947 `applicationData['applicantPlayerId'] != command.playerId \|\|` |
| `audiencePlayerIds` | L551 `[command.playerId],` | — (이 파일에서 미추출) |
| `characterId` | L230 `command.characterId,` | L411 `assignmentData['characterId'] != command.characterId \|\|` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L481 `final characterName = successorData['characterNameSnapshot'];` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L482 `final className = successorData['classNameSnapshot'];` |
| `commandId` | L549 `eventId,` | — (이 파일에서 미추출) |
| `commandRevision` | L550 `aggregate.revision + 1,` | — (이 파일에서 미추출) |
| `commandTargets` | L559 `[` | — (이 파일에서 미추출) |
| `completedAt` | L242 `now,` | — (이 파일에서 미추출) |
| `continueTogether` | — (이 파일에서 미추출) | L1142 `recruitmentContinuesTogether: recruitment?['continueTogether'] == true,` |
| `countedAsNonGroupApplicant` | — (이 파일에서 미추출) | L967 `applicationData['countedAsNonGroupApplicant'] == true;` |
| `currentCycleKey` | — (이 파일에서 미추출) | L434 `raw['currentCycleKey'] != command.cycleKey \|\|` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L432 `raw['currentCycleStatus'] != 'active' \|\|` |
| `cycleEndsAt` | L241 `Timestamp.fromDate(command.cycleEndsAt.toUtc()),` | L1133 `final rawCycleEndsAt = recruitment?['cycleEndsAt'];` |
| `cycleKey` | L233 `command.cycleKey,` | L175 `final stateCycleKey = stateData['cycleKey'] as String;` |
| `cycleStartedAt` | L238 `Timestamp.fromDate(` | — (이 파일에서 미추출) |
| `dealerCount` | L535 `0,` | — (이 파일에서 미추출) |
| `decidedAt` | L979 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `difficultyId` | L232 `command.difficultyId,` | — (이 파일에서 미추출) |
| `eventId` | L546 `eventId,` | — (이 파일에서 미추출) |
| `gameAccountId` | — (이 파일에서 미추출) | L1004 `final accountId = character?['gameAccountId'];` |
| `groupActiveRecruitmentCountAfter` | L540 `?groupCountAfter,` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L532 `false,` | — (이 파일에서 미추출) |
| `lastCommandActorPlayerId` | L570 `command.playerId,` | — (이 파일에서 미추출) |
| `lastCommandAt` | L571 `now,` | — (이 파일에서 미추출) |
| `lastCommandId` | L568 `eventId,` | — (이 파일에서 미추출) |
| `lastCommandType` | L569 `PartyAtomicCommandType.personalComplete.name,` | — (이 파일에서 미추출) |
| `lastRecruitmentId` | L607 `aggregate.recruitmentId,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | — (이 파일에서 미추출) | L848 `isLeader = data['leaderPlayerId'] == command.playerId;` |
| `manualRecruitmentEnabled` | L531 `false,` | — (이 파일에서 미추출) |
| `maxDealersPerClassPerParty` | — (이 파일에서 미추출) | L1224 `maxDealersPerClassPerParty: data['maxDealersPerClassPerParty'] as int,` |
| `memberCount` | L534 `0,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L533 `const <String>[],` | L850 `data['memberPlayerIds'] as List? ?? const [],` |
| `membersPerParty` | — (이 파일에서 미추출) | L1222 `membersPerParty: data['membersPerParty'] as int,` |
| `nonGroupMemberCount` | L539 `0,` | — (이 파일에서 미추출) |
| `occurredAt` | L555 `now,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L227 `ownership.revision,` | L438 `? memberData['ownershipRevision']` |
| `partyCount` | — (이 파일에서 미추출) | L1221 `partyCount: data['partyCount'] as int,` |
| `partySlots` | L537 `const <Map<String, Object?>>[],` | — (이 파일에서 미추출) |
| `pendingApplicationCount` | L969 `FieldValue.increment(-1),` | — (이 파일에서 미추출) |
| `pendingNonGroupApplicantCount` | L971 `FieldValue.increment(-1),` | — (이 파일에서 미추출) |
| `playerId` | L229 `command.playerId,` | L410 `(assignmentData['playerId'] != command.playerId \|\|` |
| `raidId` | L231 `command.raidId,` | L366 `recruitmentData['raidId'] != command.raidId) {` |
| `raidStateTargets` | L538 `const <Map<String, Object?>>[],` | — (이 파일에서 미추출) |
| `reason` | L554 `'weeklyRaidCompleted',` | L524 `..['reason'] = 'weeklyRaidCompleted';` |
| `recruitmentId` | L236 `null,` | L405 `final recruitmentId = stateData['recruitmentId'];` |
| `resolutionReason` | L977 `'weeklyRaidCompleted',` | — (이 파일에서 미추출) |
| `revision` | L237 `1,` | L436 `raw['revision'] != command.observation?.recruitmentRevision \|\|` |
| `schemaVersion` | L228 `1,` | L430 `raw['schemaVersion'] != 2 \|\|` |
| `source` | L235 `'manual',` | L783 `if (stateData['source'] != 'party') {` |
| `stateId` | L562 `PartyRaidState.documentIdFor(` | — (이 파일에서 미추출) |
| `status` | L234 `'completed',` | L177 `if (stateData['status'] != 'completed' \|\|` |
| `supportCount` | L536 `0,` | — (이 파일에서 미추출) |
| `supportsPerParty` | — (이 파일에서 미추출) | L1223 `supportsPerParty: data['supportsPerParty'] as int,` |
| `targetPlayerId` | L553 `command.playerId,` | — (이 파일에서 미추출) |
| `title` | — (이 파일에서 미추출) | L847 `title = data['title'] as String?;` |
| `type` | L548 `'memberLeft',` | — (이 파일에서 미추출) |
| `updatedAt` | L243 `now,` | L944 `applicationData['updatedAt'] != candidate.observed['updatedAt'] \|\|` |

### lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart
근거: [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | — (이 파일에서 미추출) | L172 `final characterId = data['characterId'];` |
| `cycleKey` | — (이 파일에서 미추출) | L249 `data['cycleKey'] != cycleKey \|\|` |
| `ownershipRevision` | — (이 파일에서 미추출) | L231 `? data['ownershipRevision']` |
| `playerId` | — (이 파일에서 미추출) | L248 `if (data['playerId'] != playerId \|\|` |
| `raidId` | — (이 파일에서 미추출) | L173 `final raidId = data['raidId'];` |
| `recruitmentId` | — (이 파일에서 미추출) | L195 `recruitmentId: data['recruitmentId'] as String?,` |
| `status` | — (이 파일에서 미추출) | L174 `final status = data['status'];` |

### lib/features/group/data/mappers/group_active_recruitment_write_plan.dart
근거: [lib/features/group/data/mappers/group_active_recruitment_write_plan.dart](../../lib/features/group/data/mappers/group_active_recruitment_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | L15 `currentCount + 1,` | — (이 파일에서 미추출) |
| `lastRecruitmentId` | L16 `recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L17 `groupRevision + 1,` | — (이 파일에서 미추출) |
| `updatedAt` | L18 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_application_write_plan.dart
근거: [lib/features/group/data/mappers/group_application_write_plan.dart](../../lib/features/group/data/mappers/group_application_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L71 `incrementByOne,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L70 `addedGroupIdUnion,` | — (이 파일에서 미추출) |
| `applicationCountSnapshot` | L174 `applicationCount,` | — (이 파일에서 미추출) |
| `blockedByPlayerId` | L168 `blockedByPlayerId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L173 `relation.characterNameSnapshot,` | — (이 파일에서 미추출) |
| `combatPowerSnapshot` | L176 `relation.combatPowerSnapshot,` | — (이 파일에서 미추출) |
| `createdAt` | L64 `serverTimestamp,` | — (이 파일에서 미추출) |
| `decidedAt` | L226 `serverTimestamp,` | — (이 파일에서 미추출) |
| `displayCharacterIdSnapshot` | L60 `relation.characterIdSnapshot,` | — (이 파일에서 미추출) |
| `displayCharacterNameSnapshot` | L61 `relation.characterNameSnapshot,` | — (이 파일에서 미추출) |
| `expiresAt` | L83 `null,` | — (이 파일에서 미추출) |
| `groupId` | L54 `groupId,` | — (이 파일에서 미추출) |
| `groupNameSnapshot` | L81 `groupName,` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L175 `relation.itemLevelSnapshot,` | — (이 파일에서 미추출) |
| `joinSequence` | L58 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `joinedAt` | L57 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L59 `GroupJoinedBy.application.name,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L90 `serverTimestamp,` | — (이 파일에서 미추출) |
| `memberCount` | L88 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `playerId` | L55 `playerId,` | — (이 파일에서 미추출) |
| `reason` | L169 `(pending` | — (이 파일에서 미추출) |
| `relation` | L79 `GroupRelationKind.member.name,` | — (이 파일에서 미추출) |
| `requestStatus` | L80 `GroupRequestStatus.accepted.name,` | — (이 파일에서 미추출) |
| `revision` | L63 `1,` | — (이 파일에서 미추출) |
| `role` | L56 `GroupMemberRole.member.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L53 `1,` | — (이 파일에서 미추출) |
| `sourceRevision` | L84 `1,` | — (이 파일에서 미추출) |
| `status` | L224 `status.name,` | — (이 파일에서 미추출) |
| `updatedAt` | L65 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_create_write_plan.dart
근거: [lib/features/group/data/mappers/group_create_write_plan.dart](../../lib/features/group/data/mappers/group_create_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L104 `activeGroupIds.length,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L103 `activeGroupIds,` | — (이 파일에서 미추출) |
| `activeRecruitmentCount` | L71 `0,` | — (이 파일에서 미추출) |
| `createdAt` | L76 `serverTimestamp,` | — (이 파일에서 미추출) |
| `deletedAt` | L78 `null,` | — (이 파일에서 미추출) |
| `displayCharacterIdSnapshot` | L88 `command.representativeCharacterId,` | — (이 파일에서 미추출) |
| `displayCharacterNameSnapshot` | L89 `characterName,` | — (이 파일에서 미추출) |
| `expiresAt` | L116 `null,` | — (이 파일에서 미추출) |
| `groupId` | L82 `groupId,` | — (이 파일에서 미추출) |
| `groupNameSnapshot` | L114 `name,` | — (이 파일에서 미추출) |
| `hasActiveJoinCode` | L73 `false,` | — (이 파일에서 미추출) |
| `joinCodeVisibleToMembers` | L74 `false,` | — (이 파일에서 미추출) |
| `joinSequence` | L86 `1,` | — (이 파일에서 미추출) |
| `joinedAt` | L85 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L87 `GroupJoinedBy.created.name,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L75 `serverTimestamp,` | — (이 파일에서 미추출) |
| `leaderDisplayCharacterNameSnapshot` | L69 `characterName,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L68 `playerId,` | — (이 파일에서 미추출) |
| `memberCount` | L70 `1,` | — (이 파일에서 미추출) |
| `name` | L58 `name,` | — (이 파일에서 미추출) |
| `normalizedName` | L59 `normalizer.normalize(name),` | — (이 파일에서 미추출) |
| `normalizedRepresentativeCharacterName` | L62 `normalizer.normalize(` | — (이 파일에서 미추출) |
| `playerId` | L83 `playerId,` | — (이 파일에서 미추출) |
| `relation` | L112 `'member',` | — (이 파일에서 미추출) |
| `representativeCharacterId` | L60 `command.representativeCharacterId,` | — (이 파일에서 미추출) |
| `representativeCharacterNameSnapshot` | L61 `characterName,` | — (이 파일에서 미추출) |
| `representativeServerNameSnapshot` | L65 `normalizer.displayName(` | — (이 파일에서 미추출) |
| `requestStatus` | L113 `null,` | — (이 파일에서 미추출) |
| `revision` | L72 `1,` | — (이 파일에서 미추출) |
| `role` | L84 `GroupMemberRole.leader.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L56 `1,` | — (이 파일에서 미추출) |
| `sourceRevision` | L117 `1,` | — (이 파일에서 미추출) |
| `status` | L57 `'active',` | — (이 파일에서 미추출) |
| `updatedAt` | L77 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_document_mapper.dart
근거: [lib/features/group/data/mappers/group_document_mapper.dart](../../lib/features/group/data/mappers/group_document_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupIds` | — (이 파일에서 미추출) | L209 `final groupIds = data['activeGroupIds'];` |
| `activeJoinCode` | — (이 파일에서 미추출) | L50 `activeJoinCode: _optionalString(data, 'activeJoinCode'),` |
| `blockedByPlayerId` | — (이 파일에서 미추출) | L187 `blockedByPlayerId: _string(data, 'blockedByPlayerId'),` |
| `characterClassNameSnapshot` | — (이 파일에서 미추출) | L139 `_displayText(data['characterClassNameSnapshot']) ?? '-',` |
| `characterIdSnapshot` | — (이 파일에서 미추출) | L134 `characterIdSnapshot: _string(data, 'characterIdSnapshot'),` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L136 `_displayText(data['characterNameSnapshot']) ?? '알 수 없는 캐릭터',` |
| `combatPowerSnapshot` | — (이 파일에서 미추출) | L75 `combatPowerSnapshot: _displayNumber(data['combatPowerSnapshot']),` |
| `decidedAt` | — (이 파일에서 미추출) | L147 `decidedAt: data['decidedAt'] == null ? null : _date(data, 'decidedAt'),` |
| `displayCharacterIdSnapshot` | — (이 파일에서 미추출) | L70 `displayCharacterIdSnapshot: _string(data, 'displayCharacterIdSnapshot'),` |
| `displayCharacterNameSnapshot` | — (이 파일에서 미추출) | L72 `_displayText(data['displayCharacterNameSnapshot']) ?? '알 수 없는 캐릭터',` |
| `displayClassNameSnapshot` | — (이 파일에서 미추출) | L73 `displayClassNameSnapshot: _displayText(data['displayClassNameSnapshot']),` |
| `expiresAt` | — (이 파일에서 미추출) | L103 `expiresAt: data['expiresAt'] == null ? null : _date(data, 'expiresAt'),` |
| `gemValidationSnapshot` | — (이 파일에서 미추출) | L76 `gemValidationSnapshot: _softGemValidation(data['gemValidationSnapshot']),` |
| `groupId` | — (이 파일에서 미추출) | L60 `groupId: _string(data, 'groupId'),` |
| `groupNameSnapshot` | — (이 파일에서 미추출) | L100 `groupNameSnapshot: _displayText(data['groupNameSnapshot']) ?? '이름 없는 그룹',` |
| `itemLevelSnapshot` | — (이 파일에서 미추출) | L74 `itemLevelSnapshot: _displayNumber(data['itemLevelSnapshot']),` |
| `joinedBy` | — (이 파일에서 미추출) | L67 `_string(data, 'joinedBy'),` |
| `kind` | — (이 파일에서 미추출) | L125 `_string(data, 'kind'),` |
| `lastCharacterNameSnapshot` | — (이 파일에서 미추출) | L167 `data['lastCharacterNameSnapshot'],` |
| `lastCombatPowerSnapshot` | — (이 파일에서 미추출) | L170 `lastCombatPowerSnapshot: _displayNumber(data['lastCombatPowerSnapshot']),` |
| `lastItemLevelSnapshot` | — (이 파일에서 미추출) | L169 `lastItemLevelSnapshot: _displayNumber(data['lastItemLevelSnapshot']),` |
| `leaderDisplayCharacterNameSnapshot` | — (이 파일에서 미추출) | L44 `_displayText(data['leaderDisplayCharacterNameSnapshot']) ??` |
| `name` | — (이 파일에서 미추출) | L36 `name: _string(data, 'name'),` |
| `playerId` | — (이 파일에서 미추출) | L87 `playerId: _string(data, 'playerId'),` |
| `reason` | — (이 파일에서 미추출) | L190 `_string(data, 'reason'),` |
| `relation` | — (이 파일에서 미추출) | L90 `_string(data, 'relation'),` |
| `representativeCharacterNameSnapshot` | — (이 파일에서 미추출) | L39 `_displayText(data['representativeCharacterNameSnapshot']) ??` |
| `representativeServerNameSnapshot` | — (이 파일에서 미추출) | L42 `_displayText(data['representativeServerNameSnapshot']) ?? '-',` |
| `requestStatus` | — (이 파일에서 미추출) | L84 `final requestStatus = data['requestStatus'];` |
| `requestedByPlayerId` | — (이 파일에서 미추출) | L133 `requestedByPlayerId: _string(data, 'requestedByPlayerId'),` |
| `revision` | — (이 파일에서 미추출) | L210 `final revision = data['revision'];` |
| `role` | — (이 파일에서 미추출) | L62 `role: _enumValue(GroupMemberRole.values, _string(data, 'role'), 'role'),` |
| `schemaVersion` | — (이 파일에서 미추출) | L242 `if (data['schemaVersion'] != 1) {` |
| `serverNameSnapshot` | — (이 파일에서 미추출) | L137 `serverNameSnapshot: _displayText(data['serverNameSnapshot']) ?? '-',` |
| `status` | — (이 파일에서 미추출) | L130 `_string(data, 'status'),` |
| `targetPlayerId` | — (이 파일에서 미추출) | L114 `final targetPlayerId = _string(data, 'targetPlayerId');` |

### lib/features/group/data/mappers/group_join_code_write_plan.dart
근거: [lib/features/group/data/mappers/group_join_code_write_plan.dart](../../lib/features/group/data/mappers/group_join_code_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L147 `activeGroupIds.length,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L146 `activeGroupIds,` | — (이 파일에서 미추출) |
| `activeJoinCode` | L44 `code.value,` | — (이 파일에서 미추출) |
| `createdAt` | L39 `serverTimestamp,` | — (이 파일에서 미추출) |
| `createdByPlayerId` | L38 `createdByPlayerId,` | — (이 파일에서 미추출) |
| `decidedAt` | L124 `serverTimestamp,` | — (이 파일에서 미추출) |
| `displayCharacterIdSnapshot` | L136 `character.characterId,` | — (이 파일에서 미추출) |
| `displayCharacterNameSnapshot` | L137 `character.characterName,` | — (이 파일에서 미추출) |
| `expiresAt` | L159 `null,` | — (이 파일에서 미추출) |
| `groupId` | L36 `groupId,` | — (이 파일에서 미추출) |
| `groupNameSnapshot` | L157 `groupName,` | — (이 파일에서 미추출) |
| `hasActiveJoinCode` | L43 `true,` | — (이 파일에서 미추출) |
| `joinCodeVisibleToMembers` | L75 `visibleToMembers,` | — (이 파일에서 미추출) |
| `joinSequence` | L134 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `joinedAt` | L133 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L135 `GroupJoinedBy.joinCode.name,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L46 `serverTimestamp,` | — (이 파일에서 미추출) |
| `memberCount` | L165 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `playerId` | L131 `playerId,` | — (이 파일에서 미추출) |
| `relation` | L155 `GroupRelationKind.member.name,` | — (이 파일에서 미추출) |
| `requestStatus` | L156 `pending ? GroupRequestStatus.accepted.name : null,` | — (이 파일에서 미추출) |
| `revision` | L45 `groupRevision + 1,` | — (이 파일에서 미추출) |
| `role` | L132 `GroupMemberRole.member.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L35 `1,` | — (이 파일에서 미추출) |
| `sourceRevision` | L160 `1,` | — (이 파일에서 미추출) |
| `status` | L37 `'active',` | — (이 파일에서 미추출) |
| `updatedAt` | L40 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_join_write_plan.dart
근거: [lib/features/group/data/mappers/group_join_write_plan.dart](../../lib/features/group/data/mappers/group_join_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L193 `activeGroupIds.length,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L192 `activeGroupIds,` | — (이 파일에서 미추출) |
| `applicationAttempt` | L293 `applicationAttempt,` | — (이 파일에서 미추출) |
| `applicationCount` | L127 `attempt,` | — (이 파일에서 미추출) |
| `characterClassNameSnapshot` | L289 `character.characterClassName,` | — (이 파일에서 미추출) |
| `characterIdSnapshot` | L286 `character.characterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L287 `character.characterName,` | — (이 파일에서 미추출) |
| `combatPowerSnapshot` | L291 `character.combatPower,` | — (이 파일에서 미추출) |
| `createdAt` | L131 `statsCreatedAt ?? serverTimestamp,` | — (이 파일에서 미추출) |
| `decidedAt` | L297 `null,` | — (이 파일에서 미추출) |
| `displayCharacterIdSnapshot` | L182 `relation.characterIdSnapshot,` | — (이 파일에서 미추출) |
| `displayCharacterNameSnapshot` | L183 `relation.characterNameSnapshot,` | — (이 파일에서 미추출) |
| `expiresAt` | L205 `null,` | — (이 파일에서 미추출) |
| `gemValidationSnapshot` | L292 `character.gemValidation?.toFields(),` | — (이 파일에서 미추출) |
| `groupId` | L125 `groupId,` | — (이 파일에서 미추출) |
| `groupNameSnapshot` | L203 `groupName,` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L290 `character.itemLevel,` | — (이 파일에서 미추출) |
| `joinSequence` | L180 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `joinedAt` | L179 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L181 `GroupJoinedBy.invitation.name,` | — (이 파일에서 미추출) |
| `kind` | L283 `kind.name,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L213 `serverTimestamp,` | — (이 파일에서 미추출) |
| `lastCharacterNameSnapshot` | L128 `character.characterName,` | — (이 파일에서 미추출) |
| `lastCombatPowerSnapshot` | L130 `character.combatPower,` | — (이 파일에서 미추출) |
| `lastItemLevelSnapshot` | L129 `character.itemLevel,` | — (이 파일에서 미추출) |
| `memberCount` | L211 `groupMemberCount + 1,` | — (이 파일에서 미추출) |
| `playerId` | L126 `playerId,` | — (이 파일에서 미추출) |
| `relation` | L201 `GroupRelationKind.member.name,` | — (이 파일에서 미추출) |
| `requestStatus` | L202 `GroupRequestStatus.accepted.name,` | — (이 파일에서 미추출) |
| `requestedByPlayerId` | L285 `requestedByPlayerId,` | — (이 파일에서 미추출) |
| `revision` | L185 `1,` | — (이 파일에서 미추출) |
| `role` | L178 `GroupMemberRole.member.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L124 `1,` | — (이 파일에서 미추출) |
| `serverNameSnapshot` | L288 `character.serverName,` | — (이 파일에서 미추출) |
| `sourceRevision` | L206 `1,` | — (이 파일에서 미추출) |
| `status` | L284 `GroupRequestStatus.pending.name,` | — (이 파일에서 미추출) |
| `targetPlayerId` | L282 `targetPlayerId,` | — (이 파일에서 미추출) |
| `updatedAt` | L132 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_leader_exit_write_plan.dart
근거: [lib/features/group/data/mappers/group_leader_exit_write_plan.dart](../../lib/features/group/data/mappers/group_leader_exit_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L85 `remainingIds.length,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L84 `remainingIds,` | — (이 파일에서 미추출) |
| `deletedAt` | L76 `serverTimestamp,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L23 `serverTimestamp,` | — (이 파일에서 미추출) |
| `leaderDisplayCharacterNameSnapshot` | L21 `incomingLeaderDisplayName,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L20 `incomingLeaderPlayerId,` | — (이 파일에서 미추출) |
| `memberCount` | L75 `0,` | — (이 파일에서 미추출) |
| `playerId` | L83 `membershipState.playerId,` | — (이 파일에서 미추출) |
| `revision` | L22 `groupRevision + 1,` | — (이 파일에서 미추출) |
| `role` | L27 `GroupMemberRole.member.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L82 `1,` | — (이 파일에서 미추출) |
| `status` | L74 `'softDeleted',` | — (이 파일에서 미추출) |
| `updatedAt` | L24 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_leave_write_plan.dart
근거: [lib/features/group/data/mappers/group_leave_write_plan.dart](../../lib/features/group/data/mappers/group_leave_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupCount` | L46 `remainingIds.length,` | — (이 파일에서 미추출) |
| `activeGroupIds` | L45 `remainingIds,` | — (이 파일에서 미추출) |
| `lastActivityAt` | L39 `serverTimestamp,` | — (이 파일에서 미추출) |
| `memberCount` | L37 `groupMemberCount - 1,` | — (이 파일에서 미추출) |
| `playerId` | L44 `membershipState.playerId,` | — (이 파일에서 미추출) |
| `revision` | L38 `groupRevision + 1,` | — (이 파일에서 미추출) |
| `schemaVersion` | L43 `1,` | — (이 파일에서 미추출) |
| `updatedAt` | L40 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_member_snapshot_write_plan.dart
근거: [lib/features/group/data/mappers/group_member_snapshot_write_plan.dart](../../lib/features/group/data/mappers/group_member_snapshot_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `updatedAt` | L23 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/group/data/mappers/group_member_write_fields.dart
근거: [lib/features/group/data/mappers/group_member_write_fields.dart](../../lib/features/group/data/mappers/group_member_write_fields.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `combatPowerSnapshot` | L16 `combatPower,` | — (이 파일에서 미추출) |
| `displayClassNameSnapshot` | L14 `className,` | — (이 파일에서 미추출) |
| `gemValidationSnapshot` | L17 `gemValidation?.toFields(),` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L15 `itemLevel,` | — (이 파일에서 미추출) |

### lib/features/group/data/repositories/firestore_group_application_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_application_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_application_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `role` | — (이 파일에서 미추출) | L272 `if (callerMember.data()?['role'] != GroupMemberRole.leader.name) {` |

### lib/features/group/data/repositories/firestore_group_character_search_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_character_search_repository.dart](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `buildIntegritySnapshot` | — (이 파일에서 미추출) | L107 `data['buildIntegritySnapshot'],` |
| `characterClassName` | — (이 파일에서 미추출) | L87 `final className = data['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L85 `final name = data['characterName'];` |
| `combatPower` | — (이 파일에서 미추출) | L105 `combatPower: parseCharacterItemLevel(data['combatPower']),` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L104 `itemLevel: parseCharacterItemLevel(data['itemAvgLevel']),` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L84 `final ownerPlayerId = data['ownerPlayerId'];` |
| `serverName` | — (이 파일에서 미추출) | L86 `final serverName = data['serverName'];` |

### lib/features/group/data/repositories/firestore_group_create_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_create_repository.dart](../../lib/features/group/data/repositories/firestore_group_create_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L103 `final className = characterData?['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L101 `final characterName = characterData?['characterName'];` |
| `combatPower` | — (이 파일에서 미추출) | L149 `parseCharacterItemLevel(characterData?['combatPower']),` |
| `gameAccountId` | — (이 파일에서 미추출) | L84 `final gameAccountId = characterData?['gameAccountId'];` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L146 `parseCharacterItemLevel(characterData?['itemAvgLevel']),` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L79 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L47 `final playerId = bindingData?['playerId'];` |
| `serverName` | — (이 파일에서 미추출) | L102 `final serverName = characterData?['serverName'];` |
| `status` | — (이 파일에서 미추출) | L48 `if (bindingData?['status'] != 'active' \|\|` |

### lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_join_code_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L375 `final className = data['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L373 `final name = data['characterName'];` |
| `combatPower` | — (이 파일에서 미추출) | L399 `parseCharacterItemLevel(data['combatPower']),` |
| `createdAt` | — (이 파일에서 미추출) | L258 `playerRelationCreatedAt: existingPlayerRelation.data()?['createdAt'],` |
| `groupId` | — (이 파일에서 미추출) | L117 `codeData['groupId'] != command.groupId \|\|` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L396 `parseCharacterItemLevel(data['itemAvgLevel']),` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L372 `final ownerPlayerId = data['ownerPlayerId'];` |
| `serverName` | — (이 파일에서 미추출) | L374 `final serverName = data['serverName'];` |
| `status` | — (이 파일에서 미추출) | L118 `codeData['status'] != 'active') {` |

### lib/features/group/data/repositories/firestore_group_join_command_repository.dart
근거: [lib/features/group/data/repositories/firestore_group_join_command_repository.dart](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | — (이 파일에서 미추출) | L629 `groupSnapshot.data()?['activeRecruitmentCount'];` |
| `characterClassName` | — (이 파일에서 미추출) | L860 `final className = data['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L858 `final name = data['characterName'];` |
| `combatPower` | — (이 파일에서 미추출) | L884 `parseCharacterItemLevel(data['combatPower']),` |
| `combatPowerSnapshot` | — (이 파일에서 미추출) | L766 `storedCombatPower: parseCharacterItemLevel(memberData?['combatPowerSnapshot']),` |
| `createdAt` | — (이 파일에서 미추출) | L209 `statsCreatedAt: statsData?['createdAt'],` |
| `displayCharacterIdSnapshot` | — (이 파일에서 미추출) | L743 `final characterId = memberData?['displayCharacterIdSnapshot'];` |
| `gemValidationSnapshot` | — (이 파일에서 미추출) | L767 `storedGemValidation: _storedGemValidation(memberData?['gemValidationSnapshot']),` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L881 `parseCharacterItemLevel(data['itemAvgLevel']),` |
| `itemLevelSnapshot` | — (이 파일에서 미추출) | L765 `storedItemLevel: parseCharacterItemLevel(memberData?['itemLevelSnapshot']),` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L524 `final leaderPlayerId = groupSnapshot.data()?['leaderPlayerId'];` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L754 `characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L729 `final playerId = bindingData?['playerId'];` |
| `role` | — (이 파일에서 미추출) | L395 `callerMember.data()?['role'] == GroupMemberRole.leader.name;` |
| `schemaVersion` | — (이 파일에서 미추출) | L434 `return data['visibility'] == 'group' && data['schemaVersion'] == 2;` |
| `serverName` | — (이 파일에서 미추출) | L859 `final serverName = data['serverName'];` |
| `status` | — (이 파일에서 미추출) | L730 `if (bindingData?['status'] != 'active' \|\|` |
| `visibility` | — (이 파일에서 미추출) | L434 `return data['visibility'] == 'group' && data['schemaVersion'] == 2;` |

### lib/features/manual_verification/data/firestore_manual_verification_repository.dart
근거: [lib/features/manual_verification/data/firestore_manual_verification_repository.dart](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `attemptNumberForTarget` | L159 `(data['attemptNumberForTarget'] as num? ?? 1) + 1,` | L159 `'attemptNumberForTarget': (data['attemptNumberForTarget'] as num? ?? 1) + 1,` |
| `blockedAt` | L405 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `blockedByOperatorPlayerId` | L404 `operatorPlayerId,` | — (이 파일에서 미추출) |
| `characterClassName` | L924 `sibling.characterClassName,` | — (이 파일에서 미추출) |
| `characterId` | L934 `characterRef.id,` | L863 `final characterId = claims[index].data()?['characterId'];` |
| `characterIds` | L904 `allCharacterIds.toList(growable: false),` | L856 `? (account.data()?['characterIds'] as List?)` |
| `characterLevel` | L925 `sibling.characterLevel,` | — (이 파일에서 미추출) |
| `characterName` | L923 `sibling.characterName,` | L271 `characterName: doc.data()['characterName'] as String? ?? '',` |
| `createdAt` | L125 `now,` | L905 `'createdAt': account.exists ? (account.data()?['createdAt'] ?? now) : now,` |
| `defenseOfRequestId` | L1400 `defenseOfRequestId,` | L1466 `defenseOfRequestId: data['defenseOfRequestId'] as String?,` |
| `disputeOpenedAt` | L1026 `nowField,` | L1460 `disputeOpenedAt: data['disputeOpenedAt'] == null` |
| `eventId` | L1112 `eventId,` | — (이 파일에서 미추출) |
| `expiresAt` | L126 `now.add(_requestTtl),` | L1454 `expiresAt: readTime(data['expiresAt']),` |
| `gameAccountId` | L919 `accountRef.id,` | L801 `.map((snapshot) => snapshot.data()?['gameAccountId'])` |
| `itemAvgLevel` | L926 `sibling.itemAvgLevel,` | — (이 파일에서 미추출) |
| `localAccountId` | L1396 `localAccountId,` | L1441 `localAccountId: (data['localAccountId'] as num?)?.toInt(),` |
| `localAccountLabelSnapshot` | L1401 `localAccountLabel,` | L1444 `data['localAccountLabelSnapshot'] as String? ?? '',` |
| `lookupCharacterName` | L903 `siblings.first.characterName,` | — (이 파일에서 미추출) |
| `occurredAt` | L1120 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `ownerPlayerId` | L891 `requesterPlayerId,` | L834 `previousOwner = account.data()?['ownerPlayerId'] as String?;` |
| `ownerResponseDeadlineAt` | L1027 `deadline,` | L638 `final deadline = liveDisputeData['ownerResponseDeadlineAt'];` |
| `ownershipRevision` | L892 `ownership.nextRevision,` | — (이 파일에서 미추출) |
| `playerId` | L398 `playerId,` | L1486 `final playerId = bindingData?['playerId'];` |
| `previousOwnerPlayerId` | L1025 `previousOwnerPlayerId,` | L1073 `final previousOwner = data['previousOwnerPlayerId'];` |
| `proofCharacterName` | L1403 `proofCharacterName.trim(),` | L1446 `proofCharacterName: data['proofCharacterName'] as String? ?? '',` |
| `proofCharacterNameSnapshot` | L1118 `proofCharacterName,` | — (이 파일에서 미추출) |
| `proofClassName` | L1405 `proofClassName,` | L1447 `proofClassName: data['proofClassName'] as String?,` |
| `proofServerName` | L1402 `proofServerName.trim(),` | L1445 `proofServerName: data['proofServerName'] as String? ?? '',` |
| `reason` | L403 `reason.trim(),` | — (이 파일에서 미추출) |
| `requestId` | L1115 `requestId,` | — (이 파일에서 미추출) |
| `requesterPlayerId` | L1116 `requesterPlayerId,` | L144 `if (data['requesterPlayerId'] != playerId) {` |
| `resolvedAt` | L192 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `reviewReason` | L392 `reason.trim(),` | L1457 `reviewReason: data['reviewReason'] as String?,` |
| `reviewedAt` | L391 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `reviewedByOperatorPlayerId` | L390 `operatorPlayerId,` | L1456 `data['reviewedByOperatorPlayerId'] as String?,` |
| `rosterStatus` | L893 `'missingFromLatestRoster',` | — (이 파일에서 미추출) |
| `schemaVersion` | L397 `1,` | — (이 파일에서 미추출) |
| `serverName` | L922 `sibling.serverName,` | L270 `serverName: doc.data()['serverName'] as String? ?? '',` |
| `status` | L191 `'cancelled',` | L147 `if (data['status'] != 'pendingProof') {` |
| `targetGameAccountId` | L401 `targetGameAccountId,` | L253 `final accountId = data['targetGameAccountId'];` |
| `targetIdentityKey` | L399 `identityKey,` | L382 `final identityKey = data['targetIdentityKey'] as String;` |
| `totalAttemptNumberForPlayer` | L160 `` | L161 `(data['totalAttemptNumberForPlayer'] as num? ?? 1) + 1,` |
| `type` | L1113 `'manualVerificationDisputeOpened',` | — (이 파일에서 미추출) |
| `updatedAt` | L127 `now,` | — (이 파일에서 미추출) |
| `verificationCode` | L155 `_codeGenerator(),` | L1448 `verificationCode: data['verificationCode'] as String? ?? '',` |

### lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart
근거: [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L135 `className: _string(data['characterClassName']) ?? '직업 미확인',` |
| `characterName` | — (이 파일에서 미추출) | L133 `characterName: _string(data['characterName']) ?? '이름 없음',` |
| `createdAt` | — (이 파일에서 미추출) | L306 `createdAt: _dateTime(data['createdAt']),` |
| `gameAccountId` | — (이 파일에서 미추출) | L126 `final gameAccountId = data['gameAccountId'];` |
| `lastSeenAt` | L225 `null});` | L307 `lastSeenAt: _dateTime(data['lastSeenAt']),` |
| `lookupCharacterName` | — (이 파일에서 미추출) | L156 `lookupCharacterName: _string(accountData?['lookupCharacterName']),` |
| `playerId` | — (이 파일에서 미추출) | L55 `final playerId = bindingData?['playerId'];` |
| `representativeCharacterId` | — (이 파일에서 미추출) | L158 `? _string(ownershipData['representativeCharacterId'])` |
| `serverName` | — (이 파일에서 미추출) | L134 `serverName: _string(data['serverName']) ?? '서버 미확인',` |
| `status` | — (이 파일에서 미추출) | L33 `if (!assignment.exists \|\| assignment.data()?['status'] != 'active') {` |

### lib/features/player/data/datasources/firestore_player_binding_store.dart
근거: [lib/features/player/data/datasources/firestore_player_binding_store.dart](../../lib/features/player/data/datasources/firestore_player_binding_store.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `createdAt` | L34 `now,` | — (이 파일에서 미추출) |
| `lastSeenAt` | L33 `null,` | — (이 파일에서 미추출) |
| `linkedAt` | L41 `now,` | — (이 파일에서 미추출) |
| `playerId` | L39 `playerRef.id,` | L52 `data['playerId'] is! String \|\|` |
| `schemaVersion` | L31 `schemaVersion,` | L50 `data['schemaVersion'] != schemaVersion \|\|` |
| `status` | L32 `activeStatus,` | L51 `data['status'] != activeStatus \|\|` |
| `updatedAt` | L35 `now,` | — (이 파일에서 미추출) |

### lib/features/player/data/repositories/firestore_player_activity_repository.dart
근거: [lib/features/player/data/repositories/firestore_player_activity_repository.dart](../../lib/features/player/data/repositories/firestore_player_activity_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `lastSeenAt` | L13 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |

### lib/features/raid_status/data/services/firestore_party_event_sync_service.dart
근거: [lib/features/raid_status/data/services/firestore_party_event_sync_service.dart](../../lib/features/raid_status/data/services/firestore_party_event_sync_service.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `playerId` | — (이 파일에서 미추출) | L41 `final playerId = data?['playerId'];` |
| `status` | — (이 파일에서 미추출) | L42 `if (data?['status'] != 'active' \|\|` |

### lib/features/recruitment_list/data/mappers/party_application_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_application_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_application_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `applicantPlayerId` | L16 `playerId,` | — (이 파일에서 미추출) |
| `approvalCount` | L30 `0,` | — (이 파일에서 미추출) |
| `buildIntegritySnapshot` | L26 `command.buildIntegrity?.toFields(),` | — (이 파일에서 미추출) |
| `characterId` | L18 `command.characterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L19 `characterName,` | — (이 파일에서 미추출) |
| `classNameSnapshot` | L20 `className,` | — (이 파일에서 미추출) |
| `combatPower` | L24 `command.combatPower,` | — (이 파일에서 미추출) |
| `createdAt` | L33 `serverTimestamp,` | — (이 파일에서 미추출) |
| `cycleKey` | L17 `command.cycleKey,` | — (이 파일에서 미추출) |
| `decidedAt` | L34 `null,` | — (이 파일에서 미추출) |
| `itemLevel` | L23 `itemLevel,` | — (이 파일에서 미추출) |
| `recruitmentId` | L15 `command.recruitmentId,` | — (이 파일에서 미추출) |
| `rejectionCount` | L31 `0,` | — (이 파일에서 미추출) |
| `requestedRole` | L21 `command.requestedRole.name,` | — (이 파일에서 미추출) |
| `resolutionReason` | L29 `null,` | — (이 파일에서 미추출) |
| `revision` | L32 `1,` | — (이 파일에서 미추출) |
| `schemaVersion` | L14 `1,` | — (이 파일에서 미추출) |
| `status` | L28 `'pending',` | — (이 파일에서 미추출) |
| `submittedBuildSnapshot` | L22 `{` | — (이 파일에서 미추출) |
| `updatedAt` | L35 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L124 `applicantPlayerId,` | — (이 파일에서 미추출) |
| `approvalCount` | L214 `currentApprovalCount + 1,` | — (이 파일에서 미추출) |
| `audiencePlayerIds` | L120 `{` | — (이 파일에서 미추출) |
| `commandId` | L118 `eventId,` | — (이 파일에서 미추출) |
| `commandRevision` | L119 `revision,` | — (이 파일에서 미추출) |
| `countedAsNonGroupApplicant` | L16 `` | L98 `final value = application['countedAsNonGroupApplicant'];` |
| `decidedAt` | L150 `serverTimestamp,` | — (이 파일에서 미추출) |
| `eventId` | L115 `eventId,` | — (이 파일에서 미추출) |
| `occurredAt` | L125 `serverTimestamp,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L15 `?ownershipRevision,` | — (이 파일에서 미추출) |
| `pendingApplicationCount` | L90 `pending,` | — (이 파일에서 미추출) |
| `pendingNonGroupApplicantCount` | L91 `pendingNonGroup,` | — (이 파일에서 미추출) |
| `recruitmentId` | L116 `aggregate.recruitmentId,` | — (이 파일에서 미추출) |
| `rejectionCount` | L148 `(application['rejectionCount'] as int? ?? 0) + 1,` | L148 `'rejectionCount': (application['rejectionCount'] as int? ?? 0) + 1,` |
| `resolutionReason` | L147 `'rejectedByApprover',` | — (이 파일에서 미추출) |
| `revision` | L92 `aggregate.revision + 1,` | — (이 파일에서 미추출) |
| `schemaVersion` | L114 `1,` | — (이 파일에서 미추출) |
| `status` | L146 `'rejected',` | — (이 파일에서 미추출) |
| `type` | L117 `type,` | — (이 파일에서 미추출) |
| `updatedAt` | L93 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | L35 `value.characterId,` | L48 `characterId: _string(data, 'characterId'),` |
| `classKey` | L37 `value.classKey,` | L54 `classKey: _string(data, 'classKey'),` |
| `continueTogether` | — (이 파일에서 미추출) | L26 `continueTogether: _bool(data, 'continueTogether'),` |
| `countedAsNonGroupMember` | L40 `value.countedAsNonGroupMember,` | L57 `countedAsNonGroupMember: _bool(data, 'countedAsNonGroupMember'),` |
| `currentCycleKey` | — (이 파일에서 미추출) | L14 `currentCycleKey: _string(data, 'currentCycleKey'),` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L15 `currentCycleStatus: _raidStatus(data['currentCycleStatus']),` |
| `difficultyId` | — (이 파일에서 미추출) | L12 `difficultyId: _string(data, 'difficultyId'),` |
| `groupId` | — (이 파일에서 미추출) | L27 `groupId: _optionalString(data, 'groupId'),` |
| `lastCommandId` | — (이 파일에서 미추출) | L28 `lastCommandId: _optionalString(data, 'lastCommandId'),` |
| `lastCommandType` | — (이 파일에서 미추출) | L29 `lastCommandType: _commandTypeOrNull(data['lastCommandType']),` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L13 `leaderPlayerId: _string(data, 'leaderPlayerId'),` |
| `nonGroupMemberCount` | — (이 파일에서 미추출) | L18 `nonGroupMemberCount: _int(data, 'nonGroupMemberCount'),` |
| `ownershipRevision` | L42 `value.ownershipRevision,` | L59 `? _int(data, 'ownershipRevision')` |
| `partyIndex` | L38 `value.partyIndex,` | L55 `partyIndex: _int(data, 'partyIndex'),` |
| `partySlots` | — (이 파일에서 미추출) | L8 `final slots = _list(data['partySlots']).map(_slot).toList(growable: false);` |
| `pendingApplicationCount` | — (이 파일에서 미추출) | L19 `pendingApplicationCount: _int(data, 'pendingApplicationCount'),` |
| `playerId` | L34 `value.playerId,` | L47 `playerId: _string(data, 'playerId'),` |
| `raidId` | — (이 파일에서 미추출) | L11 `raidId: _string(data, 'raidId'),` |
| `recruitmentId` | — (이 파일에서 미추출) | L10 `recruitmentId: _string(data, 'recruitmentId'),` |
| `revision` | — (이 파일에서 미추출) | L16 `revision: _int(data, 'revision'),` |
| `role` | L36 `value.role.name,` | L49 `role: switch (_string(data, 'role')) {` |
| `slotIndex` | L39 `value.slotIndex,` | L56 `slotIndex: _int(data, 'slotIndex'),` |
| `status` | — (이 파일에서 미추출) | L24 `status: _recruitmentStatus(data['status']),` |
| `visibility` | — (이 파일에서 미추출) | L25 `visibility: _string(data, 'visibility'),` |

### lib/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `commandTargets` | L4 `<Map<String, Object?>>[],` | — (이 파일에서 미추출) |
| `lastCommandActorPlayerId` | L7 `null,` | — (이 파일에서 미추출) |
| `lastCommandAt` | L8 `null,` | — (이 파일에서 미추출) |
| `lastCommandId` | L5 `null,` | — (이 파일에서 미추출) |
| `lastCommandType` | L6 `null,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L397 `actorPlayerId,` | — (이 파일에서 미추출) |
| `audiencePlayerIds` | L396 `[for (final slot in aggregate.partySlots) slot.playerId],` | — (이 파일에서 미추출) |
| `characterId` | L165 `newCharacterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L146 `membershipPatch['characterNameSnapshot'],` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L147 `'leaderClassNameSnapshot': membershipPatch['classNameSnapshot'],` |
| `commandId` | L394 `eventId,` | — (이 파일에서 미추출) |
| `commandRevision` | L395 `revision,` | — (이 파일에서 미추출) |
| `cycleKey` | L170 `aggregate.currentCycleKey,` | — (이 파일에서 미추출) |
| `dealerCount` | L138 `nextSlots` | — (이 파일에서 미추출) |
| `difficultyId` | L169 `difficultyId,` | — (이 파일에서 미추출) |
| `eventId` | L391 `eventId,` | — (이 파일에서 미추출) |
| `leaderCharacterNameSnapshot` | L145 `` | — (이 파일에서 미추출) |
| `leaderClassNameSnapshot` | L147 `membershipPatch['classNameSnapshot'],` | — (이 파일에서 미추출) |
| `nextCharacterId` | L188 `newCharacterId,` | — (이 파일에서 미추출) |
| `nextOwnershipRevision` | L189 `ownershipRevision ?? 0,` | — (이 파일에서 미추출) |
| `occurredAt` | L398 `serverTimestamp,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L154 `?ownershipRevision,` | — (이 파일에서 미추출) |
| `partyIndex` | L155 `partyIndex,` | — (이 파일에서 미추출) |
| `partySlots` | L125 `[` | — (이 파일에서 미추출) |
| `playerId` | L131 `slot.playerId,` | — (이 파일에서 미추출) |
| `previousCharacterId` | L187 `old.characterId,` | — (이 파일에서 미추출) |
| `raidId` | L168 `raidId,` | — (이 파일에서 미추출) |
| `raidStateTargets` | L128 `[` | — (이 파일에서 미추출) |
| `recruitmentId` | L173 `aggregate.recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L149 `nextRevision,` | — (이 파일에서 미추출) |
| `role` | L166 `newRole.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L163 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | L156 `slotIndex,` | — (이 파일에서 미추출) |
| `source` | L172 `'party',` | — (이 파일에서 미추출) |
| `stateId` | L132 `PartyRaidState.documentIdFor(` | — (이 파일에서 미추출) |
| `status` | L171 `'active',` | — (이 파일에서 미추출) |
| `supportCount` | L141 `nextSlots` | — (이 파일에서 미추출) |
| `type` | L393 `type,` | — (이 파일에서 미추출) |
| `updatedAt` | L150 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L187 `actorPlayerId,` | — (이 파일에서 미추출) |
| `audiencePlayerIds` | L184 `[` | — (이 파일에서 미추출) |
| `canApproveApplications` | L173 `true,` | — (이 파일에서 미추출) |
| `commandId` | L182 `eventId,` | — (이 파일에서 미추출) |
| `commandRevision` | L183 `nextRevision,` | — (이 파일에서 미추출) |
| `dealerCount` | L130 `remaining` | — (이 파일에서 미추출) |
| `eventId` | L179 `eventId,` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L150 `remaining.length < rules.totalMembers,` | — (이 파일에서 미추출) |
| `leaderCharacterNameSnapshot` | L157 `successorSnapshot!.characterName,` | — (이 파일에서 미추출) |
| `leaderClassNameSnapshot` | L158 `successorSnapshot.className,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L156 `successor!.playerId,` | — (이 파일에서 미추출) |
| `memberCount` | L129 `remaining.length,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L128 `[for (final slot in remaining) slot.playerId],` | — (이 파일에서 미추출) |
| `nonGroupMemberCount` | L149 `nextNonGroupMemberCount,` | — (이 파일에서 미추출) |
| `occurredAt` | L189 `serverTimestamp,` | — (이 파일에서 미추출) |
| `partySlots` | L136 `[` | — (이 파일에서 미추출) |
| `playerId` | L142 `slot.playerId,` | — (이 파일에서 미추출) |
| `raidStateTargets` | L139 `[` | — (이 파일에서 미추출) |
| `recruitmentId` | L180 `aggregate.recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L151 `nextRevision,` | — (이 파일에서 미추출) |
| `schemaVersion` | L178 `1,` | — (이 파일에서 미추출) |
| `stateId` | L143 `PartyRaidState.documentIdFor(` | — (이 파일에서 미추출) |
| `supportCount` | L133 `remaining` | — (이 파일에서 미추출) |
| `targetPlayerId` | L188 `targetPlayerId,` | — (이 파일에서 미추출) |
| `type` | L181 `eventType,` | — (이 파일에서 미추출) |
| `updatedAt` | L152 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L137 `playerId,` | — (이 파일에서 미추출) |
| `audiencePlayerIds` | L136 `[playerId],` | — (이 파일에서 미추출) |
| `characterId` | L113 `command.leaderCharacterId,` | L50 `characterId: raidState['characterId']! as String,` |
| `commandId` | L134 `eventId,` | — (이 파일에서 미추출) |
| `commandRevision` | L135 `1,` | — (이 파일에서 미추출) |
| `commandTargets` | L94 `const <Map<String, Object?>>[],` | — (이 파일에서 미추출) |
| `cycleKey` | L116 `command.cycleKey,` | — (이 파일에서 미추출) |
| `difficultyId` | L115 `command.metadata.difficultyId,` | — (이 파일에서 미추출) |
| `eventId` | L131 `eventId,` | — (이 파일에서 미추출) |
| `groupActiveRecruitmentCountAfter` | L95 `groupActiveRecruitmentCountAfter,` | — (이 파일에서 미추출) |
| `joinedBy` | — (이 파일에서 미추출) | L194 `final joinedBy = base.membership['joinedBy'];` |
| `lastCommandActorPlayerId` | L98 `null,` | — (이 파일에서 미추출) |
| `lastCommandAt` | L99 `null,` | — (이 파일에서 미추출) |
| `lastCommandId` | L96 `null,` | — (이 파일에서 미추출) |
| `lastCommandType` | L97 `null,` | — (이 파일에서 미추출) |
| `nonGroupMemberCount` | L88 `0,` | — (이 파일에서 미추출) |
| `occurredAt` | L138 `serverTimestamp,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L30 `?ownershipRevision,` | — (이 파일에서 미추출) |
| `partyIndex` | — (이 파일에서 미추출) | L195 `final partyIndex = base.membership['partyIndex'];` |
| `partySlots` | L87 `[PartyAtomicDocumentMapper.slot(slot)],` | — (이 파일에서 미추출) |
| `pendingApplicationCount` | L89 `0,` | — (이 파일에서 미추출) |
| `pendingNonGroupApplicantCount` | L90 `0,` | — (이 파일에서 미추출) |
| `playerId` | L92 `playerId, 'stateId': raidStateId},` | L191 `final playerId = base.membership['playerId'];` |
| `raidId` | L114 `command.metadata.raidId,` | L51 `raidId: raidState['raidId']! as String,` |
| `raidStateTargets` | L91 `[` | — (이 파일에서 미추출) |
| `recruitmentId` | L86 `command.recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L120 `1,` | — (이 파일에서 미추출) |
| `role` | — (이 파일에서 미추출) | L193 `final roleName = base.membership['role'];` |
| `schemaVersion` | L85 `2,` | — (이 파일에서 미추출) |
| `slotIndex` | — (이 파일에서 미추출) | L196 `final slotIndex = base.membership['slotIndex'];` |
| `source` | L118 `'party',` | — (이 파일에서 미추출) |
| `stateId` | L258 `PartyRaidState.documentIdFor(` | — (이 파일에서 미추출) |
| `status` | L117 `'active',` | — (이 파일에서 미추출) |
| `type` | L133 `'partyCreated',` | — (이 파일에서 미추출) |
| `visibility` | — (이 파일에서 미추출) | L55 `recruitment['visibility'] == RecruitmentVisibility.group` |

### lib/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | — (이 파일에서 미추출) | L63 `groupPlan.groupPatch['activeRecruitmentCount'],` |
| `groupActiveRecruitmentCountAfter` | L62 `` | — (이 파일에서 미추출) |
| `revision` | L64 `nextRevision,` | — (이 파일에서 미추출) |
| `updatedAt` | L65 `serverTimestamp,` | — (이 파일에서 미추출) |
| `visibility` | L61 `nextVisibility,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_atomic_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_atomic_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_atomic_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L252 `command.actorPlayerId,` | — (이 파일에서 미추출) |
| `audiencePlayerIds` | L249 `[` | — (이 파일에서 미추출) |
| `characterId` | L221 `slot.characterId,` | — (이 파일에서 미추출) |
| `commandId` | L247 `command.commandId,` | — (이 파일에서 미추출) |
| `commandRevision` | L248 `command.expectedRevision + 1,` | — (이 파일에서 미추출) |
| `commandTargets` | L166 `[` | — (이 파일에서 미추출) |
| `completedAt` | L152 `null,` | — (이 파일에서 미추출) |
| `completedByPlayerId` | L153 `null,` | — (이 파일에서 미추출) |
| `completionTargets` | L258 `[` | — (이 파일에서 미추출) |
| `currentCycleKey` | L144 `command.nextCycleKey,` | — (이 파일에서 미추출) |
| `currentCycleStatus` | L136 `'completed',` | — (이 파일에서 미추출) |
| `cycleEndsAt` | L150 `command.nextCycleEndsAt,` | — (이 파일에서 미추출) |
| `cycleKey` | L227 `command.nextCycleKey,` | L114 `data['cycleKey'] != command.expectedCycleKey \|\|` |
| `cycleStartedAt` | L148 `command.nextCycleStartedAt,` | — (이 파일에서 미추출) |
| `difficultyId` | L225 `aggregate.difficultyId,` | — (이 파일에서 미추출) |
| `eventId` | L242 `command.commandId,` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L158 `false,` | — (이 파일에서 미추출) |
| `lastCommandActorPlayerId` | L173 `command.actorPlayerId,` | — (이 파일에서 미추출) |
| `lastCommandAt` | L174 `serverTimestamp,` | — (이 파일에서 미추출) |
| `lastCommandId` | L171 `command.commandId,` | — (이 파일에서 미추출) |
| `lastCommandType` | L172 `command.type.name,` | — (이 파일에서 미추출) |
| `manualRecruitmentEnabled` | L157 `false,` | — (이 파일에서 미추출) |
| `occurredAt` | L263 `serverTimestamp,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L223 `slot.ownershipRevision,` | — (이 파일에서 미추출) |
| `playerId` | L168 `target.playerId, 'stateId': target.raidStateId},` | — (이 파일에서 미추출) |
| `raidId` | L224 `aggregate.raidId,` | — (이 파일에서 미추출) |
| `recruitmentId` | L226 `aggregate.recruitmentId,` | L113 `data['recruitmentId'] != command.recruitmentId \|\|` |
| `revision` | L170 `nextRevision,` | L115 `data['revision'] is! int) {` |
| `role` | L204 `aggregate.partySlots` | — (이 파일에서 미추출) |
| `schemaVersion` | L219 `1,` | — (이 파일에서 미추출) |
| `source` | L230 `'party',` | — (이 파일에서 미추출) |
| `status` | L138 `aggregate.continueTogether ? 'active' : 'completed',` | L118 `final status = data['status'];` |
| `targetCycleKey` | L146 `command.nextCycleKey,` | — (이 파일에서 미추출) |
| `type` | L244 `command.type == PartyAtomicCommandType.incompleteEnd` | — (이 파일에서 미추출) |
| `updatedAt` | L175 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_complete_claim_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_complete_claim_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_complete_claim_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | L20 `characterId,` | L57 `membership['characterId'] == snapshot['characterId'] &&` |
| `completedAt` | L29 `serverTimestamp,` | — (이 파일에서 미추출) |
| `createdAt` | L49 `serverTimestamp,` | — (이 파일에서 미추출) |
| `cycleEndsAt` | L28 `cycleEndsAt,` | — (이 파일에서 미추출) |
| `cycleKey` | L22 `cycleKey,` | — (이 파일에서 미추출) |
| `cycleStartedAt` | L27 `cycleStartedAt,` | — (이 파일에서 미추출) |
| `difficultyId` | L23 `difficultyId,` | — (이 파일에서 미추출) |
| `partyIndex` | — (이 파일에서 미추출) | L59 `membership['partyIndex'] == snapshot['partyIndex'] &&` |
| `playerId` | L19 `playerId,` | — (이 파일에서 미추출) |
| `raidId` | L21 `raidId,` | — (이 파일에서 미추출) |
| `recruitmentId` | L46 `recruitmentId,` | — (이 파일에서 미추출) |
| `role` | L48 `role,` | L58 `membership['role'] == snapshot['role'] &&` |
| `schemaVersion` | L18 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | — (이 파일에서 미추출) | L60 `membership['slotIndex'] == snapshot['slotIndex'];` |
| `source` | L24 `'partyOwner',` | L68 `return claim['source'] == 'partyOwner' &&` |
| `sourceCompletionRevision` | L26 `sourceCompletionRevision,` | L70 `_revisionOf(claim['sourceCompletionRevision']) ==` |
| `sourceRecruitmentId` | L25 `sourceRecruitmentId,` | L69 `claim['sourceRecruitmentId'] == recruitmentId &&` |
| `updatedAt` | L30 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_create_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_create_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_create_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `approvalPolicy` | L50 `_approvalPolicy(command),` | — (이 파일에서 미추출) |
| `buildIntegritySnapshot` | L91 `command.leaderBuildIntegrity?.toFields(),` | — (이 파일에서 미추출) |
| `canApproveApplications` | L93 `true,` | — (이 파일에서 미추출) |
| `characterChangedAt` | L92 `null,` | — (이 파일에서 미추출) |
| `characterId` | L79 `command.leaderCharacterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L80 `verifiedCharacterName,` | — (이 파일에서 미추출) |
| `classNameSnapshot` | L81 `verifiedClassName,` | — (이 파일에서 미추출) |
| `combatPowerSnapshot` | L89 `command.leaderCombatPower,` | — (이 파일에서 미추출) |
| `completedAt` | L71 `null,` | — (이 파일에서 미추출) |
| `completedByPlayerId` | L72 `null,` | — (이 파일에서 미추출) |
| `continueTogether` | L51 `false,` | — (이 파일에서 미추출) |
| `createdAt` | L69 `serverTimestamp,` | — (이 파일에서 미추출) |
| `currentCycleKey` | L54 `command.cycleKey,` | — (이 파일에서 미추출) |
| `currentCycleStatus` | L56 `'active',` | — (이 파일에서 미추출) |
| `cycleEndsAt` | L58 `Timestamp.fromDate(cycle.endsAt),` | — (이 파일에서 미추출) |
| `cycleKey` | L102 `command.cycleKey,` | — (이 파일에서 미추출) |
| `cycleStartedAt` | L57 `Timestamp.fromDate(cycle.startedAt),` | — (이 파일에서 미추출) |
| `dealerCount` | L66 `command.leaderRole.name == 'dealer' ? 1 : 0,` | — (이 파일에서 미추출) |
| `difficultyAliasSnapshot` | L38 `metadata.difficultyAlias,` | — (이 파일에서 미추출) |
| `difficultyId` | L35 `metadata.difficultyId,` | — (이 파일에서 미추출) |
| `difficultyNameSnapshot` | L37 `metadata.difficultyName,` | — (이 파일에서 미추출) |
| `experienceLevel` | L42 `metadata.experienceLevel?.name,` | — (이 파일에서 미추출) |
| `gateCount` | L39 `metadata.gateCount,` | — (이 파일에서 미추출) |
| `gemValidationSnapshot` | L90 `command.leaderGemValidation?.toFields(),` | — (이 파일에서 미추출) |
| `groupId` | L49 `command.groupId,` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L53 `rules.totalMembers > 1,` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L88 `verifiedItemLevel,` | — (이 파일에서 미추출) |
| `joinedAt` | L85 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L86 `playerId,` | — (이 파일에서 미추출) |
| `leaderCharacterNameSnapshot` | L30 `verifiedCharacterName,` | — (이 파일에서 미추출) |
| `leaderClassNameSnapshot` | L31 `verifiedClassName,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L29 `playerId,` | — (이 파일에서 미추출) |
| `leaderVoteRequired` | L123 `command.approvalPolicy.leaderVoteRequired,` | — (이 파일에서 미추출) |
| `manualRecruitmentEnabled` | L52 `true,` | — (이 파일에서 미추출) |
| `maxDealersPerClassPerParty` | L62 `rules.maxDealersPerClassPerParty,` | — (이 파일에서 미추출) |
| `maxMemberCount` | L65 `rules.totalMembers,` | — (이 파일에서 미추출) |
| `maxPlayHours` | L43 `metadata.maxPlayHours,` | — (이 파일에서 미추출) |
| `memberCount` | L64 `1,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L32 `[playerId],` | — (이 파일에서 미추출) |
| `membersPerParty` | L60 `rules.membersPerParty,` | — (이 파일에서 미추출) |
| `minCombatPower` | L41 `metadata.minCombatPower,` | — (이 파일에서 미추출) |
| `minItemLevel` | L40 `metadata.minItemLevel,` | — (이 파일에서 미추출) |
| `mode` | L121 `command.approvalPolicy.mode.name,` | — (이 파일에서 미추출) |
| `partyCount` | L59 `rules.partyCount,` | — (이 파일에서 미추출) |
| `partyIndex` | L83 `0,` | — (이 파일에서 미추출) |
| `playerId` | L78 `playerId,` | — (이 파일에서 미추출) |
| `raidCatalogVersion` | L33 `metadata.catalogVersion,` | — (이 파일에서 미추출) |
| `raidId` | L34 `metadata.raidId,` | — (이 파일에서 미추출) |
| `raidNameSnapshot` | L36 `metadata.raidName,` | — (이 파일에서 미추출) |
| `raidStartAt` | L44 `metadata.raidStartAt == null` | — (이 파일에서 미추출) |
| `recruitmentId` | L101 `command.recruitmentId,` | — (이 파일에서 미추출) |
| `rejectionMode` | L124 `command.approvalPolicy.rejectionMode.name,` | — (이 파일에서 미추출) |
| `requiredApprovals` | L122 `command.approvalPolicy.requiredApprovals,` | — (이 파일에서 미추출) |
| `revision` | L68 `1,` | — (이 파일에서 미추출) |
| `role` | L82 `command.leaderRole.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L27 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | L84 `0,` | — (이 파일에서 미추출) |
| `slotLedgerVersion` | L63 `2,` | — (이 파일에서 미추출) |
| `status` | L47 `'active',` | — (이 파일에서 미추출) |
| `submittedBuildSnapshotId` | L87 `null,` | — (이 파일에서 미추출) |
| `supportCount` | L67 `command.leaderRole.name == 'support' ? 1 : 0,` | — (이 파일에서 미추출) |
| `supportsPerParty` | L61 `rules.supportsPerParty,` | — (이 파일에서 미추출) |
| `targetCycleKey` | L55 `command.cycleKey,` | — (이 파일에서 미추출) |
| `title` | L28 `command.title.trim(),` | — (이 파일에서 미추출) |
| `updatedAt` | L70 `serverTimestamp,` | — (이 파일에서 미추출) |
| `visibility` | L48 `command.visibility,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | L49 `characterId,` | — (이 파일에서 미추출) |
| `createdAt` | L54 `serverTimestamp,` | — (이 파일에서 미추출) |
| `cycleKey` | L52 `targetCycleKey,` | — (이 파일에서 미추출) |
| `playerId` | L48 `playerId,` | — (이 파일에서 미추출) |
| `raidId` | L50 `raidId,` | — (이 파일에서 미추출) |
| `recruitmentId` | L51 `recruitmentId,` | — (이 파일에서 미추출) |
| `role` | L53 `role,` | — (이 파일에서 미추출) |
| `schemaVersion` | L47 `1,` | — (이 파일에서 미추출) |
| `updatedAt` | L55 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_cycle_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_cycle_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_cycle_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `completedAt` | L15 `serverTimestamp,` | — (이 파일에서 미추출) |
| `completedByPlayerId` | L16 `completedByPlayerId,` | — (이 파일에서 미추출) |
| `completedMemberSnapshot` | L21 `memberSnapshot,` | — (이 파일에서 미추출) |
| `completionRevision` | L17 `1,` | — (이 파일에서 미추출) |
| `continueTogether` | L100 `continueTogether,` | — (이 파일에서 미추출) |
| `createdAt` | L22 `serverTimestamp,` | — (이 파일에서 미추출) |
| `currentCycleKey` | L118 `nextCycleKey,` | — (이 파일에서 미추출) |
| `currentCycleStatus` | L87 `'completed',` | — (이 파일에서 미추출) |
| `cycleEndsAt` | L121 `timestamp(nextEndsAt),` | — (이 파일에서 미추출) |
| `cycleKey` | L13 `cycleKey,` | — (이 파일에서 미추출) |
| `cycleStartedAt` | L120 `timestamp(nextStartedAt),` | — (이 파일에서 미추출) |
| `dealerCount` | L147 `0,` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L124 `hasAvailableSlot,` | — (이 파일에서 미추출) |
| `leaderCharacterNameSnapshot` | L150 `null,` | — (이 파일에서 미추출) |
| `leaderClassNameSnapshot` | L151 `null,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L149 `null,` | — (이 파일에서 미추출) |
| `manualRecruitmentEnabled` | L88 `continueTogether,` | — (이 파일에서 미추출) |
| `memberCount` | L146 `0,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L18 `memberSnapshot` | — (이 파일에서 미추출) |
| `playerId` | — (이 파일에서 미추출) | L19 `.map((member) => member['playerId'])` |
| `recruitmentId` | L12 `recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L91 `revision + 1,` | — (이 파일에서 미추출) |
| `schemaVersion` | L11 `1,` | — (이 파일에서 미추출) |
| `status` | L14 `'completed',` | — (이 파일에서 미추출) |
| `supportCount` | L148 `0,` | — (이 파일에서 미추출) |
| `targetCycleKey` | L119 `nextCycleKey,` | — (이 파일에서 미추출) |
| `updatedAt` | L23 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_event_mapper.dart
근거: [lib/features/recruitment_list/data/mappers/party_event_mapper.dart](../../lib/features/recruitment_list/data/mappers/party_event_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorCharacterNameSnapshot` | — (이 파일에서 미추출) | L57 `actorCharacterNameSnapshot: _string(data['actorCharacterNameSnapshot']),` |
| `actorPlayerId` | — (이 파일에서 미추출) | L49 `actorPlayerId: _string(data['actorPlayerId']),` |
| `audiencePlayerIds` | — (이 파일에서 미추출) | L81 `final audience = data['audiencePlayerIds'];` |
| `characterId` | — (이 파일에서 미추출) | L51 `characterId: _string(data['characterId']),` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L52 `characterNameSnapshot: _string(data['characterNameSnapshot']),` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L53 `classNameSnapshot: _string(data['classNameSnapshot']),` |
| `commandRevision` | — (이 파일에서 미추출) | L79 `final commandRevision = data['commandRevision'];` |
| `completionTargets` | — (이 파일에서 미추출) | L147 `final targets = data['completionTargets'];` |
| `cycleKey` | — (이 파일에서 미추출) | L46 `cycleKey: _string(data['cycleKey']),` |
| `difficultyId` | — (이 파일에서 미추출) | L48 `difficultyId: _string(data['difficultyId']),` |
| `eventId` | — (이 파일에서 미추출) | L13 `final eventId = data['eventId'];` |
| `eventRevision` | — (이 파일에서 미추출) | L17 `final eventRevision = data['eventRevision'];` |
| `expiresAt` | — (이 파일에서 미추출) | L19 `final expiresAt = data['expiresAt'];` |
| `occurredAt` | — (이 파일에서 미추출) | L18 `final occurredAt = data['occurredAt'];` |
| `partyIndex` | — (이 파일에서 미추출) | L55 `partyIndex: _int(data['partyIndex']),` |
| `playerId` | — (이 파일에서 미추출) | L15 `final playerId = data['playerId'];` |
| `previousCharacterNameSnapshot` | — (이 파일에서 미추출) | L62 `data['previousCharacterNameSnapshot'],` |
| `raidId` | — (이 파일에서 미추출) | L47 `raidId: _string(data['raidId']),` |
| `recruitmentId` | — (이 파일에서 미추출) | L16 `final recruitmentId = data['recruitmentId'];` |
| `role` | — (이 파일에서 미추출) | L54 `role: _string(data['role']),` |
| `slotIndex` | — (이 파일에서 미추출) | L56 `slotIndex: _int(data['slotIndex']),` |
| `targetCharacterNameSnapshot` | — (이 파일에서 미추출) | L59 `data['targetCharacterNameSnapshot'],` |
| `targetPlayerId` | — (이 파일에서 미추출) | L50 `targetPlayerId: _string(data['targetPlayerId']),` |
| `type` | — (이 파일에서 미추출) | L14 `final type = data['type'];` |

### lib/features/recruitment_list/data/mappers/party_event_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_event_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_event_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `actorPlayerId` | L114 `actorPlayerId,` | — (이 파일에서 미추출) |
| `characterId` | L74 `memberSnapshot['characterId'],` | L74 `'characterId': memberSnapshot['characterId'],` |
| `characterNameSnapshot` | L75 `memberSnapshot['characterNameSnapshot'],` | L75 `'characterNameSnapshot': memberSnapshot['characterNameSnapshot'],` |
| `classNameSnapshot` | L76 `memberSnapshot['classNameSnapshot'],` | L76 `'classNameSnapshot': memberSnapshot['classNameSnapshot'],` |
| `cycleKey` | L70 `cycleKey,` | — (이 파일에서 미추출) |
| `difficultyId` | L72 `difficultyId,` | — (이 파일에서 미추출) |
| `endReason` | L216 `?endReason,` | — (이 파일에서 미추출) |
| `eventId` | L66 `eventId,` | — (이 파일에서 미추출) |
| `eventRevision` | L73 `eventRevision,` | — (이 파일에서 미추출) |
| `expiresAt` | L80 `expiresAt,` | — (이 파일에서 미추출) |
| `occurredAt` | L79 `serverTimestamp,` | — (이 파일에서 미추출) |
| `partyIndex` | L78 `memberSnapshot['partyIndex'],` | L78 `'partyIndex': memberSnapshot['partyIndex'],` |
| `playerId` | L68 `playerId,` | — (이 파일에서 미추출) |
| `previousCharacterNameSnapshot` | L170 `?previousCharacterNameSnapshot,` | — (이 파일에서 미추출) |
| `previousPartyIndex` | L176 `?previousPartyIndex,` | — (이 파일에서 미추출) |
| `previousSlotIndex` | L177 `?previousSlotIndex,` | — (이 파일에서 미추출) |
| `raidId` | L71 `raidId,` | — (이 파일에서 미추출) |
| `reason` | L178 `?reason,` | — (이 파일에서 미추출) |
| `recruitmentId` | L69 `recruitmentId,` | — (이 파일에서 미추출) |
| `rejectionCount` | L120 `?rejectionCount,` | — (이 파일에서 미추출) |
| `role` | L77 `memberSnapshot['role'],` | L77 `'role': memberSnapshot['role'],` |
| `schemaVersion` | L65 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | L175 `?slotIndex,` | — (이 파일에서 미추출) |
| `targetCharacterNameSnapshot` | L171 `?targetCharacterNameSnapshot,` | — (이 파일에서 미추출) |
| `targetPlayerId` | L166 `?targetPlayerId,` | — (이 파일에서 미추출) |
| `type` | L67 `type,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_join_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_join_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_join_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `buildIntegritySnapshot` | L62 `` | — (이 파일에서 미추출) |
| `canApproveApplications` | L65 `false,` | — (이 파일에서 미추출) |
| `characterChangedAt` | L64 `null,` | — (이 파일에서 미추출) |
| `characterId` | L50 `characterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L51 `characterName,` | — (이 파일에서 미추출) |
| `classNameSnapshot` | L52 `className,` | — (이 파일에서 미추출) |
| `combatPowerSnapshot` | L60 `combatPower,` | — (이 파일에서 미추출) |
| `createdAt` | L76 `serverTimestamp,` | — (이 파일에서 미추출) |
| `cycleKey` | L74 `cycleKey,` | — (이 파일에서 미추출) |
| `dealerCount` | L41 `dealerCount + (role == PartyRole.dealer ? 1 : 0),` | — (이 파일에서 미추출) |
| `gemValidationSnapshot` | L61 `gemValidationFields ?? gemValidation?.toFields(),` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L43 `memberCount + 1 < maxMemberCount,` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L59 `itemLevel,` | — (이 파일에서 미추출) |
| `joinedAt` | L56 `serverTimestamp,` | — (이 파일에서 미추출) |
| `joinedBy` | L57 `joinedBy,` | — (이 파일에서 미추출) |
| `memberCount` | L40 `memberCount + 1,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L39 `[...memberPlayerIds, playerId],` | — (이 파일에서 미추출) |
| `partyIndex` | L54 `partyIndex,` | — (이 파일에서 미추출) |
| `playerId` | L49 `playerId,` | — (이 파일에서 미추출) |
| `raidId` | L72 `raidId,` | — (이 파일에서 미추출) |
| `recruitmentId` | L73 `recruitmentId,` | — (이 파일에서 미추출) |
| `revision` | L44 `revision + 1,` | — (이 파일에서 미추출) |
| `role` | L53 `role.name,` | — (이 파일에서 미추출) |
| `schemaVersion` | L48 `1,` | — (이 파일에서 미추출) |
| `slotIndex` | L55 `slotIndex,` | — (이 파일에서 미추출) |
| `submittedBuildSnapshotId` | L58 `null,` | — (이 파일에서 미추출) |
| `supportCount` | L42 `supportCount + (role == PartyRole.support ? 1 : 0),` | — (이 파일에서 미추출) |
| `updatedAt` | L45 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_membership_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_membership_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_membership_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `buildIntegritySnapshot` | L27 `buildIntegrity?.toFields(),` | — (이 파일에서 미추출) |
| `canApproveApplications` | L53 `enabled, 'updatedAt': serverTimestamp};` | — (이 파일에서 미추출) |
| `characterChangedAt` | L30 `serverTimestamp,` | — (이 파일에서 미추출) |
| `characterId` | L20 `characterId,` | — (이 파일에서 미추출) |
| `characterNameSnapshot` | L21 `characterName,` | — (이 파일에서 미추출) |
| `classNameSnapshot` | L22 `className,` | — (이 파일에서 미추출) |
| `combatPowerSnapshot` | L25 `combatPower,` | — (이 파일에서 미추출) |
| `dealerCount` | L44 `dealerCount,` | — (이 파일에서 미추출) |
| `gemValidationSnapshot` | L26 `gemValidation?.toFields(),` | — (이 파일에서 미추출) |
| `hasAvailableSlot` | L81 `!disbanded && memberCount - 1 < maxMemberCount,` | — (이 파일에서 미추출) |
| `itemLevelSnapshot` | L24 `itemLevel,` | — (이 파일에서 미추출) |
| `leaderCharacterNameSnapshot` | L42 `characterName,` | — (이 파일에서 미추출) |
| `leaderClassNameSnapshot` | L43 `className,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | L78 `nextLeaderPlayerId,` | — (이 파일에서 미추출) |
| `manualRecruitmentEnabled` | L83 `false,` | — (이 파일에서 미추출) |
| `memberCount` | L75 `memberCount - 1,` | — (이 파일에서 미추출) |
| `memberPlayerIds` | L74 `remaining,` | — (이 파일에서 미추출) |
| `partyIndex` | L28 `?partyIndex,` | — (이 파일에서 미추출) |
| `revision` | L46 `revision + 1,` | — (이 파일에서 미추출) |
| `role` | L23 `role,` | — (이 파일에서 미추출) |
| `slotIndex` | L29 `?slotIndex,` | — (이 파일에서 미추출) |
| `status` | L82 `'disbanded',` | — (이 파일에서 미추출) |
| `supportCount` | L45 `supportCount,` | — (이 파일에서 미추출) |
| `updatedAt` | L31 `serverTimestamp,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart
근거: [lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart](../../lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `currentCycleStatus` | — (이 파일에서 미추출) | L30 `after['currentCycleStatus'] == 'disbanded';` |
| `groupId` | — (이 파일에서 미추출) | L18 `final groupId = after['groupId'];` |
| `status` | — (이 파일에서 미추출) | L29 `after['status'] == 'disbanded' \|\|` |
| `visibility` | — (이 파일에서 미추출) | L26 `currentRecruitment['visibility'] == RecruitmentVisibility.group;` |

### lib/features/recruitment_list/data/mappers/party_read_document_mapper.dart
근거: [lib/features/recruitment_list/data/mappers/party_read_document_mapper.dart](../../lib/features/recruitment_list/data/mappers/party_read_document_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `applicantPlayerId` | — (이 파일에서 미추출) | L146 `applicantPlayerId: _string(data, 'applicantPlayerId'),` |
| `approvalPolicy` | — (이 파일에서 미추출) | L212 `final policy = data['approvalPolicy'];` |
| `buildIntegritySnapshot` | — (이 파일에서 미추출) | L131 `data['buildIntegritySnapshot'],` |
| `characterId` | — (이 파일에서 미추출) | L148 `characterId: _string(data, 'characterId'),` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L149 `characterName: _string(data, 'characterNameSnapshot'),` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L150 `className: _string(data, 'classNameSnapshot'),` |
| `currentCycleKey` | — (이 파일에서 미추출) | L65 `currentCycleKey: _string(data, 'currentCycleKey'),` |
| `cycleKey` | — (이 파일에서 미추출) | L147 `cycleKey: _string(data, 'cycleKey'),` |
| `difficultyAliasSnapshot` | — (이 파일에서 미추출) | L198 `difficultyAlias: _string(data, 'difficultyAliasSnapshot'),` |
| `difficultyId` | — (이 파일에서 미추출) | L195 `difficultyId: _string(data, 'difficultyId'),` |
| `difficultyNameSnapshot` | — (이 파일에서 미추출) | L197 `difficultyName: _string(data, 'difficultyNameSnapshot'),` |
| `gemValidationSnapshot` | — (이 파일에서 미추출) | L115 `final gemSnapshot = data['gemValidationSnapshot'];` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L31 `final leaderPlayerId = data['leaderPlayerId'];` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L35 `final memberPlayerIds = data['memberPlayerIds'];` |
| `mode` | — (이 파일에서 미추출) | L214 `final mode = policy['mode'];` |
| `raidCatalogVersion` | — (이 파일에서 미추출) | L193 `catalogVersion: _string(data, 'raidCatalogVersion'),` |
| `raidId` | — (이 파일에서 미추출) | L194 `raidId: _string(data, 'raidId'),` |
| `raidNameSnapshot` | — (이 파일에서 미추출) | L196 `raidName: _string(data, 'raidNameSnapshot'),` |
| `recruitmentId` | — (이 파일에서 미추출) | L145 `recruitmentId: _string(data, 'recruitmentId'),` |
| `requestedRole` | — (이 파일에서 미추출) | L153 `_string(data, 'requestedRole'),` |
| `role` | — (이 파일에서 미추출) | L124 `role: _enumValue(PartyRole.values, _string(data, 'role'), 'role'),` |
| `slotIndex` | — (이 파일에서 미추출) | L287 `final value = data['slotIndex'];` |
| `slotLedgerVersion` | — (이 파일에서 미추출) | L77 `supportsPositionChanges: data['slotLedgerVersion'] == 2,` |
| `status` | — (이 파일에서 미추출) | L60 `_string(data, 'status') == 'active' &&` |
| `submittedBuildSnapshot` | — (이 파일에서 미추출) | L140 `final buildSnapshot = data['submittedBuildSnapshot'];` |
| `title` | — (이 파일에서 미추출) | L45 `title: _string(data, 'title'),` |

### lib/features/recruitment_list/data/mappers/party_visibility_write_plan.dart
근거: [lib/features/recruitment_list/data/mappers/party_visibility_write_plan.dart](../../lib/features/recruitment_list/data/mappers/party_visibility_write_plan.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `revision` | L22 `recruitmentRevision + 1,` | — (이 파일에서 미추출) |
| `updatedAt` | L23 `serverTimestamp,` | — (이 파일에서 미추출) |
| `visibility` | L21 `visibility,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/mappers/raid_state_availability.dart
근거: [lib/features/recruitment_list/data/mappers/raid_state_availability.dart](../../lib/features/recruitment_list/data/mappers/raid_state_availability.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterId` | — (이 파일에서 미추출) | L40 `data['characterId'] is String &&` |
| `guardCheckedAt` | — (이 파일에서 미추출) | L60 `data['guardCheckedAt'] is Timestamp;` |
| `guardCycleEndsAt` | — (이 파일에서 미추출) | L33 `final end = data['guardCycleEndsAt'];` |
| `guardCycleKey` | — (이 파일에서 미추출) | L53 `data['guardCycleKey'] is String &&` |
| `guardCycleStartedAt` | — (이 파일에서 미추출) | L32 `final start = data['guardCycleStartedAt'];` |
| `guardRecruitmentId` | — (이 파일에서 미추출) | L51 `data['guardRecruitmentId'] is String &&` |
| `guardRoomRevision` | — (이 파일에서 미추출) | L35 `final revision = data['guardRoomRevision'];` |
| `guardSchemaVersion` | — (이 파일에서 미추출) | L37 `return data['guardSchemaVersion'] == 1 &&` |
| `guardSlotIndex` | — (이 파일에서 미추출) | L34 `final index = data['guardSlotIndex'];` |
| `ownershipRevision` | — (이 파일에서 미추출) | L36 `final generation = data['ownershipRevision'];` |
| `playerId` | — (이 파일에서 미추출) | L38 `data['playerId'] is String &&` |
| `raidId` | — (이 파일에서 미추출) | L42 `data['raidId'] is String &&` |

### lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | L313 `count - 1,` | L306 `final count = group?['activeRecruitmentCount'];` |
| `canApproveApplications` | L331 `true,` | — (이 파일에서 미추출) |
| `characterId` | — (이 파일에서 미추출) | L63 `final characterId = target['characterId'] as String;` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L162 `nextMember['characterNameSnapshot'] is! String \|\|` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L163 `nextMember['classNameSnapshot'] is! String) {` |
| `groupActiveRecruitmentCountAfter` | — (이 파일에서 미추출) | L311 `patch['groupActiveRecruitmentCountAfter'] = count - 1;` |
| `groupId` | — (이 파일에서 미추출) | L299 `final groupId = room['groupId'];` |
| `lastRecruitmentId` | L314 `observation.roomId,` | — (이 파일에서 미추출) |
| `leaderPlayerId` | — (이 파일에서 미추출) | L89 `final leaderTarget = targetId == room['leaderPlayerId'];` |
| `ownershipRevision` | — (이 파일에서 미추출) | L75 `? member['ownershipRevision']` |
| `partySlots` | — (이 파일에서 미추출) | L56 `final slots = List<Map<String, dynamic>>.from(room['partySlots'] as List);` |
| `playerId` | — (이 파일에서 미추출) | L25 `final actor = binding?['playerId'];` |
| `revision` | L315 `revision + 1,` | L176 `revision: room['revision'] as int,` |
| `status` | — (이 파일에서 미추출) | L26 `if (binding?['status'] != 'active' \|\| actor is! String \|\| actor.isEmpty) {` |
| `updatedAt` | L316 `now,` | L168 `successorUpdatedAt = nextMember['updatedAt'];` |
| `visibility` | — (이 파일에서 미추출) | L300 `if (room['visibility'] == 'group' &&` |

### lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart](../../lib/features/recruitment_list/data/repositories/firestore_lazy_cycle_reconciliation_gateway.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `currentCycleKey` | — (이 파일에서 미추출) | L33 `final currentCycleKey = data['currentCycleKey'];` |
| `revision` | — (이 파일에서 미추출) | L34 `final revision = data['revision'];` |
| `status` | — (이 파일에서 미추출) | L30 `if (data == null \|\| data['status'] != 'active') {` |

### lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_application_cleanup_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `playerId` | — (이 파일에서 미추출) | L36 `if (data?['status'] != 'active' \|\| data?['playerId'] != applicantPlayerId) {` |
| `status` | — (이 파일에서 미추출) | L36 `if (data?['status'] != 'active' \|\| data?['playerId'] != applicantPlayerId) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_application_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `approvalPolicy` | — (이 파일에서 미추출) | L55 `if ((r?['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') {` |
| `characterClassName` | — (이 파일에서 미추출) | L117 `final className = c?['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L116 `final name = c?['characterName'];` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L248 `final characterName = data?['characterNameSnapshot'];` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L274 `classNameSnapshot: data?['classNameSnapshot'] is String` |
| `difficultyId` | — (이 파일에서 미추출) | L133 `r?['difficultyId'] is String ? r!['difficultyId'] as String : null;` |
| `hasAvailableSlot` | — (이 파일에서 미추출) | L60 `if (r?['hasAvailableSlot'] != true) {` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L109 `final itemLevel = _parseItemLevel(c?['itemAvgLevel']);` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L124 `final leaderPlayerId = r?['leaderPlayerId'];` |
| `manualRecruitmentEnabled` | — (이 파일에서 미추출) | L50 `r?['manualRecruitmentEnabled'] != true) {` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L65 `if ((r?['memberPlayerIds'] as List?)?.contains(playerId) == true) {` |
| `minItemLevel` | — (이 파일에서 미추출) | L111 `itemLevel < (r?['minItemLevel'] as num? ?? double.infinity)) {` |
| `mode` | — (이 파일에서 미추출) | L55 `if ((r?['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') {` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L104 `if (c?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L307 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L75 `final raidId = r?['raidId'];` |
| `requestedRole` | — (이 파일에서 미추출) | L277 `role: data?['requestedRole'] is String` |
| `revision` | — (이 파일에서 미추출) | L179 `final revision = a?['revision'];` |
| `status` | — (이 파일에서 미추출) | L49 `if (r?['status'] != 'active' \|\|` |
| `targetCycleKey` | — (이 파일에서 미추출) | L70 `if (command.cycleKey != r?['targetCycleKey']) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_application_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `approvalPolicy` | — (이 파일에서 미추출) | L89 `if ((raw['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') {` |
| `characterClassName` | — (이 파일에서 미추출) | L165 `final className = characterData?['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L164 `final name = characterData?['characterName'];` |
| `eventId` | — (이 파일에서 미추출) | L221 `.doc(plan.event['eventId']! as String),` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L163 `final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);` |
| `manualRecruitmentEnabled` | — (이 파일에서 미추출) | L84 `raw['manualRecruitmentEnabled'] != true) {` |
| `minCombatPower` | — (이 파일에서 미추출) | L176 `minimum: raw['minCombatPower'] as num?,` |
| `minItemLevel` | — (이 파일에서 미추출) | L167 `itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) \|\|` |
| `mode` | — (이 파일에서 미추출) | L89 `if ((raw['approvalPolicy'] as Map?)?['mode'] != 'leaderOnly') {` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L158 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L350 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L112 `final raidId = raw['raidId'];` |
| `revision` | — (이 파일에서 미추출) | L241 `final revision = existing?['revision'];` |
| `status` | — (이 파일에서 미추출) | L83 `if (raw['status'] != 'active' \|\|` |
| `targetCycleKey` | — (이 파일에서 미추출) | L107 `if (command.cycleKey != raw['targetCycleKey']) {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | L152 `nextCount,` | L143 `final count = group.data()?['activeRecruitmentCount'];` |
| `characterId` | L319 `slot.characterId,` | — (이 파일에서 미추출) |
| `committed` | L205 `'rejected',` | — (이 파일에서 미추출) |
| `completedAt` | L189 `FieldValue.delete(),` | — (이 파일에서 미추출) |
| `cycleEndsAt` | — (이 파일에서 미추출) | L134 `recruitmentPatch['cycleEndsAt'] = Timestamp.fromDate(` |
| `cycleStartedAt` | — (이 파일에서 미추출) | L131 `recruitmentPatch['cycleStartedAt'] = Timestamp.fromDate(` |
| `groupActiveRecruitmentCountAfter` | — (이 파일에서 미추출) | L150 `recruitmentPatch['groupActiveRecruitmentCountAfter'] = nextCount;` |
| `guardCheckedAt` | L333 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |
| `guardCycleEndsAt` | L329 `Timestamp.fromDate(` | — (이 파일에서 미추출) |
| `guardCycleKey` | L325 `command.nextCycleKey,` | — (이 파일에서 미추출) |
| `guardCycleStartedAt` | L326 `Timestamp.fromDate(` | — (이 파일에서 미추출) |
| `guardRecruitmentId` | L323 `command.recruitmentId,` | — (이 파일에서 미추출) |
| `guardRoomRevision` | L324 `command.expectedRevision,` | — (이 파일에서 미추출) |
| `guardSchemaVersion` | L322 `1,` | — (이 파일에서 미추출) |
| `guardSlotIndex` | L332 `index,` | — (이 파일에서 미추출) |
| `lastRecruitmentId` | L153 `command.recruitmentId,` | — (이 파일에서 미추출) |
| `ownershipRevision` | L321 `slot.ownershipRevision ?? 0,` | — (이 파일에서 미추출) |
| `playerId` | L318 `slot.playerId,` | L57 `final playerId = bindingData?['playerId'];` |
| `raidId` | L320 `aggregate.raidId,` | — (이 파일에서 미추출) |
| `revision` | L154 `FieldValue.increment(1),` | — (이 파일에서 미추출) |
| `status` | — (이 파일에서 미추출) | L58 `if (bindingData?['status'] != 'active' \|\|` |
| `updatedAt` | L155 `FieldValue.serverTimestamp(),` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_create_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | — (이 파일에서 미추출) | L281 `: ((group?.data()?['activeRecruitmentCount'] as int?) ?? -1) + 1;` |
| `characterClassName` | — (이 파일에서 미추출) | L255 `final verifiedClass = characterData?['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L254 `final verifiedName = characterData?['characterName'];` |
| `continueTogether` | — (이 파일에서 미추출) | L161 `assignedRecruitment?.data()?['continueTogether'] == true,` |
| `currentCycleKey` | — (이 파일에서 미추출) | L158 `assignedRecruitment?.data()?['currentCycleKey']` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L155 `assignedRecruitment?.data()?['currentCycleStatus']` |
| `cycleEndsAt` | — (이 파일에서 미추출) | L163 `(assignedRecruitment?.data()?['cycleEndsAt']` |
| `cycleKey` | — (이 파일에서 미추출) | L129 `final raidStateCycleKey = raidStateData?['cycleKey'];` |
| `eventId` | — (이 파일에서 미추출) | L374 `.doc(plan.event['eventId']! as String),` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L257 `characterData?['itemAvgLevel'],` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L208 `recruitment.data()?['leaderPlayerId'] as String?,` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L191 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L57 `final playerId = bindingData?['playerId'];` |
| `recruitmentId` | — (이 파일에서 미추출) | L128 `final raidStateRecruitmentId = raidStateData?['recruitmentId'];` |
| `revision` | — (이 파일에서 미추출) | L343 `final groupRevision = group?.data()?['revision'];` |
| `status` | — (이 파일에서 미추출) | L58 `if (bindingData?['status'] != 'active' \|\|` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_join_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `approvalCount` | — (이 파일에서 미추출) | L440 `(applicationData?['approvalCount'] as num?)?.toInt() ?? 0;` |
| `approvalPolicy` | — (이 파일에서 미추출) | L184 `if ((raw['approvalPolicy'] as Map?)?['mode'] != 'directJoin') {` |
| `buildIntegritySnapshot` | — (이 파일에서 미추출) | L227 `submitted['buildIntegritySnapshot'],` |
| `canApproveApplications` | — (이 파일에서 미추출) | L555 `return member.data()?['canApproveApplications'] == true;` |
| `characterClassName` | — (이 파일에서 미추출) | L345 `final className = characterData?['characterClassName'];` |
| `characterId` | — (이 파일에서 미추출) | L216 `requestedCharacterId = applicationData['characterId'] as String?;` |
| `characterName` | — (이 파일에서 미추출) | L344 `final name = characterData?['characterName'];` |
| `combatPower` | — (이 파일에서 미추출) | L221 `combatPower = (submitted['combatPower'] as num?)?.toDouble();` |
| `countedAsNonGroupApplicant` | — (이 파일에서 미추출) | L438 `applicationData?['countedAsNonGroupApplicant'] == true;` |
| `cycleKey` | — (이 파일에서 미추출) | L218 `requestedCycleKey = applicationData['cycleKey'] as String?;` |
| `difficultyId` | — (이 파일에서 미추출) | L244 `final difficultyId = raw['difficultyId'];` |
| `eventId` | — (이 파일에서 미추출) | L132 `.doc(plan.event['eventId']! as String),` |
| `groupId` | — (이 파일에서 미추출) | L335 `? raw['groupId']` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L343 `final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);` |
| `manualRecruitmentEnabled` | — (이 파일에서 미추출) | L165 `raw['manualRecruitmentEnabled'] != true) {` |
| `minCombatPower` | — (이 파일에서 미추출) | L353 `.evaluate(minimum: raw['minCombatPower'] as num?, actual: combatPower)` |
| `minItemLevel` | — (이 파일에서 미추출) | L347 `itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) \|\|` |
| `mode` | — (이 파일에서 미추출) | L184 `if ((raw['approvalPolicy'] as Map?)?['mode'] != 'directJoin') {` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L305 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L504 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L243 `final raidId = raw['raidId'];` |
| `requestedRole` | — (이 파일에서 미추출) | L217 `requestedRole = _role(applicationData['requestedRole']);` |
| `revision` | — (이 파일에서 미추출) | L98 `if (raw['revision'] != command.expectedRecruitmentRevision \|\|` |
| `status` | — (이 파일에서 미추출) | L102 `if (applicationData['status'] != 'pending') {` |
| `submittedBuildSnapshot` | — (이 파일에서 미추출) | L219 `final submitted = applicationData['submittedBuildSnapshot'];` |
| `targetCycleKey` | — (이 파일에서 미추출) | L237 `requestedCycleKey != raw['targetCycleKey']) {` |
| `visibility` | — (이 파일에서 미추출) | L334 `final listingGroupId = raw['visibility'] == 'group'` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L234 `final className = characterData?['characterClassName'];` |
| `characterId` | — (이 파일에서 미추출) | L82 `final oldCharacterId = memberData['characterId'];` |
| `characterName` | — (이 파일에서 미추출) | L233 `final name = characterData?['characterName'];` |
| `committed` | L493 `'rejected'} failure=${result.failure}',` | — (이 파일에서 미추출) |
| `difficultyId` | — (이 파일에서 미추출) | L96 `final difficultyId = raw['difficultyId'];` |
| `eventId` | — (이 파일에서 미추출) | L323 `.doc(plan.event['eventId']! as String),` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L232 `final itemLevel = _parseItemLevel(characterData?['itemAvgLevel']);` |
| `minCombatPower` | — (이 파일에서 미추출) | L245 `minimum: raw['minCombatPower'] as num?,` |
| `minItemLevel` | — (이 파일에서 미추출) | L236 `itemLevel < (raw['minItemLevel'] as num? ?? double.infinity) \|\|` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L190 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `playerId` | — (이 파일에서 미추출) | L481 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L95 `final raidId = raw['raidId'];` |
| `recruitmentId` | — (이 파일에서 미추출) | L197 `previousRaidState.data()?['recruitmentId'] !=` |
| `revision` | — (이 파일에서 미추출) | L63 `if (raw['revision'] != command.expectedRecruitmentRevision) {` |
| `role` | — (이 파일에서 미추출) | L83 `final oldRole = _role(memberData['role']);` |
| `status` | — (이 파일에서 미추출) | L185 `if (!character.exists \|\| characterData?['status'] != 'active') {` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterNameSnapshot` | — (이 파일에서 미추출) | L102 `final characterName = data?['characterNameSnapshot'];` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L103 `final className = data?['classNameSnapshot'];` |
| `eventId` | — (이 파일에서 미추출) | L205 `.doc(plan.event['eventId']! as String),` |
| `playerId` | — (이 파일에서 미추출) | L44 `final actorPlayerId = bindingData?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L138 `final raidId = raw['raidId'];` |
| `recruitmentId` | — (이 파일에서 미추출) | L159 `raidState.data()?['recruitmentId'] != command.recruitmentId \|\|` |
| `status` | — (이 파일에서 미추출) | L45 `if (bindingData?['status'] != 'active' \|\|` |

### lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeRecruitmentCount` | — (이 파일에서 미추출) | L124 `final activeCount = groupData?['activeRecruitmentCount'];` |
| `playerId` | — (이 파일에서 미추출) | L46 `final playerId = bindingData?['playerId'];` |
| `revision` | — (이 파일에서 미추출) | L65 `if (raw['revision'] != command.expectedRecruitmentRevision) {` |
| `status` | — (이 파일에서 미추출) | L47 `if (bindingData?['status'] != 'active' \|\|` |

### lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_create_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `characterClassName` | — (이 파일에서 미추출) | L171 `final verifiedClass = characterData?['characterClassName'];` |
| `characterName` | — (이 파일에서 미추출) | L170 `final verifiedName = characterData?['characterName'];` |
| `continueTogether` | — (이 파일에서 미추출) | L134 `assignedRecruitment?.data()?['continueTogether'] == true,` |
| `currentCycleKey` | — (이 파일에서 미추출) | L132 `assignedRecruitment?.data()?['currentCycleKey'] as String?,` |
| `cycleEndsAt` | — (이 파일에서 미추출) | L136 `(assignedRecruitment?.data()?['cycleEndsAt'] as Timestamp?)` |
| `cycleKey` | — (이 파일에서 미추출) | L79 `final assignmentCycleKey = assignment.data()?['cycleKey'];` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L173 `characterData?['itemAvgLevel'],` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L120 `recruitment.data()?['leaderPlayerId'] as String?,` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L110 `if (characterData?['ownerPlayerId'] != playerId) {` |
| `partyIndex` | L200 `0,` | — (이 파일에서 미추출) |
| `playerId` | L199 `playerId,` | L41 `final playerId = bindingData?['playerId'];` |
| `recruitmentId` | — (이 파일에서 미추출) | L78 `final assignmentRecruitmentId = assignment.data()?['recruitmentId'];` |
| `slotIndex` | L201 `0,` | — (이 파일에서 미추출) |
| `status` | — (이 파일에서 미추출) | L42 `if (bindingData?['status'] != 'active' \|\|` |
| `updatedAt` | L202 `now,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_cycle_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `applicantPlayerId` | — (이 파일에서 미추출) | L608 `final applicantId = data?['applicantPlayerId'];` |
| `characterId` | L776 `data['characterId'],` | L124 `final characterId = member['characterId'] as String;` |
| `characterNameSnapshot` | L777 `data['characterNameSnapshot'],` | L561 `characterNames[current.id] = data['characterNameSnapshot'] is String` |
| `classNameSnapshot` | L778 `data['classNameSnapshot'],` | L778 `'classNameSnapshot': data['classNameSnapshot'],` |
| `combatPowerSnapshot` | L783 `data['combatPowerSnapshot'],` | L783 `'combatPowerSnapshot': data['combatPowerSnapshot'],` |
| `completedMemberSnapshot` | — (이 파일에서 미추출) | L102 `((cycle.data()?['completedMemberSnapshot'] as List?) ?? const [])` |
| `completionRevision` | — (이 파일에서 미추출) | L98 `? _readInt(cycle.data()?['completionRevision']) + 1` |
| `continueTogether` | — (이 파일에서 미추출) | L205 `continueTogether: r['continueTogether'] == true,` |
| `currentCycleKey` | — (이 파일에서 미추출) | L537 `final cycleKey = r['currentCycleKey'];` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L57 `if (r?['currentCycleStatus'] != 'active' \|\|` |
| `cycleEndsAt` | — (이 파일에서 미추출) | L93 `final cycleEndsAt = r['cycleEndsAt'];` |
| `cycleKey` | L483 `command.nextCycleKey,` | L385 `assignmentCycleKey: assignment.data()?['cycleKey'] as String?,` |
| `cycleStartedAt` | — (이 파일에서 미추출) | L92 `final cycleStartedAt = r['cycleStartedAt'];` |
| `difficultyId` | — (이 파일에서 미추출) | L91 `final difficultyId = r['difficultyId'] as String;` |
| `groupId` | — (이 파일에서 미추출) | L169 `groupId: r['groupId'],` |
| `itemLevelSnapshot` | L782 `data['itemLevelSnapshot'],` | L782 `'itemLevelSnapshot': data['itemLevelSnapshot'],` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L55 `if (r?['leaderPlayerId'] != playerId)` |
| `maxMemberCount` | — (이 파일에서 미추출) | L454 `(r?['memberCount'] as int) < (r?['maxMemberCount'] as int),` |
| `memberCount` | — (이 파일에서 미추출) | L63 `if (snapshot == null \|\| snapshot.length != r?['memberCount']) {` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L69 `(r?['memberPlayerIds'] as List?)?.map((id) => id.toString()) ??` |
| `partyIndex` | L780 `data['partyIndex'],` | L585 `final partyIndex = data['partyIndex'];` |
| `playerId` | L775 `member.id,` | L78 `for (final member in snapshot) member['playerId'] as String: member,` |
| `raidId` | — (이 파일에서 미추출) | L90 `final raidId = r!['raidId'] as String;` |
| `recruitmentId` | — (이 파일에서 미추출) | L384 `assignment.data()?['recruitmentId'] as String?,` |
| `revision` | — (이 파일에서 미추출) | L272 `if (r['revision'] != command.expectedRecruitmentRevision)` |
| `role` | L779 `data['role'],` | L368 `final role = member['role'] as String?;` |
| `slotIndex` | L781 `data['slotIndex'],` | L586 `final slotIndex = data['slotIndex'];` |
| `slotLedgerVersion` | — (이 파일에서 미추출) | L581 `if (r['slotLedgerVersion'] == 2) {` |
| `status` | — (이 파일에서 미추출) | L58 `(cycle.exists && cycle.data()?['status'] != 'completionCancelled'))` |
| `updatedAt` | L484 `now,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_join_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `approvalCount` | L454 `(applicationData?['approvalCount'] as int? ?? 0) + 1,` | L454 `'approvalCount': (applicationData?['approvalCount'] as int? ?? 0) + 1,` |
| `approvalPolicy` | — (이 파일에서 미추출) | L180 `if ((r?['approvalPolicy'] as Map?)?['mode'] != 'directJoin')` |
| `buildIntegritySnapshot` | — (이 파일에서 미추출) | L213 `submitted['buildIntegritySnapshot'],` |
| `canApproveApplications` | — (이 파일에서 미추출) | L523 `return member.data()?['canApproveApplications'] == true;` |
| `characterClassName` | — (이 파일에서 미추출) | L305 `final className = c?['characterClassName'];` |
| `characterId` | — (이 파일에서 미추출) | L202 `requestedCharacterId = applicationData?['characterId'] as String?;` |
| `characterName` | — (이 파일에서 미추출) | L304 `final name = c?['characterName'];` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L97 `final characterName = a?['characterNameSnapshot'];` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L118 `classNameSnapshot: a?['classNameSnapshot'] is String` |
| `combatPower` | — (이 파일에서 미추출) | L207 `combatPower = (submitted['combatPower'] as num?)?.toDouble();` |
| `continueTogether` | — (이 파일에서 미추출) | L288 `assignedRecruitment?.data()?['continueTogether'] as bool?,` |
| `currentCycleKey` | — (이 파일에서 미추출) | L286 `assignedRecruitment?.data()?['currentCycleKey'] as String?,` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L284 `assignedRecruitment?.data()?['currentCycleStatus'] as String?,` |
| `cycleKey` | — (이 파일에서 미추출) | L204 `requestedCycleKey = applicationData?['cycleKey'] as String?;` |
| `dealerCount` | — (이 파일에서 미추출) | L334 `final dealerCount = _asInt(r?['dealerCount']);` |
| `decidedAt` | L106 `now,` | — (이 파일에서 미추출) |
| `difficultyId` | — (이 파일에서 미추출) | L125 `difficultyId: r?['difficultyId'] is String` |
| `groupId` | — (이 파일에서 미추출) | L372 `groupId: r?['groupId'],` |
| `hasAvailableSlot` | — (이 파일에서 미추출) | L171 `if (r?['hasAvailableSlot'] != true)` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L303 `final itemLevel = _parseItemLevel(c?['itemAvgLevel']);` |
| `joinedAt` | — (이 파일에서 미추출) | L549 `joinedAt: _joinedAt(data?['joinedAt']),` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L319 `leaderPlayerId: r?['leaderPlayerId'] as String?,` |
| `manualRecruitmentEnabled` | — (이 파일에서 미추출) | L167 `if (r?['status'] != 'active' \|\| r?['manualRecruitmentEnabled'] != true)` |
| `maxDealersPerClassPerParty` | — (이 파일에서 미추출) | L330 `r?['maxDealersPerClassPerParty'],` |
| `maxMemberCount` | — (이 파일에서 미추출) | L333 `final maxMemberCount = _asInt(r?['maxMemberCount']);` |
| `memberCount` | — (이 파일에서 미추출) | L332 `final memberCount = _asInt(r?['memberCount']);` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L218 `if ((r?['memberPlayerIds'] as List?)?.contains(playerId) == true)` |
| `membersPerParty` | — (이 파일에서 미추출) | L327 `final membersPerParty = _asInt(r?['membersPerParty']);` |
| `minItemLevel` | — (이 파일에서 미추출) | L307 `itemLevel < (r?['minItemLevel'] as num? ?? double.infinity) \|\|` |
| `mode` | — (이 파일에서 미추출) | L180 `if ((r?['approvalPolicy'] as Map?)?['mode'] != 'directJoin')` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L270 `if (c?['ownerPlayerId'] != playerId)` |
| `partyCount` | — (이 파일에서 미추출) | L326 `final partyCount = _asInt(r?['partyCount']);` |
| `partyIndex` | L413 `placement.slot!.partyIndex,` | L540 `final partyIndex = _asInt(data?['partyIndex']);` |
| `playerId` | L412 `playerId,` | L493 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L124 `raidId: r?['raidId'] is String ? r!['raidId'] as String : null,` |
| `recruitmentId` | — (이 파일에서 미추출) | L238 `final assignmentRecruitmentId = assignmentData?['recruitmentId'];` |
| `rejectionCount` | L104 `rejectionCount,` | L96 `final rejectionCount = (a?['rejectionCount'] as int? ?? 0) + 1;` |
| `requestedRole` | — (이 파일에서 미추출) | L121 `role: a?['requestedRole'] is String` |
| `resolutionReason` | L103 `'rejectedByApprover',` | — (이 파일에서 미추출) |
| `revision` | L105 `nextRevision,` | L87 `if (r?['revision'] != command.expectedRecruitmentRevision \|\|` |
| `role` | — (이 파일에서 미추출) | L538 `final role = _role(data?['role']);` |
| `slotIndex` | L414 `placement.slot!.slotIndex,` | L541 `final slotIndex = _asInt(data?['slotIndex']);` |
| `slotLedgerVersion` | — (이 파일에서 미추출) | L408 `if (r?['slotLedgerVersion'] == 2) {` |
| `status` | L102 `'rejected',` | L90 `if (a?['status'] != 'pending')` |
| `submittedBuildSnapshot` | — (이 파일에서 미추출) | L205 `final submitted = applicationData?['submittedBuildSnapshot'];` |
| `supportCount` | — (이 파일에서 미추출) | L335 `final supportCount = _asInt(r?['supportCount']);` |
| `supportsPerParty` | — (이 파일에서 미추출) | L328 `final supportsPerParty = _asInt(r?['supportsPerParty']);` |
| `targetCycleKey` | — (이 파일에서 미추출) | L222 `requestedCycleKey != r?['targetCycleKey'])` |
| `updatedAt` | L107 `now,` | — (이 파일에서 미추출) |

### lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_membership_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `canApproveApplications` | L487 `true, 'updatedAt': now},` | — (이 파일에서 미추출) |
| `characterClassName` | — (이 파일에서 미추출) | L140 `final className = c?['characterClassName'];` |
| `characterId` | L244 `command.newCharacterId,` | L57 `final oldCharacterId = m?['characterId'];` |
| `characterName` | — (이 파일에서 미추출) | L139 `final name = c?['characterName'];` |
| `characterNameSnapshot` | — (이 파일에서 미추출) | L166 `final previousCharacterName = m?['characterNameSnapshot'];` |
| `classNameSnapshot` | — (이 파일에서 미추출) | L435 `nextLeaderClassName = leaderData?['classNameSnapshot'] as String?;` |
| `continueTogether` | — (이 파일에서 미추출) | L70 `r?['continueTogether'] == true &&` |
| `createdAt` | L246 `now,` | — (이 파일에서 미추출) |
| `currentCycleKey` | — (이 파일에서 미추출) | L97 `cycleKey: r?['currentCycleKey'] as String,` |
| `currentCycleStatus` | — (이 파일에서 미추출) | L71 `r?['currentCycleStatus'] == 'completed';` |
| `dealerCount` | L267 `dealerCount,` | L181 `final oldDealerCount = r['dealerCount'] as int;` |
| `difficultyId` | — (이 파일에서 미추출) | L293 `difficultyId: r['difficultyId'] is String` |
| `groupId` | — (이 파일에서 미추출) | L175 `groupId: r['groupId'],` |
| `itemAvgLevel` | — (이 파일에서 미추출) | L138 `final itemLevel = _itemLevel(c?['itemAvgLevel']);` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L250 `if (r['leaderPlayerId'] == playerId) {` |
| `maxDealersPerClassPerParty` | — (이 파일에서 미추출) | L635 `final classLimit = recruitment?['maxDealersPerClassPerParty'];` |
| `maxMemberCount` | — (이 파일에서 미추출) | L450 `maxMemberCount: r?['maxMemberCount'] as int,` |
| `memberCount` | — (이 파일에서 미추출) | L446 `memberCount: r?['memberCount'] as int,` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L180 `final beforeMembers = List<String>.from(r['memberPlayerIds'] as List);` |
| `membersPerParty` | — (이 파일에서 미추출) | L633 `final membersPerParty = recruitment?['membersPerParty'];` |
| `minItemLevel` | — (이 파일에서 미추출) | L142 `itemLevel < (r?['minItemLevel'] as num? ?? double.infinity) \|\|` |
| `ownerPlayerId` | — (이 파일에서 미추출) | L108 `if (c?['ownerPlayerId'] != playerId)` |
| `partyCount` | — (이 파일에서 미추출) | L632 `final partyCount = recruitment?['partyCount'];` |
| `partyIndex` | L225 `destination.partyIndex,` | L191 `final oldPartyIndex = m?['partyIndex'];` |
| `playerId` | L224 `playerId,` | L922 `final playerId = data?['playerId'];` |
| `raidId` | — (이 파일에서 미추출) | L78 `r?['raidId'] as String,` |
| `revision` | L269 `nextRevision,` | L956 `if (data['revision'] != revision)` |
| `role` | L237 `newRole.name,` | L58 `final oldRole = _role(m?['role']);` |
| `slotIndex` | L226 `destination.slotIndex,` | L192 `final oldSlotIndex = m?['slotIndex'];` |
| `slotLedgerVersion` | — (이 파일에서 미추출) | L161 `if (destination != null && r['slotLedgerVersion'] != 2) {` |
| `status` | — (이 파일에서 미추출) | L104 `if (!character.exists \|\| c?['status'] != 'active')` |
| `supportCount` | L268 `supportCount,` | L182 `final oldSupportCount = r['supportCount'] as int;` |
| `supportsPerParty` | — (이 파일에서 미추출) | L634 `final supportsPerParty = recruitment?['supportsPerParty'];` |
| `updatedAt` | L227 `now,` | — (이 파일에서 미추출) |
| `visibility` | — (이 파일에서 미추출) | L362 `if (r?['visibility'] != 'group' \|\|` |

### lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `currentCycleStatus` | — (이 파일에서 미추출) | L64 `after['currentCycleStatus'] == 'disbanded') {` |
| `groupId` | — (이 파일에서 미추출) | L27 `final groupId = data['groupId'];` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L67 `final members = after['memberPlayerIds'];` |
| `status` | — (이 파일에서 미추출) | L63 `if (after['status'] != 'active' \|\|` |
| `visibility` | — (이 파일에서 미추출) | L26 `if (data['visibility'] != 'group') continue;` |

### lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `activeGroupIds` | — (이 파일에서 미추출) | L172 `final ids = snapshot.data()?['activeGroupIds'];` |
| `completionRevision` | — (이 파일에서 미추출) | L475 `final revision = data['completionRevision'];` |
| `currentCycleKey` | — (이 파일에서 미추출) | L243 `data['currentCycleKey'] == cycleKey);` |
| `hasAvailableSlot` | — (이 파일에서 미추출) | L241 `data['hasAvailableSlot'] == true &&` |
| `manualRecruitmentEnabled` | — (이 파일에서 미추출) | L240 `data['manualRecruitmentEnabled'] == true &&` |
| `schemaVersion` | — (이 파일에서 미추출) | L237 `return data['schemaVersion'] == 2 &&` |
| `status` | — (이 파일에서 미추출) | L239 `data['status'] == 'active' &&` |
| `targetCycleKey` | — (이 파일에서 미추출) | L242 `(data['targetCycleKey'] == cycleKey \|\|` |
| `visibility` | — (이 파일에서 미추출) | L238 `data['visibility'] == 'group' &&` |

### lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart
근거: [lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart](../../lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `groupId` | — (이 파일에서 미추출) | L66 `final groupId = data['groupId'];` |
| `leaderPlayerId` | — (이 파일에서 미추출) | L61 `if (data['leaderPlayerId'] != playerId) {` |
| `memberPlayerIds` | — (이 파일에서 미추출) | L92 `for (final id in (data['memberPlayerIds'] as List?) ?? const [])` |
| `playerId` | — (이 파일에서 미추출) | L162 `final playerId = data?['playerId'];` |
| `revision` | — (이 파일에서 미추출) | L51 `if (data['revision'] != command.expectedRecruitmentRevision) {` |
| `status` | — (이 파일에서 미추출) | L56 `if (data['status'] != 'active') {` |
| `visibility` | — (이 파일에서 미추출) | L72 `final currentVisibility = data['visibility'];` |

### lib/shared/game_catalog/data/mappers/game_catalog_mapper.dart
근거: [lib/shared/game_catalog/data/mappers/game_catalog_mapper.dart](../../lib/shared/game_catalog/data/mappers/game_catalog_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `apiClassName` | — (이 파일에서 미추출) | L18 `apiClassName: _string(json, 'apiClassName'),` |
| `branchId` | — (이 파일에서 미추출) | L51 `branchId: _string(json, 'branchId'),` |
| `catalogVersion` | — (이 파일에서 미추출) | L9 `catalogVersion: _string(json, 'catalogVersion'),` |
| `category` | — (이 파일에서 미추출) | L65 `category: _skillCategoryFromName(_string(json, 'category')),` |
| `classId` | — (이 파일에서 미추출) | L17 `classId: _string(json, 'classId'),` |
| `coreName` | — (이 파일에서 미추출) | L90 `coreName: _string(json, 'coreName'),` |
| `defaultRole` | — (이 파일에서 미추출) | L24 `defaultRole: _roleFromName(_string(json, 'defaultRole')),` |
| `displayName` | — (이 파일에서 미추출) | L53 `displayName: _string(json, 'displayName'),` |
| `inferredRole` | — (이 파일에서 미추출) | L55 `inferredRole: _roleFromName(_string(json, 'inferredRole')),` |
| `name` | — (이 파일에서 미추출) | L43 `name: _string(json, 'name'),` |
| `presetId` | — (이 파일에서 미추출) | L72 `presetId: _string(json, 'presetId'),` |
| `recommendedPoint` | — (이 파일에서 미추출) | L85 `final recommendedPoint = json['recommendedPoint'];` |
| `skillId` | — (이 파일에서 미추출) | L62 `skillId: _string(json, 'skillId'),` |
| `targetId` | — (이 파일에서 미추출) | L42 `targetId: _string(json, 'targetId'),` |
| `tier1NodeName` | — (이 파일에서 미추출) | L52 `tier1NodeName: _string(json, 'tier1NodeName'),` |
| `updatedAt` | — (이 파일에서 미추출) | L10 `updatedAt: DateTime.parse(_string(json, 'updatedAt')),` |

### lib/shared/raid_catalog/data/mappers/raid_catalog_mapper.dart
근거: [lib/shared/raid_catalog/data/mappers/raid_catalog_mapper.dart](../../lib/shared/raid_catalog/data/mappers/raid_catalog_mapper.dart).

| field literal | writer 첫 표현/행 | reader/parser 첫 표현/행 |
|---|---|---|
| `catalogVersion` | — (이 파일에서 미추출) | L9 `catalogVersion: _string(json, 'catalogVersion'),` |
| `difficultyId` | — (이 파일에서 미추출) | L33 `difficultyId: _string(json, 'difficultyId'),` |
| `displayAlias` | — (이 파일에서 미추출) | L35 `displayAlias: _string(json, 'displayAlias'),` |
| `displayName` | — (이 파일에서 미추출) | L19 `displayName: _string(json, 'displayName'),` |
| `name` | — (이 파일에서 미추출) | L34 `name: _string(json, 'name'),` |
| `officialName` | — (이 파일에서 미추출) | L18 `officialName: _string(json, 'officialName'),` |
| `raidId` | — (이 파일에서 미추출) | L17 `raidId: _string(json, 'raidId'),` |
| `updatedAt` | — (이 파일에서 미추출) | L10 `updatedAt: DateTime.parse(_string(json, 'updatedAt')),` |

## query 조건 전수 source 위치
`.where/orderBy/limit/startAfter/collectionGroup`의 SDK 관련 파일별 source 출현이다. Dart iterable.where도 일부 포함하므로 서버 query와 로컬 filter를 코드의 receiver로 구분한다.

| source | 표현 |
|---|---|
| [lib/features/account/data/gateways/local_game_account_verification_gateway.dart:111](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart) | `.where(current.containsKey)` |
| [lib/features/account/data/gateways/local_game_account_verification_gateway.dart:119](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart) | `for (final slot in _slots.keys.where(` |
| [lib/features/account/data/gateways/local_game_account_verification_gateway.dart:145](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart) | `final matching = _slots.entries.where((entry) => entry.value == type);` |
| [lib/features/account/data/gateways/local_game_account_verification_gateway.dart:193](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart) | `.where((snapshot) => snapshot.exists)` |
| [lib/features/account/data/gateways/local_game_account_verification_gateway.dart:272](../../lib/features/account/data/gateways/local_game_account_verification_gateway.dart) | `.where((item) => item.id == characterRef.id)` |
| [lib/features/account/data/repositories/firestore_activity_characters_repository.dart:93](../../lib/features/account/data/repositories/firestore_activity_characters_repository.dart) | `.where(` |
| [lib/features/account/data/repositories/firestore_activity_characters_repository.dart:125](../../lib/features/account/data/repositories/firestore_activity_characters_repository.dart) | `.where(existingByCharacterId.containsKey)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:84](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.where('cycleKey', isEqualTo: cycleKey);` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:439](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.collectionGroup('applications')` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:440](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.where('schemaVersion', isEqualTo: 1)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:441](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.where('applicantPlayerId', isEqualTo: command.playerId)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:442](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.where('cycleKey', isEqualTo: command.cycleKey)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart:443](../../lib/features/account/data/repositories/firestore_weekly_raid_claim_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:448](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.where((slot) => slot.playerId == command.playerId)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:462](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.where((slot) => slot.playerId != command.playerId)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:870](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.collectionGroup('applications')` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:871](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.where('schemaVersion', isEqualTo: 1)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:872](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.where('applicantPlayerId', isEqualTo: command.playerId)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:873](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.where('cycleKey', isEqualTo: command.cycleKey)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart:874](../../lib/features/account/data/repositories/firestore_weekly_raid_status_command_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:35](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart) | `.where('cycleKey', isEqualTo: cycleKey);` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:38](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart) | `.where('cycleKey', isEqualTo: cycleKey);` |
| [lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart:41](../../lib/features/account/data/repositories/firestore_weekly_raid_status_repository.dart) | `.where('cycleKey', isEqualTo: cycleKey);` |
| [lib/features/account/presentation/pages/game_account_verification_page.dart:152](../../lib/features/account/presentation/pages/game_account_verification_page.dart) | `.where((item) => item.id == boundAccountId)` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:28](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.where('status', isEqualTo: 'active')` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:29](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.where('characterName', isEqualTo: exactName)` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:30](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.limit(limit)` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:50](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.where('status', isEqualTo: 'active')` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:51](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.where('ownerPlayerId', isEqualTo: ownerPlayerId)` |
| [lib/features/group/data/repositories/firestore_group_character_search_repository.dart:52](../../lib/features/group/data/repositories/firestore_group_character_search_repository.dart) | `.limit(limit)` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:427](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.where('leaderPlayerId', isEqualTo: playerId)` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:428](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.where('groupId', isEqualTo: command.groupId)` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:429](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.where('status', whereIn: const ['active', 'completed'])` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:430](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.limit(20)` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:583](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.where('status', isEqualTo: GroupRequestStatus.pending.name)` |
| [lib/features/group/data/repositories/firestore_group_join_command_repository.dart:584](../../lib/features/group/data/repositories/firestore_group_join_command_repository.dart) | `.limit(1)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:44](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where('relation', isEqualTo: GroupRelationKind.member.name)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:45](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:65](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where(` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:72](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:116](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where('kind', isEqualTo: kind.name)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:117](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where('status', isEqualTo: GroupRequestStatus.pending.name)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:118](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy('createdAt')` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:119](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.limit(limit)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:198](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy('createdAt', descending: true)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:199](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.limit(limit)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:259](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where('status', isEqualTo: GroupStatus.active.name)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:260](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy('lastActivityAt', descending: true)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:261](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy(FieldPath.documentId, descending: true)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:262](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.limit(limit);` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:270](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where('status', isEqualTo: GroupStatus.active.name)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:271](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where(field, isGreaterThanOrEqualTo: normalizedQuery)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:272](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where(` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:276](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy(field)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:277](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.orderBy(FieldPath.documentId)` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:278](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.limit(limit);` |
| [lib/features/group/data/repositories/firestore_group_read_repository.dart:292](../../lib/features/group/data/repositories/firestore_group_read_repository.dart) | `.where((id) => id.isNotEmpty)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:201](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('requesterPlayerId', isEqualTo: playerId)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:216](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('previousOwnerPlayerId', isEqualTo: playerId)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:222](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where((request) => request.isAwaitingOwnerResponse)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:262](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('gameAccountId', isEqualTo: accountId)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:337](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('status', isEqualTo: 'pendingProof')` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:342](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where((request) => !request.isExpiredAt(now))` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:752](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('status', isEqualTo: 'awaitingOwnerResponse')` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:800](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where((snapshot) => snapshot.exists)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:913](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where((item) => item.id == characterRef.id)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:1336](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('requesterPlayerId', isEqualTo: playerId)` |
| [lib/features/manual_verification/data/firestore_manual_verification_repository.dart:1361](../../lib/features/manual_verification/data/firestore_manual_verification_repository.dart) | `.where('requesterPlayerId', isEqualTo: playerId)` |
| [lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart:47](../../lib/features/manual_verification/presentation/pages/operator_manual_verification_detail_page.dart) | `queue.where((item) => item.id == widget.requestId).firstOrNull;` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:90](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.orderBy('lastSeenAt')` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:91](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.limit(limit)` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:117](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where('playerId', isEqualTo: playerId)` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:121](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where('ownerPlayerId', isEqualTo: playerId)` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:179](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where(` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:219](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where((document) => !document.data().containsKey('lastSeenAt'))` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:242](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where('playerId', whereIn: ids)` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:243](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where('status', isEqualTo: 'active')` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:261](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where((id) => id.isNotEmpty)` |
| [lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart:271](../../lib/features/operator_access/data/repositories/firestore_operator_access_repository.dart) | `.where(FieldPath.documentId, whereIn: ids)` |
| [lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart:35](../../lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart) | `.where('audiencePlayerIds', arrayContains: playerId)` |
| [lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart:36](../../lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart) | `.orderBy('occurredAt', descending: true)` |
| [lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart:37](../../lib/features/raid_status/data/repositories/firestore_party_event_read_repository.dart) | `.limit(limit)` |
| [lib/features/raid_status/data/services/firestore_party_event_sync_service.dart:51](../../lib/features/raid_status/data/services/firestore_party_event_sync_service.dart) | `.where('audiencePlayerIds', arrayContains: playerId)` |
| [lib/features/raid_status/data/services/firestore_party_event_sync_service.dart:52](../../lib/features/raid_status/data/services/firestore_party_event_sync_service.dart) | `.orderBy('occurredAt')` |
| [lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart:38](../../lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart) | `for (final entry in values.entries.where((e) => e.key.startsWith(prefix))) {` |
| [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart:73](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart) | `.where((slot) => slot.playerId == command.targetPlayerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart:95](../../lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository.dart) | `.where((slot) => slot.playerId != command.targetPlayerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart:18](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart) | `.where('schemaVersion', isEqualTo: 2)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart:19](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart) | `.where('memberPlayerIds', arrayContains: playerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart:20](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart) | `.where('status', isEqualTo: 'active')` |
| [lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart:21](../../lib/features/recruitment_list/data/repositories/firestore_party_raid_listing_backfill.dart) | `.limit(50)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:93](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.limit(limit)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:258](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.startAfterDocument(cursor.snapshot)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:259](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.limit(limit)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:274](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('schemaVersion', isEqualTo: 2)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:275](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('visibility', isEqualTo: 'public')` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:276](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('status', isEqualTo: 'active')` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:277](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('manualRecruitmentEnabled', isEqualTo: true)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:278](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('hasAvailableSlot', isEqualTo: true)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:279](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('targetCycleKey', isEqualTo: cycleKey)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:280](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:281](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.orderBy(FieldPath.documentId, descending: true);` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:291](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where(` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:320](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('schemaVersion', isEqualTo: 2)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:321](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('leaderPlayerId', isEqualTo: playerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:322](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('status', whereIn: openStatuses)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:326](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('schemaVersion', isEqualTo: 2)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:327](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('memberPlayerIds', arrayContains: playerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:328](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('status', whereIn: openStatuses)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:344](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.collectionGroup('applications')` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:345](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('schemaVersion', isEqualTo: 1)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:346](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('applicantPlayerId', isEqualTo: playerId)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:347](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where('cycleKey', isEqualTo: cycleKey)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:348](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.orderBy('updatedAt', descending: true)` |
| [lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart:355](../../lib/features/recruitment_list/data/repositories/firestore_party_read_repository.dart) | `.where(` |
| [lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart:35](../../lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart) | `.where('status', isEqualTo: 'pending')` |
| [lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart:36](../../lib/features/recruitment_list/data/repositories/firestore_party_visibility_command_repository.dart) | `.limit(20)` |
