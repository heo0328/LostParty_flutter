# 그룹장 이전·탈퇴·해산 계약

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## 1. 상태와 목적

- 제품 기준: [`../product/GROUP_PRODUCT_FLOW.md`](../product/GROUP_PRODUCT_FLOW.md) §10·§13·§14·§17·§18.6
- 목적: 그룹장이 그룹원을 후임자로 즉시 지정한 뒤 기존 일반 멤버 탈퇴를 사용하거나, 안전 조건을 충족한 그룹을 해산하는 흐름을 정의한다.

## 2. 확정 사용자 흐름

정상 그룹장은 바로 탈퇴할 수 없다.

1. 그룹장이 탈퇴를 누르면 `그룹장 이전`과 `그룹 해산`을 안내한다.
2. 그룹장 이전은 현재 유효한 일반 그룹원 한 명을 선택한다.
3. 확인 즉시 그룹장 권한을 Transaction으로 교체한다. 대상의 수락을 기다리지 않는다.
4. 이전한 사용자는 일반 멤버로 남는다.
5. 이전한 사용자가 탈퇴를 원하면 기존 일반 멤버 탈퇴 명령을 별도로 실행한다.

이전과 탈퇴를 하나의 명령으로 묶지 않는다. 이전 성공 후 탈퇴가 실패해도 기존 그룹장이 일반 멤버로 남을 뿐 그룹장 없는 상태를 만들지 않는다.

## 3. 즉시 지정 이전 정책

- `강제 이전`은 운영자에 의한 권한 회수가 아니라 현재 그룹장이 같은 그룹의 유효한 일반 멤버를 후임자로 즉시 지정하는 기능이다.
- 별도의 이전 요청·수락·거절·취소·만료 상태를 만들지 않는다.
- `joinRelations`를 재사용하지 않고 `leaderTransfer` 요청 문서나 Player별 역방향 Projection도 만들지 않는다.
- 대상은 현재 `members/{targetPlayerId}.role == member`인 본인 이외의 Player만 가능하다.
- 멤버가 그룹장 한 명뿐이면 이전할 수 없고 해산만 안내한다.
- 새 그룹장은 이후 다른 유효 그룹원에게 다시 이전할 수 있다. 별도 쿨다운은 두지 않는다.

확인 문구는 최소한 다음 의미를 전달한다.

> 선택한 그룹원에게 그룹장을 즉시 이전합니다. 이전 즉시 그룹 관리 권한이 넘어가며 자동으로 되돌릴 수 없습니다.

## 4. 이전 Transaction

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md#source-0003)로 이동했다.

## 5. 그룹 대표 캐릭터

- `representativeCharacterId`와 관련 Snapshot은 그룹 정체성 값이므로 그룹장 이전 시 유지한다.
- `leaderDisplayCharacterNameSnapshot`만 새 그룹장의 membership 표시 캐릭터로 변경한다.
- 그룹 생성 시 대표 Character 소유권 검증은 생성 명령의 조건이며, 현재 그룹장이 영구적으로 해당 Character를 소유해야 한다는 불변식으로 사용하지 않는다.
- 대표 Character가 삭제·숨김·인증 해제되면 그룹은 유지하고 `변경 필요`로 표시한다. 새 그룹장은 별도 그룹 정보 변경 기능에서 본인이 소유한 active Character로 바꿀 수 있어야 한다.
- 대표 Character 문제만으로 그룹장 이전을 막지 않는다.

## 6. 이전 후 탈퇴

- 이전 완료 후 기존 그룹장은 일반 멤버 탈퇴 UI와 Repository 명령을 그대로 사용한다.
- 이전 완료 화면은 `그룹장이 이전되었습니다. 이제 그룹에서 탈퇴할 수 있습니다.`라는 의미를 안내한다.
- 탈퇴는 이전 Transaction과 별개이며 현재 membership·Player 요약·그룹 인원·revision을 다시 검증한다.
- 새 그룹장으로 지정된 사용자는 다시 이전하거나 그룹을 해산하기 전에는 탈퇴할 수 없다.

## 7. 1차 그룹 해산 허용 조건


- 호출자가 현재 그룹장
- 그룹 상태가 `active`
- `memberCount == 1`이고 호출자만 membership으로 존재
- pending 초대·가입 신청이 없음
- pending 그룹장 이전은 구조상 존재하지 않음
- 활성 그룹 전용 레이드가 없음. 판정은 `raidListings` 후보를 모집 원본(`recruitments`)의 `visibility==group`·같은 `groupId`·`status==active`로 확인한다. listing은 생성 스냅샷이라 레이드방 해산 후에도 `status==active`가 남을 수 있다.
- 활성 초대코드는 없거나 해산 Transaction에서 함께 폐기 가능

조건을 충족하지 않으면 정리할 항목을 안내한다. 다른 멤버는 먼저 탈퇴하거나 후속 추방 기능으로 정리하고, pending 초대·신청은 취소·거절하며, 그룹 전용 레이드는 전체 공개 전환 또는 종료 후 해산한다.

## 8. 연결된 레이드 처리

- 그룹 해산은 일반·반복 레이드방을 자동 해산하지 않는다.
- 활성 그룹 전용 레이드가 있으면 그룹 해산을 거절한다. 레이드 현황에 방이 없어도 listing 스냅샷만으로 거절하지 않는다.
- 전체 공개로 전환된 연결 레이드는 유지하며 `groupId`는 생성 당시 소속 이력으로 남길 수 있다.
- softDeleted 그룹은 현재 그룹 목록, 검색과 필터 선택 대상에서 제외한다.
- 그룹 전용 레이드의 공개 전환·listing 동기화·자격 박탈 계약은 `NEXT_WORK.md`의 후속 작업에서 별도로 확정한다.
- 후속 제품 결정: 현재 그룹장은 그룹 상세의 `그룹 레이드 관리`에서 남은 활성 그룹 전용방을 확인하고, 방 참가 여부와 무관하게 **전체 공개 전환 또는 모집 해산**을 실행할 수 있다. 두 명령은 각각 기존 모집의 원자 상태 변경을 사용하며 그룹 해산 명령이 연결 방을 일괄 변경하지 않는다. 관리 대상 필터와 원본·집계 불일치 처리 기준은 `GROUP_PRODUCT_FLOW.md` §9.3 및 `NEXT_WORK.md` F4를 따른다.

## 9. 해산 Transaction과 보관

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md#source-0005)로 이동했다.

## 10. Rules와 자동 검증 완료 조건

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md#source-0006)로 이동했다.

