# AI CONTEXT (2026)

> 프로젝트 전체 지도와 현재 상태의 요약이다. 행동 규칙은 `ai_rules.md`, 바로 실행할 상세 작업은 `NEXT_WORK.md`, 완료 경과는 `DEV_LOG.md`가 기준이다.

## 현재 통합 상태

- 통합 기준은 `dev`이며 `dev`와 `main`에서 직접 수정하지 않는다. 최신 `dev`에서 기존 동일 목적 브랜치를 우선 확인하고, 없으면 `feature/*`, `fix/*`, `docs/*`, `refactor/*`, `release/*` 중 작업 목적에 맞는 브랜치로 분기한다. 도구명 접두사는 새로 만들지 않는다.
- 앱은 Firebase 익명 Auth와 Player binding, 게임 계정·Character 인증, 그룹, 레이드 모집·신청·참가·회차·완료 Claim, 로컬 알림과 계정 관리 흐름을 제공한다.
- 앱 시작 시 브랜드 이미지를 사용하는 약 2.2초의 1회성 Flutter 진입 연출을 서비스 초기화와 병렬 실행한다. Android 일반·적응형·단색 아이콘과 iOS AppIcon 세트도 같은 브랜드 자산으로 구성했으며 실기기 적용을 확인했다.
- 주차 운영 계약은 한국 수요일 오전 6시다. F6-F의 1회성 `incompleteEnded`와 반복방 `advanceCycle`은 임시 경계 실기기에서 확인했다. F6-H는 승계 후 lifecycle 마커를 다음 유효 Aggregate 명령이 원자적으로 소진하게 하고 앱 수명의 단일 runtime 회차 공급원을 Router에 연결했으며, 표적 Dart 검증과 원격 Rules의 F6-H 시나리오는 통과했다. 전체 Rules 실행은 별도 기존 그룹방 재가입의 1,000식 한도에서 실패해 운영 게시를 보류했으며, 실기기 확인 전이므로 완료로 판정하지 않는다.
- 그룹 생성·가입 신청·탈퇴·그룹장 양도·초대코드 확인/가입·마지막 1인 해산과 레이드 주요 명령은 운영 Rules 및 실기기에서 확인했다. `BUG-021`은 그룹 신청 승인 Transaction의 Rules 표현식 1,000개 한도 초과가 원인이었으며, 승인 분기 평가 순서만 최소 수정해 전체 demo 회귀와 운영 게시 후 기존 실패 Player 2명의 승인을 확인하고 `dev`에 통합했다.
- 수동 인증 실기기 검증은 기능 결함으로 열린 것이 아니라 다음 통합 디바이스 테스트에서 필요할 때 함께 수행한다.

## 현재 제품 축

### Character와 인증

- 앱 실행 후 내 레이드 현황 초기 로딩과 충돌하지 않게 적격 Character를 앱 수명당 한 번 갱신한다. 공통 사용 레벨 정책은 현재 1700이며 나이스단 판정과 공유한다.
- 서버 관계가 없고 로컬 인증 표시만 남은 경우 서버 불일치로 안내한다. 자동 재귀속이나 자동 로컬 삭제는 하지 않으며 앱 데이터 초기화·재인증을 기본 복구 절차로 유지한다.
- 활동 Character 8→15 저장에서 Rules 문서 접근 한도로 `permission-denied`가 발생한 문제를 작은 묶음의 차이 저장으로 보완했고, 저장·재실행·후보 반영·기존 관계 보존을 실기기에서 확인했다.
- 장비 인증 Challenge는 의도적으로 Gateway 메모리에만 두고 앱 프로세스 종료 시 함께 종료한다. 인증 진행 카드에 앱 종료 시도 종료와 인게임 즉시 조작 권장을 안내하며, 시작 시 무기·방어구 5부위 중 하나라도 미장착이면 일반 정보 실패와 구분한 전용 착용 안내를 표시한다. 자동·실기기 검증을 완료했다.
- 계약: [`../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md`](../architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md), [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md), [`../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md`](../architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md)

