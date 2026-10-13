# 빈 데이터 신규 서버 구축·전환 계획

최신 정책은 [09](09-migration-decisions.md). 기존 사용자·데이터를 이관하지 않는다. 아래는 설계안이며 구현·배포·Firebase 삭제 승인으로 해석하지 않는다.

| 단계 | 작업 | 완료 게이트 |
|---|---|---|
| 0 정책·계약 입력 | 09~12와 기존 소스 00~06, 공개 scope·local 격리·제공자 등록 확인 | guest 무계정·신규 user·이관 없음·미결정 범위 명시 |
| 1 backend 설계 | 기능 module, identity/session·public read 모델, OpenAPI/WS 계약 원본 | endpoint/DTO/SQL/Alembic을 backend에서 확정, frontend는 승인 version 참조 |
| 2 첫 구현: 인증·공개 읽기 | 12 패키지, 제공자 1개 실제 통합·자체 token·빈 DB | guest row 없음, 동시 첫 로그인·Refresh/logout·private 거절·public field 검증 |
| 3 게임 소유권 | server challenge·외부 proof·Character/owner generation | client verified 위조·만료·재사용·소유 collision 거절, 새 소유 인증 |
| 4 핵심 명령 | 파티 생성·신청·참가, 필요한 그룹 자격·원자 집계 | 8인 동시성·마지막 자리·revision·dedup·타인 Character 거절 |
| 5 그룹·주간·회차 | 초대/code/block/승계·완료/반복/준비/전환·정리 | 50 한도·마지막 1인·주차/소유 generation·서버 원자성 |
| 6 event/WS·manual/operator | commit된 event·audience·replay·수동 증거/분쟁·권한/감사 | session/권한 회수·재연결·중복 event·operator 인가·retention |
| 7 frontend 전환 | guest bootstrap/소셜 로그인, REST/WS adapter·local namespace/old ID 격리 | 사용자 실기기 인수, 향후 Swift 공유 계약, 새 계정 환경 명시 |
| 8 신규 운영 전환 | Lightsail/Caddy·backup restore·최소 앱 version·서비스 설정 | 별도 배포 승인, 빈 production 시작, health/secret redaction·신규 가입/재인증 안내 |
| 9 구서비스 정리 | Firebase SDK/config/Rules 잔존 확인·FCM 예외 결정 | 구버전/구서비스 종료·기존 데이터 실제 삭제는 별도 승인. 이번 실행 없음 |

## 검증 원칙

pytest로 비인증, actor·role 위조, 타인 소유, 단계 실패, session/Refresh race, 동시 로그인, 8인 마지막 자리, 50인 그룹, 승계·마지막 1인, 주차 전환, 명령 재전송과 event audience를 검증한다. 새 DB에서 legacy Firestore claim/listing 호환을 구현하는 대신 기능 불변식을 테스트한다. 정상 UI는 사용자 실기기 인수로 확인한다.

명령 commit 후 socket 전송 실패가 재명령을 유발하지 않도록 persisted event와 replay를 설계한다. 실제 endpoint/message/table는 backend 명세가 원본이다. 구현 전에 제공자 등록·redirect, public 필드와 token/error 계약을 확정한다.

## 실행 제외와 다음 행동

기존 Firebase Auth/DB export/import, UID linking/recovery, 데이터 이관 리허설과 dual-write는 없다. Firebase 실제 삭제, Flutter 로컬 데이터의 파괴적 초기화와 production 배포도 이번에 하지 않는다. 신규 DB backup/restore·Alembic 개발은 별도 backend 작업이다.

다음은 12의 첫 backend 패키지 설계·준비다. 저장소 위치, 첫 제공자 등록값, public 필드와 token 정책을 입력으로 받아 backend가 최종 계약을 작성한다. 현재 문서 브랜치는 유지하며 이번에 새 chat/repo·Issues·commit/push/merge를 실행하지 않는다.
