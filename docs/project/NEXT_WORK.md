# NEXT WORK — Penpot03 그룹 화면 갱신·검토 기준

## 현재 상태

사용자 지시에 따라03의 기존 **그룹 · 사용자 흐름과 화면** 메인 보드와01~08/공통 상태9개 섹션을 네이티브 dev4a0bf962 기준으로 갱신했다. 기존16개 화면 프레임/메인·섹션 ID를 유지하고08 안에6개 다른 상태를 추가해 총22개390×844 화면을 정리했다. 버전별 메인 사본은 만들지 않았고 무관한 Board·다른 페이지는 수정하지 않았다.

[Penpot03 그룹 보드](https://design.penpot.app/?screen=workspace&file-id=cd444aaf-0d8c-801b-8008-d058e3181ffd&page-id=0f0035d1-2d8f-8071-8008-dba78bf41adc&board-id=0f0035d1-2d8f-8071-8008-dbabf5c8d408)에서 검토한다. 요청 대상03에 유지하며02 이관은 하지 않았다. 이번 결과의 사용자 디자인 확인·02 이관은 남아 있다.

## 반영·검증 완료

- 실제 BackendGroupPage의 요청 분류·검색·이름 입력/제한·캐릭터 선택 진입·공개 상세/코드 가입·그룹원 메뉴·정보/코드·신청 금지·그룹장 이전/탈퇴를 반영했다. 앱에 없는 생성 전 대표 드롭다운/미리보기·상세 즉시 공개 토글을 제거했다.
- 08은 실제 주차 목록→상세→모집 조건 변경/공개·그룹 단일 선택, 같은 그룹/외부 후임 탈퇴, 직접 위임, 다음주 설정 상속을 구분한다. 일반 전환=연결 해제, C/N 독립·기존 자료 보존을 화면 밖에서 설명한다. 다이얼로그는 그룹 영향 중심 발췌이며 모든 공통 일정/캐릭터 선택창 상태나 클릭 프로토타입을 추가 복제하지 않았다.
- SDK Material 글리프12종을 SVG로 변환해 임시 문자 아이콘을 교체했다.390×844·반경16·안쪽1px 테두리·v1 색상/Noto Sans KR을 유지한다. 디자인 단위 코드 대조이며 실제 기기 픽셀 측정/완전 동일성의 주장은 아니다.
- 01~06/08/공통 섹션 PNG·07의 두 개별 화면 PNG·전체 보드 PNG를 눈검수했다.07 섹션 export의 일시적500/timeout은 개별 화면 export로 확인했다. 전체/프레임 경계 이탈0·텍스트 넘침0·03/다른 최상위 보드 보존을 재조회했다.
- 앱 코드·서버·DB·계약 변경 없음. 문서 diffcheck·내용/diff 검토를 적용하고 Flutter 시험/분석은 반복하지 않는다. 디자인은 Penpot에 저장됐으며 문서는 docs/group-native-design에서 commit/push한다.

## 보존·별도 후속

그룹1차 앱 인수/통합b8b20b50과 탭 보호8c17d827의 직접152PASS·분석0·사용자 인수·dev4a0bf962 통합을 보존한다. main은b8b20b50이다. 실제 제품/기술은 [그룹 §9](../product/GROUP_PRODUCT_FLOW.md#9-그룹-레이드-생성)·[모집37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#cycle-group-policy)·[설계39](../backend-migration/39-group-flutter-integration-design.md)를 따른다.

과거GET500은 [Backend 후속](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530965340)의 현재 미재현·원인 미확정/미해결 기록을 유지한다. 추가 회신/반복 시험을 디자인 완료 조건으로 요구하지 않는다. 종합 진단·BUG-025·제안 정밀도·개방 알럿 반복 로그·제안 발견성·웹소켓은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)의 별도 착수 조건을 따른다.

이번에 앱 구현 수정·02 이동·dev/main 재통합·AWS/release 배포·서버/DB 변경·자료 초기화·Issue 종료·브랜치 삭제는 하지 않는다. 로컬 기능 개발 후 AWS 준비와 정책09 D08을 유지한다.
