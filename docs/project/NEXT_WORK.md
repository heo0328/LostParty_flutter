# NEXT WORK — 초기 갱신 개선 로컬 dev/main 통합·원격 푸시 확인

## 현재 상태 — 2026-11-04

사용자가 LostArk 자동 상세조회 기본 최대동시수를 **2개로 확정**하고 문서 기록·프로젝트 로그 삭제를 지시했다. `feature/startup-performance-diagnostics`를 유지한다. 구현/해당 로컬 측정을 완료했고 사용자가 현재 작업의 문서 최신화·커밋/푸시·dev 병합과 main 동일시점 정렬을 지시했다. 이전 commit/push/merge 보류는 이번 통합 지시로 해제됐다. 운영배포·APK게시·자료초기화·Issue종료는 별도 지시 대상이다.

일반 runtime 기본/debug미지정/profile/release는2, debug명시5/15 비교 옵션은 유지한다. 상세조회만 병행하고 분석/로컬저장은직렬·상태조회/성공요약업로드는일괄·최종bootstrap1회다. 기존대상선정·권한/소유·수명guard·쿨다운·원명령/부분복구는보존한다. 단건수동갱신은기존경로다. long-term계약은 [계정연결30](../backend-migration/30-scoped-storage-write-contract.md), Backend소비 b1f11bb5를 따른다.

## 선택 근거와 검증

동일6조회 대상의 기본2 반복3회 자동갱신4.88/5.82/4.61초(평균5.10·중앙4.88), 최종frame9.15/10.06/8.71초다. 직전15상한/실제6동시3회 자동5.73/4.63/11.61초보다 평균/편차가유리했다. 2에서도1건3.36초대기가있어 API가2특화이거나항상최적이라는결론은아니다. 사용자선택의실용근거로기록한다. 다른8조회/일부조기종료표본·최초단건비교는 DEV_LOG의당시구간/대상차이를따른다.

검증은 기존일괄연결최종전체2811PASS/분석0, 이후기본전환표적34PASS·명시5/15각런타임1PASS·변경2파일분석0을구분한다. 기본2의3회로그는동시2·실제6조회/저장·최종frame정상/기록HTTP200을확인했다. 같은시험을코드변경없이반복하지않는다. [Issue41 사용자확정회신](https://github.com/heo0328/lostparty-backend/issues/41#issuecomment-6608556182) 게시·재조회완료.

BUG-031의 Backend0207d0f6/보고57PASS·Flutter안내/409확정거절관련321PASS/변경분석0·사용자기기변경구간인수도완료했다. 활동해제후기존방데이터/정상이용유지·새생성/교체후보제외·다른활동캐릭터교체·그룹활동목록제외를확인했다. 기존막힌dev방복구는제외하며필수후속아니다. 진회색체크박스는별도테마문제로미수정이다. [Issue42 인수](https://github.com/heo0328/lostparty-backend/issues/42#issuecomment-6607158974).

## 로그 정리·Firebase 잔여 파일 조사

사용자지시로 workspace내Git미추적 .log911개/131474908bytes(약125.4MiB)를삭제하고잔여0개를확인했다. root·.dart_tool·android·build·coverage의생성로그만삭제했으며소스/DB/설정/레거시문서는삭제하지않았다. 원본로그는이제없으며핵심측정집계/검증결과·한계는DEV_LOG/Issue에남아있다. 새측정은필요한경우에만새로그를수집한다.

사용자 후속 지시로 실행미사용 Firebase 룰스 백업3개를 삭제했다(root firestore.rules-backup, legacy/firestore.before-complexity-20260831.rules.bak, legacy/firestore - 복사본.rules). 삭제전 미수정·workspace 내부 일반파일임을 검증하고 삭제후 잔여0을 확인했다. 현재pubspec/앱코드·Android빌드·CI/tool에서Firebase실행의존/룰스배포참조를찾지못했고firebase.json/.firebaserc/package.json도없다. root firestore.rules-backup 및 legacy의두rules백업은현행앱실행에불필요한로컬비교자료다. legacy/firebase의문서/실험텍스트는과거근거/출처기록이므로현행룰스와구분한다. firestore이름의Flutter시험은in-memory fake시험으로파일명만보고삭제하지않는다. 삭제범위는 위3파일뿐이며 legacy/firebase 출처문서/실험텍스트·Flutter fake시험과 인증설정은 유지했다. Firebase 외부서비스/데이터/게시Rules는 변경하지 않았다.

이번 통합에는 성능 계측/일괄 처리·기본2 확정, 활동선택 거절 보완/실기기 통과, 실행미사용 룰스 백업 삭제와 관련 문서를 포함한다. origin/dev·origin/main 최신 확인 후 의미별 커밋·일반 병합과 main fast-forward로 동일 커밋에 맞춘다. 강제push/태그/릴리즈는 만들지 않는다. 실제 최종 동일성은 dev/main/origin의 Git 커밋으로 확인한다. 기본개발은dev로컬/debug이며실기기설치·조작은사용자담당이다.

## 마감 검증과 다음 작업

최종 통합 상태의 전체 flutter test --no-pub 2817PASS, 변경 Dart36파일 포맷 변경0·diffcheck/변경 검토 완료. 전체 flutter analyze --no-pub 문제0을 확인했다. 실제 로컬 실기기 확인·반복측정과 모의/실서버 검증의 경계는 기존 기록 그대로다. 이번 main 정렬은 코드 통합이며 AWS 서버 배포나 새 APK 게시·운영 인수가 아니다. 향후 배포는 batch지원/예방수정의 실제 운영반영 상태와 맞춰 별도 지시로 진행한다.

현재 변경에 필수 구현은 남아 있지 않다. 진회색 비활성 체크박스 표시와 기존 기능별 보류/미확인은 [차후 수정안](../product/DETAIL_IMPROVEMENTS.md)에서 다음 작업으로 선택한다. 기존 review dev 방 복구는 제외 범위로 남은 필수 과제가 아니다. 작업 브랜치는 이력을 위해 보존하며 명시 삭제 지시 없이 삭제하지 않는다.

통합 코드 기준: 성능/계측95befe12, 활동선택 오류7ac83c30, 룰스백업 정리ce13f428. 코드·시험·계약 문서를 각 커밋에 포함했고 완료 이력/현재 상태·후속 대장은 문서 마감 커밋으로 함께 반영한다. dev/main/origin 동일성·push 결과는 최종 Git 확인으로 판정하며 소스 태그를 발행하지 않는다.

## 로컬 통합 결과·원격 보류

코드/문서 통합은 dev 일반병합25391208로 완료했고 main도 fast-forward로 같은 시점에 맞췄다. 최종 상태 기록 커밋도 세 로컬 브랜치에 같은 시점으로 반영한다. 미커밋 변경 없음·작업 브랜치 보존, 기능 트리는 검증한 최종 상태와 같다.

원격 feature/dev/main 일괄 push 명령은 자동 승인 검토가 “문서 커밋·로컬 dev/main 병합은 승인됐으나 명시되지 않은 원격 push/main 변경은 범위 초과”로 거절했다. 해당 명령은 실행되지 않았고 origin/dev f2620548·origin/main83bd5895는 그대로다. 우회 push는 하지 않으며 사용자의 명시 원격푸시 승인만 남았다. 자동 검토 거절을 사용자에게 별도로 알리고 승인 시 세 브랜치를 일반 push한 뒤 동일성/미커밋없음을 확인한다. 태그/운영/APK는 별도다.
