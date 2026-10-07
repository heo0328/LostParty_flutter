# BUG-024 — 완료 반복방의 다음 주 참가 캐릭터 변경

2026-10-07. 기준 dev/origin dev `e4f8e0f`. 상태: 분석·설계, 구현 미착수.

## 사용자에게 발생한 문제

노르딘 모집/Ailker(`EsDaq4qFhXe9SDXQv5eV`)와 4막하드/니티안
(`8CNzjWUjIE43uCjkvOye`)은 BUG-023 수정 후 이번 주 완료에 성공했다.
이후 다음 주 대기 상태에서 모든 계정의 참가 캐릭터 변경이
`모집 또는 멤버 정보를 찾지 못했습니다.`로 실패했다고 사용자가 보고했다.
이번 주 완료 성공은 유효하지만 완료 이후 준비 변경을 검증한 것은 아니었다.

목표는 **완료한 캐릭터의 이번 주 기록은 유지하고, 다음 주 함께할 캐릭터만 변경**하는 것이다.
기존 완료를 취소하거나 새 캐릭터를 이번 주 완료자로 바꾸는 기능이 아니다.

## 확인한 사실과 미확인 사항

경로는 저장소 루트 기준이다.

| 위치 | 확인한 내용 |
|---|---|
| `lib/features/raid_status/presentation/pages/party_read_detail_page.dart` | `isNextWeekPrep` 안내와 확인창이 있지만 일반 변경과 같은 명령을 호출한다. 후보의 이번 주 완료 사유 예외가 있고 역할 선택은 별도 `canSelect`를 사용한다. |
| `lib/app/router/app_router.dart`, `party_atomic_membership_command_adapter.dart` | 실제 DI는 atomic member mutation Repository로 연결된다. |
| `lib/features/recruitment_list/data/repositories/firestore_party_atomic_member_mutation_repository.dart` | 기존 raidState가 없거나 해당 방이 아니거나 status가 active가 아니면 notFound를 반환한다. completed도 이 분기에 해당한다. |
| `lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart` | 모집과 회차가 active여야 한다. 이전 raidState 삭제·새 active raidState 생성, 구성·멤버·목록·이벤트 저장 방식이다. |
| `lib/features/recruitment_list/data/mappers/party_atomic_write_plan.dart` | advanceCycle은 현재 슬롯으로 새 주차의 역할·소유권·점유 정보를 upsert한다. 주차 전환 전체의 허용 여부는 별도 검증해야 한다. |

v1.1.0의 변경 mapper에도 active 회차 제한이 존재한다. BUG-023의 role 저장 보완이 새로 만든
제한은 아니다. 다만 이번 요청의 런타임 로그와 운영 데이터를 다시 수집하지 않았으므로 실제
두 요청의 정확한 반환 줄까지 재현 확인한 것으로 기록하지 않는다.

검토용 `coverage/rules-executable/review/readable.rules`의 `validAtomicMemberCharacterChange`도
active 회차와 이전 state 삭제/새 state 존재를 요구한다. legacy `validMemberCharacterChange`에는
nextWeekPrep 처리가 남아 있지만 assignment 기반이라 atomic 경로에 그대로 재사용할 수 없다.
검토용 산출물의 현재 생성 일치는 이번 문서 작업에서 재검증하지 않았다. 구현 전에 생성 도구와
실제 firestore.rules를 대조해야 하며 검토용 파일을 배포 원본으로 삼지 않는다.

제품 문서의 ‘완료 전 변경’과 명령 계약 §4.8의 ‘반복방 다음 회차 준비 변경’은 적용 상태를
분리해 해석한다. 기존 cycles/assignment 계약을 현재 통합 raidState 저장 구조에 그대로 적용하지 않는다.
화면의 ‘전체 완료 취소 불가’ 안내는 이미 폐기된 기능을 언급하므로 이번 안내 수정 대상이다.
동일 캐릭터 역할만 변경은 제품 문구와 mapper 제한이 다르며 별도 계약 불일치다. 이번에 몰래 확장하지 않는다.

## 수정 설계

### 요청과 검증

진행 중 변경은 기존 계약을 유지한다. 완료 준비 변경은 서버에서 다시 읽은 모집이 active,
continueTogether=true, currentCycleStatus=completed인 경우에만 별도 저장 계획을 선택한다.
UI 플래그나 이전 명령 표식만으로 분기하지 않는다. 본인 membership, 현재 캐릭터 소유권 차수,
새 캐릭터 소유·자격, expectedRevision, 역할·자리 구성은 기존 정책을 재사용한다.
공대장 고정석과 일반 멤버의 유효 빈자리 이동을 유지하며 다른 사람을 자동 교환하지 않는다.

후보와 최종 요청이 같은 준비 상태 정책을 사용해야 한다. 이번 주 완료만을 이유로 다음 주
준비를 막지 않되, 현재 다른 방 점유·소유권 상실까지 무조건 허용하지 않는다. 역할별 후보의
canSelect와 기존 점유 정책의 실제 결과를 구현 전에 대조한다. 다른 방 이동·신청 일괄 취소는 확장하지 않는다.

