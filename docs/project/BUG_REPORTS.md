# 버그 리포트

## BUG-028. 2차 기기 피드백: 시간 필터 예외·계정 참가 중 완료·편성 거절 잠금 (2026-10-27)

상태: 일반 앱 수정·직접 영향243개 검증 완료, 사용자 기기 재확인 대기. 시간 입력의 작은 글자 배율0.8에서216≤h≤189.6 예외를 재현해 해당 picker 배율만 보완했다. 계정의 참가 중 체크는 수동 PUT 대신 기존 개인 완료 후 탈퇴로 연결했다. 편성 적용 전409 ROOM_COMPOSITION_CONFLICT가 확정 거절 집합에서 누락돼 원요청 잠금을 유지하던 원인을 수정했다. 기존 잠긴 요청은 같은 키 재확인으로 거절을 저장/정리하며 새 요청이나 강제 삭제로 처리하지 않는다. 오류 카드·빨간 글씨24를 적용했다. 상세/회귀/기기 항목은 설계37 §37.84·NEXT_WORK 참조. 서버/웹소켓 문제로 분류하지 않는다.

## BUG-027. 개인 완료 후 탈퇴 성공에도 확인창 잔류 (2026-10-26)

상태: ef4f424c 후 기기 재발. 이전 직접 URL 진입 시험이 실제 목록→상세 push를 누락했다. root 확인창 소유권 수정만으로는 부족했고 종료 가드의 routeInformationProvider URI가 push 전 /raid-status인 탓에 이동이 막혔다. 유효 ACK가 도착해도 이후 재조회가 기록 상세를 보여줬다. §37.83에서 전역 활성 router.state.uri/pageKey와 현재 route로 판정하도록 최소 수정했다. 실제 StatefulShellRoute push+Controller 유효 ACK에서 수정 전 실패→후 통과, 계정 갱신 보류/실패와 화면/회원 변경을 포함한 직접156개 통과. 명시 기록·반대 주차·복원/다른 화면 무이동과 기존 root 모달/원요청/갱신은 유지한다. 8a31853e 이후 사용자가 '레이드 현황으로 페이지 이동이후 갱신까지 정상작동'을 보고해 목록 복귀/갱신 기기 통과·해결로 반영했다. 별도 후속의 인수까지 확대하지 않는다. NEXT_WORK/설계37 §37.83.

## BUG-026. 1차 모집 기기 점검의 후보·한도·일정 갱신 차이 (2026-10-26)

상태: native 일정 ACK/UI/오류·join 후보·조율 안내·사용량 배지 연결과 자동검증 완료. Backend172의 집계/선택조회 개발반영도 인계 수신. 후보·가입/조율·개인표/그래프는 사용자 기기 통과. 과거 제보 원ACK동일키 자체는 입증되지 않았지만 사용자 뜻대로 재현 없는 배너를 강제 기기 과제로 남기지 않는다. 상세 근거/영향은 설계37 §37.77, 현재 순서/담당은 NEXT_WORK, 협업은 [Issue13 요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6409130575).

