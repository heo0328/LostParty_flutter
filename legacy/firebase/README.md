# 기존 Firebase 문서 보관

2026-10-13 사용자 지시로 기존 문서·항목을 분리했다. 신규 backend-migration13문서는 내용·위치 모두 제외했다. 앱/Rules/설정·운영 데이터/배포 변경 없음. 과거 자료를 자동 구현/배포 승인으로 읽지 않는다.

## 보관 규칙

- [이전 로컬 실험 원본](local-experiments-2026-10-30/README.md): 2026-10-30 미추적 Rules 실험 소스·백업의 선별 보관과 원본 해시. 현행 실행 도구가 아니다.

전용 문서는 docs 아래 원래 분류를 유지한다. 혼합 문서는 extracted 아래 원본 경로별로 모으고 각 원문의 파일·절·행·SHA를 기록한다. 로컬 Notion의 private 발췌는 기존 추적 제외 성격을 .gitignore로 유지한다. local 문서를 새로 공개하지 않는다.

## 이동 문서

| 원본 경로 | 보관 위치 | 원본 SHA256 |
|---|---|---|
| docs/architecture/BUG_022_REMAINING_FIX_DESIGN.md | [BUG_022_REMAINING_FIX_DESIGN.md](docs/architecture/BUG_022_REMAINING_FIX_DESIGN.md) | 81ade760e6ad89aadd4e1ed60f35bf5f56c568b02c4abd294fb2e2473763cc28 |
| docs/architecture/FIREBASE_PARTY_PRODUCT_FLOW.md | [FIREBASE_PARTY_PRODUCT_FLOW.md](docs/architecture/FIREBASE_PARTY_PRODUCT_FLOW.md) | a874e4b8fa1763098b7fb2010b186caca6237f0692282ba8cc65101a709be343 |
| docs/architecture/FIREBASE_PLAYER_BINDING_CONTRACT.md | [FIREBASE_PLAYER_BINDING_CONTRACT.md](docs/architecture/FIREBASE_PLAYER_BINDING_CONTRACT.md) | 2da5d89e0f502c069f4ebf5527e2d5ffca5d27a0467fdd818df6087879ad8682 |
| docs/architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md | [FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md](docs/architecture/FIRESTORE_GROUP_MEMBERSHIP_CONTRACT.md) | 4a008fb43396b335baad5e35c18909f61c2eafeccc9fa5da1067255c4de298a4 |
| docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md | [FIRESTORE_PARTY_COMMAND_CONTRACT.md](docs/architecture/FIRESTORE_PARTY_COMMAND_CONTRACT.md) | 80de8537d5c63a4bb625eb51f33c752c3ee01cce256c315fbe899d53e4068390 |
| docs/architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md | [FIRESTORE_PARTY_EVENT_CONTRACT.md](docs/architecture/FIRESTORE_PARTY_EVENT_CONTRACT.md) | 0e35f4212be9930a9810c80a1aa218146a7c3ace4bf6f75287e760edb994da45 |
| docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md | [FIRESTORE_PARTY_READ_MODEL_CONTRACT.md](docs/architecture/FIRESTORE_PARTY_READ_MODEL_CONTRACT.md) | b3afde5768e2d50cd1f4db093623c9121e4c3ba8e3533b7b218e9e84bffe5f5c |
| docs/architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md | [FIRESTORE_RULES_REDUCTION_DESIGN.md](docs/architecture/FIRESTORE_RULES_REDUCTION_DESIGN.md) | 22fa4f206ee615d381d634d4b2632a48c6d02d250e0ea179aef55c1d019578b1 |
| docs/architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md | [GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md](docs/architecture/GAME_ACCOUNT_CHARACTER_FIREBASE_CONTRACT.md) | 88403809994bb09533e6f8e035f3960b71c36948bdd8b3be40d5d8bf36a482b4 |
| docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md | [PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md](docs/architecture/PARTY_GROUP_COMMAND_SCALABILITY_REDESIGN.md) | 9e73343af4618670e42ab54f266c6feb75a6a38aa46d32caf761666bd5f5cca3 |
| docs/architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md | [PLAYER_FIREBASE_MIGRATION_REVIEW.md](docs/architecture/PLAYER_FIREBASE_MIGRATION_REVIEW.md) | b0a3b0f32444d6f4356a005aac7bc5c4787453a24a5b7193e32a66629afa2355 |
| docs/architecture/RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md | [RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md](docs/architecture/RECURRING_CYCLE_SERVER_TRANSACTION_DESIGN.md) | 1d5e23c854dd16e7c41f496c37e3c3d2a6f36c12901b9aab8e353ca6f75c498a |
| docs/architecture/RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md | [RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md](docs/architecture/RECURRING_CYCLE_SPARK_ALTERNATIVE_DESIGN.md) | f22527d45d95d7afa7a0f5afe74c83d2db51fbc62c1c001dbff15669ef3817fc |
| docs/architecture/RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md | [RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md](docs/architecture/RECURRING_NEXT_WEEK_CHARACTER_CHANGE_DESIGN.md) | 2ab0df2f63d5cf0d6ad3bc3f5179973641b16ba48a5f8224a6b9692584f2071c |
| docs/architecture/RULES_LOCALIZATION_EXECUTION_PLAN.md | [RULES_LOCALIZATION_EXECUTION_PLAN.md](docs/architecture/RULES_LOCALIZATION_EXECUTION_PLAN.md) | 4c1f7256cbe5b285320668d7fd85a21ea85a79217be85e0e8e635be9deca181a |
| docs/architecture/RULES_PRODUCTION_RESTRUCTURE_DESIGN.md | [RULES_PRODUCTION_RESTRUCTURE_DESIGN.md](docs/architecture/RULES_PRODUCTION_RESTRUCTURE_DESIGN.md) | d17181ba3ac330eb3404c4ad493ced0b8192f1d0fb4a17e87effda51d6eb2a1d |
| docs/architecture/RULES_SIMPLIFICATION_THREE_TRACK_DESIGN.md | [RULES_SIMPLIFICATION_THREE_TRACK_DESIGN.md](docs/architecture/RULES_SIMPLIFICATION_THREE_TRACK_DESIGN.md) | 97c6f4067e364af3168a1e18cc06dc546a2eb63e63a0fdecc20e2fe1e67938f0 |
| docs/architecture/TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md | [TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md](docs/architecture/TRUSTED_PARTY_JOIN_COMMAND_DESIGN.md) | dc7a31fff392a0951adcfed2e4bbd85f11e72e0d6cce20e9a950472d059a69fb |
| docs/integrations/FIREBASE_INITIAL_SETUP_REVIEW.md | [FIREBASE_INITIAL_SETUP_REVIEW.md](docs/integrations/FIREBASE_INITIAL_SETUP_REVIEW.md) | df61854c3ec04e7ee041da41281010485595cf568406aabfffc8fdaea995708a |
| docs/project/archive/ROSTER_REAUTH_2026-10-05_WORK_HISTORY.md | [ROSTER_REAUTH_2026-10-05_WORK_HISTORY.md](docs/project/archive/ROSTER_REAUTH_2026-10-05_WORK_HISTORY.md) | 278481294c127b3ac903c3ced3a57bd2dd2f32c583642213bf2247f9e32658c5 |
| docs/project/archive/RULES_REDUCTION_2026-10-09_WORK_HISTORY.md | [RULES_REDUCTION_2026-10-09_WORK_HISTORY.md](docs/project/archive/RULES_REDUCTION_2026-10-09_WORK_HISTORY.md) | 954f5f722b523ba5080bf7adb929d6604369d1ebec613f5374b2bbbd0c3e5b72 |
| docs/project/ROSTER_RULES_PUBLISH_DIAGNOSIS.md | [ROSTER_RULES_PUBLISH_DIAGNOSIS.md](docs/project/ROSTER_RULES_PUBLISH_DIAGNOSIS.md) | ec46f264be5f45e0de4ae1a605bea41ab73770131241943db0f32a1593d00475 |
| docs/project/RULES_AUDIT_INVENTORY.md | [RULES_AUDIT_INVENTORY.md](docs/project/RULES_AUDIT_INVENTORY.md) | f8a684029f975a2c7a18e753f6f9a00f03033cfebf10c34ce3b1a9508b54ec3e |
| docs/project/RULES_SCOPE_EXPERIMENT.md | [RULES_SCOPE_EXPERIMENT.md](docs/project/RULES_SCOPE_EXPERIMENT.md) | cacc49007ba5cc7d9351a35187a8b8e90a246029e1214ab3cfa26ab968262992 |
| docs/project/TASK-086-OPERATOR-WRITE-BLOCKER.md | [TASK-086-OPERATOR-WRITE-BLOCKER.md](docs/project/TASK-086-OPERATOR-WRITE-BLOCKER.md) | d3296c367250526b20a0082c565958b764103b895ee9e89b1d1251cb91f73fbe |
| docs/project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md | [TASK-11-FIRESTORE-RULES-COMPLEXITY.md](docs/project/TASK-11-FIRESTORE-RULES-COMPLEXITY.md) | 0305879a61c0de8b668611e164c641e3f52c41bb86b82d4e1ed87999b802bc6a |

