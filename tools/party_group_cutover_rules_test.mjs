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
  getFirestore,
  setDoc,
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
    const db = getFirestore(context);
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
    const previousIds = stateSnap.exists
      ? stateSnap.data().activeGroupIds ?? []
      : [];
    const previousRevision = stateSnap.exists ? stateSnap.data().revision ?? 0 : 0;
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

async function createPublicRecruitmentTxn(db) {
  const { startedAt, endsAt } = cycleWindow(cycleKey);
  const stateId = `${characterId}_${raidId}`;
  return runTransaction(db, async (tx) => {
    const recruitmentRef = doc(db, 'recruitments', recruitmentId);
    const memberRef = doc(db, 'recruitments', recruitmentId, 'members', playerId);
    const raidStateRef = doc(db, 'players', playerId, 'raidStates', stateId);
    const eventId = `partyCreated_${recruitmentId}_1`;
    const eventRef = doc(db, 'partyEvents', eventId);

    tx.set(recruitmentRef, {
      schemaVersion: 2,
      recruitmentId,
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
      approvalPolicy: { mode: 'leaderApproval' },
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
      nonGroupMemberCount: 1,
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
      recruitmentId,
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
      recruitmentId,
      type: 'partyCreated',
      commandId: eventId,
      commandRevision: 1,
      audiencePlayerIds: [playerId],
      actorPlayerId: playerId,
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
    console.log('test: group create on clean membershipState');
    await assertSucceeds(createGroupTxn(db, 'group-new-1'));
    console.log('PASS: group create clean');

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