### Character Build 무결성

- 깨달음·아크그리드 질서 해/달 14P·보석 Tooltip 직업을 기본 검사한다. 별과 혼돈은 필수 판정에서 제외한다.
- 2026-09-12 제품 합의에서 빨간 확정 오류를 `보석 11개 미만`, `타 직업 보석`, `API 스킬·등록 특수 스킬 양쪽에 없는 보석`, `질서 해·달 누락/각 14P 미만`, `아크그리드 요구 아크패시브 불충족`으로 고정했다. 카탈로그 미등록은 중립 사유가 아니며 사용자가 정상 특수 스킬을 점진적으로 추가한다. API·Tooltip 자체의 정보 부족만 중립이다.
- 확정 오류 v2의 아이콘 fallback 제거와 오류 전용 표시 보정을 구현·자동 검증했다. 정상 근거는 `ArmorySkills OR 승인 카탈로그`로 제한하고 정상·판정 불능은 비표기, 확정 오류만 빨간색으로 표시한다. 복수 캐릭터 진단 도구도 OS 임시 원본 저장과 미등록 후보 추출을 지원한다.
- 카탈로그 `2026.09.12`에는 사용자 확인을 거쳐 환수사 `야성`의 `둔갑 금술 스킬`, 가디언나이트 `드레드 로어`의 `가디언 피어`, 데모닉 `멈출 수 없는 충동`의 `블러드 제노사이드`를 정상 특수 보석 대상으로 추가했다.
- 같은 카탈로그에 차원술사 `시간 관리자`의 `시간선 스킬`도 사용자 확인 정상 대상으로 추가했다.
- 27직업 108캐릭터의 실제 API 표본을 추가 교차검증해 카탈로그 `2026.09.12.2`를 30직업의 현재 깨달음 1티어 분기로 확장했다. `ArmorySkills`에 없고 Tooltip 직업이 일치한 특수 보석만 등록했으며, 인파이터의 브레이커 보석과 데빌헌터의 바드 보석 표본은 타 직업 오류로 유지한다.
- 실기기에서 확인한 새 파티장 membership의 보석 Snapshot 누락과 참가 Character 변경 목록의 통합 표시 누락을 보완했다. 새 파티장에는 기존 보석 최소 요약을 저장하고 변경 목록은 로컬 통합 상태로 보석·아크그리드 오류를 함께 표시한다. 표적 테스트 63건과 변경 파일 분석이 통과했고 Rules·권한·점유 순서는 변경하지 않았다. 사용자가 그룹 레이드 생성 파티장의 오류 표시를 실기기에서 확인해 기능 구현을 완료 판정했다.
- 신청·즉시 참가 Character 선택 목록에도 같은 로컬 통합 오류 표시를 적용했다. 과거 파티 마이그레이션은 현재 단독 테스트 단계에서 불필요하다는 사용자 결정으로 제외했다.
- 릴리즈 실기기에서 확인한 후보의 아크그리드·아크패시브 오류 전달 누락을 보완했다. 기존 보석 전용 Snapshot을 유지하면서 통합 `buildIntegritySnapshot`을 신청·membership에 dual-write하고, 승인 시 신청 당시 값을 복사하며 과거 문서는 기존 보석 경고로 호환한다. 운영 활성 Rules와 로컬 소스 일치 및 실기기 지속 표시를 확인했다.
- 계약: [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md)

### 그룹과 레이드

