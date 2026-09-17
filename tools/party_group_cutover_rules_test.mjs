import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  updateDoc,
  getDoc,
  runTransaction,
  serverTimestamp,
  Timestamp,
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

async function seedJoiner(testEnv) {
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
    console.log('test: group create on clean membershipState');
    await assertSucceeds(createGroupTxn(db, 'group-new-1'));
    console.log('PASS: group create clean');

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
    console.log('test: public application create, withdraw and reapply');
    await assertSucceeds(applicationTxn(applicantDb, 'apply'));
    await assertSucceeds(applicationTxn(applicantDb, 'withdraw'));
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
    await assertSucceeds(createPublicRecruitmentTxn(db));
    const oldCycleKey = currentCycleKey(new Date(Date.now() - 7 * 86400000));
    const oldCycle = cycleWindow(oldCycleKey);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await updateDoc(doc(adminDb, 'recruitments', recruitmentId), {
        currentCycleKey: oldCycleKey,
        targetCycleKey: oldCycleKey,
        cycleStartedAt: Timestamp.fromDate(oldCycle.startedAt),
        cycleEndsAt: Timestamp.fromDate(oldCycle.endsAt),
      });
      await updateDoc(doc(adminDb, 'players', playerId, 'raidStates', `${characterId}_${raidId}`), {
        cycleKey: oldCycleKey,
      });
    });
    console.log('test: same-transaction stale replacement exceeds Rules budget');
    await assertFails(createPublicRecruitmentTxn(db, {
      id: 'recruitment-next-cycle', replaceStale: true,
    }));
    console.log('PASS: same-transaction stale replacement denied (expected)');
    console.log('test: standalone stale cleanup followed by atomic create');
    await assertSucceeds(runTransaction(db, async (tx) => {
      const oldRef = doc(db, 'recruitments', recruitmentId);
      const stateRef = doc(db, 'players', playerId, 'raidStates', `${characterId}_${raidId}`);
      const oldRoom = (await tx.get(oldRef)).data();
      const oldState = (await tx.get(stateRef)).data();
      if (oldState.recruitmentId !== recruitmentId || oldState.cycleKey !== oldCycleKey
        || oldRoom.continueTogether || oldRoom.cycleEndsAt.toMillis() > Date.now()) {
        throw new Error('Stale fixture is not an expired one-shot assignment');
      }
      tx.delete(stateRef);
    }));
    await assertSucceeds(createPublicRecruitmentTxn(db, { id: 'recruitment-next-cycle' }));
    console.log('PASS: standalone stale cleanup and new atomic create');

    await testEnv.clearFirestore();
    await seedBase(testEnv, { weeklyClaim: true });
    console.log('test: public recruitment with manual weekly claim');
    await assertFails(createPublicRecruitmentTxn(db));
    console.log('PASS: weekly claim blocks raidState create (expected)');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error('FAIL:', error);
  process.exit(1);
});
