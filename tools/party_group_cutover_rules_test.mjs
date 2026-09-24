import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  query,
  runTransaction,
  serverTimestamp,
  deleteField,
  increment,
  arrayUnion,
  Timestamp,
  where,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Full production-source regression runs only against a demo Emulator project.
// It never authenticates to or deploys into the production Firebase project.
const PROJECT_ID = 'demo-party-group-cutover';
const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

const authUid = 'owner-auth';
const playerId = 'player-1';
const characterId = 'charabcdefghijklmnop'; // 20 chars
const gameAccountId = 'account-1';
const joinerAuthUid = 'joiner-auth';
const joinerPlayerId = 'player-2';
const joinerCharacterId = 'charqrstuvwxyzabcdef';
const joinCode = 'ABCD23';
const recruitmentId = 'recruitment-1';
const raidId = 'valtan';
const cycleKey = currentCycleKey();

function currentCycleKey(now = new Date()) {
  const utcOffsetMs = 9 * 60 * 60 * 1000;
  const local = new Date(now.getTime() + utcOffsetMs);
  const midnight = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate());
  const weekday = new Date(midnight).getUTCDay(); // 0 Sun .. 3 Wed
  const resetWeekday = 3;
  const days = (weekday - resetWeekday + 7) % 7;
  let start = midnight - days * 86400000 + 6 * 3600000;
  const localMs = local.getTime();
  if (localMs < start) start -= 7 * 86400000;
  const startLocal = new Date(start);
  const y = startLocal.getUTCFullYear();
  const m = String(startLocal.getUTCMonth() + 1).padStart(2, '0');
  const d = String(startLocal.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function cycleWindow(key) {
  const [y, m, d] = key.split('-').map(Number);
  const localStart = Date.UTC(y, m - 1, d, 6, 0, 0);
  const startedAt = new Date(localStart - 9 * 3600000);
  const endsAt = new Date(startedAt.getTime() + 7 * 86400000);
  return { startedAt, endsAt };
}

async function seedBase(testEnv, { membershipState = null, weeklyClaim = false } = {}) {
  const now = Timestamp.now();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'authBindings', authUid), {
      schemaVersion: 1,
      playerId,
      status: 'active',
      linkedAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'players', playerId), {
      schemaVersion: 1,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'characters', characterId), {
      schemaVersion: 1,
      status: 'active',
      ownerPlayerId: playerId,
      gameAccountId,
      characterName: '테스트',
      serverName: '루페온',
      characterClassName: '버서커',
      itemAvgLevel: 1700,
    });
    await setDoc(doc(db, 'playerGameAccounts', `${playerId}_${gameAccountId}`), {
      schemaVersion: 1,
      playerId,
      gameAccountId,
      status: 'active',
      representativeCharacterId: characterId,
      updatedAt: now,
    });
    if (membershipState != null) {
      await setDoc(
        doc(db, 'players', playerId, 'groupMembershipState', 'current'),
        membershipState,
      );
    }
    if (weeklyClaim) {
      const claimId = `${cycleKey}_${characterId}_${raidId}`;
      await setDoc(doc(db, 'players', playerId, 'weeklyRaidClaims', claimId), {
        schemaVersion: 1,
        playerId,
        characterId,
        raidId,
        cycleKey,
        source: 'manual',
        completedAt: now,
        updatedAt: now,
      });
    }
  });
}

async function seedApplicationForCleanup(testEnv, id, { parentStatus } = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    if (parentStatus != null) {
      await setDoc(doc(adminDb, 'recruitments', id), { status: parentStatus });
    }
    await setDoc(doc(adminDb, 'recruitments', id, 'applications', playerId), {
      schemaVersion: 1,
      recruitmentId: id,
      applicantPlayerId: playerId,
      status: 'pending',
    });
  });
}

async function createGroupTxn(db, groupId) {
  return runTransaction(db, async (tx) => {
    const groupRef = doc(db, 'groups', groupId);
    const memberRef = doc(db, 'groups', groupId, 'members', playerId);
    const stateRef = doc(db, 'players', playerId, 'groupMembershipState', 'current');
    const relationRef = doc(db, 'players', playerId, 'groupRelations', groupId);
    const stateSnap = await tx.get(stateRef);
    const previousIds = stateSnap.exists()
      ? stateSnap.data().activeGroupIds ?? []
      : [];
    const previousRevision = stateSnap.exists()
      ? stateSnap.data().revision ?? 0
      : 0;
    const activeGroupIds = [...previousIds, groupId];
    tx.set(groupRef, {
      schemaVersion: 1,
      status: 'active',
      name: '테스트의 그룹',
      normalizedName: '테스트의그룹',
      representativeCharacterId: characterId,
      representativeCharacterNameSnapshot: '테스트',
      normalizedRepresentativeCharacterName: '테스트',
      representativeServerNameSnapshot: '루페온',
      leaderPlayerId: playerId,
      leaderDisplayCharacterNameSnapshot: '테스트',
      memberCount: 1,
      activeRecruitmentCount: 0,
      revision: 1,
      hasActiveJoinCode: false,
      joinCodeVisibleToMembers: false,
      lastActivityAt: serverTimestamp(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      deletedAt: null,
    });
    tx.set(memberRef, {
      schemaVersion: 1,
      groupId,
      playerId,
      role: 'leader',
      joinedAt: serverTimestamp(),
      joinSequence: 1,
      joinedBy: 'created',
      displayCharacterIdSnapshot: characterId,
      displayCharacterNameSnapshot: '테스트',
      displayClassNameSnapshot: '버서커',
      itemLevelSnapshot: 1700,
      combatPowerSnapshot: null,
      gemValidationSnapshot: null,
      revision: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    tx.set(stateRef, {
      schemaVersion: 1,
      playerId,
      activeGroupIds,
      activeGroupCount: activeGroupIds.length,
      revision: previousRevision + 1,
      updatedAt: serverTimestamp(),
    });
    tx.set(relationRef, {
      schemaVersion: 1,
      groupId,
      playerId,
      relation: 'member',
      requestStatus: null,
      groupNameSnapshot: '테스트의 그룹',
      displayCharacterNameSnapshot: '테스트',
      expiresAt: null,
      sourceRevision: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  });
}

function offsetCycleKey(key, days) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10);
}

async function seedJoiner(testEnv, { membershipState = null } = {}) {
  const now = Timestamp.now();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'authBindings', joinerAuthUid), {
      schemaVersion: 1, playerId: joinerPlayerId, status: 'active',
      linkedAt: now, updatedAt: now,
    });
    await setDoc(doc(db, 'players', joinerPlayerId), {
      schemaVersion: 1, status: 'active', createdAt: now, updatedAt: now,
    });
    await setDoc(doc(db, 'characters', joinerCharacterId), {
      schemaVersion: 1, status: 'active', ownerPlayerId: joinerPlayerId,
      gameAccountId: 'account-2', characterName: '가입자', serverName: '루페온',
      characterClassName: '바드', itemAvgLevel: 1700,
    });
    if (membershipState != null) {
      await setDoc(
        doc(db, 'players', joinerPlayerId, 'groupMembershipState', 'current'),
        membershipState,
      );
    }
  });
}