## 혼합 문서별 출처

| 원본 문서 | 발췌 | 항목 수 |
|---|---|---|
| AGENTS.md | [원문·출처](extracted/AGENTS.md) | 3 |
| docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md | [원문·출처](extracted/docs/architecture/ACTIVITY_CHARACTER_AND_RAID_FILTER_CONTRACT.md) | 13 |
| docs/architecture/BACKEND_PARTY_ARCHITECTURE.md | [원문·출처](extracted/docs/architecture/BACKEND_PARTY_ARCHITECTURE.md) | 15 |
| docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md | [원문·출처](extracted/docs/architecture/CHARACTER_BUILD_INTEGRITY_CONTRACT.md) | 9 |
| docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md | [원문·출처](extracted/docs/architecture/CHARACTER_INTERACTION_AUTO_REFRESH_CONTRACT.md) | 14 |
| docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md | [원문·출처](extracted/docs/architecture/GAME_ACCOUNT_VERIFICATION_CONTRACT.md) | 5 |
| docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md | [원문·출처](extracted/docs/architecture/GITHUB_ANDROID_RELEASE_PIPELINE.md) | 10 |
| docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md | [원문·출처](extracted/docs/architecture/GROUP_LEADER_EXIT_DISBAND_CONTRACT.md) | 6 |
| docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md | [원문·출처](extracted/docs/architecture/OPERATOR_AUTHORIZATION_CONTRACT.md) | 18 |
| docs/architecture/PARTY_NOTIFICATION_CONTRACT.md | [원문·출처](extracted/docs/architecture/PARTY_NOTIFICATION_CONTRACT.md) | 19 |
| docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md | [원문·출처](extracted/docs/architecture/WEEKLY_RAID_CLAIM_CONTRACT.md) | 10 |
| docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md | [원문·출처](extracted/docs/design/LOSTPARTY_DESIGN_SYSTEM_V1_REQUEST.md) | 2 |
| docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md | [원문·출처](extracted/docs/feature-definitions/LOSTPARTY_CORE_USER_FLOW_OVERVIEW.md) | 11 |
| docs/feature-definitions/README.md | [원문·출처](extracted/docs/feature-definitions/README.md) | 2 |
| docs/notion/notion_command_center_source.md | [원문·출처](private/docs/notion/notion_command_center_source.md) | 44 |
| docs/product/BUILD_MEMO_SHARING.md | [원문·출처](extracted/docs/product/BUILD_MEMO_SHARING.md) | 6 |
| docs/product/CLASS_SYNERGY_CATALOG.md | [원문·출처](extracted/docs/product/CLASS_SYNERGY_CATALOG.md) | 3 |
| docs/product/DETAIL_IMPROVEMENTS.md | [원문·출처](extracted/docs/product/DETAIL_IMPROVEMENTS.md) | 10 |
| docs/product/GROUP_PRODUCT_FLOW.md | [원문·출처](extracted/docs/product/GROUP_PRODUCT_FLOW.md) | 11 |
| docs/product/PARTY_PARTICIPATION_RULES.md | [원문·출처](extracted/docs/product/PARTY_PARTICIPATION_RULES.md) | 6 |
| docs/project/AI_CONTEXT.md | [원문·출처](extracted/docs/project/AI_CONTEXT.md) | 11 |
| docs/project/ai_rules.md | [원문·출처](extracted/docs/project/ai_rules.md) | 10 |
| docs/project/BUG_REPORTS.md | [원문·출처](extracted/docs/project/BUG_REPORTS.md) | 22 |
| docs/project/DEV_LOG.md | [원문·출처](extracted/docs/project/DEV_LOG.md) | 539 |
| docs/project/NEXT_WORK.md | [원문·출처](extracted/docs/project/NEXT_WORK.md) | 4 |
| docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md | [원문·출처](extracted/docs/project/ROSTER_REAUTH_CHANGE_GUIDE.md) | 9 |
| docs/project/ROSTER_REAUTH_DEVICE_CHECKLIST.md | [원문·출처](extracted/docs/project/ROSTER_REAUTH_DEVICE_CHECKLIST.md) | 2 |
| docs/README.md | [원문·출처](extracted/docs/README.md) | 20 |

[전체 출처 대장](PROVENANCE.md)에 원본 절·행·hash를 기록했다. 이동 후 상대링크를 조정해 hash가 달라질 수 있다. 코드와 backend-migration은 별도 불변 검사를 한다. 이번 커밋/push/merge/배포 없음.

추가 정책/과거 실행 문맥 발췌는 extracted/additional 아래 원본 경로로 보관했다. [링크 정정 기록](LINK_REPAIRS.md)도 함께 확인한다.

## 최종 확인

전용26문서 본문은 이전 Git 기준과 대조해 출처 안내·상대링크 변경 외 의미 있는 차이 없음. 혼합문서 1차834항목과 추가8발췌(지침/옛 실행 문맥/문서지도)를 원문·출처와 보존했다. 상대파일링크·명시적 발췌앵커 누락0,코드펜스 짝 정상,private 추적제외 확인. backend-migration13파일·기존 비문서 추적887파일 SHA 불변,git diff --check 통과.
