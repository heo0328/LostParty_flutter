# NEXT WORK — 화면 재구성 수정 마감·분리된 후속

## 현재 기준 — 화면 재구성 수정 인수 완료

2026-10-19 사용자 디바이스3항목(명시 로그인 후 회원 카드·설정 표시, 로그인 유지 재실행, 로그아웃 후 로컬 화면 복귀) 전부 통과 보고를 받았다. 로그인 후 화면 재구성 수정의 구현·인수는 완료했다. 직접 영향43PASS·변경3파일분석0 결과는 코드 변경 없이 재사용하며 Flutter 시험을 반복하지 않는다. 기존 디자인/4초 진입·앱 수명 복원은 유지한다. 상세 설계·검증·통합 근거는 DEV_LOG를 따른다.

수정 커밋8937445를 최신 origin/dev 확인 후 dev에 fast-forward 병합/push했고 원격 SHA 일치를 확인했다. [최종 인수·통합 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6263145675) 게시·재조회 완료. 분쟁 결과/다른 기기 변경 복원 전체를 이번3항목 통과로 확대하지 않는다. 기존 통계35·플랫폼 생성/백업/tools 변경은 보존하고 현재 커밋에서 제외한다. 다음 독립 후보는 아래 #13 Q1~Q3 검토이며 신규 구현은 아직 승인하지 않았다.

## 이전 구현 마감 — 분쟁 V2

2026-10-19 사용자 승인으로 원정대 인증·분쟁 V2 D1~D4 구현 구간을 마감했다. 구현 `43cd4e9`를 dev에 fast-forward 병합·origin/dev 푸시한 뒤 통합 기록을 정리했다. Backend 작업으로 현재 분쟁 결과의 실서버·디바이스 검증은 불가능하므로 차후 인수로 분리했다. 실기기 통과를 뜻하지 않으며, 인수 대기만으로 현재 브랜치를 계속 열린 구현 작업으로 두지 않는다. 최종 커밋·dev/push 근거는 DEV_LOG를 따른다.

