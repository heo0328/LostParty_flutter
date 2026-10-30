# 이전 로컬 Firebase 실험 원본

2026-10-30 사용자가 미커밋 자료 전체의 선별 보관·불필요 임시 자료 정리를 요청해 보관했다. tools의 미추적 실험 소스34개와 루트 Rules 백업2개를 바이트 변경 없이 이동했다. 원래 경로·현재 파일·SHA256은 source-map.json에 기록했으며 이동 전후 해시 일치를 확인했다.

현재 Python Backend의 실행 도구나 통과한 검증 묶음이 아니다. Firebase Rules 후보 생성·에뮬레이터 경계 실험이며 assert_rules_denied.mjs, rules_executable_compact.mjs 등 일부 과거 의존 파일과 coverage 생성물을 요구한다. 당시 앱 정책을 호출하는 Dart fixture도 이 실험 입력용이다. 재현에 필요한 전체 환경을 보관한 것으로 주장하지 않는다.

현재 분석·실행 대상과 혼동하지 않도록 원래 이름 뒤에 .txt를 붙였다. 실제 내용은 수정하지 않았다. 기존 서비스 제약과 과거 의사결정 조사에만 사용하며 배포/실행 지시로 재사용하지 않는다. 루트의 빈 devtools_options.yaml과 tools의 과거 로그·node_modules는 불필요한 로컬 생성물로 삭제했다. 민감 키의 대표 패턴을 확인했고 일치 항목은 없었다.
