# 버그 리포트

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
