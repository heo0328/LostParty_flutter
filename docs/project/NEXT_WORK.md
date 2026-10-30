# NEXT WORK — 주차 탭 보호 인수·dev 통합 기준

## 완료한 작업

2026-10-31 사용자가 모집 상세의 로딩 중 주차 탭 보호를 정상 적용으로 확인하고 dev 병합을 지시했다. 수정 코드 `8c17d827`은 기존 선택기를 상세/부속 조회 중 비활성화하고 이전 프레임의 콜백도 차단한다. 성공/실패 완료 후 다시 선택할 수 있으며 ViewModel의 늦은 응답·회원/환경 epoch 보호와 기존 오류 안내를 유지한다. [구현·검증 회신](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6531287833)을 따른다.

직접 영향6파일152PASS(신규 지연 성공/500 실패2경계 포함)·변경2파일 분석0·포맷 통과와 이번 사용자 기기 인수를 완료 기준으로 사용한다. 이후 변경은 인수/통합 문서뿐이며 같은 시험을 반복하지 않는다. 최신 origin/dev b8b20b50·분기 차이1커밋·미커밋 없음에서 검토했다. 인수 기록을 목적 브랜치에서 보관한 뒤 dev에 일반 merge·push하고 main b8b20b50은 유지한다. 최종 통합 SHA·원격 일치는 Git 이력과 [Issue16](https://github.com/heo0328/lostparty-backend/issues/16)에 기록한다. 목적 브랜치는 보존한다.

그룹1차 주차별 변경/해제·승계/위임·C/N 독립·개방/상속·표시의 기존 앱 인수와 통합 b8b20b50은 보존한다. 제품/기술 원본은 [그룹 §9](../product/GROUP_PRODUCT_FLOW.md#9-그룹-레이드-생성)·[모집37](../backend-migration/37-raid-scheduling-and-multi-raid-planning.md#cycle-group-policy)·[설계39](../backend-migration/39-group-flutter-integration-design.md)다.

## 별도 남은 항목·다음 행동

| 항목 | 현재 상태·담당 | 다음 행동 |
|---|---|---|
| 과거 상세 GET500 | Backend 조사6279daf5에서 현재 미재현·원인 미확정/미해결 | [HTTP 후속 조사](https://github.com/heo0328/lostparty-backend/issues/16#issuecomment-6530965340) 유지. 자연 재발 근거가 생기면 대조한다. 이번 네이티브 인수를 서버 원인 해소로 확대하거나 추가 확인·기기 반복 시험을 요구하지 않는다. |
| Penpot03 시각 검수·02 이관 | Flutter / 도구 대기 | 도구 제공 시 기존 보드 갱신·시각 검수 후 같은 묶음02 이관. 앱 인수로 대신 완료 처리하지 않는다. |
| 종합 기술 진단·기타 네이티브 보류 | 별도 작업, 자동 착수 안 함 | [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)의 담당·착수 조건을 따른다. BUG-025·제안 정밀도·개방 알럿 반복 로그·제안 발견성·웹소켓을 이번 병합에 포함하지 않는다. |

현재 탭 보호에 남은 코드/기기 인수 작업은 없다. Backend 고정 계약 b212ad0f·마지막 확인 실행 b8542ef7/DB0035는 유지한다. 이번 dev 병합 외 main 정렬·release/AWS 배포·DB/서버 변경·자료 초기화·Issue 종료·브랜치 삭제는 실행하지 않는다. 로컬 기능 개발 후 AWS 준비·정책09 D08을 유지한다.
