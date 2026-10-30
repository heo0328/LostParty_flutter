# NEXT WORK — 그룹1차 통합 기준·별도 후속

## 목표·기준

2026-10-30 승인한 그룹1차 기능은 앱 기기 인수까지 완료했다. 2026-10-31 사용자 지시에 따라 그룹 작업을 dev에 병합하고 dev/main을 같은 커밋으로 정렬한다. 목적 브랜치는 삭제하지 않고 통합 시점으로 보존한다. 제품 계약은 [그룹 제품 §9](../product/GROUP_PRODUCT_FLOW.md#9-그룹-레이드-생성), 주차별 기술 계약은 [모집37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#cycle-group-policy), 연결 책임은 [설계39](../backend-migration/39-group-flutter-integration-design.md)다.

일반→A 연결, A→B 교체, A→일반 연결 해제를 해당 주차 공대장이 수행한다. 일반은 연결 없음+전체 공개, 그룹은 한 그룹 연결+그룹 전용이다. C/N의 그룹·공개범위는 독립이며 제목 등 무관한 방 공통값까지 분리하지 않는다. 기존 참가·신청·배정·일정·예약·완료/기록을 보존한다. 탈퇴·직접 위임의 일반 전환/승계도 한 명령으로 원자 처리한다.

## 실제 상태·담당·다음 행동

통합 기준: 착수 시8fc38e0e/작업트리 clean, 최신 origin/dev·main bdfe0edf, dev 단독 변경0건. 최종 전체 시험2,730PASS·전체 분석0 후 일반 병합d5bc724e를 만들었고 검증 코드와 병합 트리 동일성을 확인했다. 후행 통합 문서를 포함한 최종 dev/main·원격 동일 SHA는 [통합 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530680059)과 Git 이력에서 확인한다. 앱 기기 인수 완료와 별도 서버/디자인 후속은 아래처럼 구분한다.

**현재 그룹·레이드 변경의 네이티브 연결·자동 검증·사용자 앱 기기 인수 완료 / 과거 GET500 자연 재발 근거·Penpot 검수 대기**다. 코드055e0608 인계 후 사용자가 “앱 테스트 전부 통과”라고 확인했다. 그룹 변경·승계/직접 위임·C/N 독립/다음주 개방·상속·기존 주차 보존·그룹명/소속 배지/주차별 표시·이름 제한 안내의 앱 확인 대기를 해소한다. 같은 정상 시험을 다시 요구하지 않는다. [전체 앱 인수 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6529987970)을 게시하고 본문을 재조회했다.

계약은 Backend b212ad0f, 마지막 확인 실행 소스b8542ef7/DB0035·기록476d1f31이다. 구현88a69fa7, 개방 보완ffffc4e6·3ec0f54f, 이름 안내055e0608을 보존한다. 기반 전체2,724PASS·개방 직접110PASS/전체 분석0·이름 안내 페이지 분석0은 각각 당시 실행 결과이며 이번 사용자 수동 인수와 합산하지 않는다. 완료 경과/세부 인수는 DEV_LOG, 장기 계약은 제품 §9/설계39를 따른다.

| 별도 남은 작업 | 담당·상태 | 완료 조건 |
|---|---|---|
| 과거 상세 GET500 원인 미확정·현재 미재현 | 자연 재발 근거 대기 / [Backend 조사](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530073442)·[Flutter 입력 기록 대조](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530221606) | 재발 시 UTC/새 request_id·민감값 없는 profile/query·anchor 사용 여부/동작/주차 상태 전달 후 표적 재현. 정상 시험 반복·추측 수정 없음 |
| Penpot03 실제 화면 대조·검수 | Flutter / 도구 대기 | 기존 보드 갱신·시각 검수 후 같은 묶음02 이관. 앱 인수만으로 시각 검수 완료 처리하지 않음 |

현재 확인된 앱 미구현/기기 실패 항목은 없다. 정상 앱 인수를 과거 서버500 원인 해소로 간주하지 않는다. Backend 조사 기록1be55a7d는 직접 호출/응답모델 대조에서 예상외 예외0이나 과거 원인 해소/수정 완료는 아니다. 당시 두 요청의 앱 query/화면/상태 원기록은 확인하지 못해 회신했다. 현재 추가 Flutter 코드/API 변경 근거는 없으며 자연 재발 근거가 생기면 해당 차이만 대조한다. 종합 기술 개선은 별도 후속이며 이번 인수로 자동 착수·완료 처리하지 않는다. 이번 승인한 dev/main 정렬 외 추가 통합·배포·자료초기화·브랜치 삭제는 수행하지 않는다.

## 협업 상태

- 현행 근거: [Issue16 서버 인계](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6503318794), [Flutter 기존 연결](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6503895060).
- 새 정책 요청: [Issue16 확정 정책·구현 요청](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6521839291), 게시 본문 재조회 확인. Backend b212ad0f 고정 계약·격리 검증 및 실행b8542ef7/DB0035 반영 인계 완료. [Flutter 연결·자동검증 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6527340458)의 본문을 재조회했다. 현재 앱 기기 인수는 완료했으며 별도 Backend 조회 오류/디자인 후속은 위 표를 따른다.
- [다음주 방 생성 사용자 인수 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6529639375): 본문 재조회 확인. 개방 오류의 기기 대기는 해소했다. 별도 상세GET500 원인 대조는 Backend 후속이다.
- [추가 기기 인수 정정·GET500 조사 요청](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6529904340): 본문 재조회 확인. 그룹 변경/같은 그룹 승계/직접 위임 통과. Backend가 원인·영향·수정 필요성·실행 상태를 같은 Issue에 회신하면 Flutter 영향 여부를 대조한다.
- [Backend 조사 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530073442): 과거500 확인·현재 미재현·원인 미확정, 코드/계약/실행 변경 없음. [Flutter 답변](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530221606): 당시 요청별 입력 기록 확인 불가. 정상 앱 인수 유지·자연 재발 근거 대기.
- 모집·탈퇴 연계: [Issue13 출처 연결](https://github.com/heo0328/lostparty-backend/issues/13#issuecomment-6521848149), 게시 본문 재조회 확인. completed 상태 유지·재개/종료 조작 없음.

## 회귀 보호·자동 검증

- 서버 최종 권한·현재 가입·실제 주차/세대·revision, 검토 후 탈퇴/위임/그룹변경·동시명령 시 재검토. 확인 없이 영향 범위를 바꾸지 않는다.
- 최대8인 대표로 같은 그룹 우선/그 안의 기존 참가순서 승계, 같은 그룹 후임 없음→일반 전환+승계, 마지막1인 종료. 권한 부여 불가 참가자의 복구 상태는 기존 서버 경계를 보존한다.
- C/N 다른 공대장·서로 다른 그룹·모두 탈퇴/직접 위임·신규 N 설정 상속·이미 열린 N 보존. 반대 주차 참가/공개/예약/완료 불변.
- 그룹 교체/해제 후 기존 참가·pending origin·배정/일정/예약·완료/기록 보존. 실제 주차의 검색/필터/카드·배지/그룹 해산 활성 목록 판정.
- 원본문/멱등키·과거 ACK/재가입·회원/환경·늦은 응답·ACK 실패 rollback·성공 후 조회 실패. 과거 미확정 요청을 새 정책으로 재작성/자동 replay하지 않는다.
- 공용 조회/저장 계약을 변경하는 최종 앱 연결 상태에서 전체 flutter test·flutter analyze·포맷·diff 검토. 문서 정정만 한 구간에는 기능 시험 반복 없음.

## 범위 밖·후속

그룹 자체 탈퇴/추방/해산 정책 변경, G-RECOVERY·자료삭제/초기화·AWS/release 배포·웹소켓·공지·통계는 제외한다. 현재 로컬에서 계획 기능을 개발·검증한 뒤 AWS 준비를 진행한다. 종합 기술 개선은 이번 그룹 정리 이후 별도 작업이며 [기술 진단 인계](../product/DETAIL_IMPROVEMENTS.md#technical-review-handoff)를 보존한다. 개발환경/자료 수명은 정책09 D08을 유지하고 별도 이중 운영/복원 리허설을 추가하지 않는다.

네이티브의 별도 후속은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에 유지한다. 그룹 정리 후 종합 기술 진단/개선은 별도 작업이며 후보를 확정 결함으로 취급하지 않는다. BUG-025의 최초 자동 갱신 후 카드 전투력 표시, 계정/출시 경계, 제안 시간 정밀도1건은 각 원본의 착수 조건을 따른다. 다음주 개방 알럿 반복 로그·제안 발견성·웹소켓/운영 복구 등 보류·미채택 범위를 현재 그룹 필수 구현으로 끌어오지 않는다. 현재 방 생성 성공 확인이 이전 알럿 반복 로그의 해결 근거는 아니다. AWS는 계획 기능의 로컬 개발 이후이며 지금 준비/배포하지 않는다.