- 후보: 모집번호5/4막하드 기대1720에1704 소울이터가 노출, 실제 신청은 차단. 당시 apply/change_character는 서버 후보 원본, join은 기존 목록 경로였다. Backend164/170에서 direct_join 일반목록 경로 차이로 확인하고 join 후보 source690f36f를 개발반영했다. §37.81에서 native 시트도 연결했으며 사용자 기기에서 레벨 미달 후보 제외를 확인했다. 직업중복/완료 후보 제외는 사용자 통과.
- 한도: Backend164는 활성3방(C/N표시4건)+과거10/14 미종료7관계로10을 집계했다. 사용자는 현재 참가중 목록에서 확인·이용 가능한 활성방만10개의 대상이라고 명확히 했다. 과거 관계만 남은 방을 포함한 집계는 제품 의도와 다르며 [정정요청](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6410274718)에 따라 Backend169의 현재목록 공통판정은6412692643에서 소비수용했으며 실제 현재 참가가 유지되는 확인 필요 상태는 포함한다. Backend172/1800160d 구현·개발반영을 수신했고 native 서버 사용량 배지도 연결했다. 사용자가6/10은 같은방 C/N1개 정책임을 확인하고 현행 유지를 선택했다. 과거 자료 삭제/강제탈퇴로 해결하지 않는다.
- 일정 갱신: 공대원 '내 일정 갱신' 뒤 공통 오류와 현황의 미확인 배너(첨부11.jpg). 서버 beta 복사 revision+1과 앱의 같은 개인표 no-op 기대 차이를 코드/합성 응답으로 재현·수정했다. 기존 원요청 보존 복구 시험은 통과, 제보 원ACK/기기는 미확인.
- 자동조율: 인원 충족 뒤 빠른 시간 확정이 안 되는 것 같다는 제보. 인원 충족+전원 표/예약·진행시간에 맞는 공통후보 필요, 없으면 기본 약속 유지가 정책이다. Backend164 현재 snapshot에서 번호3/5는 공통후보0, 번호4는 인원미달/worker성공을 확인했다. 승인된 한 줄 안내는6412692643에서 선택조회 계약을 수용했으며 Backend172 구현/개발반영과 native 연결은 완료, 대기 문구와 조기 자동확정은 사용자 기기에서 확인했다.

내 참가 캐릭터명은 사용자가 계정 혼동으로 정정했으므로 결함으로 등록하지 않는다. 웹소켓 자동갱신과 BUG-025는 이 제보의 원인으로 묶지 않는다. 사용자가 보고한 일정·승계/1인탈퇴·주차 독립은 통과로 유지하며 개인/주차 완료 후 목록 복귀만 BUG027에서 재확인한다.

## BUG-025. 최초 자동 빌드 갱신 완료 후 캐릭터 카드 전투력 미표시 (2026-10-24, 후속 조사·UX 검증 대기)

**상태:** 사용자 관찰 접수·코드 경로 정적 확인. 실제 원인은 미확정이며 수정/재현 테스트는 미실행이다. 사용자는 당장 코드 변경이 아니라 후속 작업 등록을 요청했다. 담당은 Flutter의 재현·표시/저장 흐름 대조이며, 서버 계약·응답의 실제 차이가 확인될 때만 Backend와 협업한다.

**사용자 관찰:** 여러 디바이스의 모집 참가·인원별 출발 시간 조율 테스트를 위해 로그인된 미인증 원정대를 Backend에서 인증 상태로 변경했다. 앱을 재실행한 후 자동 빌드 갱신 결과는 정상 완료로 표시됐지만, 이전에 캐릭터 카드에서 수동 전투력 갱신을 하지 않은 캐릭터는 데이터 없음으로 표시됐다. 서버에 값이 있거나 다른 기능에 사용 가능하더라도 사용자에게는 갱신 실패처럼 보였다는 보고다. 인증 상태 변경 자체를 원인으로 단정하지 않는다.

**확인한 코드와 가설 구분:**

