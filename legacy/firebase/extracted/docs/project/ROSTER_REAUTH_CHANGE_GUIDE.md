# 기존 서비스 발췌 — docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md

원본 문서: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md ([현재 문서](../../../../../docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md)). 분리일: 2026-10-13.
원본 전체 SHA256: d5e9954d31295ec5888406dcc7268b757fec5213f1cec4323f3b629f53772426.
아래는 기존 Firebase 환경의 원문이다. 신규 서버의 실행 지시/배포 승인으로 사용하지 않는다. 행 범위는 분리 직전이며 링크 위치만 조정한다.

<a id="source-0001"></a>

## 발췌 1: # 원정대 재인증 변경 안내

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 10~12행 · 원문 절: # 원정대 재인증 변경 안내.

이 문서는 이번 기능 수정과 Rules 게시 문제 해결을 한 흐름으로 설명한다.
앞부분은 사용자가 보게 되는 변경, 뒷부분은 개발 기록과 근거를 다룬다. 실행할 테스트 목록은 채팅에서만 안내한다.
과거 시도 전체는 복제하지 않고 기존 설계·진단 기록으로 연결한다.

<a id="source-0002"></a>

## 발췌 2: ## 1. 이번 작업의 목적

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 24~25행 · 원문 절: ## 1. 이번 작업의 목적.

이와 별도로, 기능을 서버에서 허용할 Rules가 게시되지 않던 문제를 해결했다.
**운영 게시 성공과 새 기능의 실기기 통과는 서로 다른 완료 조건**이다.

<a id="source-0003"></a>

## 발췌 3: ## 2. 현재 확인된 결과

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 29~37행 · 원문 절: ## 2. 현재 확인된 결과.

| 항목 | 확인 상태 | 해석 |
|---|---|---|
| 운영 Rules 게시 | 10월 5일 12:03 KST 성공, 활성 소스 해시 일치 | 새 Rules가 운영에 적용됨 |
| 서버 경계 제한 자동 검증 | 통과 | 최대 인원 정리·승계·주차 전환 및 권한·부분쓰기 등의 제한 사례 |
| 일반방 생성·신청·수락 | 금일 사용자 확인 | 현재 빌드의 기본 흐름 통과 |
| 그룹방 생성·신청·수락 | 금일 사용자 확인 | 현재 빌드의 기본 흐름 통과 |
| 기존 반복방의 새 확인 버튼 | 표시되지만 권한 관련 오류로 진행하지 못했다는 사용자 보고 | 정확한 문구·실패 단계·원인 미확인 |
| 다른 사용자로 원정대 재인증 후 정상 사용 | 사용자 정상 이용 확인 및 현재 구간 완료 결정 | 동일 방의 옛 참가 중복은 후속 고아 관계 처리로 분리 |
| 당시 월요일13시 시험의 주차 전환 결과 | 아직 보고되지 않음 | 전환 전후 비교 필요 |

<a id="source-0004"></a>

## 발췌 4: ## 4. 이번 권한 관련 오류의 해석

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 100~101행 · 원문 절: ## 4. 이번 권한 관련 오류의 해석.

3. Firebase의 `permission-denied`나 일반적인 연결/권한 안내가 나온 경우:
   조회 단계인지 확인창 이후 저장 단계인지부터 구분해야 한다.

<a id="source-0005"></a>

## 발췌 5: ## 4. 이번 권한 관련 오류의 해석

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 105~108행 · 원문 절: ## 4. 이번 권한 관련 오류의 해석.

다음 재현에서 **버튼의 정확한 문구, 오류 전문, 누른 사용자/대상 캐릭터, 방 ID, 완료 여부,
소유권을 실제로 이전했는지, 확인창 전후 어느 단계인지, 발생 시각**을 남긴다.
오류 사례에 한해 터미널 로그를 함께 확인한다. 원인 확인을 위해 기존 방을 삭제하지 않는다.
주간키를 수동 변경하거나 Rules를 완화하는 조치는 아직 하지 않는다.

<a id="source-0006"></a>

## 발췌 6: ## 6. 최종 파일·검증·한계

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 145~145행 · 원문 절: ## 6. 최종 파일·검증·한계.

- 배포 파일: 저장소 루트 `firestore.rules`, 134,048 UTF-8 bytes.

<a id="source-0007"></a>

## 발췌 7: ## 6. 최종 파일·검증·한계

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 156~157행 · 원문 절: ## 6. 최종 파일·검증·한계.

가독본과 이름 대응표는 `node tools/integrate_roster_rules.mjs --check --review`로
`coverage/rules-executable/review/`에 생성한다. 실제 배포는 계속 루트 Rules 한 파일이다.

<a id="source-0008"></a>

## 발췌 8: ## 7. 상세 근거 위치

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 162~162행 · 원문 절: ## 7. 상세 근거 위치.

- [Rules 복잡도 조사](../../../docs/project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md), [게시 비교 실험](../../../docs/project/ROSTER_RULES_PUBLISH_DIAGNOSIS.md).

<a id="source-0009"></a>

## 발췌 9: ## 7. 상세 근거 위치

출처: docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md · 원본 165~165행 · 원문 절: ## 7. 상세 근거 위치.

- 정리 거래: `lib/features/recruitment_list/data/repositories/firestore_completed_ownership_cleanup_repository.dart`.