- 그룹 membership·초대코드·그룹장 이전/해산 계약과 레이드 명령·읽기·주간 Claim 계약이 구현돼 있다.
- 진행 중 레이드 카드의 방별 unread 배지는 레이드 현황 탭 재선택 갱신으로 보완했다. 모든 방의 실시간 Listener는 추가하지 않았다.
- 8인 공격대 자리 이동과 점유 자리 교환, 동일 파티 중복 직업 교환 차단은 구현됐고 실기기에서 확인했다. Character 변경 자동 이동·파란 안내 제거와 알림의 일부 실기기 확인은 남아 있다.
- BUG-022의 A1 현재 그룹 count 검증과 A2 참가자 제거 listing 수정은 운영 게시됐고, 기존 문제 방 추방도 실기기에서 성공했다. F6-F는 지난 주차 1회성 방을 `raidState` 삭제 없이 `incompleteEnded`로 전환해 운영 문제 방에서 실제 동작을 확인했다. F6-G는 참가 Character 후보와 최종 Transaction의 점유 판정을 공용 정책으로 정렬하고 기존 단일 고아 정리 UX를 연결했다. 자동 삭제·자동 변경이나 Rules 수정 없이, 실기기에서 정리 안내 후 수동 재선택·Character 변경 성공까지 확인해 완료했다. 그룹방 재가입 C는 별도 과제이며, DE의 최신 목표는 원정대 재인증 후 새 사용자 정상 이용과 이전 무효 관계의 제한 정리다. 로그인 연결·기존 Player 복구는 이번 범위에서 제외한다. 최신 실행 기준은 아래 다음 작업을 따른다. 설계: [`../architecture/BUG_022_REMAINING_FIX_DESIGN.md`](../architecture/BUG_022_REMAINING_FIX_DESIGN.md), 실행 계획: [`NEXT_WORK.md`](NEXT_WORK.md)
- 기존 `release/1.0.0` 후보는 다인 명령 확장성 결함으로 폐기하고 이력용으로만 보존한다. 현재 우선 작업은 `BUG-018` 단일 보정이 아니라 파티·그룹 Firestore 명령, Player별 이벤트 fan-out과 Rules 접근 구조의 재설계다. 서버 후처리 단계는 사용하지 않고 현재 최대 8인의 핵심 상태를 제한된 원자 명령으로 확정하며, assignment·주간 Claim은 통합 `raidState`로 교체하는 방향이다. 종료 하위 문서 정리는 정확성과 분리한다. 기준: [`../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md`](../architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md)
- 계약: [`../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md`](../architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md), [`../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md`](../architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md), [`../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md`](../architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md), [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)

## 차후 제품 후보

- Character Build 오류·상태 정의, 기본 판정, 파티 생성 리더 Snapshot 및 참가 Character 변경 목록 표시 보완은 완료됐다.
- 기존 membership 보석 Snapshot을 통합 Build 상태로 이행할지 여부는 별도 후보다.
- 약 60개 직업·분기의 특수 보석 카탈로그 조사는 캐릭터명 기반 진단 도구와 사용자 승인을 반복하는 상시 관리 작업이다. 절차는 [`../integrations/LOST_ARK_API.md`](../integrations/LOST_ARK_API.md)를 따른다.
- 직업·깨달음·질서 해/달/별 계층 메모, `망소빙` 같은 Build 별칭과 버전형 JSON 공유: [`../product/BUILD_MEMO_SHARING.md`](../product/BUILD_MEMO_SHARING.md)
- 직업 시너지 선택·필터: [`../product/CLASS_SYNERGY_CATALOG.md`](../product/CLASS_SYNERGY_CATALOG.md)
- 진행 중 내 Character 필터와 진행 중/레이드 모집의 참가 인원 로컬 정렬·남은 자리 2차 필터는 구현·실기기 확인했다. 계약: [`../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md`](../architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md) §14
- 테스트 데이터의 고아 `raidState`/신청 참조를 안전하게 진단·정리하는 도구는 별도 후속 작업이다. 모집 원본만 콘솔에서 단독 삭제하거나 Firebase 전체를 초기화하지 않는다. 실행 순서는 [`NEXT_WORK.md`](NEXT_WORK.md)의 F6 범위 밖 백로그를 따른다.
- FCM, 유료 서비스, 서버 상시 스케줄러는 별도 승인 전까지 제외한다.

## 문서와 운영 주의

