# 함수 범위 배치 비교 — 2026-10-05

원본 cd04e69e:223114bytes → 최종 e7aeb309:223488bytes. 함수274/match34/allow118 유지.
187함수를 최소 공통 match로 이동,87함수 전역 유지. 본문/인자/allow/경로/평가 순서 동일.
호출자 scope 고정점 검사, wildcard 자유변수 capture 이동 제외. 호출 깊이6/재귀0/미도달0.

## 활성화 없는 서버 검사

요청: https://firebaserules.googleapis.com/v1/projects/lost-party:test

| 비교 | 기준본 | 배치본7a3a9158 |
|---|---|---|
| 최초 |503/7212ms|200/5100ms, body {}|
| 재현 |503/7292ms|200/4925ms, body {}|

실패 본문: `{"error":{"code":503,"message":"The service is currently unavailable.","status":"UNAVAILABLE"}}`.
배치 최초본224236bytes에서 이동 자리의 빈 행 공백만 제거한 최종본223488bytes.
기준본은 test 실패, Ruleset/Release 미도달. 과거3b0f492b는 test/Ruleset 성공 후 Release503이었다.
배치가 실패에 영향을 준다는 비교 근거를 확보했지만 서버 내부 크기/특정250KB 초과는 미확인이다.

## 분할본과 이전 근거