async function applyToGroupTxn(db, groupId) {
  return runTransaction(db, async (tx) => {
    const groupRef = doc(db, 'groups', groupId);
    const relationRef = doc(db, 'groups', groupId, 'joinRelations', joinerPlayerId);
    const statsRef = doc(db, 'groups', groupId, 'applicantStats', joinerPlayerId);
    const playerRelationRef = doc(db, 'players', joinerPlayerId, 'groupRelations', groupId);
    const stateRef = doc(db, 'players', joinerPlayerId, 'groupMembershipState', 'current');
    const characterRef = doc(db, 'characters', joinerCharacterId);
    const group = (await tx.get(groupRef)).data();
    await tx.get(stateRef);
    await tx.get(characterRef);
    await tx.get(relationRef);
    await tx.get(statsRef);
    const expiresAt = Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000);
    tx.set(relationRef, {
      schemaVersion: 1, groupId, targetPlayerId: joinerPlayerId,
      kind: 'application', status: 'pending', requestedByPlayerId: joinerPlayerId,
      characterIdSnapshot: joinerCharacterId,
      characterNameSnapshot: '가입자', serverNameSnapshot: '루페온',
      characterClassNameSnapshot: '바드', itemLevelSnapshot: 1700,
      combatPowerSnapshot: null, gemValidationSnapshot: null,
      applicationAttempt: 1, revision: 1,
      createdAt: serverTimestamp(), expiresAt, decidedAt: null,
      updatedAt: serverTimestamp(),
    });
    tx.set(statsRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId,
      applicationCount: 1, lastCharacterNameSnapshot: '가입자',
      lastItemLevelSnapshot: 1700, lastCombatPowerSnapshot: null,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(playerRelationRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId,
      relation: 'applied', requestStatus: 'pending',
      groupNameSnapshot: group.name,
      displayCharacterNameSnapshot: '가입자', expiresAt,
      sourceRevision: 1, createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    tx.update(groupRef, {
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
  });
}

async function approveGroupApplicationTxn(db, groupId) {
  return runTransaction(db, async (tx) => {
    const groupRef = doc(db, 'groups', groupId);
    const relationRef = doc(db, 'groups', groupId, 'joinRelations', joinerPlayerId);
    const memberRef = doc(db, 'groups', groupId, 'members', joinerPlayerId);
    const stateRef = doc(db, 'players', joinerPlayerId, 'groupMembershipState', 'current');
    const playerRelationRef = doc(db, 'players', joinerPlayerId, 'groupRelations', groupId);
    const group = (await tx.get(groupRef)).data();
    const relation = (await tx.get(relationRef)).data();
    await tx.get(memberRef);
    tx.update(relationRef, {
      status: 'accepted', revision: relation.revision + 1,
      decidedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(memberRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId, role: 'member',
      joinedAt: serverTimestamp(), joinSequence: group.memberCount + 1,
      joinedBy: 'application', displayCharacterIdSnapshot: joinerCharacterId,
      displayCharacterNameSnapshot: '가입자', displayClassNameSnapshot: '바드',
      itemLevelSnapshot: 1700, combatPowerSnapshot: null,
      gemValidationSnapshot: null, revision: 1,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(stateRef, {
      schemaVersion: 1, playerId: joinerPlayerId,
      activeGroupIds: arrayUnion(groupId),
      activeGroupCount: increment(1), revision: increment(1),
      updatedAt: serverTimestamp(),
    }, { merge: true });
    tx.set(playerRelationRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId,
      relation: 'member', requestStatus: 'accepted',
      groupNameSnapshot: group.name,
      displayCharacterNameSnapshot: relation.characterNameSnapshot,
      expiresAt: null, sourceRevision: 1,
      updatedAt: serverTimestamp(),
    }, { merge: true });
    tx.update(groupRef, {
      memberCount: group.memberCount + 1, revision: group.revision + 1,
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
  });
}

async function createJoinCodeTxn(db, groupId) {
  return runTransaction(db, async (tx) => {
    const groupRef = doc(db, 'groups', groupId);
    const codeRef = doc(db, 'groupJoinCodes', joinCode);
    const group = (await tx.get(groupRef)).data();
    await tx.get(codeRef);
    tx.set(codeRef, {
      schemaVersion: 1, groupId, status: 'active', createdByPlayerId: playerId,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.update(groupRef, {
      hasActiveJoinCode: true, activeJoinCode: joinCode,
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
  });
}

async function joinByCodeTxn(db) {
  return runTransaction(db, async (tx) => {
    const code = (await tx.get(doc(db, 'groupJoinCodes', joinCode))).data();
    const groupId = code.groupId;
    const groupRef = doc(db, 'groups', groupId);
    const stateRef = doc(db, 'players', joinerPlayerId, 'groupMembershipState', 'current');
    const memberRef = doc(db, 'groups', groupId, 'members', joinerPlayerId);
    const joinRelationRef = doc(db, 'groups', groupId, 'joinRelations', joinerPlayerId);
    const playerRelationRef = doc(db, 'players', joinerPlayerId, 'groupRelations', groupId);
    const group = (await tx.get(groupRef)).data();
    await tx.get(stateRef);
    await tx.get(doc(db, 'characters', joinerCharacterId));
    await tx.get(joinRelationRef);
    await tx.get(playerRelationRef);
    tx.set(memberRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId, role: 'member',
      joinedAt: serverTimestamp(), joinSequence: group.memberCount + 1,
      joinedBy: 'joinCode', displayCharacterIdSnapshot: joinerCharacterId,
      displayCharacterNameSnapshot: '가입자', displayClassNameSnapshot: '바드',
      itemLevelSnapshot: 1700, combatPowerSnapshot: null,
      gemValidationSnapshot: null, revision: 1,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(stateRef, {
      schemaVersion: 1, playerId: joinerPlayerId, activeGroupIds: [groupId],
      activeGroupCount: 1, revision: 1, updatedAt: serverTimestamp(),
    });
    tx.set(playerRelationRef, {
      schemaVersion: 1, groupId, playerId: joinerPlayerId, relation: 'member',
      requestStatus: null, groupNameSnapshot: group.name,
      displayCharacterNameSnapshot: '가입자', expiresAt: null,
      sourceRevision: 1, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.update(groupRef, {
      memberCount: group.memberCount + 1, revision: group.revision + 1,
      lastActivityAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
  });
}

async function createPublicRecruitmentTxn(db, { id = recruitmentId, replaceStale = false } = {}) {
  const { startedAt, endsAt } = cycleWindow(cycleKey);
  const stateId = `${characterId}_${raidId}`;
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', id);
    const memberRef = doc(db, 'recruitments', id, 'members', playerId);
    const raidStateRef = doc(db, 'players', playerId, 'raidStates', stateId);
    const eventId = `partyCreated_${id}_1`;
    const eventRef = doc(db, 'partyEvents', eventId);

    if (replaceStale) tx.delete(raidStateRef);
    tx.set(recruitmentRef, {
      schemaVersion: 2,
      recruitmentId: id,
      title: '공개 모집',
      leaderPlayerId: playerId,
      leaderCharacterNameSnapshot: '테스트',
      leaderClassNameSnapshot: '버서커',
      memberPlayerIds: [playerId],
      raidCatalogVersion: 1,
      raidId,
      difficultyId: 'normal',
      raidNameSnapshot: '발탄',
      difficultyNameSnapshot: '노말',
      difficultyAliasSnapshot: '노말',
      gateCount: 2,
      minItemLevel: 1415,
      minCombatPower: null,
      experienceLevel: null,
      maxPlayHours: null,
      raidStartAt: null,
      status: 'active',
      visibility: 'public',
      groupId: null,
      approvalPolicy: { mode: 'leaderOnly' },
      continueTogether: false,
      manualRecruitmentEnabled: true,
      hasAvailableSlot: true,
      currentCycleKey: cycleKey,
      targetCycleKey: cycleKey,
      currentCycleStatus: 'active',
      cycleStartedAt: Timestamp.fromDate(startedAt),
      cycleEndsAt: Timestamp.fromDate(endsAt),
      partyCount: 1,
      membersPerParty: 4,
      supportsPerParty: 1,
      maxDealersPerClassPerParty: 1,
      slotLedgerVersion: 2,
      memberCount: 1,
      maxMemberCount: 4,
      dealerCount: 1,
      supportCount: 0,
      revision: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      completedAt: null,
      completedByPlayerId: null,
      partySlots: [
        {
          playerId,
          characterId,
          role: 'dealer',
          classKey: '버서커',
          partyIndex: 0,
          slotIndex: 0,
          countedAsNonGroupMember: false,
        },
      ],
      nonGroupMemberCount: 0,
      pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0,
      raidStateTargets: [{ playerId, stateId }],
      commandTargets: [],
      groupActiveRecruitmentCountAfter: 0,
      lastCommandId: null,
      lastCommandType: null,
      lastCommandActorPlayerId: null,
      lastCommandAt: null,
    });
    tx.set(memberRef, {
      schemaVersion: 1,
      playerId,
      characterId,
      characterNameSnapshot: '테스트',
      classNameSnapshot: '버서커',
      role: 'dealer',
      partyIndex: 0,
      slotIndex: 0,
      joinedAt: serverTimestamp(),
      joinedBy: playerId,
      submittedBuildSnapshotId: null,
      itemLevelSnapshot: 1700,
      combatPowerSnapshot: null,
      gemValidationSnapshot: null,
      buildIntegritySnapshot: null,
      characterChangedAt: null,
      canApproveApplications: true,
      updatedAt: serverTimestamp(),
    });
    tx.set(raidStateRef, {
      schemaVersion: 1,
      playerId,
      characterId,
      raidId,
      recruitmentId: id,
      cycleKey,
      role: 'dealer',
      status: 'active',
      source: 'party',
      revision: 1,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    tx.set(eventRef, {
      schemaVersion: 1,
      eventId,
      recruitmentId: id,
      type: 'partyCreated',
      commandId: eventId,
      commandRevision: 1,
      audiencePlayerIds: [playerId],
      actorPlayerId: playerId,
      occurredAt: serverTimestamp(),
    });
  });
}

// F2-A: mirror the connected atomic application repository's public-room writes.
async function applicationTxn(db, action, { countedAsNonGroup = false } = {}) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const applicationRef = doc(db, 'recruitments', recruitmentId, 'applications', joinerPlayerId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    const application = (await tx.get(applicationRef)).data();
    const nextRevision = recruitment.revision + 1;
    const isWithdraw = action === 'withdraw';
    const eventType = isWithdraw ? 'applicationWithdrawn' : 'applicationSubmitted';
    if (isWithdraw) {
      tx.update(applicationRef, {
        status: 'withdrawn', resolutionReason: 'withdrawnByApplicant',
        revision: application.revision + 1, decidedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    } else {
      const pending = {
        cycleKey, characterId: joinerCharacterId,
        characterNameSnapshot: '가입자', classNameSnapshot: '바드',
        requestedRole: 'support',
        submittedBuildSnapshot: { itemLevel: 1700, combatPower: null, buildIntegritySnapshot: null },
        status: 'pending', resolutionReason: null, approvalCount: 0,
        revision: application ? application.revision + 1 : 1,
        decidedAt: null, updatedAt: serverTimestamp(),
        countedAsNonGroupApplicant: countedAsNonGroup,
      };
      if (application) {
        tx.update(applicationRef, pending);
      } else {
        tx.set(applicationRef, {
          schemaVersion: 1, recruitmentId, applicantPlayerId: joinerPlayerId,
          rejectionCount: 0, createdAt: serverTimestamp(), ...pending,
        });
      }
    }
    tx.update(recruitmentRef, {
      pendingApplicationCount: recruitment.pendingApplicationCount + (isWithdraw ? -1 : 1),
      pendingNonGroupApplicantCount: recruitment.pendingNonGroupApplicantCount
        + (isWithdraw ? -(application.countedAsNonGroupApplicant ? 1 : 0)
          : (countedAsNonGroup ? 1 : 0)),
      revision: nextRevision, updatedAt: serverTimestamp(),
    });
    const eventId = `${eventType}_${recruitmentId}_${nextRevision}`;
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: eventType,
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: [playerId, joinerPlayerId],
      actorPlayerId: joinerPlayerId, occurredAt: serverTimestamp(),
    });
  });
}

async function deleteOldRaidStateTxn(db) {
  return runTransaction(db, async (tx) => {
    const oldRef = doc(db, 'recruitments', recruitmentId);
    const stateRef = doc(db, 'players', playerId, 'raidStates', `${characterId}_${raidId}`);
    const oldRoom = (await tx.get(oldRef)).data();
    const oldState = (await tx.get(stateRef)).data();
    if (oldState.recruitmentId !== recruitmentId || oldRoom.recruitmentId !== recruitmentId) {
      throw new Error('Stale fixture points to an unexpected recruitment');
    }
    tx.delete(stateRef);
  });
}

async function approvePublicApplicationTxn(db) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const applicationRef = doc(db, 'recruitments', recruitmentId, 'applications', joinerPlayerId);
    const characterRef = doc(db, 'characters', joinerCharacterId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', joinerPlayerId);
    const stateId = `${joinerCharacterId}_${raidId}`;
    const stateRef = doc(db, 'players', joinerPlayerId, 'raidStates', stateId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    const application = (await tx.get(applicationRef)).data();
    const character = (await tx.get(characterRef)).data();
    if (application.status !== 'pending' || character.ownerPlayerId !== joinerPlayerId) {
      throw new Error('Approval fixture is not pending or character ownership differs');
    }
    const nextRevision = recruitment.revision + 1;
    const eventId = `memberJoined_${recruitmentId}_${nextRevision}`;
    tx.update(recruitmentRef, {
      memberPlayerIds: [...recruitment.memberPlayerIds, joinerPlayerId],
      memberCount: 2, dealerCount: 1, supportCount: 1, hasAvailableSlot: true,
      partySlots: [...recruitment.partySlots, {
        playerId: joinerPlayerId, characterId: joinerCharacterId,
        role: 'support', classKey: '바드', partyIndex: 0, slotIndex: 3,
        countedAsNonGroupMember: false,
      }],
      raidStateTargets: [...recruitment.raidStateTargets, {
        playerId: joinerPlayerId, stateId,
      }],
      nonGroupMemberCount: 0, pendingApplicationCount: 0,
      pendingNonGroupApplicantCount: 0, revision: nextRevision,
      updatedAt: serverTimestamp(),
    });
    tx.update(applicationRef, {
      status: 'approved', resolutionReason: 'approvedByApprover',
      approvalCount: application.approvalCount + 1,
      revision: application.revision + 1, decidedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    tx.set(memberRef, {
      schemaVersion: 1, playerId: joinerPlayerId, characterId: joinerCharacterId,
      characterNameSnapshot: '가입자', classNameSnapshot: '바드',
      role: 'support', partyIndex: 0, slotIndex: 3,
      joinedAt: serverTimestamp(), joinedBy: playerId,
      submittedBuildSnapshotId: null, itemLevelSnapshot: 1700,
      combatPowerSnapshot: null, gemValidationSnapshot: null,
      buildIntegritySnapshot: null, characterChangedAt: null,
      canApproveApplications: false, updatedAt: serverTimestamp(),
    });
    tx.set(stateRef, {
      schemaVersion: 1, playerId: joinerPlayerId,
      characterId: joinerCharacterId, raidId, difficultyId: 'normal',
      recruitmentId, cycleKey, role: 'support', status: 'active',
      source: 'party', revision: 1,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'memberJoined',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: [playerId, joinerPlayerId],
      actorPlayerId: playerId, occurredAt: serverTimestamp(),
    });
  });
}

async function repositionApprovedMemberTxn(db, destinationSlotIndex = 2, memberSlotIndex = destinationSlotIndex) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', joinerPlayerId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    await tx.get(memberRef);
    const nextRevision = recruitment.revision + 1;
    const eventId = `membersRepositioned_${recruitmentId}_${nextRevision}`;
    tx.update(recruitmentRef, {
      partySlots: recruitment.partySlots.map((slot) => slot.playerId === joinerPlayerId
        ? { ...slot, slotIndex: destinationSlotIndex } : slot),
      revision: nextRevision, updatedAt: serverTimestamp(),
    });
    tx.update(memberRef, { slotIndex: memberSlotIndex, updatedAt: serverTimestamp() });
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'membersRepositioned',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: [playerId, joinerPlayerId], actorPlayerId: playerId,
      occurredAt: serverTimestamp(),
    });
  });
}

async function removeApprovedMemberTxn(
  db,
  actorPlayerId,
  { tamperListingCount = false } = {},
) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', joinerPlayerId);
    const stateRef = doc(db, 'players', joinerPlayerId, 'raidStates', `${joinerCharacterId}_${raidId}`);
    const recruitment = (await tx.get(recruitmentRef)).data();
    await tx.get(memberRef);
    const nextRevision = recruitment.revision + 1;
    const selfLeave = actorPlayerId === joinerPlayerId;
    const eventType = selfLeave ? 'memberLeft' : 'memberKicked';
    const eventId = `${eventType}_${recruitmentId}_${nextRevision}`;
    tx.update(recruitmentRef, {
      memberPlayerIds: [playerId], memberCount: 1, dealerCount: 1,
      supportCount: 0, partySlots: recruitment.partySlots.filter((slot) => slot.playerId !== joinerPlayerId),
      raidStateTargets: recruitment.raidStateTargets.filter((target) => target.playerId !== joinerPlayerId),
      nonGroupMemberCount: 0, hasAvailableSlot: true,
      revision: nextRevision, updatedAt: serverTimestamp(),
    });
    tx.delete(memberRef);
    tx.delete(stateRef);
    if (recruitment.visibility === 'group') {
      tx.update(
        doc(db, 'groups', recruitment.groupId, 'raidListings', recruitmentId),
        {
          memberCount: tamperListingCount ? 7 : 1,
          sourceRevision: nextRevision,
          updatedAt: serverTimestamp(),
        },
      );
    }
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: eventType,
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: [playerId, joinerPlayerId], actorPlayerId,
      targetPlayerId: joinerPlayerId, occurredAt: serverTimestamp(),
    });
  });
}

async function kickApprovedMemberTxn(db, options = {}) {
  return removeApprovedMemberTxn(db, playerId, options);
}

async function leaveApprovedRoomTxn(db, options = {}) {
  return removeApprovedMemberTxn(db, joinerPlayerId, options);
}

async function directRejoinAfterKickTxn(db, { tamperListing = false } = {}) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', joinerPlayerId);
    const stateId = `${joinerCharacterId}_${raidId}`;
    const stateRef = doc(db, 'players', joinerPlayerId, 'raidStates', stateId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    await tx.get(doc(db, 'characters', joinerCharacterId));
    await tx.get(stateRef);
    const nextRevision = recruitment.revision + 1;
    const eventId = `memberJoined_${recruitmentId}_${nextRevision}`;
    const recruitmentPatch = {
      memberPlayerIds: [...recruitment.memberPlayerIds, joinerPlayerId],
      memberCount: 2, dealerCount: 1, supportCount: 1, hasAvailableSlot: true,
      partySlots: [...recruitment.partySlots, {
        playerId: joinerPlayerId, characterId: joinerCharacterId,
        role: 'support', classKey: '바드', partyIndex: 0, slotIndex: 3,
        countedAsNonGroupMember: false,
      }],
      raidStateTargets: [...recruitment.raidStateTargets, {
        playerId: joinerPlayerId, stateId,
      }],
      nonGroupMemberCount: 0, revision: nextRevision,
      updatedAt: serverTimestamp(),
    };
    tx.update(recruitmentRef, recruitmentPatch);
    tx.set(memberRef, {
      schemaVersion: 1, playerId: joinerPlayerId, characterId: joinerCharacterId,
      characterNameSnapshot: '가입자', classNameSnapshot: '바드',
      role: 'support', partyIndex: 0, slotIndex: 3,
      joinedAt: serverTimestamp(), joinedBy: joinerPlayerId,
      submittedBuildSnapshotId: null, itemLevelSnapshot: 1700,
      combatPowerSnapshot: null, gemValidationSnapshot: null,
      buildIntegritySnapshot: null, characterChangedAt: null,
      canApproveApplications: false, updatedAt: serverTimestamp(),
    });
    tx.set(stateRef, {
      schemaVersion: 1, playerId: joinerPlayerId,
      characterId: joinerCharacterId, raidId, difficultyId: 'normal',
      recruitmentId, cycleKey, role: 'support', status: 'active',
      source: 'party', revision: 1,
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    if (recruitment.visibility === 'group') {
      const listingPatch = {
        ...recruitmentPatch,
        sourceRevision: nextRevision,
      };
      if (tamperListing) listingPatch.memberCount = 7;
      tx.update(
        doc(db, 'groups', recruitment.groupId, 'raidListings', recruitmentId),
        listingPatch,
      );
    }
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'memberJoined',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: [playerId, joinerPlayerId],
      actorPlayerId: joinerPlayerId, occurredAt: serverTimestamp(),
    });
  });
}

async function seedExpandedApprovedRoom(testEnv, totalMembers) {
  if (totalMembers !== 4 && totalMembers !== 8) throw new Error('Unsupported boundary fixture');
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const recruitmentRef = doc(adminDb, 'recruitments', recruitmentId);
    const recruitment = (await getDoc(recruitmentRef)).data();
    const addedSlots = [];
    const addedTargets = [];
    const addedIds = [];
    for (let index = 1; index <= totalMembers - 2; index += 1) {
      const extraPlayerId = `player-extra-${index}`;
      const extraCharacterId = `character-extra-${index}`;
      const partyIndex = index <= 2 ? 0 : 1;
      const slotIndex = index <= 2 ? index : index - 3;
      const role = totalMembers === 8 && index === 6 ? 'support' : 'dealer';
      const stateId = `${extraCharacterId}_${raidId}`;
      const slot = {
        playerId: extraPlayerId, characterId: extraCharacterId,
        role, classKey: `class-${index}`, partyIndex, slotIndex,
        countedAsNonGroupMember: false,
      };
      addedIds.push(extraPlayerId);
      addedSlots.push(slot);
      addedTargets.push({ playerId: extraPlayerId, stateId });
      await setDoc(doc(adminDb, 'recruitments', recruitmentId, 'members', extraPlayerId), {
        schemaVersion: 1, playerId: extraPlayerId, characterId: extraCharacterId,
        characterNameSnapshot: `추가 ${index}`, classNameSnapshot: `class-${index}`,
        role, partyIndex, slotIndex, joinedAt: Timestamp.now(),
        joinedBy: playerId, canApproveApplications: false, updatedAt: Timestamp.now(),
      });
      await setDoc(doc(adminDb, 'players', extraPlayerId, 'raidStates', stateId), {
        schemaVersion: 1, playerId: extraPlayerId, characterId: extraCharacterId,
        raidId, difficultyId: 'normal', recruitmentId, cycleKey,
        role, status: 'active', source: 'party', revision: 1,
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    }
    await updateDoc(recruitmentRef, {
      partyCount: totalMembers === 8 ? 2 : 1,
      maxMemberCount: totalMembers,
      memberPlayerIds: [...recruitment.memberPlayerIds, ...addedIds],
      memberCount: totalMembers,
      dealerCount: totalMembers === 8 ? 6 : 3,
      supportCount: totalMembers === 8 ? 2 : 1,
      hasAvailableSlot: false,
      partySlots: [...recruitment.partySlots, ...addedSlots],
      raidStateTargets: [...recruitment.raidStateTargets, ...addedTargets],
    });
  });
}

async function swapTwoDealersTxn(db) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const firstRef = doc(db, 'recruitments', recruitmentId, 'members', 'player-extra-1');
    const secondRef = doc(db, 'recruitments', recruitmentId, 'members', 'player-extra-2');
    const recruitment = (await tx.get(recruitmentRef)).data();
    await tx.get(firstRef);
    await tx.get(secondRef);
    const nextRevision = recruitment.revision + 1;
    const eventId = `membersRepositioned_${recruitmentId}_${nextRevision}`;
    tx.update(recruitmentRef, {
      partySlots: recruitment.partySlots.map((slot) => {
        if (slot.playerId === 'player-extra-1') return { ...slot, slotIndex: 2 };
        if (slot.playerId === 'player-extra-2') return { ...slot, slotIndex: 1 };
        return slot;
      }),
      revision: nextRevision, updatedAt: serverTimestamp(),
    });
    tx.update(firstRef, { slotIndex: 2, updatedAt: serverTimestamp() });
    tx.update(secondRef, { slotIndex: 1, updatedAt: serverTimestamp() });
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'membersRepositioned',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: recruitment.memberPlayerIds,
      actorPlayerId: playerId, occurredAt: serverTimestamp(),
    });
  });
}

