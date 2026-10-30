# NEXT WORK — 모집 상세 주차 탭의 로딩 중 전환 방지

## 목표·근거

2026-10-31 사용자는 N 정보가 표시되기 전에 C로 빠르게 돌아왔을 때 오류창을 한 번 봤다고 설명했다. [사용자 회상 전달](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6531090992)·[관찰 범위 보충](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6531137779)은 당시 request_id에 대응하는 원로그가 아니다. 사용자는 추가 Backend 확인 요청 대신 네이티브 화면/탭 통신 수명 대응을 지시했다.

목적 브랜치 `fix/recruitment-cycle-tab-loading`은 상세 로딩 중 탭 전환 차단·완료 후 복구를 연결하고 직접 비동기 경계 검증/인계를 마치면 종료한다. 시작 기준 dev/main·그룹 브랜치 b8b20b50, 작업트리 clean·최신 origin/dev 동일이다. 그룹1차 인수·통합은 [기존 통합 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530680059)에 보존한다.

## 조사·설계와 포함 범위

- 실제 앱 BackendApp Router → BackendRecruitmentDetailPage → BackendRecruitmentDetailViewModel.load → application-display 또는 membership detail 조회 연결을 유지한다. ViewModel이 선택 주차·조회 epoch·회원/환경 수명과 loading을 소유한다.
- 기존 ViewModel은 주차/회원/환경 변경 후 늦은 성공·오류를 epoch로 폐기한다. 하지만 페이지의 MemberCycleSelector는 loading을 전달하지 않아 조회 중 C/N 왕복을 허용한다. 역사적 서버500 원인이라는 증거는 없으며, 이번 수정은 확인된 네이티브 조작 경계에 한정한다.
- 페이지는 기존 선택기의 enabled에 !loading을 연결한다. 이전 프레임의 콜백이 호출돼도 loading이면 선택하지 않는다. 주차 조회·부속 조회가 성공/실패해 loading이 해제되면 다시 선택할 수 있다. 회원/환경 변경·dispose 시 기존 epoch 보호를 유지한다.
- ViewModel의 명시 선택/늦은 응답 계약은 바꾸지 않는다. 실제 통신 취소·캐시·추가 요청·서버 계약·UI 배치·오류 숨기기를 도입하지 않는다. 현재 선택 주차의 실패는 기존 안내와 재조회로 처리한다.

## 작업 순서·완료 조건

현재 상태: 네이티브 페이지 연결·직접 검증 완료. 신규 지연 성공/500 실패2경계를 포함한 직접 영향6파일152PASS, 변경 Dart2파일 분석0·포맷 통과. 공용 경계 변경이 없어 전체 시험은 반복하지 않는다. 보관·인계 결과는 목적 브랜치 Git 이력과 [Issue16](https://github.com/heo0328/lostparty-backend/issues/16)을 따른다. 이 변경의 실제 기기 확인은 미확인으로 남기며 기존 그룹 전체 시험을 다시 요구하지 않는다. dev/main은 b8b20b50에 유지한다.

1. 기존 페이지에 로딩 중 선택 차단을 연결한다.
2. 실제 페이지에서 지연 응답 성공/500 실패 각각에 대해 N 조회 중 C 선택 무효·추가 조회 없음·완료 후 재선택 가능을 검증한다. 최초 C 로딩과 재조회·회원 전환/늦은 결과는 기존 직접 시험을 회귀로 사용한다.
3. 직접 영향 모집 시험·변경 파일 분석·포맷·diffcheck/diff 검토 후 코드/시험/문서를 같은 파트로 commit/push한다. 공용 모델·DTO·저장·DI/Router 변경이 없어 전체 Flutter 시험은 기본 반복하지 않으며 새 실패/공용 영향이 확인될 때 확대한다.
4. Issue16에 네이티브 대응 범위·실행 검증·미확인을 회신한다. Backend에 같은 조사/기기 시험을 반복 요청하지 않는다. 실제 기기 확인은 사용자 담당이며 이 수정의 기기 통과를 자동 시험으로 대신 주장하지 않는다.

## 보호 흐름·별도 후속

- 그룹1차 연결/교체/일반 전환·승계/위임·C/N 독립·개방/상속·표시의 앱 전체 인수와 dev/main 통합 b8b20b50을 보존한다. 제품은 [그룹 §9](../product/GROUP_PRODUCT_FLOW.md#9-그룹-레이드-생성), 기술 계약은 [모집37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#cycle-group-policy)·[설계39](../backend-migration/39-group-flutter-integration-design.md)를 따른다.
- 현재 Backend 고정 계약 b212ad0f·마지막 확인 실행 b8542ef7/DB0035는 유지한다. [Backend HTTP 후속 조사](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530965340)는 현재 미재현·과거500 원인 미확정/미해결이다. 이번 탭 보호를 서버500 해결 완료로 확대하지 않는다. 자연 재발 근거가 있으면 기존 Issue에서 대조하며 사용자에게 과거 시각/원기록 회상을 반복 요구하지 않는다.
- Penpot03 실제 시각 검수·02 이관은 도구 대기다. UI 배치 변경 없이 동작만 보완하며 미검수를 완료로 보고하지 않는다.
- AWS/release 배포·자료 초기화·DB/서버 변경·dev/main 재통합·브랜치 삭제·Issue 종료·그룹 자체 관리 정책·종합 기술 개선은 제외한다. 로컬 기능 개발 후 AWS 준비라는 정책09 D08을 유지한다.
- 다른 보류/미채택 기능·BUG-025·제안 시간 정밀도·다음주 개방 알럿 반복 로그·제안 발견성·웹소켓은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)의 별도 착수 조건을 따른다.
