# 테스트 전환 분류 대장

기준: Flutter dev `7db7bde` (2026-10-14), 기존 테스트 218개. 이번 제거 원본은 이 커밋과 부모 `c984287`에 추적되어 있으며 Git에서 복구한다. skip/legacy 이동/분석 제외로 대체하지 않는다. 활성 기능·계약의 성공을 테스트 개수 감소로 판단하지 않는다.

## 처리와 책임

- 제거: 익명 Firebase 인증·AuthUid↔Player binding, Firestore Rules/Repository/경로·소스 문자열 계약과 기존 MyApp 전용 통합 테스트. 새 회원/세션은 `test/features/auth/`, 시작 화면은 `test/app/bootstrap/backend_loading_screen_test.dart`가 검증한다. MyApp의 그룹·서버 UI는 새 진입점에서 아직 제공하지 않으며 사용자 인수/후속 API 작업으로 분리한다.
- 유지: 로컬 DB·캐릭터·빌드·Lost Ark API·카탈로그·공통 정책/Validator/ViewModel 검증. 이름에 firestore가 있어도 실제 API 대신 fake repository로 제품 흐름을 검증하면 유지한다.
- 이식 대기: 유효한 정책과 Timestamp/레거시 저장 수명 결합이 남은 파일. 이번에는 제거하지 않고 실행을 유지한다. 신규 업무 계약이 정해지면 타입/서버 저장 경계를 분리하며 현재 Backend 업무 기능을 검증한다고 주장하지 않는다.
- Rules 원자성·권한·최대 8인·마지막 1인 해산·승계 정책은 기존 Domain/Validator 검증으로 보존한다. 실제 FastAPI 업무 권한/동시성은 후속 Backend API와 함께 pytest에서 검증해야 한다. 현재 인증 pytest는 업무 기능의 대체 검증이 아니다.

아래 책임은 각 파일의 import/검증 대상에 근거한다. 기본 보존 근거는 `7db7bde:<경로>`이며 제거 후에도 유효하다. 같은 파일의 공통 정책/로컬 검증은 유지한다. 제거한 소스 문자열 계약의 정책 행동 검증은 유지한 Validator/Write Plan 테스트로 이어지며 서버 구현 증거는 후속이다.