async function seedGroupLinkedRoom(testEnv, db, {
  activeRecruitmentCount = 1,
  recruitmentCountSnapshot = 1,
  includeJoinerGroupMember = false,
} = {}) {
  const groupId = 'group-room-1';
  await assertSucceeds(createGroupTxn(db, groupId));
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await updateDoc(doc(adminDb, 'groups', groupId), { activeRecruitmentCount });
    const recruitmentRef = doc(adminDb, 'recruitments', recruitmentId);
    await updateDoc(recruitmentRef, {
      groupId, visibility: 'group',
      groupActiveRecruitmentCountAfter: recruitmentCountSnapshot,
    });
    const recruitment = (await getDoc(recruitmentRef)).data();
    await setDoc(
      doc(adminDb, 'groups', groupId, 'raidListings', recruitmentId),
      recruitment,
    );
    if (includeJoinerGroupMember) {
      await setDoc(doc(adminDb, 'groups', groupId, 'members', joinerPlayerId), {
        schemaVersion: 1, groupId, playerId: joinerPlayerId, role: 'member',
        joinedAt: Timestamp.now(), joinSequence: 2, joinedBy: 'application',
        displayCharacterIdSnapshot: joinerCharacterId,
        displayCharacterNameSnapshot: '가입자', displayClassNameSnapshot: '바드',
        itemLevelSnapshot: 1700, combatPowerSnapshot: null,
        gemValidationSnapshot: null, revision: 1,
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    }
  });
}