- 자동 대상 분류에는 기존 전투력의 수동 저장 이력 조건이 없다. `domain/scoped_startup_refresh.dart::projectScopedRefreshTargets`는 활동 선택·사용 가능 상태·나이스단 정책을 사용한다. `StoredRoleSummary`는 초기 version=1/summary=null을 허용하며 빈 역할 레코드도 생성한다.
- `data/scoped_startup_refresh_source.dart::refresh`는 prepareRoleBuild → Armory 조회/분석 → 로컬 saveRoleBuild → onLocalSaved/서버 sync 순서다. 로컬 저장 완료와 서버 저장 대기는 별도 상태다. 성공 건수만으로 카드가 최신 상태인지 판정할 수 없다.
- `presentation/viewmodels/member_account_view_model.dart::_runnerChanged`는 자동 작업 종료 후 전체 refresh를 비동기로 요청한다. 그 완료는 자동 작업의 completed 표시와 별도이며, 카드의 새 역할 요약을 직접 반영하는 수동 `refreshCharacter`의 readCachedRoleBuild → _setCharacter 경로와 다르다. 자동 후속 재조회 지연/실패·이전 표시 잔존은 **가능한 가설**이며 이 사용자 사례의 확정 원인은 아니다.
- 카드 표시는 `member_account_page.dart::memberDisplayRole/_character`와 `ScopedRoleState.displaySummary`를 사용한다. 자동 판정한 역할과 선호/표시 역할, 로컬 pending/서버 확정 요약, 초기 빈 캐시·bootstrap 재조회 결과가 무엇을 표시했는지 대조해야 한다. 원인 확인 없이 서버 저장 실패나 특정 역할 문제로 단정하지 않는다.

위 파일 경로는 `lib/features/account/` 기준이다.

**후속 작업 순서:**

1. 수동 저장 이력이 없는 최초 빈 캐릭터와 기존 저장 캐릭터를 같은 조건에서 비교한다. 보고된 인증 상태 전환→재실행을 재현하되 정상 인증 등록 후 최초 갱신도 함께 구분한다. 새 UI나 재시도 정책을 먼저 정하지 않는다.
2. 대상 포함/제외 → 조회·분석 → 역할별 로컬 저장 → 서버 동기화/원ACK → 캐시·화면 모델 반영 → 카드 수치와 완료 안내까지 한 흐름으로 추적한다. 어느 화면 단계에서 값/역할/표시가 달라지는지 확인한다.
3. ‘갱신 완료’가 의미하는 범위, 화면 반영 대기/실패와 서버 저장 대기의 표현·재시도 동작을 실제 UX와 함께 정의한다. 저장 성공을 실패로 뒤집거나, 화면 미반영을 아무 안내 없이 성공으로 끝내지 않는 기준을 정한다. 즉시 카드 반영·일부 재조회·전체 재조회 중 무엇을 쓸지는 데이터 소유/수명·기존 비동기 보호를 확인한 뒤 선택한다.
4. 재현 원인과 합의된 완료 기준을 근거로 필요한 최소 수정/추가를 설계한다. 기존 자동 1회·활동/나이스단 제외·역할별 저장·회원/환경 격리·원pending/ACK를 회귀 보호하며 별도 전면 리팩토링으로 확대하지 않는다.

**테스트/완료 조건:** 최초 빈 데이터·기존 데이터, 딜러/서포터 자동 판정과 표시 역할, 로컬 성공/서버 대기, 저장 후 재조회 지연·실패, 부분 성공, 화면 재진입·앱 재실행·다중 디바이스, 도중 로그아웃/회원 변경을 영향 범위로 확인한다. 정상 UI는 사용자 실기기로, 비동기 경합·지연/실패·다른 회원 응답 덮어쓰기 등 경계는 필요한 표적 자동 테스트로 보완한다. 사용자가 추가 수동 갱신을 하지 않아도 완료 안내에 맞는 카드 상태를 확인할 수 있어야 하며, 미확인/일부 실패는 그 의미와 다음 행동이 구분돼야 한다. 서버 값 존재/API 성공만으로 완료 판정하지 않는다.

