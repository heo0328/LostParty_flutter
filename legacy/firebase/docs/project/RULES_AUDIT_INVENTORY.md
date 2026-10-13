# Rules 정적 전수 목록 — 2026-10-04

> 원본 문서: `docs/project/RULES_AUDIT_INVENTORY.md` · 이동일:2026-10-13. 기존 서비스의 보관 문서이며 신규 서버의 실행 기준이 아니다.

고정 SHA `6a4a4b52cf566f9c119d9de3c3876c411c336da24ee62b9bca5fd1be97bd1da9`. `node tools/rules_audit.mjs` 결과.
정적 도달성은 실행 성공/필수 조건/컴파일 크기를 뜻하지 않는다. 상세 판정은 TASK-11 문서를 따른다.

## 전체 allow 목록

| 경로 | 동작 | Rules 행 | 직접 호출 | 도달 함수 수 |
|---|---|---:|---|---:|
| /authBindings/{authUid} | get | 3817 | signedIn | 1 |
| /authBindings/{authUid} | list | 3818 |  | 0 |
| /authBindings/{authUid} | create | 3819 | signedIn, bindingPath, validActiveBinding, playerPath, playerPath | 4 |
| /authBindings/{authUid} | update, delete | 3826 |  | 0 |
| /operatorAssignments/{playerId} | get | 3830 | hasActiveBinding, currentPlayerId | 4 |
| /operatorAssignments/{playerId} | list, create, update, delete | 3831 |  | 0 |
| /players/{playerId} | get | 3835 | signedIn, bindingPath, bindingPath, isActiveOperator | 7 |
| /players/{playerId} | list | 3839 | isActiveOperator | 7 |
| /players/{playerId} | create | 3840 | signedIn, bindingPath, validActivePlayer, bindingPath | 3 |
| /players/{playerId} | update | 3844 | validPlayerLastSeenUpdate, validLegacyLastSeenBackfill | 9 |
| /players/{playerId} | delete | 3852 |  | 0 |
| /players/{playerId}/activeRaidAssignments/{assignmentId} | get | 3857 | hasActiveBinding | 3 |
| /players/{playerId}/activeRaidAssignments/{assignmentId} | list | 3858 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/activeRaidAssignments/{assignmentId} | create, update | 3860 |  | 0 |
| /players/{playerId}/activeRaidAssignments/{assignmentId} | delete | 3861 | validLegacyAssignmentConsumedByPersonalCompletion, validLegacyStaleAssignmentDelete | 12 |
| /players/{playerId}/events/{eventId} | get, list | 3873 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/events/{eventId} | create | 3876 | validManualVerificationDisputeEvent | 9 |
| /players/{playerId}/events/{eventId} | update, delete | 3883 |  | 0 |
| /players/{playerId}/groupMembershipState/{docId} | get, list | 3889 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/groupMembershipState/{docId} | create | 3894 | currentPlayerId, validLeaderApprovedMembershipStateAdd, validMembershipStateAdd | 11 |
| /players/{playerId}/groupMembershipState/{docId} | update | 3908 | currentPlayerId, validLeaderApprovedMembershipStateAdd, validMembershipStateRemove, validMembershipStateAdd | 15 |
| /players/{playerId}/groupMembershipState/{docId} | delete | 3931 |  | 0 |
| /players/{playerId}/groupRelations/{groupId} | get, list | 3935 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/groupRelations/{groupId} | create, update | 3938 | currentPlayerId, validLeaderApprovedGroupRelation, validJoinCodeMemberGroupRelation, validInitialMemberGroupRelation, validGroupRequestRelation, validAcceptedGroupRelation | 16 |
| /players/{playerId}/groupRelations/{groupId} | delete | 3964 | validGroupMemberLeaveRelationDelete, validGroupDisbandRelationDelete | 8 |
| /players/{playerId}/weeklyRaidClaims/{claimId} | get | 3971 | hasActiveBinding | 3 |
| /players/{playerId}/weeklyRaidClaims/{claimId} | list | 3972 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/weeklyRaidClaims/{claimId} | create | 3974 | validManualWeeklyRaidClaimCreate | 9 |
| /players/{playerId}/weeklyRaidClaims/{claimId} | update | 3979 |  | 0 |
| /players/{playerId}/weeklyRaidClaims/{claimId} | delete | 3980 | validManualWeeklyRaidClaimDelete | 9 |
| /players/{playerId}/raidStates/{stateId} | get | 3989 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/raidStates/{stateId} | list | 3991 | hasActiveBinding, currentPlayerId | 4 |
| /players/{playerId}/raidStates/{stateId} | create | 3993 | validManualRaidStateCreate, validAtomicAdvanceRaidStateCreate, validAtomicRaidStateCreate | 27 |
| /players/{playerId}/raidStates/{stateId} | update | 4007 | validPersonalRaidStateCompletion, deOlderState, validManualRaidStateCreate, deReplacePriorState, validPersonalRaidStateCompletion, validAtomicRaidStateUpdate | 33 |
| /players/{playerId}/raidStates/{stateId} | delete | 4023 | validPersonalCompletedRaidStateDelete, validAtomicRaidStateDelete, validAtomicMembershipRaidStateDelete, validAtomicStaleRaidStateDelete | 18 |
| /players/{playerId}/characterActivity/{characterId} | get, list | 4046 | hasActiveBinding | 3 |
| /players/{playerId}/characterActivity/{characterId} | create, update | 4047 | validCharacterActivityWrite | 11 |
| /players/{playerId}/characterActivity/{characterId} | delete | 4052 | validCharacterActivityDelete | 6 |
| /accountVerificationChallenges/{challengeId} | read, write | 4341 |  | 0 |
| /activeAccountVerificationChallenges/{playerId} | read, write | 4345 |  | 0 |
| /manualVerificationRequests/{requestId} | get | 4349 | hasActiveBinding, currentPlayerId, currentPlayerId, isActiveOperator | 7 |
| /manualVerificationRequests/{requestId} | list | 4353 | isActiveOperator, hasActiveBinding, currentPlayerId, currentPlayerId | 7 |
| /manualVerificationRequests/{requestId} | create | 4357 | validManualVerificationCreate | 8 |
| /manualVerificationRequests/{requestId} | update | 4358 | validManualVerificationRequesterCancel, validManualVerificationReissue, validManualVerificationOperatorWrite, validManualVerificationDisputeTransfer | 19 |
| /manualVerificationRequests/{requestId} | delete | 4371 |  | 0 |
| /manualVerificationBlocks/{blockId} | get | 4375 | canGetManualVerificationBlock | 8 |
| /manualVerificationBlocks/{blockId} | list | 4376 | isActiveOperator | 7 |
| /manualVerificationBlocks/{blockId} | create | 4377 | validManualVerificationBlockWrite | 8 |
| /manualVerificationBlocks/{blockId} | update, delete | 4378 |  | 0 |
| /gameAccounts/{gameAccountId} | read | 4512 | signedIn | 1 |
| /gameAccounts/{gameAccountId} | create | 4513 | signedIn, deValidGeneration | 2 |
| /gameAccounts/{gameAccountId} | update | 4515 | signedIn, deGenerationUpdate | 3 |
| /gameAccounts/{gameAccountId} | delete | 4516 |  | 0 |
| /characters/{characterId} | read | 4520 | signedIn | 1 |
| /characters/{characterId} | create | 4521 | signedIn, deCharacterGeneration | 3 |
| /characters/{characterId} | update | 4522 | signedIn, deCharacterGeneration | 3 |
| /characters/{characterId} | delete | 4527 |  | 0 |
| /characterIdentityClaims/{claimId} | read, write | 4531 | signedIn | 1 |
| /playerGameAccounts/{ownershipId} | read | 4535 | signedIn | 1 |
| /playerGameAccounts/{ownershipId} | create | 4536 | signedIn | 1 |
| /playerGameAccounts/{ownershipId} | update | 4541 | signedIn, changesRepresentativeCharacter, validRepresentativeCharacterSeed, validRepresentativeCharacterUpdate | 10 |
| /playerGameAccounts/{ownershipId} | delete | 4552 | signedIn | 1 |
| /partyEvents/{eventId} | get, list | 4557 | hasActiveBinding, currentPlayerId | 4 |
| /partyEvents/{eventId} | update, delete | 4559 |  | 0 |
| /partyEvents/{eventId} | create | 4560 | dePeerCleanupEventCreate, deLeaderCleanupEventCreate, deCleanupEventCreate, validAtomicMembershipPartyEvent, validAtomicLifecyclePartyEvent | 23 |
| /recruitments/{recruitmentId} | get | 4571 | canGetRecruitment | 9 |
| /recruitments/{recruitmentId} | list | 4572 | canListRecruitment | 5 |
| /recruitments/{recruitmentId} | create | 4573 | validAtomicInitialRecruitment | 12 |
| /recruitments/{recruitmentId} | update | 4577 | dePersonalCompletionBoundary, validPersonalCompletionRecruitmentUpdate, deChangedSlotGenerations, deLastCompletedDisband, validAtomicLifecycleUpdate, dePeerCleanupAggregate, deLeaderCleanupAggregate, deCleanupAggregate, validRecurrenceChange, validAtomicLifecycleUpdate, validAtomicPendingApplicationUpdate, validAtomicRecruitmentJoin, validAtomicCharacterRevisionUpdate, validAtomicPositionAggregateUpdate, validAtomicRecruitmentMemberRemoval, validAtomicRecruitmentVisibilityChange | 62 |
| /recruitments/{recruitmentId} | delete | 4609 |  | 0 |
| /recruitments/{recruitmentId}/members/{playerId} | get, list | 4612 | canReadPrivateRecruitmentData, canReadPublicRecruitmentMembers, hasActiveBinding, currentPlayerId | 9 |
| /recruitments/{recruitmentId}/members/{playerId} | create | 4615 | validAtomicInitialLeaderMembership, validAtomicJoinedMembership | 19 |
| /recruitments/{recruitmentId}/members/{playerId} | update | 4624 | dePersonalCommand, deManualCurrentOwnership, validApprovalPermissionChange, deCurrentOwnership, deCurrentOwnership, validMemberPositionChange, validAtomicMemberCharacterChange, deLeaderSuccessorUpdate, validMemberCharacterChange, validApprovalPermissionChange | 34 |
| /recruitments/{recruitmentId}/members/{playerId} | delete | 4646 | dePersonalCommand, validPersonalCompletionMemberDelete, dePeerCommand, dePeerCleanupMemberDelete, deLeaderCleanupMemberDelete, deCleanupMemberDelete, validAtomicMemberRemoval | 21 |
| /recruitments/{recruitmentId}/slots/{slotId} | get, list | 4655 | canReadPrivateRecruitmentData, canReadPublicRecruitmentMembers | 9 |
| /recruitments/{recruitmentId}/slots/{slotId} | create, update, delete | 4657 |  | 0 |
| /recruitments/{recruitmentId}/applications/{playerId} | get | 4661 | canGetRecruitmentApplication | 8 |
| /recruitments/{recruitmentId}/applications/{playerId} | list | 4662 | canReadPrivateRecruitmentData, hasActiveBinding, currentPlayerId | 6 |
| /recruitments/{recruitmentId}/applications/{playerId} | create | 4665 | validPendingApplication | 19 |
| /recruitments/{recruitmentId}/applications/{playerId} | update | 4670 | validApplicantWithdrawal, validApplicationReapply, validApplicationDecision, validApplicationWeeklyCompletion | 27 |
| /recruitments/{recruitmentId}/applications/{playerId} | delete | 4692 | validOrphanApplicationDelete | 6 |
| /recruitments/{recruitmentId}/applications/{playerId}/votes/{voterPlayerId} | get, list | 4699 | canReadPrivateRecruitmentData | 6 |
| /recruitments/{recruitmentId}/applications/{playerId}/votes/{voterPlayerId} | create, update, delete | 4700 |  | 0 |
| /recruitments/{recruitmentId}/cycles/{cycleKey} | get, list | 4706 | canReadPrivateRecruitmentData | 6 |
| /recruitments/{recruitmentId}/cycles/{cycleKey} | create, update, delete | 4707 |  | 0 |
| /groups/{groupId} | get | 4712 | canGetGroup | 8 |
| /groups/{groupId} | list | 4714 | hasActiveBinding | 3 |
| /groups/{groupId} | create | 4715 | validInitialGroup | 14 |
| /groups/{groupId} | update | 4722 | validGroupLeaderApproveUpdate, validAtomicGroupRecruitmentClose, validGroupDisbandUpdate, validGroupLeaderTransferUpdate, validGroupMemberLeaveUpdate, validGroupJoinCommandUpdate, validAtomicGroupRecruitmentOpen, validGroupJoinCodeFlagUpdate, validGroupJoinCodeVisibilityUpdate, validGroupJoinCommandUpdate | 27 |
| /groups/{groupId} | delete | 4766 |  | 0 |
| /groups/{groupId}/members/{playerId} | get, list | 4769 | isCurrentGroupMember | 6 |
| /groups/{groupId}/members/{playerId} | create | 4771 | validApprovedGroupMember, validJoinCodeGroupMember, validInitialGroupMember, validInvitedGroupMember | 22 |
| /groups/{groupId}/members/{playerId} | update | 4790 | validGroupMemberRoleTransferUpdate, validGroupMemberSelfSnapshotRefresh | 12 |
| /groups/{groupId}/members/{playerId} | delete | 4801 | validGroupMemberSelfLeaveDelete, validGroupMemberDisbandDelete | 9 |
| /groups/{groupId}/raidListings/{recruitmentId} | get, list | 4813 | isCurrentGroupMember | 6 |
| /groups/{groupId}/raidListings/{recruitmentId} | create | 4814 | validGroupRaidListingCreate, validGroupRaidListingBackfill, validAtomicVisibilityListingWrite | 10 |
| /groups/{groupId}/raidListings/{recruitmentId} | update | 4827 | dePersonalCommand, validPersonalCompletionListingUpdate, dePeerCommand, dePeerCleanupListing, deLeaderCleanupListing, deCleanupListing, validAtomicMemberRemovalListingUpdate, validGroupRaidListingCreate, validAtomicLifecycleListingUpdate, validAtomicVisibilityListingWrite | 29 |
| /groups/{groupId}/raidListings/{recruitmentId} | delete | 4844 | validPersonalCompletionListingDelete, validGroupRaidListingDelete, validAtomicLifecycleListingDelete | 11 |
| /groups/{groupId}/joinRelations/{playerId} | get | 4852 | hasActiveBinding, currentPlayerId, isCurrentGroupMember | 6 |
| /groups/{groupId}/joinRelations/{playerId} | list | 4854 | isCurrentGroupMember | 6 |
| /groups/{groupId}/joinRelations/{playerId} | create | 4855 | validGroupInvitationCreate, validGroupApplicationCreate | 18 |
| /groups/{groupId}/joinRelations/{playerId} | update | 4869 | validGroupApplicationDecision, validGroupInvitationCreate, reusableGroupJoinRelation, validGroupApplicationCreate, reusableGroupJoinRelation, validGroupJoinRelationDecision, validJoinCodeRelationAccept | 24 |
| /groups/{groupId}/joinRelations/{playerId} | delete | 4901 |  | 0 |
| /groups/{groupId}/applicantStats/{playerId} | get | 4905 | hasActiveBinding, currentPlayerId, isCurrentGroupMember | 6 |
| /groups/{groupId}/applicantStats/{playerId} | list | 4907 | isCurrentGroupLeader | 6 |
| /groups/{groupId}/applicantStats/{playerId} | create | 4908 | validGroupApplicantStatsWrite | 8 |
| /groups/{groupId}/applicantStats/{playerId} | update | 4915 | validGroupApplicantStatsWrite | 8 |
| /groups/{groupId}/applicantStats/{playerId} | delete | 4922 |  | 0 |
| /groups/{groupId}/blockedPlayers/{playerId} | get, list | 4929 | isCurrentGroupLeader | 6 |
| /groups/{groupId}/blockedPlayers/{playerId} | create | 4930 | validGroupBlockCreate | 10 |
| /groups/{groupId}/blockedPlayers/{playerId} | update | 4935 |  | 0 |
| /groups/{groupId}/blockedPlayers/{playerId} | delete | 4936 | isActiveGroupLeader | 7 |
| /groupJoinCodes/{code} | get | 4943 | hasActiveBinding, validJoinCodeId | 4 |
| /groupJoinCodes/{code} | list | 4944 |  | 0 |
| /groupJoinCodes/{code} | create | 4945 | validJoinCodeCreate | 9 |
| /groupJoinCodes/{code} | update | 4946 |  | 0 |
| /groupJoinCodes/{code} | delete | 4947 | validJoinCodeDelete | 9 |
| /{path=**}/applications/{applicantPlayerId} | list | 4953 | hasActiveBinding, currentPlayerId | 4 |