async function disbandApprovedRoomTxn(db, {
  recruitmentCountAfter = null,
  skipGroupUpdate = false,
} = {}) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    const groupRef = recruitment.groupId
      ? doc(db, 'groups', recruitment.groupId) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : null;
    const nextRevision = recruitment.revision + 1;
    const eventId = `disband_${recruitmentId}_${recruitment.revision}`;
    const completed = recruitment.currentCycleStatus === 'completed';
    tx.update(recruitmentRef, {
      status: 'disbanded', manualRecruitmentEnabled: false, hasAvailableSlot: false,
      commandTargets: completed ? [] : recruitment.raidStateTargets,
      ...(group ? {
        groupActiveRecruitmentCountAfter:
          recruitmentCountAfter ?? group.activeRecruitmentCount - 1,
      } : {}),
      revision: nextRevision, lastCommandId: eventId, lastCommandType: 'disband',
      lastCommandActorPlayerId: playerId,
      lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    if (!completed) {
      for (const target of recruitment.raidStateTargets) {
        tx.delete(doc(db, 'players', target.playerId, 'raidStates', target.stateId));
      }
    }
    if (groupRef && !skipGroupUpdate) {
      tx.update(groupRef, {
        activeRecruitmentCount: group.activeRecruitmentCount - 1,
        lastRecruitmentId: recruitmentId,
        revision: group.revision + 1,
        updatedAt: serverTimestamp(),
      });
      tx.delete(doc(db, 'groups', recruitment.groupId, 'raidListings', recruitmentId));
    }
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'disband',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: recruitment.memberPlayerIds, actorPlayerId: playerId,
      occurredAt: serverTimestamp(),
    });
  });
}