**일정/범위:** 후속 조사·기능 정의/테스트 대상으로 등록하며 이번에는 기능 코드를 수정하지 않는다. [개발 품질·UX 기준 §6](../architecture/DEVELOPMENT_QUALITY_AND_UX_STANDARD.md#6-서비스-복구-릴리즈-이후-최적화-검토)의 흐름별 점검에서도 참조한다. 다만 알려진 UX 결함의 필수 수정 여부는 서비스 복구 릴리즈 인수 전에 판단하며, 무조건 릴리즈 후 최적화로 미룬다는 결정은 아니다. Issue25 B 작업과 별도 구간으로 관리한다.

> 기존 서비스 전용 항목은 [원문·출처 기록](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md)으로 분리했다. 남은 제품/협업 문맥의 신규 서버 적용 여부는 별도 설계에서 판단한다.

## BUG-024. 완료 반복방 다음 주 참가 캐릭터 변경 실패 (2026-10-07, 실제 앱 도입·활성화400으로 운영 반영 보류)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0001)로 이동했다.

## BUG-023. 캐릭터 변경 후 반복 모집 전체 완료 실패 (2026-10-06 완료)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0002)로 이동했다.

## 이전 완료 판정 (2026-10-05, 1.1.0 공개 이후 — BUG-023 발생 전)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0003)로 이동했다.

## 아래는 과거 조사 이력

## 2026-10-04 후속 확인 — 일반 추방 후보와 거절 경계 분리

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0004)로 이동했다.

## 2026-10-04 Rules 감사에서 분리한 미해결 항목

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0005)로 이동했다.

## 최신 판정 요약 (2026-09-29)

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0006)로 이동했다.

## BUG-009. 신규 그룹의 멤버 목록·상세 전투력 누락

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0007)로 이동했다.

## BUG-022. 앱 재설치·동일 원정대 재인증 후 그룹 모집 관리 권한 오류

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0008)로 이동했다.

## BUG-021. 그룹 가입 신청 승인이 Rules 평가 한도로 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0009)로 이동했다.

## BUG-001. 모집 생성 후 상세가 다른 방(A)을 보여 줌

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 (수정됨) |
| 보고일 | 2026-08-26 |

상세 `recruitmentId` 변경 시 State·구독이 따라가지 않아, 방 A 상세 후 방 B 생성 시 A가 남을 수 있었다. `ValueKey`·`didUpdateWidget`/`restart`로 수정했고, 정상 스텝 실기기에서 통과 확인 후 종료.

---

## BUG-002. 목록은 4인 노말인데 상세·구성은 8인 공격대처럼 보임

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0010)로 이동했다.

## BUG-003. 회차 완료 후 완료 기록이 비어 보임 / 진행 중에서 사라져 해산 불가

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0011)로 이동했다.

## BUG-004. 하단 탭 전환 시 이전 상세 스택이 남음

| 항목 | 내용 |
| --- | --- |
| 상태 | 패치됨 |
| 보고일 | 2026-08-26 |

모집 탭 갔다가 현황으로 돌아오면 해산·종료로 비었어야 할 상세가 다시 열렸다. 탭 전환 시 브랜치 스택을 유지했기 때문이다.

패치: 탭 터치마다 `goBranch(..., initialLocation: true)`로 해당 탭 루트로 이동.

---

## BUG-005. 같은 레이드 회차 완료 후 재생성·재완료가 막히지 않음

| 항목 | 내용 |
| --- | --- |
| 상태 | Task-074~075 주간 Claim 작업에 흡수 |
| 보고일 | 2026-08-26 |

완료 → (해산) → 같은 레이드 재생성 → 다시 완료를 같은 주차에 반복할 수 있다. 원인은 서버 개인 주간 완료 Claim이 없는 것이다. 별도 임시 패치 대신 [`../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md`](../architecture/WEEKLY_RAID_CLAIM_CONTRACT.md)와 Task-075 이후 단계에서 생성·신청·가입·교체를 함께 차단한다.

---

## BUG-006. 회차 완료·해산이 처음 1~2회 실패하다 이후 성공

| 항목 | 내용 |
| --- | --- |
| 상태 | 종료 간주 (현재 재현 없음, 재발 시 재개) |
| 보고일 | 2026-08-26 |