| 경로 | 분류 | 검증 책임·근거 | 계약/후속 | 처리 상태 |
|---|---|---|---|---|
| `test/app/bootstrap/anonymous_auth_initializer_test.dart` | 제거 | 폐기 익명 인증·AuthUid/Player 모델; 신규 auth 경계로 대체 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/app/bootstrap/app_bootstrap_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/bootstrap/app_bootstrap.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/app/bootstrap/backend_loading_screen_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/backend_app.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/app/bootstrap/lost_party_entry_screen_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/bootstrap/lost_party_entry_screen.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/app/router/app_router_cycle_runtime_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/app/shell/app_shell_dispute_alert_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/shell/app_shell.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/app/theme/app_theme_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/theme/app_colors.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/activity_characters_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/data/datasources/lost_ark_character_remote_data_source_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/datasources/lost_ark_character_remote_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/gateways/firestore_character_minimum_display_sync_gateway_test.dart` | 제거 | 폐기 Firestore 저장 adapter: lib/features/account/data/gateways/firestore_character_minimum_display_sync_gateway.dart | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/data/gateways/local_game_account_verification_gateway_test.dart` | 이식 대기(실행 유지) | 공통/로컬 정책과 레거시 타입 결합: lib/features/account/data/datasources/lost_ark_character_remote_data_source.dart | 업무 DTO·저장 계약 확정 후 분리 | 보존·skip 없음 |
| `test/features/account/data/local/account_database_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/local/party_notification_receipt_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/activity_characters_firebase_mapper_test.dart` | 제거 | 폐기 Firestore 저장 adapter: lib/features/account/data/mappers/activity_characters_firebase_mapper.dart | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/data/mappers/character_activity_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/mappers/character_activity_write_plan.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/character_build_analysis_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/mappers/character_build_analysis_mapper.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/character_profile_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/dtos/character_profile_dto.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/sibling_character_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/dtos/sibling_character_dto.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/weekly_raid_claim_document_id_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/mappers/weekly_raid_claim_document_id.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/mappers/weekly_raid_claim_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/dtos/weekly_raid_claim_dto.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/ownership_record_stream_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/repositories/ownership_record_stream.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/repositories/account_repository_impl_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/datasources/local_account_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/data/repositories/firestore_activity_characters_repository_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/data/repositories/firestore_weekly_raid_claim_repository_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/data/weekly_raid_status_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/account/domain/completed_cleanup_recovery_test.dart` | 이식 대기(실행 유지) | 공통/로컬 정책과 레거시 타입 결합: lib/features/recruitment_list/data/repositories/completed_cleanup_journal.dart | 업무 DTO·저장 계약 확정 후 분리 | 보존·skip 없음 |
| `test/features/account/domain/completed_ownership_cleanup_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/completed_ownership_cleanup.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/entities/character_build_analysis_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/entities/local_game_account_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/game_account_ownership_snapshot_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/game_account_ownership_snapshot.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/game_account_ownership_transition_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/game_account_ownership_transition.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/policies/activity_characters_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/owned_activity_character.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/account_identity_sync_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/build_integrity_snapshot_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/character_auto_refresh_coordinator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_auto_refresh_result.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/character_build_role_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_role.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/character_minimum_display_sync_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/character_summary_sync_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_draft.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/character_usage_level_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/services/character_usage_level_policy.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/gem_validation_snapshot_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/nice_group_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/representative_character_sync_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/startup_character_refresh_eligibility_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/startup_character_refresh_orchestrator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_auto_refresh_result.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/weekly_raid_display_projector_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_weekly_raid_display_preference.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/services/weekly_raid_status_projector_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/weekly_raid_status_projection.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/domain/weekly_raid_command_observation_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/weekly_raid_claim_command.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/pages/character_detail_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/pages/character_management_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/theme/app_theme.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/pages/game_account_verification_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/game_account_verification.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/pages/my_account_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_snapshot.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/viewmodels/character_detail_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/viewmodels/character_management_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_snapshot.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/viewmodels/my_account_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_snapshot.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/viewmodels/my_account_weekly_raid_claim_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/fakes/in_memory_character_weekly_raid_display_repository.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/account/presentation/widgets/account_character_card_weekly_claim_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/auth/android_google_authentication_gateway_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/auth/data/android_google_authentication_gateway.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/auth/auth_session_controller_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/auth/domain/auth_repository.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/auth/backend_auth_api_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/backend_app.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/auth/login_navigation_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/auth/domain/auth_session_controller.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/features/group/data/group_combat_power_sync_test.dart` | 제거 | 폐기 Firestore 저장 adapter: lib/features/account/data/gateways/firestore_character_combat_power_sync_gateway.dart | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/group/data/group_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/group/data/mappers/group_active_recruitment_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_active_recruitment_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_application_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_application_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_create_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_create_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_document_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_document_mapper.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_join_code_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_join_code_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_join_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_join_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_leader_exit_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_leader_exit_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_leave_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_leave_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_member_snapshot_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_member_snapshot_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/mappers/group_member_write_fields_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/mappers/group_member_write_fields.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/data/repositories/firestore_group_character_search_repository_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/group/domain/entities/group_join_code_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/entities/group_join_code.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_create_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/entities/group_create_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_disband_active_raid_check_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/services/group_disband_active_raid_check.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_join_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/entities/group_join_code_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_local_member_display_lookup_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_member_display_builder_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/entities/group_member.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/domain/services/group_name_normalizer_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/services/group_name_normalizer.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/presentation/group_character_options_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/presentation/group_create_account_mismatch_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/presentation/group_failure_messages_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/data/repositories/group_command_runner.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/presentation/group_join_code_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/group/domain/entities/group_join_code.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/group/presentation/group_member_display_flow_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_snapshot.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/manual_verification/domain/manual_verification_account_scope_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/manual_verification/domain/entities/manual_verification_request.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/manual_verification/domain/manual_verification_code_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/manual_verification/domain/manual_verification_code.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/manual_verification/domain/manual_verification_request_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/manual_verification/domain/entities/manual_verification_request.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/manual_verification/presentation/manual_verification_pages_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_summary.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/operator_access/data/operator_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/operator_access/domain/operator_user_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/operator_access/domain/entities/operator_user.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/operator_access/presentation/operator_user_pages_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/operator_access/domain/entities/operator_user.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/player/data/repositories/player_binding_repository_impl_test.dart` | 제거 | 폐기 익명 인증·AuthUid/Player 모델; 신규 auth 경계로 대체 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/player/domain/entities/player_session_test.dart` | 제거 | 폐기 익명 인증·AuthUid/Player 모델; 신규 auth 경계로 대체 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/raid_status/data/services/party_event_sync_type_boundary_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_event.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/repositories/party_event_read_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/repositories/party_event_read_repository.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/services/active_raid_cycle_visibility_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/services/active_raid_cycle_visibility_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/services/filtered_page_session_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/services/filtered_page_session.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/services/raid_list_sort_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/entities/raid_list_sort_selection.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/services/raid_status_filter_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/entities/raid_status_filter_selection.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/domain/throttled_party_event_sync_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/domain/services/party_event_sync_service.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/active_raid_filter_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/save_activity_characters_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/party_notification_message_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/presentation/party_notification_message.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/party_notification_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/party_read_detail_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/party_read_detail_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/presentation/viewmodels/party_read_detail_view_model.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/party_read_stream_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/presentation/viewmodels/party_read_stream_view_model.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/raid_history_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/raid_status/presentation/raid_status_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/data/local/account_database.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/fakes/fake_recruitment_runtime_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/fakes/in_memory_active_raid_assignment_repository.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/fakes/in_memory_recruitment_state_repository.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/fakes/in_memory_weekly_raid_clear_repository.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/lazy_cycle_reconciliation_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/mappers/party_application_event_writer_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_event_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_application_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_application_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_application_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_application_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_document_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_document_mapper.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_lifecycle_marker_patch.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_member_mutation_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_member_removal_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_raid_listing_document.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_membership_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_membership_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_atomic_visibility_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_atomic_write_plan_test.dart` | 이식 대기(실행 유지) | 공통/로컬 정책과 레거시 타입 결합: lib/features/recruitment_list/data/mappers/party_raid_listing_document.dart | 업무 DTO·저장 계약 확정 후 분리 | 보존·skip 없음 |
| `test/features/recruitment_list/data/mappers/party_complete_claim_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_complete_claim_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_create_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_create_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_cycle_assignment_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_cycle_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_cycle_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_event_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_event_mapper.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_event_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_event_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_join_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_join_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_lifecycle_event_writer_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_event_mapper.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_membership_event_writer_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_event_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_membership_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_membership_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_raid_listing_document_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_raid_listing_document.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_raid_listing_sync_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_raid_listing_sync.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_read_document_mapper_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/dto/party_read_document_dto.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/party_visibility_write_plan_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/mappers/party_visibility_write_plan.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/data/mappers/raid_state_availability_test.dart` | 이식 대기(실행 유지) | 공통/로컬 정책과 레거시 타입 결합: lib/features/account/domain/game_account_ownership_snapshot.dart | 업무 DTO·저장 계약 확정 후 분리 | 보존·skip 없음 |
| `test/features/recruitment_list/data/party_atomic_lifecycle_marker_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_c_cutover_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_f6_incomplete_end_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r1_scaffold_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r2_lifecycle_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r3_group_count_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r3_personal_completion_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r4_create_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r5_membership_create_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r6_membership_update_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_atomic_rules_r7_legacy_prune_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_disband_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_gem_validation_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_group_audience_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_group_cutover_rules_baseline_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_raid_listing_backfill_batch_test.dart` | 제거 | 폐기 Firestore 저장 adapter: lib/features/recruitment_list/data/repositories/party_raid_listing_backfill_batch.dart | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_scalability_proof_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/party_slot_ledger_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/repositories/firestore_active_raid_assignment_lookup_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/repositories/firestore_party_atomic_command_repository_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/repositories/firestore_party_atomic_member_removal_repository_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/repositories/firestore_party_atomic_membership_repositories_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/data/repositories/firestore_party_atomic_visibility_and_group_disband_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/domain/entities/party_atomic_command_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_atomic_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/entities/party_event_rules_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/features/recruitment_list/domain/entities/party_slot_board_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_read_models.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/party_ownership_record_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/game_account_ownership_snapshot.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/approval_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/policies/approval_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/minimum_combat_power_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/policies/minimum_combat_power_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/participation_conflict_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/active_raid_assignment.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/party_composition_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_recruitment.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/party_cycle_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/policies/party_cycle_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/recruitment_auto_title_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_recruitment.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/policies/weekly_raid_reset_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/policies/weekly_raid_reset_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/existing_raid_state_occupancy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/services/party_create_occupancy_gate.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/group_raid_qualification_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/services/group_raid_qualification.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/lazy_cycle_reconciler_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/services/lazy_cycle_reconciler.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/legacy_ended_assignment_replacement_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/services/legacy_ended_assignment_replacement_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_application_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_application_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_create_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_create_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_create_occupancy_gate_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/services/party_create_occupancy_gate.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_cycle_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_cycle_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_cycle_runtime_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/policies/party_cycle_policy.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_join_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_join_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/party_membership_command_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_membership_command.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/raid_activity_character_candidate_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/recruitment_application_candidate_composition_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/recruitment_application_candidate_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/recruitment_command_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/fakes/fake_recruitment_runtime.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/services/recruitment_leader_candidate_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/domain/state/recruitment_state_machine_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_recruitment.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/local_recruitment_card_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/app/theme/app_theme.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/models/candidate_build_display_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_recruitment.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/models/recruitment_form_draft_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/presentation/models/recruitment_form_draft.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/public_recruitment_list_view_model_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/raid_status/data/repositories/drift_raid_status_filter_store.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/recruitment_create_firestore_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/recruitment_create_flow_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/local_game_account.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/recruitment_form_layout_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/account/domain/entities/character_build_analysis.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/features/recruitment_list/presentation/recruitment_list_page_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/domain/entities/party_read_models.dart | 현재 Flutter 정책 검증; 신규 서버 계약 적용 여부 별도 | 보존·실행 유지 |
| `test/firestore_rules_warning_contract_test.dart` | 제거 | 폐기 Firestore/기존 Router 소스 계약; 행동 정책은 공통 검증에 보존 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |
| `test/local_recruitment_list_data_source_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/raid_master_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/raid_master/data/repositories/raid_master_repository_impl.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/recruitment_card_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/recruitment_list_repository_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/features/recruitment_list/data/datasources/local_recruitment_list_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/character_build/character_optional_display_preservation_test.dart` | 이식 대기(실행 유지) | 공통/로컬 정책과 레거시 타입 결합: lib/shared/character_build/character_optional_display_preservation.dart | 업무 DTO·저장 계약 확정 후 분리 | 보존·skip 없음 |
| `test/shared/formatters/display_number_formatter_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/formatters/display_number_formatter.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/formatters/korea_time_formatter_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/formatters/korea_time_formatter.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/game_catalog/data/class_synergy_catalog_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/game_catalog/data/catalogs/class_synergy_catalog.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/game_catalog/data/game_catalog_repository_impl_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/game_catalog/data/datasources/asset_game_catalog_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/game_catalog/domain/game_catalog_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/game_catalog/domain/entities/game_catalog.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/game_catalog/domain/services/class_synergy_service_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/game_catalog/domain/entities/class_synergy.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/lost_ark_api/auth/api_token_store_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/lost_ark_api/auth/api_token.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/lost_ark_api/client/lost_ark_api_client_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/lost_ark_api/auth/api_token.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/raid_catalog/data/raid_catalog_repository_impl_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/raid_catalog/data/datasources/asset_raid_catalog_data_source.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/raid_catalog/domain/raid_catalog_validator_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/raid_catalog/domain/entities/raid_catalog.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/raid_catalog/domain/raid_eligibility_policy_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/raid_catalog/domain/entities/raid_catalog.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/shared/widgets/clearable_text_form_field_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/widgets/clearable_text_form_field.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/tool/lost_ark_gem_probe_test.dart` | 유지 | 로컬·공통·신규 인증 검증: lib/shared/game_catalog/data/mappers/game_catalog_mapper.dart | 현재 로컬/인증 계약 | 보존·실행 유지 |
| `test/widget_test.dart` | 제거 | 폐기 MyApp/Player 기반 경로; BackendApp 로딩·auth 탐색 검증 유지 | 신규 서버 업무 인가·저장 검증은 후속 Backend 계약 | 제거 완료; 원본 7db7bde |