async function createManualRaidStateTxn(db) {
  const { startedAt, endsAt } = cycleWindow(cycleKey);
  const stateRef = doc(db, 'players', playerId, 'raidStates', `${characterId}_${raidId}`);
  return setDoc(stateRef, {
    schemaVersion: 1, playerId, characterId, raidId, difficultyId: 'normal',
    cycleKey, status: 'completed', source: 'manual', recruitmentId: null,
    revision: 1, cycleStartedAt: Timestamp.fromDate(startedAt),
    cycleEndsAt: Timestamp.fromDate(endsAt), completedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}

async function deleteCompletedRaidStateTxn(db, ownerPlayerId, ownerCharacterId) {
  return runTransaction(db, async (tx) => {
    tx.delete(doc(db, 'players', ownerPlayerId, 'raidStates', `${ownerCharacterId}_${raidId}`));
  });
}

async function cleanupOrphanRaidStateTxn(
  db,
  ownerPlayerId,
  ownerCharacterId,
  orphanRecruitmentId,
) {
  return runTransaction(db, async (tx) => {
    const stateRef = doc(
      db,
      'players',
      ownerPlayerId,
      'raidStates',
      `${ownerCharacterId}_${raidId}`,
    );
    const assignmentRef = doc(
      db,
      'players',
      ownerPlayerId,
      'activeRaidAssignments',
      `${ownerCharacterId}_${raidId}`,
    );
    const recruitmentRef = doc(db, 'recruitments', orphanRecruitmentId);
    await tx.get(stateRef);
    await tx.get(assignmentRef);
    await tx.get(recruitmentRef);
    tx.delete(stateRef);
    tx.delete(assignmentRef);
  });
}

async function seedOrphanRaidState(testEnv, orphanRecruitmentId) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    const now = Timestamp.now();
    const stateId = `${characterId}_${raidId}`;
    await setDoc(
      doc(adminDb, 'players', playerId, 'raidStates', stateId),
      {
        schemaVersion: 1,
        playerId,
        characterId,
        raidId,
        difficultyId: 'normal',
        cycleKey,
        status: 'active',
        source: 'party',
        recruitmentId: orphanRecruitmentId,
        revision: 1,
        createdAt: now,
        updatedAt: now,
      },
    );
    await setDoc(
      doc(adminDb, 'players', playerId, 'activeRaidAssignments', stateId),
      {
        schemaVersion: 1,
        playerId,
        characterId,
        raidId,
        difficultyId: 'normal',
        cycleKey,
        recruitmentId: orphanRecruitmentId,
        role: 'dealer',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      },
    );
  });
}

async function advanceCycleWithMissingStateTxn(db, nextCycleKey) {
  const { startedAt, endsAt } = cycleWindow(nextCycleKey);
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    const target = recruitment.raidStateTargets[0];
    const slot = recruitment.partySlots[0];
    const eventId = `advanceCycle_${recruitmentId}_${recruitment.revision}`;
    tx.update(recruitmentRef, {
      status: 'active', currentCycleStatus: 'active',
      currentCycleKey: nextCycleKey, targetCycleKey: nextCycleKey,
      cycleStartedAt: Timestamp.fromDate(startedAt),
      cycleEndsAt: Timestamp.fromDate(endsAt),
      completedAt: null, completedByPlayerId: null,
      commandTargets: recruitment.raidStateTargets,
      revision: recruitment.revision + 1,
      lastCommandId: eventId, lastCommandType: 'advanceCycle',
      lastCommandActorPlayerId: playerId,
      lastCommandAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(doc(db, 'players', target.playerId, 'raidStates', target.stateId), {
      schemaVersion: 1, playerId: slot.playerId,
      characterId: slot.characterId, raidId: recruitment.raidId,
      difficultyId: recruitment.difficultyId,
      recruitmentId, cycleKey: nextCycleKey, role: slot.role,
      status: 'active', source: 'party', revision: increment(1),
      completedAt: deleteField(), updatedAt: serverTimestamp(),
    }, { merge: true });
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'advanceCycle',
      commandId: eventId, commandRevision: recruitment.revision + 1,
      audiencePlayerIds: recruitment.memberPlayerIds,
      actorPlayerId: playerId, occurredAt: serverTimestamp(),
    });
  });
}

async function completeActiveMemberTxn(
  db,
  actorPlayerId,
  actorCharacterId,
  { forgedLeaderSnapshot = false } = {},
) {
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', actorPlayerId);
    const stateId = `${actorCharacterId}_${raidId}`;
    const stateRef = doc(db, 'players', actorPlayerId, 'raidStates', stateId);
    const recruitment = (await tx.get(recruitmentRef)).data();
    await tx.get(memberRef);
    const remainingSlots = recruitment.partySlots.filter(
      (slot) => slot.playerId !== actorPlayerId,
    );
    const remainingIds = recruitment.memberPlayerIds.filter(
      (id) => id !== actorPlayerId,
    );
    const transfersLeadership = recruitment.leaderPlayerId === actorPlayerId
      && remainingIds.length > 0;
    const successorRef = transfersLeadership
      ? doc(db, 'recruitments', recruitmentId, 'members', remainingIds[0])
      : null;
    const successor = successorRef ? (await tx.get(successorRef)).data() : null;
    const groupRef = recruitment.groupId
      ? doc(db, 'groups', recruitment.groupId) : null;
    const group = groupRef ? (await tx.get(groupRef)).data() : null;
    const groupListingRef = recruitment.groupId
      ? doc(db, 'groups', recruitment.groupId, 'raidListings', recruitmentId)
      : null;
    const nextRevision = recruitment.revision + 1;
    const eventId = `memberLeft_${recruitmentId}_${nextRevision}`;
    tx.update(recruitmentRef, {
      ...(remainingIds.length === 0 ? {
        status: 'disbanded', manualRecruitmentEnabled: false,
        hasAvailableSlot: false,
      } : { hasAvailableSlot: true }),
      memberPlayerIds: remainingIds,
      memberCount: remainingIds.length,
      dealerCount: remainingSlots.filter((slot) => slot.role === 'dealer').length,
      supportCount: remainingSlots.filter((slot) => slot.role === 'support').length,
      partySlots: remainingSlots,
      raidStateTargets: recruitment.raidStateTargets.filter(
        (target) => target.playerId !== actorPlayerId,
      ),
      nonGroupMemberCount: remainingSlots.filter(
        (slot) => slot.countedAsNonGroupMember,
      ).length,
      ...(group && remainingIds.length === 0
        ? { groupActiveRecruitmentCountAfter: group.activeRecruitmentCount - 1 }
        : {}),
      ...(transfersLeadership
        ? {
          leaderPlayerId: remainingIds[0],
          leaderCharacterNameSnapshot: forgedLeaderSnapshot
            ? '위조된 가입자'
            : successor.characterNameSnapshot,
          leaderClassNameSnapshot: successor.classNameSnapshot,
        } : {}),
      commandTargets: [{ playerId: actorPlayerId, stateId }],
      lastCommandId: eventId, lastCommandType: 'personalComplete',
      lastCommandActorPlayerId: actorPlayerId,
      lastCommandAt: serverTimestamp(),
      revision: nextRevision, updatedAt: serverTimestamp(),
    });
    tx.delete(memberRef);
    if (successorRef) {
      tx.update(successorRef, {
        canApproveApplications: true,
        updatedAt: serverTimestamp(),
      });
    }
    if (groupRef && remainingIds.length === 0) {
      tx.update(groupRef, {
        activeRecruitmentCount: group.activeRecruitmentCount - 1,
        lastRecruitmentId: recruitmentId,
        revision: group.revision + 1,
        updatedAt: serverTimestamp(),
      });
      tx.delete(groupListingRef);
    } else if (groupListingRef) {
      tx.update(groupListingRef, {
        memberCount: remainingIds.length,
        sourceRevision: nextRevision,
        updatedAt: serverTimestamp(),
      });
    }
    tx.update(stateRef, {
      status: 'completed', source: 'manual', revision: 2,
      completedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(doc(db, 'partyEvents', eventId), {
      schemaVersion: 1, eventId, recruitmentId, type: 'memberLeft',
      commandId: eventId, commandRevision: nextRevision,
      audiencePlayerIds: recruitment.memberPlayerIds,
      actorPlayerId, targetPlayerId: actorPlayerId,
      reason: 'weeklyRaidCompleted',
      occurredAt: serverTimestamp(),
    });
  });
}