사용자 성공 보고만 있으며 당시 성공 요청본문/소요시간은 확보되지 않았다.
분할1: 함수150/match9(루트 포함), 수동인증요청·partyEvents·recruitments와 하위 경로.
분할2: 함수165/match26, auth/player/계정·캐릭터·groups·joinCode 및 collection-group 신청.
현재 raw117135/117188bytes는 CRLF 포함이며 과거 LF manifest114750/114389와 구분한다.
함수·match 전체 목록과 SHA는 coverage/rules-scope/*-inventory.json, 과거 분할 구성은
coverage/rules-publish-isolation/split-manifest.json. 기존 실패 로그는 ROSTER_RULES_PUBLISH_DIAGNOSIS 참조.

## 검증 범위

정적 배치3건/Flutter 계약3건 통과. 기준본 CI37211831330 결과 재사용.
배치본 CI37215585491 제한 검증: 최대8 정리/승계/주차전환·위조/부분쓰기·개인완료·그룹 보호.
전체 제품 조합/실기기 검증으로 확대하지 않는다. 최종 활성화 결과는 DEV_LOG에 별도 기록한다.

## 변경 행과 이유

모두 함수 본문 수정 없는 최소 공통 scope 이동이다. 공유 함수는 호출자보다 아래로 이동하지 않는다.

| 함수 | 원본 행 | 최종 행 | 목적 scope |
|---|---:|---:|---|
| `validActiveBinding` | 3598 | 1346 | `/databases/{database}/documents/authBindings/{authUid}` |
| `validAtomicStaleRaidStateRecruitment` | 2971 | 1380 | `/databases/{database}/documents/players/{playerId}` |
| `validActivePlayer` | 3614 | 1391 | `/databases/{database}/documents/players/{playerId}` |
| `validPlayerLastSeenUpdate` | 3629 | 1406 | `/databases/{database}/documents/players/{playerId}` |
| `validLegacyLastSeenBackfill` | 3637 | 1414 | `/databases/{database}/documents/players/{playerId}` |
| `validLegacyAssignmentConsumedByPersonalCompletion` | 2061 | 1441 | `/databases/{database}/documents/players/{playerId}/activeRaidAssignments/{assignmentId}` |
| `validLegacyStaleAssignmentDelete` | 2084 | 1464 | `/databases/{database}/documents/players/{playerId}/activeRaidAssignments/{assignmentId}` |
| `validEventTiming` | 3295 | 1500 | `/databases/{database}/documents/players/{playerId}/events/{eventId}` |
| `validManualVerificationDisputeEvent` | 3306 | 1506 | `/databases/{database}/documents/players/{playerId}/events/{eventId}` |
| `validMembershipStateAdd` | 326 | 1550 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validMembershipStateAddMember` | 351 | 1575 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validMembershipStateDocumentKeys` | 438 | 1596 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `removedActiveGroupId` | 676 | 1603 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validMembershipStateRemove` | 790 | 1608 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validRemovedMembershipState` | 812 | 1630 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validLeaderApprovedMembershipStateAdd` | 1012 | 1637 | `/databases/{database}/documents/players/{playerId}/groupMembershipState/{docId}` |
| `validInitialMemberGroupRelation` | 372 | 1713 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validGroupMemberLeaveRelationDelete` | 819 | 1738 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validGroupDisbandRelationDelete` | 828 | 1747 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validGroupRelationProjectionKeys` | 849 | 1757 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validGroupRequestRelation` | 859 | 1765 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validAcceptedGroupRelation` | 881 | 1786 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validLeaderApprovedGroupRelation` | 1044 | 1812 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validJoinCodeMemberGroupRelation` | 1259 | 1836 | `/databases/{database}/documents/players/{playerId}/groupRelations/{groupId}` |
| `validManualWeeklyRaidClaimCreate` | 3466 | 1896 | `/databases/{database}/documents/players/{playerId}/weeklyRaidClaims/{claimId}` |
| `validManualWeeklyRaidClaimDelete` | 3504 | 1934 | `/databases/{database}/documents/players/{playerId}/weeklyRaidClaims/{claimId}` |
| `atomicCommandIncludes` | 1568 | 1973 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `atomicAdvanceStateMatchesSlot` | 1583 | 1980 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicAdvanceRaidStateCreate` | 1611 | 1991 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicRaidStateUpdate` | 1636 | 2016 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicRaidStateDelete` | 1670 | 2050 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicRaidStateCreate` | 1951 | 2058 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validManualRaidStateCreate` | 1984 | 2091 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validPersonalRaidStateCompletion` | 2021 | 2128 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validPersonalCompletedRaidStateDelete` | 2053 | 2160 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicMembershipRaidStateDelete` | 2942 | 2168 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `validAtomicStaleRaidStateDelete` | 2954 | 2180 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `deManualAssignmentAvailable` | 4385 | 2195 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `deReplacePriorState` | 4419 | 2201 | `/databases/{database}/documents/players/{playerId}/raidStates/{stateId}` |
| `playerGameAccountPath` | 3704 | 2263 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `characterActivityPath` | 3708 | 2267 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `ownedActiveCharacterMatches` | 3712 | 2271 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `ownedActiveGameAccount` | 3720 | 2279 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `representativeActivityCovered` | 3728 | 2287 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `validCharacterActivityWrite` | 3741 | 2300 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `validCharacterActivityDelete` | 3764 | 2323 | `/databases/{database}/documents/players/{playerId}/characterActivity/{characterId}` |
| `validManualVerificationCode` | 4023 | 2397 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `manualVerificationAccountOwnedBy` | 4028 | 2402 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `manualVerificationRequesterAlreadyOwns` | 4038 | 2412 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationCreate` | 4056 | 2430 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `manualVerificationOperatorContextUnchanged` | 4091 | 2465 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationOperatorReviewBody` | 4096 | 2470 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationDisputeOpenBody` | 4137 | 2511 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationDisputeDefendedBody` | 4159 | 2533 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationOperatorForceBody` | 4172 | 2546 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationOperatorWrite` | 4191 | 2565 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `unchangedManualVerificationIdentity` | 4206 | 2580 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationRequesterCancel` | 4216 | 2590 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationReissue` | 4230 | 2604 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationDefenseApprove` | 4249 | 2623 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationDisputeTransfer` | 4263 | 2637 | `/databases/{database}/documents/manualVerificationRequests/{requestId}` |
| `validManualVerificationBlockWrite` | 4276 | 2676 | `/databases/{database}/documents/manualVerificationBlocks/{blockId}` |
| `canGetManualVerificationBlock` | 4293 | 2693 | `/databases/{database}/documents/manualVerificationBlocks/{blockId}` |
| `deGenerationUpdate` | 4459 | 2803 | `/databases/{database}/documents/gameAccounts/{gameAccountId}` |
| `deCharacterGeneration` | 4467 | 2819 | `/databases/{database}/documents/characters/{characterId}` |
| `changesRepresentativeCharacter` | 3644 | 2841 | `/databases/{database}/documents/playerGameAccounts/{ownershipId}` |
| `representativeCharacterOwned` | 3651 | 2848 | `/databases/{database}/documents/playerGameAccounts/{ownershipId}` |
| `oldRepresentativeCharacterId` | 3660 | 2857 | `/databases/{database}/documents/playerGameAccounts/{ownershipId}` |
| `validRepresentativeCharacterSeed` | 3666 | 2863 | `/databases/{database}/documents/playerGameAccounts/{ownershipId}` |
| `validRepresentativeCharacterUpdate` | 3681 | 2878 | `/databases/{database}/documents/playerGameAccounts/{ownershipId}` |
| `deLeaderCleanupEventCreate` | 2398 | 2923 | `/databases/{database}/documents/partyEvents/{eventId}` |
| `dePeerCleanupEventCreate` | 2499 | 2929 | `/databases/{database}/documents/partyEvents/{eventId}` |
| `deCleanupEventCreate` | 2613 | 2935 | `/databases/{database}/documents/partyEvents/{eventId}` |
| `canAccessRecruitmentByAudience` | 1294 | 2955 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validRecurrenceChange` | 1301 | 2962 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicLifecycleActorAllowed` | 1328 | 2976 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicTargetMatchesTransition` | 1369 | 2985 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicExpectedTargetMatches` | 1386 | 2996 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicAllExpectedTargetsMatch` | 1392 | 3002 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicAllTargetsMatch` | 1403 | 3013 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicValidLifecycleShape` | 1421 | 3031 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicValidLifecycleState` | 1439 | 3049 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicValidIncompleteEndShape` | 1494 | 3104 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicClosesActiveGroupRecruitment` | 1504 | 3114 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicValidClosingGroupLifecycleCount` | 1512 | 3122 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicValidGroupLifecycleCount` | 1523 | 3133 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicLifecycleUpdate` | 1558 | 3142 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `atomicInitialPartySlotMatches` | 1862 | 3152 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicInitialRecruitment` | 1874 | 3164 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicPendingApplicationUpdate` | 2188 | 3234 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicRecruitmentJoin` | 2211 | 3257 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicCharacterRevisionUpdate` | 2258 | 3304 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicPositionAggregateUpdate` | 2276 | 3322 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `validAtomicRecruitmentVisibilityChange` | 2850 | 3339 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `canListRecruitment` | 3550 | 3362 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `canReadRecruitment` | 3557 | 3369 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `canGetRecruitment` | 3566 | 3376 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `canReadPrivateRecruitmentData` | 3572 | 3382 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `canReadPublicRecruitmentMembers` | 3581 | 3389 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `deChangedSlotGenerations` | 4444 | 3397 | `/databases/{database}/documents/recruitments/{recruitmentId}` |
| `recruitmentSlotPath` | 48 | 3447 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `recruitmentFirstPartySlotPath` | 54 | 3453 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `recruitmentSecondPartySlotPath` | 64 | 3463 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `deLeaderCleanupMemberDelete` | 2376 | 3473 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `deLeaderSuccessorUpdate` | 2405 | 3483 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `dePeerCleanupMemberDelete` | 2476 | 3498 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `deCleanupMemberDelete` | 2592 | 3509 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validAtomicJoinedMembership` | 2873 | 3518 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validAtomicMemberRemoval` | 2907 | 3552 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validPersonalCompletionMemberDelete` | 2925 | 3570 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validAtomicInitialLeaderMembership` | 2982 | 3587 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validAtomicMemberCharacterChange` | 3126 | 3609 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validMemberCharacterChange` | 3175 | 3658 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validApprovalPermissionChange` | 3240 | 3723 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `atomicPositionSlotAt` | 3252 | 3735 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `atomicPositionInSlots` | 3259 | 3742 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `validMemberPositionChange` | 3270 | 3753 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `deApprovedGeneration` | 4429 | 3778 | `/databases/{database}/documents/recruitments/{recruitmentId}/members/{playerId}` |
| `recruitmentApplicationPath` | 74 | 3833 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `validPendingApplication` | 3334 | 3837 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `validApplicantWithdrawal` | 3364 | 3867 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `validOrphanApplicationDelete` | 3379 | 3882 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `validApplicationReapply` | 3414 | 3895 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `validApplicationDecision` | 3523 | 3947 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `canGetRecruitmentApplication` | 3591 | 3972 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `deAvailablePriorState` | 4399 | 3979 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `deApplicationGeneration` | 4425 | 3984 | `/databases/{database}/documents/recruitments/{recruitmentId}/applications/{playerId}` |
| `groupMembershipStatePath` | 160 | 4040 | `/databases/{database}/documents/groups/{groupId}` |
| `groupApplicantStatsPath` | 172 | 4044 | `/databases/{database}/documents/groups/{groupId}` |
| `groupBlockPath` | 176 | 4048 | `/databases/{database}/documents/groups/{groupId}` |
| `hasGroupBlock` | 182 | 4052 | `/databases/{database}/documents/groups/{groupId}` |
| `isCurrentGroupLeader` | 201 | 4056 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupDisplayName` | 240 | 4061 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupSearchProjection` | 247 | 4068 | `/databases/{database}/documents/groups/{groupId}` |
| `validInitialGroup` | 256 | 4077 | `/databases/{database}/documents/groups/{groupId}` |
| `canGetGroup` | 399 | 4123 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupActivityUpdate` | 653 | 4130 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupMemberJoinUpdate` | 661 | 4138 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupMemberLeaveUpdate` | 694 | 4151 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupLeaderTransferUpdate` | 707 | 4164 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupDisbandUpdate` | 756 | 4186 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupJoinCommandUpdate` | 840 | 4207 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupLeaderApproveUpdate` | 1071 | 4216 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupJoinCodeFlagUpdate` | 1169 | 4229 | `/databases/{database}/documents/groups/{groupId}` |
| `validGroupJoinCodeVisibilityUpdate` | 1190 | 4249 | `/databases/{database}/documents/groups/{groupId}` |
| `validAtomicGroupRecruitmentClose` | 1814 | 4264 | `/databases/{database}/documents/groups/{groupId}` |
| `validAtomicGroupRecruitmentCloseBody` | 1832 | 4282 | `/databases/{database}/documents/groups/{groupId}` |
| `validAtomicGroupRecruitmentOpen` | 3004 | 4312 | `/databases/{database}/documents/groups/{groupId}` |
| `validAtomicGroupRecruitmentOpenBody` | 3022 | 4330 | `/databases/{database}/documents/groups/{groupId}` |
| `validInitialGroupMember` | 302 | 4412 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberDocumentKeys` | 417 | 4435 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validNewGroupMemberCore` | 427 | 4445 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberOptionalNumberFields` | 445 | 4456 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberSnapshotsFromRelation` | 457 | 4468 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberSnapshotsFromCharacter` | 464 | 4475 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberSelfSnapshotRefresh` | 473 | 4483 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validInvitedGroupMember` | 629 | 4515 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberSelfLeaveDelete` | 682 | 4538 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberRoleTransferUpdate` | 729 | 4550 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupMemberDisbandDelete` | 777 | 4577 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validApprovedGroupMember` | 984 | 4590 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validJoinCodeGroupMember` | 1207 | 4615 | `/databases/{database}/documents/groups/{groupId}/members/{playerId}` |
| `validGroupRaidListingCreate` | 206 | 4689 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validGroupRaidListingBackfill` | 224 | 4707 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validAtomicLifecycleListingUpdate` | 1751 | 4721 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validAtomicLifecycleListingDelete` | 1761 | 4731 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validPersonalCompletionListingUpdate` | 1791 | 4742 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validPersonalCompletionListingDelete` | 1807 | 4758 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `deLeaderCleanupListing` | 2386 | 4765 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `dePeerCleanupListing` | 2487 | 4777 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `deCleanupListing` | 2601 | 4789 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validAtomicMemberRemovalListingUpdate` | 2652 | 4801 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validAtomicVisibilityListingWrite` | 3046 | 4856 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validGroupRaidListingDelete` | 3065 | 4875 | `/databases/{database}/documents/groups/{groupId}/raidListings/{recruitmentId}` |
| `validGroupJoinRelationKeys` | 407 | 4929 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `reusableGroupJoinRelation` | 507 | 4939 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupRequestExpiry` | 516 | 4945 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupPendingJoinRelation` | 522 | 4951 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupInvitationCreate` | 555 | 4982 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupApplicationCreate` | 578 | 5004 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupJoinRelationDecision` | 602 | 5026 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupApplicationDecision` | 958 | 5051 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validJoinCodeRelationAccept` | 1239 | 5074 | `/databases/{database}/documents/groups/{groupId}/joinRelations/{playerId}` |
| `validGroupApplicantStatsWrite` | 908 | 5145 | `/databases/{database}/documents/groups/{groupId}/applicantStats/{playerId}` |
| `validGroupBlockCreate` | 1086 | 5198 | `/databases/{database}/documents/groups/{groupId}/blockedPlayers/{playerId}` |
| `validJoinCodeCreate` | 1130 | 5243 | `/databases/{database}/documents/groupJoinCodes/{code}` |
| `validJoinCodeDelete` | 1153 | 5266 | `/databases/{database}/documents/groupJoinCodes/{code}` |
