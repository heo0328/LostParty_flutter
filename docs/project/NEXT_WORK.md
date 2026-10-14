# NEXT WORK — DB 점검 결과 검토·복원 범위 확정

2026-10-14. 사용자 지시의 Issue6 마무리와 전체 DB 설계 점검을 완료했다. [DB 설계 재점검24](../backend-migration/24-database-design-review.md)가 현재 저장 구조·근거·미구현/재현 문제의 기준이다. 기능 코드나 실제 DB를 바꾸지 않았다.

## 완료 기준

- 회원 설정 기능2e0764f, dev통합5cee964·push와사용자ON/OFF·관리재진입·동일Google재로그인3흐름성공. [Issue6 최종 인계/종료6170736672](https://github.com/heo0328/lostparty-backend/issues/6#issuecomment-6170736672). Backend79255f0소비,전체1219뒤국소32·최종분석0/APK9.4초를재사용했다.
- Backend dev4eb23f5(0003)와79255f0게시기준(0004)의차이를구분해19개모델/4개migration·서비스·정리를검토했다. Flutter schema13의8개테이블·secure storage·메모리캐시/활성DI를대조했다. 실DB접속/자료이관/삭제/DDL변경없음.
- 메모리DB1개probe에서foreign_keys=0·missing캐릭터삭제뒤build1/weekly1잔존을재현했다. 실제기기재현은미실행이며probePASS는문제재현관찰일뿐정상화판정이아니다.

## 다음에 확정할 단일 설계 구간

1. DB-01: 로그인 회원 원정대/캐릭터의 정답을 서버로 둘 때, 내 계정 주목록과 비로그인 로컬 목록을 어떻게 연결/표시할지 사용자와 협의한다. 현재 로컬DB는 회원/origin구분이 없고 서버등록은 별도다. 이름매칭만으로소유권이나서버ID를확정하지않는다.
2. DB-02/RESTORE-01: 서버에 저장할 dealer/support 빌드·선호 역할·표시순서/개수의 최소 복원 목록을 확정한다. 저장Snapshot형식/버전·등록/캐릭터연결키·수정충돌/복원순서를 정한 뒤 필요한 Backend 요청을 분리한다. 기존Firebase/테스터자료이관은하지않는다.
3. DB-03은 별도 작은 수정 그룹 후보: 실제 삭제 경로/기존 고아 상태와 FK활성 영향 범위를 확인하고 종속 빌드·주간 표시 정합성을 수정한다. 조사 중 발견했어도 이번에 코드를 바꾸지 않았다.
4. DB-04/POWER-01: 전체빌드자동갱신은설정GET성공+전체대상roster준비→같은회원/세션→나이스판정후실행을설계한다. 설정예외false/준비실패실행1회소진을연결하지않는다. 전체빌드계약/재시도UX는아직미확정이다.

## 후속·제외

기존 [Flutter 후속 대장14](../backend-migration/14-my-account-flutter-integration-plan.md#flutter-follow-up-20261014)의 장비/실provider근거·활동대표·인수/운영 항목은 유지한다. DB-05 상태/ID 매핑·DB-06 비활성schema·DB-07 Backend0004 Git통합은보고서24의담당/다음행동을따른다. Backend의실제확정변경/질문이생길때만새Issue로요청한다.

다음구현은사용자가선택한단일구간만진행한다. 파티/그룹/주간구현·전체DB재작성·마이그레이션/자료삭제·운영배포·기기자동조작은현재승인범위아니다. 문서만변경한이번검증은내용검토/diffcheck와격리메모리probe이며전체Flutter테스트를반복하지않았다.