### 저장 경계

| 데이터 | 완료 준비 변경의 처리 |
|---|---|
| 모집 partySlots, raidStateTargets, 역할별 인원, 방장 표시 | 새 다음 주 구성으로 갱신. 방장 Player와 권한, 인원수는 유지 |
| 본인 membership | 새 캐릭터·역할·위치·표시·소유권 차수 반영 |
| 그룹 raidListings | 기존 목록 정책에 따라 원본과 같은 revision/표시를 원자 반영. 없는 목록을 임의 재노출하지 않음 |
| 변경 이벤트 | 기존 공용 이벤트 규약으로 한 번 기록, 과거 완료 이벤트는 유지 |
| 이전·새 캐릭터 raidStates 및 완료 이력 | 준비 변경으로 생성·수정·삭제하지 않음 |
| currentCycleKey/status, 완료 시각·완료자 | 완료 상태 그대로 유지 |

단순히 completed를 active 검사에 추가하는 수정은 금지한다. 그러면 기존 writer가 완료 기록을
삭제하고 현재 주차 점유를 새로 만들 수 있다. 준비 전용 Write Plan은 state 쓰기를 구조적으로
생성하지 않아야 한다. A→B→C 반복 변경에서 B의 이번 주 state가 없더라도 이것만으로 실패하지 않는다.
과거 완료 명단을 mutable partySlots로 다시 만드는 것도 금지한다.

### Rules와 원자성

모집·본인 멤버·그룹 목록·이벤트의 제한된 동시 변경을 검증하는 완료 준비 경로를 설계한다.
기존 진행 중 경로를 넓히거나 legacy allow에 우회시키지 않는다. 타인 변경, 역할/권한 필드 위조,
모집 단독 또는 멤버 단독 쓰기, 완료 상태 해제는 거절한다. state를 건드리지 않는 요청 계약과
별개로 기존 state allow가 같은 요청으로 완료 기록을 변경할 수 없는지도 부정 검증한다.
새 경로의 정확한 affected keys, lifecycle marker 소비, listing/event 계약은 생성 도구의 실제
호출 경로를 대조한 뒤 구현한다. 개인 기록 읽기 권한 확대와 전체 멤버 반복 조회는 하지 않는다.

### 주차 전환과 동시 요청

변경된 raidStateTargets가 다음 주 전환 대상이 된다. 기존 advanceCycle upsert만으로 충분하다고
가정하지 않고 대상 state 부재/이번 주 완료/다른 방 사용 상태와 소유권 검사를 추적한다.
준비 변경 자체는 다음 주 독점 예약을 생성하지 않는다. 전환 시 최신 소유권·점유를 다시 검증하고
충돌은 기존 정책으로 처리한다. 주차 경계와 변경이 경합하면 revision으로 한 상태만 확정하고
오래된 요청은 재조회한다. 완료 상태인 이전 주차를 현재 진행 상태로 오인해 쓰지 않는다.
기존 완료 기록 보존은 준비 변경 시 보존을 뜻하며 통합 raidState의 정상 주차 갱신 수명은 바꾸지 않는다.

## 진단과 회귀 보호

요청 ID에 준비/진행 모드, 조회한 회차 상태·주차·revision, 이전/새 캐릭터·역할, 단계와
쓰는 경로 종류를 연결한다. 읽지 않은 타인 state를 확인했다고 기록하지 않는다.
실제 문서 부재, 상태 변경 충돌, 자격 실패를 notFound 한 가지로 합치지 않는다.
트랜잭션 재시도와 최종 성공을 구분하며 토큰·전체 개인 문서는 출력하지 않는다.

자동 검증은 최대 8인 대표 준비 변경의 원자성, 권한 없는 변경/부분 쓰기 거절,
완료 기록 보존, 연속 변경, 주차 경합, 소유권 이전, 준비 후 전환·완료 경계에 제한한다.
BUG-023의 role 보완 완료, 진행 중 캐릭터 변경·자동 이동, 그룹 목록 동기화는 회귀 보호 대상이다.
동일 코드의 전체 테스트를 반복하지 않는다. 정상 UI는 사용자 실기기로 확인하며 목록은 채팅 제공한다.

종료 조건은 두 실제 방의 다음 주 캐릭터 변경, 다른 기기 구성 반영, 기존 완료 기록 보존과
다음 주 전환 후 정상 완료 확인이다. 코드·에뮬레이터 통과만으로 종료하지 않는다.

## 이번 작업 범위

`fix/recurring-next-week-character-change`에서 분석·설계 문서만 커밋한다.
앱·Rules·운영 데이터·초기화 설정·릴리즈는 변경하지 않는다. dev/main 병합과 push는 이번 범위 밖이다.
복구키·이전 소유자의 고아 관계 처리 및 별도 구조 개선은 후속 작업으로 유지한다.
