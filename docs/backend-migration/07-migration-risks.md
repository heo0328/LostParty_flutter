# 신규 서버 전환 위험과 미확정 사항

최신 기준은 [09 신규 시작 정책](09-migration-decisions.md). 기존 Firebase 사용자·데이터는 이관하지 않는다. 초기 분석의 UID linking/recovery·schema census/import 위험은 실행 범위에서 제외하며 기존 소스 분석01~05는 보존한다.

## 계속 필요한 위험 관리

| ID | 현재 코드 근거/새 서버 위험 | 설계 대응·결정 |
|---|---|---|
| R02 | 익명 Auth/Player 생성이 기존 bootstrap 필수 | guest UID/회원 없이 공개 실행,식별 액션 알럿과 server deny. nullable session/Router는 frontend 별도 설계 |
| R03 | client 메모리 장비 challenge 후 소유권 기록 | server challenge·fresh evidence·single-use·기한 검증. 소셜 로그인과 game ownership 분리 |
| R04 | auth-only identity claim 등 넓은 Rules | allow를 복제하지 않고 새 actor/owner/role deny matrix 적용 |
| R05 | 소유권 이전이 기존 참가/완료와 충돌할 수 있음 | 기존 데이터를 가져오지는 않지만 새 서버의 미래 이전에도 generation/역사·정리 정책 필요 |
| R07 | room/member/state/group count/event가 결합 | command 단위 Transaction·revision/idempotency·DB 제약,partial effect 거절 |
| R08 | 여러 chunk/preflight/cleanup 단계 존재 | 새 서버에서 불필요한 Firebase 예산 workaround를 재현하지 않음. 증거 freshness·중도 실패/재진입은 검증 |
| R09 | 8인/50인/50그룹·role/자리 제한 | 동시 마지막 자리·중복 Character/raid·승계/해산 race를 pytest로 보장 |
| R10 | KST 수요일06시 주차·반복/준비/완료 | 서버 clock과 cycle 전이/target 정책,새 데이터의 미래 상태를 검증 |
| R11 | Timestamp/null/missing·client ID 규칙 | 신규 API 타입/UTC·timezone·ID·에러 계약을 backend에서 정의;legacy doc20자 제약 자동 복제 금지 |
| R12 | listing/count/summary 등 중복 표현 | authoritative 관계와 query projection 구분,새 DB에 모든 복사 컬렉션을 그대로 만들지 않음 |
| R13 | local Drift/읽음/build와 server IDs 혼합 | 기기 자료 삭제 미승인. 환경/principal 격리,old server ID를 신규 권한으로 인정하지 않음 |
| R14 | secure cleanup journal은 자동 재전송 후보 | old journal의 새 서버 replay 금지,보존/격리 정책. 새 journal은 actor+환경+명령 scope |
| R15 | event audience·local receipt·전체 get | 신규 event/WS audience·persist/replay·cursor/retention/읽음 정책 필요 |
| R16 | admin 조회가 legacy patch를 수행 | 새 DB에는 legacy patch 불필요. admin read와 승인·감사 mutation을 분리 |
| R17 | in-memory 상세·fixed clock·미연결 projection·invalidRequest adapter | 신규 기능 계약/actual Router 재정의. 가짜 상태를 API 완료 근거로 사용하지 않음 |
| R18 | dev와 중단 branch 정책/기능 차이 | baseline은dev e24baab,후속 branch 기능은 선택 사항. 자동 merge/채택 없음 |
| R19 | 구버전 Firestore client와 신규 API 데이터 세계 분리 | 최소 앱 버전·신규 가입/재인증 안내·endpoint 환경·구서비스 종료 순서 필요 |
| R20 | client 수동 승인/분쟁 만료 실행 | server 인가·증거·state 전이·감사와만료 책임 재설계 |
| R21 | server/name Character identity 충돌/변경 가능 | 신규 데이터에서도 rename/server 이전 정책,서버 identity verification 필요 |
| N01 | 잘못된 OAuth/client redirect·Refresh replay |11의 provider 검증·session revocation·race/retry 정책과테스트 |
| N02 | 단일 process WS hub 증설/재시작 | persisted event/replay,멀티worker 전 cross-process delivery 설계.10 참조 |

## 제외된 이관 작업

기존 Auth credential의 제공자 연결·기기 분실 사용자 복구, Player mapping·운영자 승계, Firestore/Auth export/import, legacy schema census·변환·대조, dual-write와 기존 데이터 세계로의 rollback을 제외한다. 기존 Firebase 자료를 삭제했다는 뜻은 아니다. 신규 DB backup/restore와 Alembic schema evolution은 별개로 필요하다.

## 남은 결정과 백엔드 확인

공개 Character 이름·그룹 요약 범위, 기존 local 계정/build/읽음 보존·격리 또는 삭제, Lost Ark API credential 방식, 신규 탈퇴/정지·세션/retention, 첫 제공자 등록·redirect, 첫 operator 부여, 구버전 종료·기존 Firebase 실제 삭제 시점이 남는다. [09 O01~O07](09-migration-decisions.md)의 결정표를 기준으로 중복 기록하지 않는다.

현재 운영 데이터·Auth·Rules 활성·비용/트래픽은 미조회다. 신규 DB 구현의 필수 export로 요구하지 않는다. 용량·RPO/RTO·S3/FCM 필요는 신규 운영 요구로 확인한다. 첫 구현의 입력·검증 게이트는 [12](12-first-backend-work-package.md)다.

확인된 미연결/비지원 소스는 유지한다. activity projection generator/reader는 save/Rules 연결이 없고, AtomicMembership.setApprovalPermission은 invalidRequest다. AtomicCreate의 비연결 주석은 실제 Router와 다르다. 새 서버에서 지원할지 결정하며 이번에 기존 코드를 수정하지 않는다.