## 전체 함수 목록

| 함수 | Rules 행 | bytes | 직접 호출 |
|---|---:|---:|---|
| signedIn | 6 | 62 |  |
| bindingPath | 10 | 108 |  |
| playerPath | 14 | 104 |  |
| operatorAssignmentPath | 18 | 128 |  |
| hasActiveBinding | 22 | 179 | signedIn, bindingPath, bindingPath |
| currentPlayerId | 28 | 97 | bindingPath |
| isActiveOperator | 32 | 330 | hasActiveBinding, playerPath, currentPlayerId, playerPath, currentPlayerId, operatorAssignmentPath, currentPlayerId, operatorAssignmentPath, currentPlayerId |
| recruitmentPath | 40 | 124 |  |
| recruitmentMemberPath | 44 | 160 |  |
| recruitmentSlotPath | 48 | 237 | recruitmentFirstPartySlotPath, recruitmentSecondPartySlotPath |
| recruitmentFirstPartySlotPath | 54 | 495 |  |
| recruitmentSecondPartySlotPath | 64 | 496 |  |
| recruitmentApplicationPath | 74 | 188 |  |
| assignmentPath | 78 | 160 |  |
| weeklyRaidClaimId | 82 | 123 |  |
| weeklyRaidClaimPath | 86 | 213 | weeklyRaidClaimId |
| hasWeeklyRaidClaimAfter | 90 | 209 | weeklyRaidClaimPath |
| raidStatePath | 99 | 169 |  |
| hasCompletedRaidStateAfter | 103 | 472 | raidStatePath |
| hasWeeklyRaidCompletionAfter | 118 | 324 | hasWeeklyRaidClaimAfter, hasCompletedRaidStateAfter |
| characterPath | 133 | 116 |  |
| ownsActiveCharacter | 137 | 208 | characterPath, currentPlayerId |
| ownsActiveCharacterForPlayer | 143 | 218 | characterPath |
| groupPath | 152 | 100 |  |
| groupMemberPath | 156 | 136 |  |
| groupMembershipStatePath | 160 | 147 |  |
| groupRelationPath | 164 | 146 |  |
| groupJoinRelationPath | 168 | 148 |  |
| groupApplicantStatsPath | 172 | 151 |  |
| groupBlockPath | 176 | 142 |  |
| hasGroupBlock | 182 | 105 | groupBlockPath |
| isCurrentPlayerActive | 186 | 143 | hasActiveBinding, playerPath, currentPlayerId |
| isCurrentGroupMember | 191 | 142 | hasActiveBinding, groupMemberPath, currentPlayerId |
| isCurrentGroupLeader | 201 | 155 | hasActiveBinding, groupPath, currentPlayerId |
| validGroupRaidListingCreate | 206 | 760 | recruitmentPath, recruitmentPath, isCurrentGroupMember, currentPlayerId, recruitmentPath |
| validGroupRaidListingBackfill | 224 | 646 | recruitmentPath, recruitmentPath, isCurrentGroupMember, recruitmentPath, currentPlayerId |
| validGroupDisplayName | 240 | 185 |  |
| validGroupSearchProjection | 247 | 377 |  |
| validInitialGroup | 256 | 2203 | currentPlayerId, groupMemberPath, groupMembershipStatePath, isCurrentPlayerActive, validGroupDisplayName, validGroupSearchProjection, ownsActiveCharacter, groupRelationPath |
| validInitialGroupMember | 302 | 906 | groupPath, hasActiveBinding, currentPlayerId, validNewGroupMemberCore, validGroupMemberSnapshotsFromCharacter |
| validMembershipStateAdd | 326 | 732 | hasActiveBinding, currentPlayerId, validMembershipStateDocumentKeys, validMembershipStateAddMember |
| validMembershipStateAddMember | 351 | 787 | groupMemberPath |
| validInitialMemberGroupRelation | 372 | 1053 | groupPath, groupMemberPath, hasActiveBinding, currentPlayerId |
| canGetGroup | 399 | 200 | hasActiveBinding, groupPath, isCurrentGroupMember |
| validGroupJoinRelationKeys | 407 | 475 |  |
| validGroupMemberDocumentKeys | 417 | 420 |  |
| validNewGroupMemberCore | 427 | 376 | validGroupMemberDocumentKeys |
| validMembershipStateDocumentKeys | 438 | 207 |  |
| validGroupMemberOptionalNumberFields | 445 | 479 |  |
| validGroupMemberSnapshotsFromRelation | 457 | 339 | validGroupMemberOptionalNumberFields |
| validGroupMemberSnapshotsFromCharacter | 464 | 453 | characterPath, validGroupMemberOptionalNumberFields |
| validGroupMemberSelfSnapshotRefresh | 473 | 1260 | characterPath, isCurrentPlayerActive, currentPlayerId, groupMemberPath, validGroupMemberOptionalNumberFields |
| reusableGroupJoinRelation | 507 | 165 |  |
| validGroupRequestExpiry | 516 | 222 |  |
| validGroupPendingJoinRelation | 522 | 1094 | isCurrentPlayerActive, validGroupJoinRelationKeys, validGroupRequestExpiry, groupPath, groupMemberPath, hasGroupBlock, groupRelationPath |
| validGroupInvitationCreate | 555 | 564 | validGroupPendingJoinRelation, currentPlayerId, currentPlayerId, isCurrentGroupMember |
| validGroupApplicationCreate | 578 | 595 | groupApplicantStatsPath, validGroupPendingJoinRelation, currentPlayerId |
| validGroupJoinRelationDecision | 602 | 1082 | isCurrentPlayerActive, groupRelationPath, currentPlayerId, hasGroupBlock, groupMemberPath, currentPlayerId, isCurrentGroupMember, currentPlayerId, isCurrentGroupLeader |
| validInvitedGroupMember | 629 | 1079 | groupPath, groupJoinRelationPath, groupMembershipStatePath, isCurrentPlayerActive, currentPlayerId, validNewGroupMemberCore, validGroupMemberSnapshotsFromRelation, hasGroupBlock |
| validGroupActivityUpdate | 653 | 321 |  |
| validGroupMemberJoinUpdate | 661 | 618 | groupMemberPath, currentPlayerId |
| removedActiveGroupId | 676 | 170 |  |
| validGroupMemberSelfLeaveDelete | 682 | 505 | groupPath, hasActiveBinding, currentPlayerId, groupPath, groupMemberPath, groupRelationPath |
| validGroupMemberLeaveUpdate | 694 | 584 | isCurrentPlayerActive, groupMemberPath, currentPlayerId |
| validGroupLeaderTransferUpdate | 707 | 1044 | groupMemberPath, currentPlayerId, groupMemberPath, isCurrentPlayerActive, currentPlayerId |
| validGroupMemberRoleTransferUpdate | 729 | 914 | groupPath, groupPath, isCurrentPlayerActive, currentPlayerId, currentPlayerId |
| validGroupDisbandUpdate | 756 | 885 | isCurrentPlayerActive, currentPlayerId, groupMemberPath, currentPlayerId |
| validGroupMemberDisbandDelete | 777 | 509 | groupPath, hasActiveBinding, currentPlayerId, groupMemberPath, groupRelationPath |
| validMembershipStateRemove | 790 | 858 | hasActiveBinding, currentPlayerId, validMembershipStateDocumentKeys, validRemovedMembershipState |
| validRemovedMembershipState | 812 | 316 | removedActiveGroupId, groupMemberPath, groupRelationPath |
| validGroupMemberLeaveRelationDelete | 819 | 371 | groupPath, hasActiveBinding, currentPlayerId, groupPath, groupMemberPath |
| validGroupDisbandRelationDelete | 828 | 373 | groupPath, hasActiveBinding, currentPlayerId, groupMemberPath |
| validGroupJoinCommandUpdate | 840 | 385 | isCurrentPlayerActive, isCurrentGroupMember, groupRelationPath, currentPlayerId, validGroupActivityUpdate, validGroupMemberJoinUpdate |
| validGroupRelationProjectionKeys | 849 | 302 |  |
| validGroupRequestRelation | 859 | 967 | groupPath, groupJoinRelationPath, isCurrentPlayerActive, currentPlayerId, isCurrentGroupMember, validGroupRelationProjectionKeys |
| validAcceptedGroupRelation | 881 | 1077 | groupPath, groupMemberPath, groupJoinRelationPath, isCurrentPlayerActive, currentPlayerId, validGroupRelationProjectionKeys |
| validGroupApplicantStatsWrite | 908 | 1172 | groupJoinRelationPath, isCurrentPlayerActive, currentPlayerId |
| isActiveGroupLeader | 949 | 246 | currentPlayerId, hasActiveBinding, playerPath, groupPath |
| validGroupApplicationDecision | 958 | 984 | isActiveGroupLeader, currentPlayerId, groupRelationPath, hasGroupBlock, groupMemberPath, groupBlockPath |
| validApprovedGroupMember | 984 | 1169 | currentPlayerId, groupPath, groupJoinRelationPath, groupMembershipStatePath, hasActiveBinding, playerPath, validNewGroupMemberCore, validGroupMemberSnapshotsFromRelation, hasGroupBlock |
| validLeaderApprovedMembershipStateAdd | 1012 | 935 | currentPlayerId, groupMemberPath, hasActiveBinding, playerPath, validMembershipStateDocumentKeys, validMembershipStateAddMember, groupPath |
| validLeaderApprovedGroupRelation | 1044 | 996 | currentPlayerId, groupPath, groupMemberPath, hasActiveBinding, playerPath, validGroupRelationProjectionKeys |
| validGroupLeaderApproveUpdate | 1071 | 564 | isCurrentPlayerActive, currentPlayerId |
| validGroupBlockCreate | 1086 | 1439 | groupJoinRelationPath, groupApplicantStatsPath, isActiveGroupLeader, currentPlayerId, currentPlayerId |
| validJoinCodeId | 1125 | 135 |  |
| validJoinCodeCreate | 1130 | 863 | groupPath, groupPath, isActiveGroupLeader, validJoinCodeId, currentPlayerId |
| validJoinCodeDelete | 1153 | 539 | groupPath, groupPath, isActiveGroupLeader, validJoinCodeId |
| validGroupJoinCodeFlagUpdate | 1169 | 802 | isCurrentPlayerActive, currentPlayerId, validJoinCodeId |
| validGroupJoinCodeVisibilityUpdate | 1190 | 643 | isCurrentPlayerActive, currentPlayerId |
| validJoinCodeGroupMember | 1207 | 1261 | groupPath, groupMembershipStatePath, groupJoinRelationPath, isCurrentPlayerActive, currentPlayerId, validNewGroupMemberCore, validGroupMemberSnapshotsFromCharacter, ownsActiveCharacter, characterPath, hasGroupBlock |
| validJoinCodeRelationAccept | 1239 | 786 | isCurrentPlayerActive, currentPlayerId, hasGroupBlock, groupMemberPath, groupMemberPath |
| validJoinCodeMemberGroupRelation | 1259 | 1044 | groupPath, groupMemberPath, groupJoinRelationPath, isCurrentPlayerActive, currentPlayerId, validGroupRelationProjectionKeys |
| canApproveApplications | 1285 | 395 | recruitmentPath, currentPlayerId, recruitmentMemberPath, recruitmentMemberPath |
| canAccessRecruitmentByAudience | 1294 | 241 | groupMemberPath, currentPlayerId |
| validRecurrenceChange | 1301 | 553 | hasActiveBinding, currentPlayerId |
| atomicRaidStatePath | 1316 | 147 |  |
| atomicRaidStateDocPath | 1320 | 147 |  |
| atomicHasGroupId | 1324 | 103 |  |
| atomicLifecycleActorAllowed | 1328 | 384 | hasActiveBinding, currentPlayerId, currentPlayerId |
| atomicIsLifecycleCommand | 1337 | 310 |  |
| atomicLifecycleMarkerConsumedOrPreserved | 1345 | 738 | atomicIsLifecycleCommand |
| atomicTargetStateMatches | 1361 | 335 |  |
| atomicTargetMatchesTransition | 1369 | 422 | atomicRaidStatePath, atomicTargetStateMatches, atomicRaidStatePath |
| atomicExpectedTargetStateMatches | 1380 | 226 |  |
| atomicExpectedTargetMatches | 1386 | 263 | atomicExpectedTargetStateMatches, atomicRaidStatePath |
| atomicAllExpectedTargetsMatch | 1392 | 583 | atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches, atomicExpectedTargetMatches |
| atomicAllTargetsMatch | 1403 | 895 | atomicAllExpectedTargetsMatch, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition, atomicTargetMatchesTransition |
| atomicValidLifecycleShape | 1421 | 884 | currentPlayerId |
| atomicValidLifecycleState | 1439 | 2819 |  |
| atomicValidIncompleteEndShape | 1494 | 469 |  |
| atomicClosesActiveGroupRecruitment | 1504 | 314 |  |
| atomicValidClosingGroupLifecycleCount | 1512 | 502 | groupPath, groupPath |
| atomicValidGroupLifecycleCount | 1523 | 418 | atomicHasGroupId, atomicClosesActiveGroupRecruitment, atomicClosesActiveGroupRecruitment, atomicValidClosingGroupLifecycleCount |
| deLastCompletedDisband | 1533 | 1471 | deCleanupStateUnchanged, atomicHasGroupId, currentPlayerId |
| validAtomicLifecycleUpdate | 1558 | 437 | atomicIsLifecycleCommand, atomicLifecycleActorAllowed, atomicValidLifecycleShape, atomicValidLifecycleState, atomicValidIncompleteEndShape, atomicAllTargetsMatch, atomicValidGroupLifecycleCount |
| atomicTargetAt | 1568 | 228 |  |
| atomicCommandIncludes | 1574 | 498 | atomicTargetAt, atomicTargetAt, atomicTargetAt, atomicTargetAt, atomicTargetAt, atomicTargetAt, atomicTargetAt, atomicTargetAt |
| atomicAdvanceStateMatchesSlotAt | 1585 | 430 |  |
| atomicAdvanceStateMatchesSlot | 1593 | 588 | atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt, atomicAdvanceStateMatchesSlotAt |
| deCurrentOwnership | 1604 | 649 | characterPath |
| validAtomicAdvanceRaidStateCreate | 1617 | 1156 | recruitmentPath, atomicIsLifecycleCommand, deCurrentOwnership, atomicCommandIncludes, atomicAdvanceStateMatchesSlot |
| validAtomicRaidStateUpdate | 1642 | 1685 | recruitmentPath, atomicIsLifecycleCommand, deCurrentOwnership, atomicCommandIncludes, atomicAdvanceStateMatchesSlot, atomicAdvanceStateMatchesSlot |
| validAtomicRaidStateDelete | 1676 | 353 | recruitmentPath, atomicCommandIncludes |
| atomicEventTargetMatches | 1684 | 597 |  |
| atomicAllEventTargetsMatch | 1698 | 769 | atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches, atomicEventTargetMatches |
| atomicValidV2LifecycleEventPayload | 1713 | 992 | atomicAllEventTargetsMatch |
| atomicLifecycleEventType | 1734 | 186 |  |
| validAtomicLifecyclePartyEvent | 1740 | 877 | recruitmentPath, atomicIsLifecycleCommand, atomicValidV2LifecycleEventPayload, atomicLifecycleEventType |
| validAtomicLifecycleListingUpdate | 1757 | 435 | recruitmentPath, atomicIsLifecycleCommand |
| validAtomicLifecycleListingDelete | 1767 | 504 | recruitmentPath, atomicIsLifecycleCommand |
| personalCompletionCommandMarker | 1778 | 372 | currentPlayerId |
| personalCompletionTargetsCurrentPlayer | 1788 | 396 | personalCompletionCommandMarker, currentPlayerId |
| validPersonalCompletionListingUpdate | 1797 | 574 | recruitmentPath, personalCompletionTargetsCurrentPlayer |
| validPersonalCompletionListingDelete | 1813 | 290 | recruitmentPath, personalCompletionTargetsCurrentPlayer |
| validAtomicGroupRecruitmentClose | 1820 | 756 | recruitmentPath, validAtomicGroupRecruitmentCloseBody, recruitmentPath |
| validAtomicGroupRecruitmentCloseBody | 1838 | 1309 | atomicIsLifecycleCommand, personalCompletionTargetsCurrentPlayer |
| atomicInitialPartySlotMatches | 1868 | 461 |  |
| validAtomicInitialRecruitment | 1880 | 3072 | currentPlayerId, recruitmentMemberPath, atomicRaidStatePath, hasActiveBinding, groupMemberPath, groupPath, groupPath, groupPath, ownsActiveCharacter, atomicInitialPartySlotMatches |
| atomicRaidStateTargetAt | 1950 | 271 |  |
| atomicRaidStateListedInTargets | 1956 | 642 | atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt, atomicRaidStateTargetAt |
| validAtomicRaidStateCreate | 1967 | 1408 | recruitmentPath, recruitmentMemberPath, deCurrentOwnership, hasActiveBinding, currentPlayerId, canApproveApplications, atomicIsLifecycleCommand, ownsActiveCharacterForPlayer, deBlockingClaim, atomicRaidStateListedInTargets |
| validManualRaidStateCreate | 2000 | 1466 | hasActiveBinding, currentPlayerId, deManualCurrentOwnership, deBlockingClaim, deManualAssignmentAvailable |
| validPersonalRaidStateCompletion | 2037 | 1390 | recruitmentPath, deManualCurrentOwnership, hasActiveBinding, currentPlayerId, personalCompletionTargetsCurrentPlayer, recruitmentMemberPath |
| validPersonalCompletedRaidStateDelete | 2069 | 321 | hasActiveBinding, currentPlayerId, deManualCurrentOwnership |
| validLegacyAssignmentConsumedByPersonalCompletion | 2077 | 880 | atomicRaidStateDocPath, recruitmentPath, hasActiveBinding, currentPlayerId |
| validLegacyStaleAssignmentDelete | 2100 | 568 | recruitmentPath, deManualCurrentOwnership, hasActiveBinding, currentPlayerId, validAtomicStaleRaidStateRecruitment |
| atomicIsMembershipEventType | 2118 | 391 |  |
| atomicMembershipEventKeys | 2130 | 883 |  |
| validAtomicMembershipPartyEvent | 2150 | 1250 | recruitmentPath, atomicIsLifecycleCommand, atomicIsMembershipEventType, atomicMembershipEventKeys, currentPlayerId, personalCompletionTargetsCurrentPlayer |
| atomicActiveV2Recruitment | 2179 | 210 | hasActiveBinding |
| atomicAggregateSizesMatch | 2186 | 792 |  |
| validAtomicPendingApplicationUpdate | 2204 | 1078 | atomicActiveV2Recruitment, atomicLifecycleMarkerConsumedOrPreserved |
| validAtomicRecruitmentJoin | 2227 | 2374 | atomicActiveV2Recruitment, atomicLifecycleMarkerConsumedOrPreserved, atomicAggregateSizesMatch |
| validAtomicCharacterRevisionUpdate | 2274 | 872 | atomicActiveV2Recruitment, atomicLifecycleMarkerConsumedOrPreserved, atomicAggregateSizesMatch |
| validAtomicPositionAggregateUpdate | 2292 | 790 | atomicActiveV2Recruitment, currentPlayerId, atomicLifecycleMarkerConsumedOrPreserved |
| deLeaderCleanupTransition | 2310 | 370 | currentPlayerId |
| deLeaderCleanupComposition | 2320 | 308 | deCleanupComposition |
| deLeaderCleanupEvent | 2327 | 849 | currentPlayerId |
| deLeaderCleanupAggregate | 2343 | 3679 | hasActiveBinding, deLeaderCleanupTransition, currentPlayerId, deCurrentOwnership, deOwnershipChanged, deLeaderCleanupComposition, deLeaderCleanupEvent |
| deLeaderCleanupMemberDelete | 2388 | 496 | recruitmentPath, recruitmentPath, deLeaderCleanupTransition, deCleanupStateUnchanged |
| deLeaderCleanupListing | 2398 | 722 | recruitmentPath, recruitmentPath, deLeaderCleanupTransition, deLeaderCleanupComposition |
| deLeaderCleanupEventCreate | 2410 | 287 | recruitmentPath, recruitmentPath, deLeaderCleanupTransition, deLeaderCleanupEvent |
| deLeaderSuccessorUpdate | 2417 | 872 | recruitmentPath, recruitmentPath, deLeaderCleanupTransition, deCurrentOwnership |
| dePeerCleanupTransition | 2431 | 366 | currentPlayerId |
| dePeerCleanupEvent | 2442 | 817 | currentPlayerId |
| dePeerCleanupAggregate | 2457 | 3169 | hasActiveBinding, dePeerCleanupTransition, currentPlayerId, deCurrentOwnership, deOwnershipChanged, deCleanupComposition, dePeerCleanupEvent |
| dePeerCleanupMemberDelete | 2497 | 580 | recruitmentPath, recruitmentPath, dePeerCleanupTransition, deOwnershipChanged, deCleanupStateUnchanged |
| dePeerCleanupListing | 2508 | 636 | recruitmentPath, recruitmentPath, dePeerCleanupTransition, deCleanupComposition |
| dePeerCleanupEventCreate | 2520 | 281 | recruitmentPath, recruitmentPath, dePeerCleanupTransition, dePeerCleanupEvent |
| dePeerCommand | 2527 | 277 | recruitmentPath, recruitmentPath |
| deCleanupTransition | 2533 | 358 | currentPlayerId |
| deOwnershipChanged | 2541 | 771 | characterPath |
| deCleanupStateUnchanged | 2556 | 247 | atomicRaidStateDocPath |
| deCleanupComposition | 2563 | 570 |  |
| deCleanupEvent | 2576 | 713 | currentPlayerId |
| deCleanupAggregate | 2590 | 2832 | hasActiveBinding, deCleanupTransition, currentPlayerId, currentPlayerId, currentPlayerId, deCurrentOwnership, deOwnershipChanged, deCleanupStateUnchanged, deCleanupComposition, deCleanupEvent |
| deCleanupMemberDelete | 2629 | 426 | recruitmentPath, recruitmentPath, deCleanupTransition |
| deCleanupListing | 2638 | 628 | recruitmentPath, recruitmentPath, deCleanupTransition, deCleanupComposition |
| deCleanupEventCreate | 2650 | 269 | recruitmentPath, recruitmentPath, deCleanupTransition, deCleanupEvent |
| validAtomicRecruitmentMemberRemoval | 2656 | 1678 | currentPlayerId, currentPlayerId, atomicActiveV2Recruitment, atomicLifecycleMarkerConsumedOrPreserved, atomicAggregateSizesMatch |
| validAtomicMemberRemovalListingUpdate | 2689 | 2555 | recruitmentPath, recruitmentPath, validAtomicRecruitmentMemberRemoval |
| validPersonalCompletionSuccessor | 2744 | 640 | recruitmentMemberPath, currentPlayerId |
| validPersonalCompletionLeaderProjection | 2759 | 393 | validPersonalCompletionSuccessor |
| validPersonalLastMemberCompletion | 2768 | 2738 | atomicRaidStatePath, atomicActiveV2Recruitment, currentPlayerId, currentPlayerId, currentPlayerId, currentPlayerId, currentPlayerId, personalCompletionTargetsCurrentPlayer, groupPath |
| validPersonalCompletionRecruitmentUpdate | 2821 | 3317 | atomicRaidStatePath, validPersonalLastMemberCompletion, atomicActiveV2Recruitment, currentPlayerId, currentPlayerId, currentPlayerId, atomicAggregateSizesMatch, validPersonalCompletionLeaderProjection, personalCompletionTargetsCurrentPlayer, groupPath |
| validAtomicRecruitmentVisibilityChange | 2887 | 1075 | atomicActiveV2Recruitment, currentPlayerId, atomicLifecycleMarkerConsumedOrPreserved |
| validAtomicJoinedMembership | 2910 | 1644 | recruitmentPath, recruitmentPath, currentPlayerId, canApproveApplications, currentPlayerId, deCurrentOwnership, hasActiveBinding, ownsActiveCharacterForPlayer, deApprovedGeneration, isCurrentGroupMember, atomicRaidStateListedInTargets, atomicRaidStateDocPath |
| validAtomicMemberRemoval | 2944 | 858 | recruitmentPath, recruitmentPath, hasActiveBinding, currentPlayerId, currentPlayerId, atomicRaidStateDocPath, currentPlayerId, atomicRaidStateDocPath, atomicRaidStateDocPath |
| validPersonalCompletionMemberDelete | 2962 | 600 | recruitmentPath, hasActiveBinding, currentPlayerId, personalCompletionTargetsCurrentPlayer, atomicRaidStateDocPath |
| validAtomicMembershipRaidStateDelete | 2979 | 542 | recruitmentPath, hasActiveBinding, atomicIsLifecycleCommand, currentPlayerId, currentPlayerId, atomicRaidStateListedInTargets |
| validAtomicStaleRaidStateDelete | 2991 | 594 | recruitmentPath, deManualCurrentOwnership, hasActiveBinding, currentPlayerId, validAtomicStaleRaidStateRecruitment |
| validAtomicStaleRaidStateRecruitment | 3008 | 465 |  |
| validAtomicInitialLeaderMembership | 3019 | 999 | recruitmentPath, deCurrentOwnership, hasActiveBinding, currentPlayerId, ownsActiveCharacter, atomicRaidStateListedInTargets, atomicRaidStateDocPath |
| validAtomicGroupRecruitmentOpen | 3041 | 754 | recruitmentPath, validAtomicGroupRecruitmentOpenBody, recruitmentPath |
| validAtomicGroupRecruitmentOpenBody | 3059 | 949 | currentPlayerId, currentPlayerId |
| validAtomicVisibilityListingWrite | 3083 | 780 | recruitmentPath, hasActiveBinding, currentPlayerId |
| validGroupRaidListingDelete | 3102 | 695 | recruitmentPath, recruitmentPath, recruitmentPath, currentPlayerId, hasActiveBinding, currentPlayerId |
| atomicCharacterSlot | 3118 | 754 |  |
| atomicCharacterDestinationFreeAt | 3134 | 217 |  |
| atomicCharacterPlacementMatches | 3140 | 1396 | atomicCharacterSlot, atomicCharacterSlot, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt, atomicCharacterDestinationFreeAt |
| validAtomicMemberCharacterChange | 3163 | 2282 | recruitmentPath, recruitmentPath, deCurrentOwnership, hasActiveBinding, currentPlayerId, atomicCharacterPlacementMatches, ownsActiveCharacter, atomicRaidStateDocPath, atomicRaidStateDocPath, atomicRaidStateDocPath, deBlockingClaim |
| validMemberCharacterChange | 3212 | 3161 | recruitmentPath, recruitmentSlotPath, recruitmentSlotPath, hasActiveBinding, currentPlayerId, ownsActiveCharacter, assignmentPath, assignmentPath, assignmentPath, assignmentPath, assignmentPath, assignmentPath, assignmentPath, hasWeeklyRaidCompletionAfter |
| validApprovalPermissionChange | 3277 | 500 | recruitmentPath, hasActiveBinding, currentPlayerId, currentPlayerId |
| atomicPositionSlotAt | 3289 | 260 |  |
| atomicPositionInSlots | 3296 | 681 | atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt, atomicPositionSlotAt |
| validMemberPositionChange | 3307 | 1179 | recruitmentPath, recruitmentPath, hasActiveBinding, currentPlayerId, currentPlayerId, atomicPositionInSlots, atomicPositionInSlots |
| validEventTiming | 3332 | 221 |  |
| validManualVerificationDisputeEvent | 3343 | 1310 | isActiveOperator, validEventTiming |
| validPendingApplication | 3371 | 1301 | recruitmentPath, deApplicationGeneration, hasActiveBinding, currentPlayerId, canAccessRecruitmentByAudience, ownsActiveCharacter, deAvailablePriorState, deBlockingClaim |
| validApplicantWithdrawal | 3401 | 622 | hasActiveBinding, currentPlayerId |
| validOrphanApplicationDelete | 3416 | 492 | recruitmentPath, hasActiveBinding, currentPlayerId |
| validApplicationWeeklyCompletion | 3429 | 826 | hasActiveBinding, currentPlayerId, hasWeeklyRaidCompletionAfter, recruitmentPath |
| validApplicationReapply | 3451 | 2532 | recruitmentPath, deApplicationGeneration, hasActiveBinding, currentPlayerId, groupMemberPath, canAccessRecruitmentByAudience, ownsActiveCharacter, deAvailablePriorState, deBlockingClaim |
| validManualWeeklyRaidClaimCreate | 3503 | 1561 | hasActiveBinding, currentPlayerId, weeklyRaidClaimId, ownsActiveCharacter, assignmentPath |
| validManualWeeklyRaidClaimDelete | 3541 | 702 | deManualCurrentOwnership, hasActiveBinding, currentPlayerId, weeklyRaidClaimId |
| validApplicationDecision | 3560 | 1144 | recruitmentMemberPath, hasActiveBinding, canApproveApplications |
| canListRecruitment | 3587 | 224 | hasActiveBinding, currentPlayerId, currentPlayerId |
| canReadRecruitment | 3594 | 233 | hasActiveBinding, canAccessRecruitmentByAudience, currentPlayerId, currentPlayerId |
| canGetRecruitment | 3603 | 182 | hasActiveBinding, recruitmentPath, canReadRecruitment |
| canReadPrivateRecruitmentData | 3609 | 283 | recruitmentPath, hasActiveBinding, currentPlayerId, currentPlayerId |
| canReadPublicRecruitmentMembers | 3618 | 250 | hasActiveBinding, recruitmentPath, canAccessRecruitmentByAudience, recruitmentPath |
| canGetRecruitmentApplication | 3628 | 319 | hasActiveBinding, recruitmentApplicationPath, canReadPrivateRecruitmentData, currentPlayerId |
| validActiveBinding | 3635 | 425 |  |
| validActivePlayer | 3651 | 392 |  |
| validPlayerLastSeenUpdate | 3666 | 300 | hasActiveBinding, currentPlayerId |
| validLegacyLastSeenBackfill | 3674 | 255 | isActiveOperator |
| changesRepresentativeCharacter | 3681 | 214 |  |
| representativeCharacterOwned | 3688 | 414 | characterPath |
| oldRepresentativeCharacterId | 3697 | 180 |  |
| validRepresentativeCharacterSeed | 3703 | 637 | oldRepresentativeCharacterId, hasActiveBinding, currentPlayerId, representativeCharacterOwned |
| validRepresentativeCharacterUpdate | 3718 | 981 | oldRepresentativeCharacterId, hasActiveBinding, currentPlayerId, representativeCharacterOwned |
| playerGameAccountPath | 3741 | 163 |  |
| characterActivityPath | 3745 | 161 |  |
| ownedActiveCharacterMatches | 3749 | 348 | characterPath |
| ownedActiveGameAccount | 3757 | 345 | playerGameAccountPath |
| representativeActivityCovered | 3765 | 617 | playerGameAccountPath, characterActivityPath |
| validCharacterActivityWrite | 3778 | 859 | hasActiveBinding, currentPlayerId, ownedActiveCharacterMatches, ownedActiveGameAccount, representativeActivityCovered |
| validCharacterActivityDelete | 3801 | 637 | playerGameAccountPath, hasActiveBinding, currentPlayerId |
| validManualVerificationCode | 4060 | 151 |  |
| manualVerificationAccountOwnedBy | 4065 | 465 |  |
| manualVerificationRequesterAlreadyOwns | 4075 | 669 | manualVerificationAccountOwnedBy, manualVerificationAccountOwnedBy |
| validManualVerificationCreate | 4093 | 1799 | hasActiveBinding, currentPlayerId, validManualVerificationCode, manualVerificationRequesterAlreadyOwns, currentPlayerId |
| manualVerificationOperatorContextUnchanged | 4128 | 212 |  |
| validManualVerificationOperatorReviewBody | 4133 | 1673 | manualVerificationOperatorContextUnchanged, validManualVerificationDefenseApprove |
| validManualVerificationDisputeOpenBody | 4174 | 1070 | manualVerificationOperatorContextUnchanged |
| validManualVerificationDisputeDefendedBody | 4196 | 553 |  |
| validManualVerificationOperatorForceBody | 4209 | 874 |  |
| validManualVerificationOperatorWrite | 4228 | 612 | isActiveOperator, currentPlayerId, validManualVerificationOperatorReviewBody, validManualVerificationDisputeOpenBody, validManualVerificationDisputeDefendedBody, validManualVerificationOperatorForceBody |
| unchangedManualVerificationIdentity | 4243 | 535 |  |
| validManualVerificationRequesterCancel | 4253 | 584 | hasActiveBinding, currentPlayerId, unchangedManualVerificationIdentity |
| validManualVerificationReissue | 4267 | 890 | hasActiveBinding, currentPlayerId, unchangedManualVerificationIdentity, validManualVerificationCode |
| validManualVerificationDefenseApprove | 4286 | 589 |  |
| validManualVerificationDisputeTransfer | 4300 | 564 | hasActiveBinding |
| validManualVerificationBlockWrite | 4313 | 608 | isActiveOperator, currentPlayerId |
| canGetManualVerificationBlock | 4330 | 366 | hasActiveBinding, isActiveOperator, currentPlayerId |
| dePersonalCommand | 4386 | 205 | recruitmentPath |
| dePersonalCompletionBoundary | 4390 | 1600 | recruitmentMemberPath, atomicRaidStatePath, atomicCharacterSlot, recruitmentMemberPath, dePersonalCompletionListing |
| dePersonalCompletionListing | 4412 | 344 |  |
| deManualCurrentOwnership | 4417 | 317 | characterPath, deCurrentOwnership |
| deManualAssignmentAvailable | 4422 | 275 | assignmentPath, deOlderRecord |
| deOlderRecord | 4427 | 312 |  |
| deOlderState | 4432 | 251 | deOlderRecord |
| deAvailablePriorState | 4436 | 257 | raidStatePath, deOlderState |
| deBlockingClaim | 4440 | 278 | weeklyRaidClaimPath, deOlderRecord |
| deFreshParticipation | 4444 | 818 | recruitmentPath, recruitmentMemberPath |
| deReplacePriorState | 4456 | 354 | deOlderState, deFreshParticipation, validAtomicRaidStateCreate |
| deApplicationGeneration | 4462 | 213 | deCurrentOwnership |
| deApprovedGeneration | 4466 | 363 |  |
| deSlotMemberGeneration | 4471 | 432 |  |
| deChangedSlotGenerationAt | 4477 | 247 | deSlotMemberGeneration |
| deChangedSlotGenerations | 4481 | 610 | deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt, deChangedSlotGenerationAt |
| deValidGeneration | 4489 | 280 |  |
| deGenerationUpdate | 4496 | 381 | deValidGeneration, deValidGeneration |
| deCharacterGeneration | 4504 | 354 | deValidGeneration, deValidGeneration |