권한 확인 실패 후 재시도하면 성공하는 경우가 있었다. 이후 Transaction 읽기 후 쓰기 순서 수정과 실기기 검증 뒤 같은 증상이 재현되지 않았다. 재발 시 명령·방 상태·오류 코드를 새로 기록해 다시 연다.

---

## BUG-007. 반복 파티 완료·다음주 캐릭 변경·취소 반복 시 Claim/취소 꼬임

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0012)로 이동했다.

## BUG-008. Task-086 운영자 승인·분쟁·강제 인증 permission-denied

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0013)로 이동했다.

## BUG-010. 정상 특수 보석 대상이 스킬 미확인으로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **수정·자동 검증·주요 실기기 확인 완료** |
| 보고일 | 2026-09-08 |
| 심각도 | 중간 — 표기 오류 및 Build 검증 신뢰도 저하 |
| 기준 문서 | [`../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md`](../architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md) |

### 재현과 실제 결과

- 발키리 support의 `신앙 스킬`과 바드 dealer의 `템페스트 스킬`이 `보석의 대상 스킬을 확인할 수 없습니다`로 표시됐다.
- 실제 API 진단을 확대해 홀리나이트 support `신앙 스킬`, dealer `심판자 스킬`, 도화가 support `음양 스킬`에서도 같은 카탈로그 공백을 확인했다.
- 바드 support `세레나데 스킬`, 발키리 dealer `종언의 빛`, 도화가 dealer `떠오르는 달`은 현재 카탈로그에서 정상 분류됐다.

### 확인된 원인

- 기존 4직업 fixture는 실제 API 실측이 아닌 사용자 제공 계약값이었고 `신앙`, `심판자`, `음양`처럼 실제 대상명의 `스킬` 접미사가 빠져 있었다.
- 바드 실제 fixture의 `템페스트 스킬`은 카탈로그 없는 호출에서 아이콘 fallback으로 통과했지만, 알려진 직업은 타 직업 오판 방지를 위해 fallback을 차단하므로 현재 카탈로그에서 unknown이 된다.
- 보석 대상명만으로는 발키리와 홀리나이트의 동일한 `신앙 스킬`을 구분할 수 있다. 실제 보석 Tooltip의 `[직업]`을 현재 Character 직업과 함께 비교해야 한다.

### 해결 결과

- 모든 직업의 전체 Build를 선행 수기 입력하지 않는다.
- 실제 확인된 특수 대상명을 교정하고 동일 직업·대상 미확인과 다른 직업 보석을 분리했다.
- 깨달음·아크그리드 기본 조건과 해·달 존재/14P 검사를 구현하고 자동·주요 실계정 검증을 완료했다.
- 파티 신청자와 membership 카드의 최소 보석 검증 Snapshot 전파를 완료했다. 그룹 membership 전파는 현재 `NEXT_WORK.md`의 별도 작업 그룹으로 진행한다.

---

## BUG-011. 주차 경계 후 미완료 종료·반복방 전환 상태 불일치

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0014)로 이동했다.

## BUG-012. 동일 레이드 다른 난이도 신청 후보에 확정 참가 Character가 노출됨

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0015)로 이동했다.

## BUG-013. 4인 파티에서 방장과 동일한 딜러 직업이 신청 후보에 노출됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 실기기 확인·`dev` 반영 완료** |
| 보고일 | 2026-09-10 |
| 심각도 | 높음 — 파티별 동일 딜러 직업 제한의 신청 사전 차단 누락 |
| 기준 문서 | [`../product/PARTY_PARTICIPATION_RULES.md`](../product/PARTY_PARTICIPATION_RULES.md) |

### 원인

- 카탈로그와 `PartyCompositionPolicy`는 4인 1파티의 동일 딜러 직업 상한을 1명으로 올바르게 정의한다.
- 모집 상세 신청 팝업은 현재 membership·파티 구성 없이 생성용 `RecruitmentLeaderCandidateService`를 호출해 방장과 신청 Character의 직업 중복을 판정할 수 없다.
- 최종 즉시 가입·승인 배치는 다시 검증하지만 승인 대기 신청 후보 단계에는 누락돼 있다. 이 경로는 최근 assignment 수정에서 제한을 제거한 것이 아니라 기존 신청 화면 연결의 검증 공백이다.