async function main() {
  console.log('cycleKey', cycleKey);
  console.log('cutover baseline: loading tracked firestore.rules');
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
  console.log('cutover baseline: rules compile succeeded');
  const db = testEnv.authenticatedContext(authUid).firestore();

  try {
    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(
        doc(adminDb, 'players', playerId, 'raidStates', `${characterId}_${raidId}`),
        {
          schemaVersion: 1,
          playerId,
          characterId,
          raidId,
          cycleKey,
          status: 'active',
          source: 'party',
          recruitmentId,
          revision: 1,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        },
      );
      await setDoc(
        doc(
          adminDb,
          'players',
          playerId,
          'activeRaidAssignments',
          `${characterId}_${raidId}`,
        ),
        {
          schemaVersion: 1,
          playerId,
          characterId,
          raidId,
          cycleKey,
          recruitmentId,
          status: 'active',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        },
      );
    });
    const crossPlayerDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    const ownRaidStates = query(
      collection(db, 'players', playerId, 'raidStates'),
      where('cycleKey', '==', cycleKey),
    );
    const ownAssignments = query(
      collection(db, 'players', playerId, 'activeRaidAssignments'),
      where('cycleKey', '==', cycleKey),
    );
    console.log('test: owner can list current-cycle raid status sources');
    await assertSucceeds(getDocs(ownRaidStates));
    await assertSucceeds(getDocs(ownAssignments));
    await assertFails(
      getDocs(
        query(
          collection(crossPlayerDb, 'players', playerId, 'raidStates'),
          where('cycleKey', '==', cycleKey),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(crossPlayerDb, 'players', playerId, 'activeRaidAssignments'),
          where('cycleKey', '==', cycleKey),
        ),
      ),
    );
    console.log('PASS: owner-only raid status list contract');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    console.log('test: owner creates and deletes manual completed raidState');
    await assertSucceeds(createManualRaidStateTxn(db));
    await assertSucceeds(deleteCompletedRaidStateTxn(db, playerId, characterId));
    console.log('PASS: personal manual completion toggle');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    const orphanRecruitmentId = 'missing-recruitment';
    await seedOrphanRaidState(testEnv, orphanRecruitmentId);
    console.log('test: owner cleans only a missing-recruitment raid state');
    await assertSucceeds(
      cleanupOrphanRaidStateTxn(
        db,
        playerId,
        characterId,
        orphanRecruitmentId,
      ),
    );
    const orphanState = await getDoc(
      doc(db, 'players', playerId, 'raidStates', `${characterId}_${raidId}`),
    );
    const orphanAssignment = await getDoc(
      doc(
        db,
        'players',
        playerId,
        'activeRaidAssignments',
        `${characterId}_${raidId}`,
      ),
    );
    if (orphanState.exists() || orphanAssignment.exists()) {
      throw new Error('orphan raid status documents were not deleted');
    }

    await seedOrphanRaidState(testEnv, orphanRecruitmentId);
    const orphanAttackerDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertFails(
      cleanupOrphanRaidStateTxn(
        orphanAttackerDb,
        playerId,
        characterId,
        orphanRecruitmentId,
      ),
    );
    console.log('PASS: orphan cleanup is owner-only');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(
        doc(
          adminDb,
          'players',
          playerId,
          'activeRaidAssignments',
          `${characterId}_${raidId}`,
        ),
        {
          schemaVersion: 1,
          playerId,
          characterId,
          raidId,
          difficultyId: 'normal',
          cycleKey,
          recruitmentId,
          role: 'dealer',
          status: 'active',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        },
      );
    });
    await assertFails(
      cleanupOrphanRaidStateTxn(db, playerId, characterId, recruitmentId),
    );
    console.log('PASS: active recruitment participation cannot be orphan-cleaned');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    const previousCycleKey = offsetCycleKey(cycleKey, -7);
    const previousWindow = cycleWindow(previousCycleKey);
    const nextCycleKey = cycleKey;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), {
        continueTogether: true,
        currentCycleStatus: 'completed',
        currentCycleKey: previousCycleKey,
        targetCycleKey: previousCycleKey,
        cycleStartedAt: Timestamp.fromDate(previousWindow.startedAt),
        cycleEndsAt: Timestamp.fromDate(previousWindow.endsAt),
        revision: 2,
      });
      await updateDoc(
        doc(adminDb, 'players', playerId, 'raidStates', `${characterId}_${raidId}`),
        {
          status: 'completed', cycleKey: previousCycleKey,
          completedAt: Timestamp.now(), revision: 2,
        },
      );
    });
    await assertSucceeds(deleteCompletedRaidStateTxn(db, playerId, characterId));
    console.log('test: next cycle recreates a personally cleared raidState');
    await assertSucceeds(advanceCycleWithMissingStateTxn(db, nextCycleKey));
    const recreatedState = (await getDoc(doc(
      db,
      'players',
      playerId,
      'raidStates',
      `${characterId}_${raidId}`,
    ))).data();
    if (recreatedState.status !== 'active'
      || recreatedState.source !== 'party'
      || recreatedState.cycleKey !== nextCycleKey) {
      throw new Error('Next-cycle missing raidState reconstruction mismatch');
    }
    console.log('PASS: next-cycle missing raidState reconstruction');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    console.log('test: last member completes manually and disbands atomically');
    await assertSucceeds(completeActiveMemberTxn(db, playerId, characterId));
    const singleCompletionRoom = (await getDoc(doc(db, 'recruitments', recruitmentId))).data();
    const singleCompletionState = (await getDoc(doc(db, 'players', playerId,
      'raidStates', `${characterId}_${raidId}`))).data();
    if (singleCompletionRoom.status !== 'disbanded'
      || singleCompletionRoom.memberCount !== 0
      || singleCompletionState.status !== 'completed') {
      throw new Error('Last-member personal completion mismatch');
    }
    console.log('PASS: last-member personal completion');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await seedGroupLinkedRoom(testEnv, db);
    console.log('test: group-room last member completion closes listing and count');
    await assertSucceeds(completeActiveMemberTxn(db, playerId, characterId));
    const completedGroup = (await getDoc(doc(db, 'groups', 'group-room-1'))).data();
    const completedGroupRoom = (await getDoc(
      doc(db, 'recruitments', recruitmentId),
    )).data();
    const completedGroupListing = await getDoc(
      doc(db, 'groups', 'group-room-1', 'raidListings', recruitmentId),
    );
    if (completedGroup.activeRecruitmentCount !== 0
      || completedGroupRoom.status !== 'disbanded'
      || completedGroupListing.exists()) {
      throw new Error('Group-room personal completion aggregate mismatch');
    }
    console.log('PASS: group-room personal completion');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    const personalApplicantDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(applicationTxn(personalApplicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    console.log('test: joined member leaves and completes in one transaction');
    await assertSucceeds(completeActiveMemberTxn(
      personalApplicantDb,
      joinerPlayerId,
      joinerCharacterId,
    ));
    const memberCompletionRoom = (await getDoc(doc(db, 'recruitments', recruitmentId))).data();
    const memberCompletionState = (await getDoc(doc(personalApplicantDb,
      'players', joinerPlayerId, 'raidStates', `${joinerCharacterId}_${raidId}`))).data();
    if (memberCompletionRoom.memberCount !== 1
      || memberCompletionRoom.memberPlayerIds.includes(joinerPlayerId)
      || memberCompletionState.status !== 'completed') {
      throw new Error('Joined-member personal completion mismatch');
    }
    console.log('PASS: joined-member personal completion');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    const leaderTransferApplicantDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(applicationTxn(leaderTransferApplicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    console.log('test: leader personal completion transfers leadership atomically');
    await assertSucceeds(completeActiveMemberTxn(db, playerId, characterId));
    const leaderTransferRoom = (await getDoc(
      doc(db, 'recruitments', recruitmentId),
    )).data();
    const leaderTransferMember = (await getDoc(
      doc(db, 'recruitments', recruitmentId, 'members', joinerPlayerId),
    )).data();
    if (leaderTransferRoom.leaderPlayerId !== joinerPlayerId
      || leaderTransferRoom.leaderCharacterNameSnapshot !== '가입자'
      || leaderTransferRoom.leaderClassNameSnapshot !== '바드'
      || leaderTransferMember.canApproveApplications !== true) {
      throw new Error('Leader personal completion transfer mismatch');
    }
    console.log('PASS: leader personal completion transfer');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    const forgedTransferApplicantDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(applicationTxn(forgedTransferApplicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    console.log('test: forged successor snapshot is denied');
    await assertFails(completeActiveMemberTxn(
      db,
      playerId,
      characterId,
      { forgedLeaderSnapshot: true },
    ));
    console.log('PASS: forged successor snapshot denied');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    console.log('test: group create on clean membershipState');
    await assertSucceeds(createGroupTxn(db, 'group-new-1'));
    console.log('PASS: group create clean');

    await seedJoiner(testEnv);
    const firstJoinerDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(applyToGroupTxn(firstJoinerDb, 'group-new-1'));
    console.log('test: group application approval creates first membershipState');
    await assertSucceeds(approveGroupApplicationTxn(db, 'group-new-1'));
    console.log('PASS: first group application approval');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createGroupTxn(db, 'group-empty-approval'));
    await seedJoiner(testEnv, {
      membershipState: {
        schemaVersion: 1,
        playerId: joinerPlayerId,
        activeGroupIds: [],
        activeGroupCount: 0,
        revision: 14,
        updatedAt: Timestamp.now(),
      },
    });
    const returningJoinerDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(applyToGroupTxn(returningJoinerDb, 'group-empty-approval'));
    console.log('test: group application approval updates empty membershipState');
    await assertSucceeds(approveGroupApplicationTxn(db, 'group-empty-approval'));
    console.log('PASS: empty membershipState approval');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createGroupTxn(db, 'group-new-1'));
    await seedJoiner(testEnv);
    await assertSucceeds(createJoinCodeTxn(db, 'group-new-1'));
    console.log('test: join by code on clean membershipState');
    const joinerDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await assertSucceeds(joinByCodeTxn(joinerDb));
    const joinedGroup = (await getDoc(doc(joinerDb, 'groups', 'group-new-1'))).data();
    if (joinedGroup.memberCount !== 2) throw new Error('Join code memberCount mismatch');
    console.log('PASS: join by code clean');

    await testEnv.clearFirestore();
    await seedBase(testEnv, {
      membershipState: {
        schemaVersion: 1,
        playerId,
        // missing activeGroupIds / revision on purpose
        updatedAt: Timestamp.now(),
      },
    });
    console.log('test: group create with broken membershipState');
    await assertFails(createGroupTxn(db, 'group-broken-1'));
    console.log('PASS: broken membershipState denied (expected)');

    await testEnv.clearFirestore();
    await seedBase(testEnv, {
      membershipState: {
        schemaVersion: 1,
        playerId,
        activeGroupIds: [],
        activeGroupCount: 0,
        revision: 3,
        updatedAt: Timestamp.now(),
      },
    });
    console.log('test: group create with empty list membershipState');
    await assertSucceeds(createGroupTxn(db, 'group-empty-1'));
    console.log('PASS: empty membershipState create');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    console.log('test: public recruitment create clean');
    await assertSucceeds(createPublicRecruitmentTxn(db));
    console.log('PASS: public recruitment create clean');

    await seedJoiner(testEnv);
    const applicantDb = testEnv.authenticatedContext(joinerAuthUid).firestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(
        context.firestore(),
        'players',
        joinerPlayerId,
        'raidStates',
        `${joinerCharacterId}_${raidId}`,
      ), {
        schemaVersion: 1,
        playerId: joinerPlayerId,
        characterId: joinerCharacterId,
        raidId,
        recruitmentId: 'missing-recruitment',
        cycleKey,
        role: 'support',
        status: 'active',
        source: 'party',
        revision: 1,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    });
    console.log('test: application create denied while exact raidState remains');
    await assertFails(applicationTxn(applicantDb, 'apply'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(
        context.firestore(),
        'players',
        joinerPlayerId,
        'raidStates',
        `${joinerCharacterId}_${raidId}`,
      ));
    });
    console.log('PASS: occupied applicant state blocks application create');
    console.log('test: public application create, withdraw and reapply');
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(applicationTxn(applicantDb, 'withdraw'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(
        context.firestore(),
        'players',
        joinerPlayerId,
        'raidStates',
        `${joinerCharacterId}_${raidId}`,
      ), {
        schemaVersion: 1,
        playerId: joinerPlayerId,
        characterId: joinerCharacterId,
        raidId,
        recruitmentId: 'missing-recruitment',
        cycleKey,
        role: 'support',
        status: 'active',
        source: 'party',
        revision: 1,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
    });
    console.log('test: application reapply denied while exact raidState remains');
    await assertFails(applicationTxn(applicantDb, 'reapply'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(doc(
        context.firestore(),
        'players',
        joinerPlayerId,
        'raidStates',
        `${joinerCharacterId}_${raidId}`,
      ));
    });
    await assertSucceeds(applicationTxn(applicantDb, 'reapply'));
    const reapplication = (await getDoc(doc(applicantDb, 'recruitments', recruitmentId, 'applications', joinerPlayerId))).data();
    const afterReapply = (await getDoc(doc(applicantDb, 'recruitments', recruitmentId))).data();
    if (reapplication.status !== 'pending' || reapplication.revision !== 3
      || afterReapply.pendingApplicationCount !== 1 || afterReapply.revision !== 4) {
      throw new Error('Application reapply state mismatch');
    }
    console.log('PASS: public application create, withdraw and reapply');

    await assertSucceeds(applicationTxn(applicantDb, 'withdraw'));
    await assertSucceeds(createGroupTxn(db, 'group-linked-1'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), {
        groupId: 'group-linked-1', visibility: 'public', nonGroupMemberCount: 0,
      });
    });
    console.log('test: reapply after public linked-room group membership changes');
    await assertSucceeds(applicationTxn(applicantDb, 'reapply', { countedAsNonGroup: true }));
    const changedSnapshot = (await getDoc(doc(applicantDb, 'recruitments', recruitmentId, 'applications', joinerPlayerId))).data();
    if (changedSnapshot.countedAsNonGroupApplicant !== true) {
      throw new Error('Reapplication group snapshot not refreshed');
    }
    console.log('PASS: reapply refreshes group snapshot');

    await assertSucceeds(applicationTxn(applicantDb, 'withdraw'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await setDoc(doc(adminDb, 'groups', 'group-linked-1', 'members', joinerPlayerId), {
        schemaVersion: 1, groupId: 'group-linked-1', playerId: joinerPlayerId,
        role: 'member', joinedAt: Timestamp.now(), revision: 1,
      });
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), { visibility: 'group' });
      await updateDoc(doc(adminDb, 'groups', 'group-linked-1'), { activeRecruitmentCount: 1 });
    });
    console.log('test: group-only reapply checks current group membership');
    await assertFails(applicationTxn(applicantDb, 'reapply', { countedAsNonGroup: true }));
    await assertSucceeds(applicationTxn(applicantDb, 'reapply'));
    const groupApplication = (await getDoc(doc(applicantDb, 'recruitments', recruitmentId, 'applications', joinerPlayerId))).data();
    const groupRecruitment = (await getDoc(doc(applicantDb, 'recruitments', recruitmentId))).data();
    if (groupApplication.countedAsNonGroupApplicant !== false
      || groupRecruitment.pendingNonGroupApplicantCount !== 0) {
      throw new Error('Group-only reapply count mismatch');
    }
    console.log('PASS: group-only reapply validates group snapshot');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    console.log('test: approver cannot read applicant raidState');
    await assertFails(getDoc(doc(db, 'players', joinerPlayerId, 'raidStates', `${joinerCharacterId}_${raidId}`)));
    console.log('PASS: applicant raidState get denied (expected)');
    console.log('test: public application approval without applicant raidState read');
    await assertSucceeds(approvePublicApplicationTxn(db));
    console.log('PASS: public application approved without applicant raidState read');

    console.log('test: non-leader cannot reposition another member');
    await assertFails(repositionApprovedMemberTxn(applicantDb));
    console.log('PASS: non-leader reposition denied');
    console.log('test: member projection cannot disagree with aggregate slot');
    await assertFails(repositionApprovedMemberTxn(db, 2, 1));
    console.log('PASS: mismatched member projection denied');

    console.log('test: leader repositions a joined member using aggregate slots');
    await assertSucceeds(repositionApprovedMemberTxn(db));
    console.log('PASS: aggregate position change');
    console.log('test: leader kicks joined member without reading private raidState');
    await assertSucceeds(kickApprovedMemberTxn(db));
    console.log('PASS: joined member kick');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'recruitments', recruitmentId), {
        approvalPolicy: { mode: 'directJoin' },
      });
    });
    console.log('test: kicked member can directly rejoin when room allows direct join');
    await assertSucceeds(directRejoinAfterKickTxn(applicantDb));
    console.log('PASS: kicked member direct rejoin');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    console.log('test: non-leader cannot disband joined room');
    await assertFails(disbandApprovedRoomTxn(applicantDb));
    console.log('PASS: non-leader disband denied');
    console.log('test: leader disbands two-member room without private raidState reads');
    await assertSucceeds(disbandApprovedRoomTxn(db));
    console.log('PASS: two-member disband');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), {
        status: 'completed', currentCycleStatus: 'completed', hasAvailableSlot: false,
        manualRecruitmentEnabled: false,
      });
      for (const [targetPlayer, targetCharacter] of [
        [playerId, characterId], [joinerPlayerId, joinerCharacterId],
      ]) {
        await updateDoc(doc(adminDb, 'players', targetPlayer, 'raidStates',
          `${targetCharacter}_${raidId}`), { status: 'completed' });
      }
    });
    console.log('test: completed-room disband preserves completed raidStates');
    await assertSucceeds(disbandApprovedRoomTxn(db));
    console.log('PASS: completed-room disband');

    for (const totalMembers of [4, 8]) {
      await testEnv.clearFirestore();
      await seedBase(testEnv);
      await seedJoiner(testEnv);
      await assertSucceeds(createPublicRecruitmentTxn(db));
      await assertSucceeds(applicationTxn(applicantDb, 'apply'));
      await assertSucceeds(approvePublicApplicationTxn(db));
      await seedExpandedApprovedRoom(testEnv, totalMembers);
      if (totalMembers === 4) {
        console.log('test: occupied dealer slots exchange at four-member boundary');
        await assertSucceeds(swapTwoDealersTxn(db));
        console.log('PASS: occupied slot exchange');
      }
      console.log(`test: ${totalMembers}-member active room disband`);
      await assertSucceeds(disbandApprovedRoomTxn(db));
      console.log(`PASS: ${totalMembers}-member active disband`);
    }

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await seedGroupLinkedRoom(testEnv, db, {
      activeRecruitmentCount: 17,
      recruitmentCountSnapshot: 5,
    });
    console.log('test: old group room disband closes current count from 17 to 16');
    await assertSucceeds(disbandApprovedRoomTxn(db));
    console.log('PASS: old group room disband uses current count');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await seedGroupLinkedRoom(testEnv, db, {
      activeRecruitmentCount: 17,
      recruitmentCountSnapshot: 5,
    });
    console.log('test: group room disband rejects forged count 15');
    await assertFails(disbandApprovedRoomTxn(db, { recruitmentCountAfter: 15 }));
    console.log('PASS: forged group close count denied');

    console.log('test: group room disband requires current group count update');
    await assertFails(disbandApprovedRoomTxn(db, { skipGroupUpdate: true }));
    console.log('PASS: missing group close update denied');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await seedGroupLinkedRoom(testEnv, db);
    console.log('test: leader kick updates group listing with recruitment revision');
    await assertSucceeds(kickApprovedMemberTxn(db));
    const kickedGroupListing = (await getDoc(doc(
      db, 'groups', 'group-room-1', 'raidListings', recruitmentId,
    ))).data();
    if (kickedGroupListing.memberCount !== 1
      || kickedGroupListing.sourceRevision !== 4) {
      throw new Error('Group listing member removal snapshot mismatch');
    }
    console.log('PASS: group room leader kick listing update');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await seedGroupLinkedRoom(testEnv, db, { includeJoinerGroupMember: true });
    console.log('test: member self-leave updates group listing');
    await assertSucceeds(leaveApprovedRoomTxn(applicantDb));
    console.log('PASS: group room self-leave listing update');
    console.log('test: group room rejoin rejects listing mismatch');
    await assertFails(directRejoinAfterKickTxn(applicantDb, {
      tamperListing: true,
    }));
    console.log('PASS: mismatched group rejoin listing denied');
    console.log('test: member directly rejoins group room after self-leave');
    await assertSucceeds(directRejoinAfterKickTxn(applicantDb));
    console.log('PASS: group room rejoin after self-leave');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(approvePublicApplicationTxn(db));
    await seedGroupLinkedRoom(testEnv, db);
    console.log('test: member removal cannot forge group listing member count');
    await assertFails(kickApprovedMemberTxn(db, { tamperListingCount: true }));
    console.log('PASS: forged group listing member count denied');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'players', joinerPlayerId,
        'raidStates', `${joinerCharacterId}_${raidId}`), {
        schemaVersion: 1, playerId: joinerPlayerId,
        characterId: joinerCharacterId, raidId,
        recruitmentId: 'different-recruitment', cycleKey,
        role: 'support', status: 'active', source: 'party', revision: 1,
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    });
    console.log('test: approval cannot overwrite existing applicant raidState');
    await assertFails(approvePublicApplicationTxn(db));
    console.log('PASS: existing applicant raidState blocks approval');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'players', joinerPlayerId,
        'weeklyRaidClaims', `${cycleKey}_${joinerCharacterId}_${raidId}`), {
        schemaVersion: 1, playerId: joinerPlayerId,
        characterId: joinerCharacterId, raidId, cycleKey,
        source: 'manual', completedAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
    });
    console.log('test: applicant weekly completion blocks approval');
    await assertFails(approvePublicApplicationTxn(db));
    console.log('PASS: applicant weekly completion blocks approval');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await assertSucceeds(createPublicRecruitmentTxn(db));
    console.log('test: current-cycle active raid state cleanup denied');
    await assertFails(deleteOldRaidStateTxn(db));
    console.log('PASS: current-cycle active raid state cleanup denied');
    const oldCycleKey = currentCycleKey(new Date(Date.now() - 7 * 86400000));
    const oldCycle = cycleWindow(oldCycleKey);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), {
        currentCycleKey: oldCycleKey,
        targetCycleKey: oldCycleKey,
        cycleStartedAt: Timestamp.fromDate(oldCycle.startedAt),
        cycleEndsAt: Timestamp.fromDate(oldCycle.endsAt),
        continueTogether: true,
      });
      await updateDoc(doc(adminDb, 'players', playerId, 'raidStates', `${characterId}_${raidId}`), {
        cycleKey: oldCycleKey,
      });
    });
    console.log('test: expired repeating-room raid state cleanup denied');
    await assertFails(deleteOldRaidStateTxn(db));
    console.log('PASS: expired repeating-room raid state cleanup denied');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'recruitments', recruitmentId), {
        continueTogether: false,
      });
    });
    console.log('test: same-transaction stale replacement exceeds Rules budget');
    await assertFails(createPublicRecruitmentTxn(db, {
      id: 'recruitment-next-cycle', replaceStale: true,
    }));
    console.log('PASS: same-transaction stale replacement denied (expected)');
    console.log('test: standalone stale cleanup followed by atomic create');
    await assertSucceeds(deleteOldRaidStateTxn(db));
    await assertSucceeds(createPublicRecruitmentTxn(db, { id: 'recruitment-next-cycle' }));
    console.log('PASS: standalone stale cleanup and new atomic create');

    await testEnv.clearFirestore();
    await seedBase(testEnv, { weeklyClaim: true });
    console.log('test: public recruitment with manual weekly claim');
    await assertFails(createPublicRecruitmentTxn(db));
    console.log('PASS: weekly claim blocks raidState create (expected)');

    await testEnv.clearFirestore();
    await seedBase(testEnv);
    await seedJoiner(testEnv);
    await seedApplicationForCleanup(testEnv, 'missing-parent');
    const missingApplication = doc(
      db,
      'recruitments',
      'missing-parent',
      'applications',
      playerId,
    );
    console.log('test: applicant deletes application with missing parent');
    await assertSucceeds(deleteDoc(missingApplication));
    await seedApplicationForCleanup(testEnv, 'missing-parent-other');
    await assertFails(deleteDoc(doc(
      joinerDb,
      'recruitments',
      'missing-parent-other',
      'applications',
      playerId,
    )));
    await seedApplicationForCleanup(testEnv, 'ended-parent', {
      parentStatus: 'disbanded',
    });
    console.log('test: applicant deletes application with ended parent');
    await assertSucceeds(deleteDoc(doc(
      db,
      'recruitments',
      'ended-parent',
      'applications',
      playerId,
    )));
    await seedApplicationForCleanup(testEnv, 'active-parent', {
      parentStatus: 'active',
    });
    console.log('test: active parent and another player cannot delete application');
    await assertFails(deleteDoc(doc(
      db,
      'recruitments',
      'active-parent',
      'applications',
      playerId,
    )));
    await assertFails(deleteDoc(doc(
      joinerDb,
      'recruitments',
      'active-parent',
      'applications',
      playerId,
    )));
    console.log('PASS: orphan application delete boundary');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error('FAIL:', error);
  process.exit(1);
});