- Firestore Rules 변경 섹션은 로컬 검증 후 AI가 실제 배포를 한 번만 시도한다. 실패하면 반복 배포·기능 삭제를 멈추고 실패 단계와 콘솔 활성 소스를 먼저 조사하며, 재시도는 사용자의 새 지시가 있을 때만 한 번 수행한다.
- CLI 503은 실패 단계(`/test`, `/rulesets`, `/releases`)와 콘솔 활성 게시본을 함께 확인한다. 503만으로 Rules 복잡도나 특정 기능을 원인으로 확정하거나 기능을 제거하지 않는다.
- Firebase 콘솔 복사본은 로컬 대조 자료일 뿐 배포 원본은 `firebase.json`이 지정한 `firestore.rules`다.
- 상세 완료 이력은 [`DEV_LOG.md`](DEV_LOG.md), Rules 장애·경고 이력은 [`TASK-11-FIRESTORE-RULES-COMPLEXITY.md`](TASK-11-FIRESTORE-RULES-COMPLEXITY.md)를 따른다.

## 다음 작업

2026-09-29 사용자가 Rules 게시 후 그룹방 탈퇴·추방·재가입 성공을 확인했다.
A2-B 앱과 운영 Rules 불일치로 발생한 권한 오류는 정상화됐으며 활성 소스·해시는
AI가 독립 대조하지 않았다. A3는 재현 전제 정정 후 전체 CI 통과 상태다.
이후 사용자는 반복방과 고아 데이터 처리도 정상 동작했다고 확인했다. 전체 조합 검증으로
확대하지 않으며 재발 시 해당 사례를 재조사한다. 상세는
[`DEV_LOG.md`](DEV_LOG.md)의 최신 실기기 기록을 따른다.

**BUG-017: 8인 참가 Character 변경의 다른 파티 배치 누락**은 공용 배치 정책 연결과
Rules 평가 비용 보완을 마쳐 전체 CI `36545232145`가 통과했다. 이후 사용자가 Rules를
직접 게시하고 디바이스 3대로 시험한 캐릭터 변경 성공을 확인했다. 만석에서 자동 교환 없이
제자리 변경되는 경우는 실기기 미확인이며 운영 활성 소스·해시는 독립 미대조다.
실행 범위·체크리스트는 [`NEXT_WORK.md`](NEXT_WORK.md), 원인과 상태는
[`BUG_REPORTS.md`](BUG_REPORTS.md), 검증·게시 이력은 [`DEV_LOG.md`](DEV_LOG.md)를 따른다.

F6-I와 기존 실기기 통과는 유지한다. dev/main은 ed787c7로 통합됐다. 전체 테스트 22건 실패·
analyze 51건은 미해결 기준이며 직접 영향 실패를 새 기능 검증 전에 분류한다.

최우선 작업은 **DE 원정대 재인증 후 정상 사용 보장**이다. 새 사용자에게 과거 그룹·권한·
이력을 승계하지 않고 정상 이용을 보장하며, 이전 무효 관계는 별도로 정리한다. 로그인 복구는 제외한다.
설계만 dev에 먼저 반영하고 fix/roster-reauth-isolation에서 개발·테스트·회귀·문서를 완료할 때까지
브랜치 전환·중간 dev 병합·별도 구현 분기를 금지한다. 상세 계약은
[DE 설계 §3–4](../architecture/BUG_022_REMAINING_FIX_DESIGN.md), 실행 단계는 [NEXT_WORK.md](NEXT_WORK.md)를 따른다.
현재는 설계 문서 단계이며 구현·새 Rules 배포·운영 데이터 정리는 수행하지 않았다.

DE1 코드 조사·계약 구체화는 설계 §5에 기록했다. 신규 B의 모든 이용이 과거 state로 막힌다는 가설은 미입증이며 lifecycle·재이전·완료 반복방 위험을 확인했다. 다음은 DE2 최소 서버 proof이며 구현/실기기 완료가 아니다.

DE2 최소 서버 proof는 CI 36581670667에서 부분 통과·전체 실패다. 단건 소유권 검사는 정상 8인 완료/구세대 거절을 통과했으나 baseline과 후보 모두 8인 주차 전환이 실패했다. 다음은 DE2-B 해당 Rules 비용 proof이며 운영 Rules/앱은 무변경이다. 상세는 설계 §6을 따른다.