### 수정

- 상세 읽기 모델의 membership과 `PublicRecruitmentSummary.partyRules`를 신청·캐릭터 변경 후보 Query에 전달한다.
- 신청·즉시 가입 후보는 최종 가입과 같은 `PartyCompositionPolicy.assignEmptySlot`으로 판정한다.
- 캐릭터 변경은 자리 유지 `failureForInPlaceReplacement`로 membership 명령과 같은 파티 단위 제한을 적용한다.
- 모집 생성 후보는 membership을 넘기지 않아 기존 생성 흐름을 유지한다.

### 검증

- 표적·영향 자동 테스트와 변경 파일 analyze가 통과했다.
- 실기기: 4인 동일 딜러 직업 후보 미노출, 8인 동일 직업 2명 신청 허용을 확인했다.
- 8인 동일 직업 3번째 차단과 변경 가능 캐릭터 없음 알림은 자동 테스트로 고정했고 실기기 재확인을 남긴다.

---

## BUG-014. 장비 인증의 앱 종료 정책 안내 누락

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0016)로 이동했다.

## BUG-015. 후보의 아크그리드 오류가 신청자·파티원 카드에서 사라짐

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0017)로 이동했다.

## BUG-016. 인증 시작 장비 미착용이 일반 정보 실패로 표시됨

| 항목 | 내용 |
| --- | --- |
| 상태 | **종료 — 자동 수정·실기기 확인 완료** |
| 보고일 | 2026-09-13 |
| 심각도 | 낮음 — 사용자가 필요한 조치를 알 수 없음 |
| 기준 문서 | [`../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md`](../architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md) |

### 원인

- 인증 시작은 무기와 방어구 5부위 중 하나라도 미장착이면 Gateway에서 `FormatException`을 발생시킨다.
- 화면의 공통 실행기는 장비 누락, Character 불일치와 실제 응답 파싱 실패를 모두 같은 `FormatException`으로 받아 `캐릭터 또는 장비 정보를 처리할 수 없습니다.`로 표시한다.

### 해결 방향

- 6부위 미착용을 식별 가능한 인증 시작 오류로 분리하고 `인증을 시작하려면 무기와 방어구 5부위를 모두 착용한 뒤 다시 시도해 주세요.`를 표시한다.
- 실제 API 오류·응답 누락·파싱 실패의 일반 안내는 유지한다.
- challenge 생성, 무작위 부위 선택과 인증 성공 판정은 변경하지 않는다.

### 수정 결과

- 장비 미착용을 문자열 비교가 아닌 `incompleteEquipment` 전용 시작 오류로 분리했다.
- 무기·방어구 5부위 완전 장착 성공, 일부 누락, 손상된 응답을 Gateway 테스트로 분리하고 화면 문구를 Widget 테스트로 고정했다.
- 사용자가 실제 기기에서 장비 미착용 전용 문구가 일반 정보 실패와 분리되는 것을 확인했다.

---

## BUG-017. 8인 Character 변경이 다른 파티 배치 가능성을 보지 않음

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0018)로 이동했다.

## BUG-018. 확정 참가자가 있는 모집 해산이 권한 오류로 실패

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0019)로 이동했다.

## BUG-019. 원자 모집 생성·목록·후보·신청 상태 불일치

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0020)로 이동했다.

## BUG-020. 파티 완료 수명주기의 권한·기록·개인 해제 회귀

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0021)로 이동했다.

## 백로그 연결

> 기존 자료는 [출처가 기록된 레거시 발췌](../../legacy/firebase/extracted/docs/project/BUG_REPORTS.md#source-0022)로 이동했다.