- 공식 추적 [Issue15](https://github.com/heo0328/lostparty-backend/issues/15), 구현/계약과 후속 체크는 [설계36](../backend-migration/36-roster-ownership-dispute-flutter-design.md#9-backend-준비-후-후속-실기기-인수).
- [구현 마감·실기기 후속 이관 회신](https://github.com/heo0328/lostparty-backend/issues/15#issuecomment-6260104075) 게시·재조회 완료. Backend 준비 후 사용자 인수를 재개한다.
- 검증은 D1~D4 직접 영향 테스트·변경 파일 분석 결과를 재사용한다. D4 최종68고유PASS·변경18파일분석0, 코드 변경 없이 문서/Git만 마감하므로 Flutter 시험을 반복하지 않는다.
- 기존 UI·V1 미완료·회원/환경/명령 복구·현재 GET 후 소유 반영과 PARTY_IMPACT_REVIEW_REQUIRED 안전 보류를 보존한다. 배포·DB 변경/자료 삭제·기기 설치/조작·main 반영은 이번 지시에 포함하지 않는다.
- 사용자 백업/tools/DevTools/플랫폼 생성 변경 및 별도 통계 문서 변경은 소유를 보존해 현재 분쟁 커밋에서 제외한다.

## 다음 독립 작업 후보 — Issue13 Q1~Q3 검토

최신 수신: [F2-A 내부 조회](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6260548709), [F2-B 후보 HTTP](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6260695606). Backend 보고 기준 F2-B 9fb2058은 로컬 커밋·미push, 개발 서버/원본 OpenAPI 미반영이며 신규 Flutter 시험 요청은 없다. Q1~Q3는여전히 미확정이고 현재 화면 재구성 결함 문서화와 분리한다. F3 고정 계약·원격 게시/실행 버전 확인 전 새 API 연결을 시작하지 않는다.

아직 착수하지 않았다. 별도 작업 승인이 있으면 적합한 목적 브랜치를 확인한 뒤 기존 문서/코드와 대조하는 검토만 진행한다. 분쟁 브랜치에 모집 기능 구현을 섞지 않는다.

- 근거: [#13 시간순12번째 계약 제안](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259336924), [13번째 F1 내부 기반 보고](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259515470).
- Q1: 종료 미정·주차를 넘는 일정의 기존 소비/사용자 흐름과 초기 지원 범위 대조.
- Q2: 딜러·서포터 최소 전투력의 실제 수치·출처 대조. 임의 P1 분석값을 서버 검증 증거로 사용하지 않는다.
- Q3: 그룹 탈퇴 후 기존 방 잔류·조회·탈퇴/파티장 이전의 권한/최소 회복 범위 대조.
- 완료 조건: 기존 확정 정책과 충돌하는 지점/기존 기준으로 회신 가능한 내용/사용자 새 결정 필요 항목을 분리해 #13에 회신한다. 신규 API/Flutter 구현·실기기 시험·정책 임의 확정은 제외한다.

## 후속 인수 — 현재 구현 마감과 분리

담당은 Backend 준비 후 사용자 실제 조작, Flutter는 결과 기록과 발견된 문제의 최소 수정이다. 재개 시 최신 실행 Backend 계약·사용자 인수 가능 상태를 확인하고 [설계36 §9](../backend-migration/36-roster-ownership-dispute-flutter-design.md#9-backend-준비-후-후속-실기기-인수)의 한 묶음을 사용한다. 실제 장비·24시간/공통기한·일괄 방어·새 기기/재실행·계정 전환·좁은 화면/큰 글꼴은 아직 통과하지 않았다. 이미 통과한 기존 정상 흐름은 반복 요구하지 않는다.

## 분리된 후속 대장

2026-10-19 협업 회신 게시·재조회 완료: [G1/G2 #12](https://github.com/heo0328/lostparty-backend/issues/12#issuecomment-6259124455), [모집 #13](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6259125080), [G3 #16](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6259125692), [소멸/이름재사용 #17](https://github.com/heo0328/lostparty-backend/issues/17#issuecomment-6259126286), [첫 기준레벨/수동 제외 #18](https://github.com/heo0328/lostparty-backend/issues/18#issuecomment-6259126990), [통계 #19](https://github.com/heo0328/lostparty-backend/issues/19#issuecomment-6259127594). 현재 #15는 D1~D4 코드/자동 검증을 마쳤고 실제 인수 대기다.

- G1/G2는 Backend 통합 보고를 접수했으며 Flutter 연결은 미완료다. G3 고정 `332a8ab9697ca1a8e0d2ebcc147169c54ce9161c`의 SPEC/OpenAPI와 기존 그룹장 계약을 대조했다. 최소 ACK→현재 GET·즉시 이전 후 별도 탈퇴를 소비하며 실제 모집 원천 전 조건부 해산은 비활성이다. G3는 Backend 작업 브랜치 push 완료·main/dev 미통합 보고 상태다.
- #17은 Backend의 소멸 근거/한계와 최소 계약 검토, #18은 영속 정책/DTO·동시성 초안 인계가 다음 행동이다. 자료 삭제나 과거 미선택 일괄 활성화는 승인하지 않았다.
- #19는 Backend 최종 초안에서 확정 기준과 제안을 분리해 예시를 제시한 뒤 검토한다. 최초 참가 type 고정·함께 집계의 경계 참가/해산 조건·평균 분모·그룹 조회 권한 상세는 미확정이며 #13 독립 구현을 차단하지 않는다.

| 범위 | 현재 상태/다음 행동 |
|---|---|
| 개별 캐릭터 세팅 갱신 | 회원 상세 페이지의 누락 기능. 자동전체 갱신/서버저장 재시도로 대체하지 않으며 별도 복구 작업 필요. |
| 그룹/모집 연결 | [선행32](../backend-migration/32-backend-domain-prework-requests.md), #12/#13의 최신 인계부터 확인. 과거 ‘G1 미게시’ 문구로 되돌리지 않는다. 기존 화면/조작을 재사용한다. |
| 한도/통계 | [한도34](../backend-migration/34-member-limits-and-room-restrictions.md)·[통계35](../backend-migration/35-weekly-member-and-group-statistics.md)의 확정 정책 보존. 기본15/5/10, 주간 KST수요일06시. BM 즉시 도입 아님. |
| 첫1700 신규 활성/수동 제외 보호 | 서버 영속 정책 인계·정식 계약 여부부터 확인. 기존1700은 최초 기본 선택이며 저레벨 수동 사용 허용. |
| 생명주기/이력 | [26](../backend-migration/26-roster-character-lifecycle-design.md)·[29](../backend-migration/29-scoped-character-identity-design.md). API 목록 기준/새 이름 새ID, 파티/이름재사용·claim/퇴역은 해당 기능 계약과 함께 확인. |
| QA/운영 | DB-03 구기기 삭제 정합성, QA-01 등록제거/구자료, AUTH-01 탈퇴재가입·릴리즈/OAuth 인수는 [후속14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)·[점검24](../backend-migration/24-database-design-review.md). |
| 성능/애니메이션 | 사용자 보류. UI프레임·분석/중복계산·개별 저장 GET3+PUT1 최적화와 별/광채 재적용을 임의 재개하지 않는다. |

## 검증·자료 보존

정상 개발환경/DB/키는 계속 사용하며 베타 시작 직전에만 승인된 DB 내용 초기화를 한다. 새 환경 구축/기초 인수 재시작/Firebase 자료 승계는 요구하지 않는다. 기기 테스트는 사용자가 수행한다.

새 기기/재설치·OFF 제외/실패 재시도·로그아웃/계정 전환·실제 레이드 참가 관계 등 자동시험만으로 인수할 수 없는 잔여 조작은 각 후속의 수동 체크로 묶으며 완료로 확대하지 않는다. 일괄API 실측과 수동완료 성공 보고 등 이미 받은 결과는 반복 요청하지 않는다.

문서 정리 전 상세 단계/당시 SHA·순번/조건은 [원문 기록](history/scoped-account-cache-2026-10-18.md)에 보존했다. 이 원문은 현재 실행 지시가 아니다. 최신 기준은 이 문서·AI_CONTEXT·해당 기능 계약이다.