## CI·보조 파일·Node 실행 경로

| 대상 | 처리 | 근거·보존 |
|---|---|---|
| `.github/workflows/party-group-cutover-rules.yml` | 제거 | Firestore Emulator/Rules만 검증, 원본 7db7bde |
| `.github/workflows/party-join-v3-proof.yml` | 제거 | 폐기 Rules proof만 실행, 원본 7db7bde |
| `.github/workflows/party-scalability-proof.yml` | 제거 | 폐기 Rules proof만 실행, 원본 7db7bde |
| `.github/workflows/android-apk-release.yml` | 유지 | 별도 빌드·서명·릴리즈 흐름; 이번 배포 없음 |
| `test/support/firestore_transaction_fake.dart` | 제거 | 사용한 3개 Firestore adapter 테스트 제거 후 사용처 없음 |
| `test/support/party_read_fakes.dart` | 유지 | 공통 목록·필터·UI 테스트에서 사용 |
| test fixture와 로컬 catalog JSON | 유지 | AccountRepository/빌드/공통 정책 테스트가 사용 |
| 미추적 Rules 실험·백업 | 보존 | 이번 작업 전 사용자/이전 작업 산출물, Git 이력 없음; 임의 삭제 금지 |

기본 `flutter test`는 test 디렉터리의 남은 파일을 모두 실행한다. tools/package.json에는 기본 test script가 없고 Node/Rules 실행은 기존 workflow 또는 수동 명령이었다. 3개 전용 workflow 제거로 활성 CI 연결을 종료한다. 추적된 tools 파일은 아래 대장처럼 보존한다. 과거 실험과 공유 import가 얽혀 있어 이번에는 도구·SDK 전체 제거를 확대하지 않는다. 아래 수동 Node 테스트/증명 파일은 신규 서버 검증 명령이 아니며 현재 실행·배포에 사용하지 않는다. 해당 파일의 보조 모듈·proof.rules·firebase 설정·package/lock도 동일 의존성으로 보존한다. 도구 최종 제거는 Firebase 소스·SDK 정리 구간에 인계한다.