2026-09-30 DE2-B 비용 비교 후보 세 가지는 정상 8인 주차 전환을 통과하지 못했다(CI 36607243281). 그룹 완료/listing·해산 보존은 확인했으며 운영 소스 이식은 하지 않았다. 다음은 DE2-B2의 개별 실패 조건 진단이다. 상세는 설계 §7과 NEXT_WORK를 따른다.

DE2-B4 검증 완료·후보 채택 불가: CI 36698759925에서 직접 분기는 주차 전환과 위조 거절을
통과했지만 기존 전체 완료·추방이 실패했다. 원본 대조 CI 36699127414는 통과하여 회귀를 확인했다.
DE2-B5의 명령 선택 설계와 recurrence 순서 변경 실험도 완료했다. CI 36700305266은
기존 회귀 통과·8인 전환 실패로 후보 채택 불가다. DE2-B6는 CI 36704079227에서 coverage 확보 완료다.
원본 target 0–6 true·7의 완료 반환 누락, 직접 분기 8건 true를 관찰했으며 정확한 식 수는 미확정이다.
DE2-B7은 CI 36705703747에서 정상 8인 전환/완료·기존 회귀·위조 거절·소유권 결합을 통과했고,
CI 36706232887에서 미완료 종료 보존도 확인했다. 해결 후보를 demo에 확보했으며 운영 수정은 없다.
DE2-C도 CI 36721590205에서 8인 혼합 재생성/완료/legacy 및 원자 거절 16건을 통과했다.
DE2-D는 CI 36725053530에서 완료 반복방 일반 참가자 정리·완료 이력 보존·재시도·정리 후 주차 전환과
기존 활성방 탈퇴/추방·위조 원자 거절을 포함한 26건을 통과했다.
DE2-E 최초 proof(CI 36748905075)는 기존 26건 통과·정상 공대장 승계 평가 한도 실패다.
DE2-E2는 중복 검사 보정 후 CI 36827919490에서 정상 첫 후임 승계·재시도·주차 전환과
신규 거절 포함 39건 통과, 마지막 후임까지 탐색하는 정상 8인 사례 1건은 평가 한도로 실패했다.
DE2-E3는 최대 단일 계측과 필수 쓰기 간 검사 분담 후보를 검증했으나 둘 다 실패해 후보를
채택하지 않았다. DE2-E4는 단건 stale 정리 후 첫 후임 승계를 권고한다. stale 공대장일 때
유효 일반 참가자의 제한 정리로 DE2-E5 CI 36838000885의 48건이 통과했다.
최대 8인 연쇄·승계·재시도·기존 회귀를 확인했다. F는 CI 36840397200의 마지막 1인 해산 10건 통과.
G에서 실제 자동·수동 인증에 공통 차수 정책을 연결하고 표적 7건/분석을 통과했다.
G2 차수 서버 후보는 CI 36874438459에서 15건 통과. H1은 참가 Snapshot의 저장/이동/전환 보존을 연결했다.
H2는 실제 생성·신청·가입/승인·Character 변경의 소유권 조회와 Snapshot 전달을 연결했다.
다음은 참가 서버 경계와 구세대 점유 대체다. 운영 Rules·정리 UI·전체 앱/실기기는 미완료다.
[설계 §14–22](../architecture/BUG_022_REMAINING_FIX_DESIGN.md),
[실행 계획](NEXT_WORK.md)을 따른다. 전용 브랜치 고정·dev/main 미반영.

2026-10-02 H3 참가 서버 후보 CI 36884163312 11/11 통과. 최대 8인 자리 교환 평가 한도도
기존 validator 평가 순서 보정으로 통과했다. 다음은 구세대 점유 대체와 앱 연결(설계 §22.2).
운영 Rules/정리 UI/전체 회귀/실기기는 미완료이며 전용 브랜치를 유지한다.