| 추적 도구 경로 | 분류 | 근거/후속 |
|---|---|---|
| `tools/assert_rules_denied.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_advance_budget_diagnosis.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_preparation_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_regression_runner.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_runtime_regression_runner.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_spark_feasibility_runner.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_spark_preparation_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_spark_seal_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/bug024_spark_seal_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/character_activity_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/compact_rules_source.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/fixtures/roster_reauth_preintegration.rules` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/gen_removed_group_id_rules.js` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/group_leave_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/integrate_roster_rules.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/manual_verification_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/package-lock.json` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/package.json` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_completion_role_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_group_cutover_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_join_v3_firebase.json` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_join_v3_proof.rules` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_join_v3_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_scalability_firebase.json` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_scalability_proof.rules` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/party_scalability_rules_test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/patch_group_leave_rules.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/prune_r7_unused_rules_functions.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/removed_active_group_id.rules.txt` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_completed_cleanup_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_completed_cleanup_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_complexity_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_complexity_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_complexity_differential.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_dispatch_rules_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_generation_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_generation_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_last_member_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_last_member_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_leader_cleanup_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_leader_cleanup_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_legacy_rules_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_legacy_rules_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_lifecycle_boundary_diagnosis.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_lifecycle_coverage_summary.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_lifecycle_predicate_diagnosis.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_manual_completion_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_manual_completion_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_occupancy_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_occupancy_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_orphan_cleanup_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_orphan_cleanup_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_ownership_rules_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_participation_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_participation_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_peer_cleanup_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_peer_cleanup_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_personal_completion_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_personal_completion_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_personal_dedup.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_personal_differential.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_position_differential.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/roster_target_rules_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_advance_shared.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_audit_cause.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_auth_direct.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_auth_direct_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_availability_runtime.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_baseline_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_call_depth_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_cleanup_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_cleanup_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_cleanup_design_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_cleanup_diagnosis.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_cleanup_event_design_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_completion_role.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_completion_role.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_contract_size_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_depth_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_depth_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_depth_recheck_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_depth_recheck_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_executable_compact.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_executable_compact.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_group_count_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_group_display_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_group_display_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_group_display_contract.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_group_update_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_indent.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_leader_budget_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_leader_budget_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_leader_budget_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_legacy_size_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_listing_boundary_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_listing_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_listing_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_listing_safety_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_local_display.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_local_display_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_localization_pipeline.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_member_retirement_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_member_retirement_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_member_retirement_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_next_week_preparation.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_personal_budget_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_personal_budget_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_prep_dedup.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_prep_dedup_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_production_restructure.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_production_restructure_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_publication_budget.json` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_publication_preflight.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_removal_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_removal_proof.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_removal_rejection_audit.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_removal_rejection_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_removal_rejection_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_scope_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_scope_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_seal_direct.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_strip_comments.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_target_scan_candidate.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |
| `tools/rules_target_scan_candidate.test.mjs` | 보존·실행 종료 | 폐기 Rules 도구 의존성·과거 근거; 신규 서버 검증 아님, 최종 제거 후속 |


## 신규 검증과 보조 자료

- `test/features/auth/auth_session_store_test.dart`: 신규 유지. 서버 scheme/host/port별 세션 격리·한 origin 삭제의 독립성, 같은 origin 새 인스턴스의 읽기, Backend 세션 교체/삭제 시 Lost Ark API 키 보존을 실제 secure-storage adapter의 mock 저장소로 검증한다. 기기 KeyStore 정상 동작은 사용자 인수다.
- 남은 `test/support/party_read_fakes.dart`와 fixture 자료는 제품 정책·로컬 데이터 테스트에 계속 사용한다. 아래 추적 fixture는 삭제하지 않는다.

| 보조 자료 | 처리/소유 |
|---|---|
| `test/fixtures/lost_ark/character_armory_full.json` | 유지 · 기존 테스트/fixture |
| `test/fixtures/lost_ark/support_hybrid_builds_user_reference.json` | 유지 · 기존 테스트/fixture |
| `test/support/party_read_fakes.dart` | 유지 · 기존 테스트/fixture |

## 2026-10-14 유지 테스트 안정화 정정

- 알림/레이드 테스트4파일은 유지한다. 직접 DB 조회는 기존 now 인자로 고정시각을 지정하고 UI/ViewModel에는 새 `test/support/fixed_clock_account_database.dart`가 실제 메모리 DB query의 cutoff만 고정한다. 기본2026-09-10으로 fixture 발생 뒤·만료 전이며 명시적인 now는 그대로 사용한다. 실제 만료 제외/수신자·방·읽음 정책을 보존한다.
- `party_read_detail_page_test.dart`의 동일 캐릭터 반대 역할 항목은 현재 writer의 미지원 후보 제외·무명령 전송과 다른 캐릭터 후보 허용을 검증하도록 정합화했다. 제품 문서의 역할 변경 요구를 삭제하거나 지원 완료로 선언하지 않는다. `party_atomic_member_mutation_write_plan_test.dart`도 같은 state ID를 거절하는 현재 구현을 검증하고 있다. 신규 서버의 동일 state 원자 update는 후속 계약 항목이다.
- 테스트2경고는 불필요 import/null-aware 연산만 정리한다. 분석의 coverage 과거소스 사본은 .gitignore에 이미 제외된 생성물이라 coverage/** 분석 제외를 명시하고 lib/test/tool은 검증에 유지한다.
- 폐기 예정 Firestore adapter4파일의49개 중괄호 lint만 수정했다. 중괄호·공백을 제외한 원본과 변경본의 모든 문자가 동일함을 확인해 분기/반환/쓰기 순서를 보존한다. 이 lint 정리는 Firebase 제거 완료를 의미하지 않는다.
- 미추적 `tools/roster_rebalance_domain_fixtures.dart`의3개 lint는 이전 산출물을 수정하지 않고 전체 분석 결과에 명시한다. tools 전체를 분석에서 제외하지 않는다.
