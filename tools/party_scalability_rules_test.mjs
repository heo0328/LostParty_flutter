import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(
  path.join(dirname, 'party_scalability_proof.rules'),
  'utf8',
);
const projectId = 'demo-party-scalability';
const recruitmentId = 'recruitment-1';
const groupId = 'group-1';
const leaderUid = 'leader-auth';
const leaderPlayerId = 'player-0';

function targets(memberCount) {
  return Array.from({ length: memberCount }, (_, index) => ({
    playerId: `player-${index}`,
    stateId: `character-${index}_raid-1`,
  }));
}

function stateRef(db, target) {
  return db.doc(`players/${target.playerId}/raidStates/${target.stateId}`);
}

async function seed(testEnv, memberCount, status = 'active') {
  await testEnv.clearFirestore();
  const now = firebase.firestore.Timestamp.now();
  const cycleStatus = status === 'completed' ? 'completed' : 'active';
  const stateStatus = cycleStatus;
  const memberTargets = targets(memberCount);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc(`authBindings/${leaderUid}`).set({
      playerId: leaderPlayerId,
      status: 'active',
    });
    await db.doc(`groups/${groupId}`).set({
      activeRecruitmentCount: 1,
      lastRecruitmentId: recruitmentId,
      revision: 1,
      updatedAt: now,
    });
    await db.doc(`recruitments/${recruitmentId}`).set({
      recruitmentId,
      leaderPlayerId,
      groupId,
      status,
      currentCycleStatus: cycleStatus,
      currentCycleKey: '2026-09-09',
      raidStateTargets: memberTargets,
      commandTargets: memberTargets,
      groupActiveRecruitmentCountAfter: 1,
      revision: 1,
      lastCommandId: 'seed',
      lastCommandType: 'seed',
      lastCommandActorPlayerId: leaderPlayerId,
      lastCommandAt: now,
    });
    await db.doc(`groups/${groupId}/raidListings/${recruitmentId}`).set({
      recruitmentId,
      sourceRevision: 1,
      status,
      updatedAt: now,
    });
    for (const target of memberTargets) {
      await stateRef(db, target).set({
        playerId: target.playerId,
        characterId: target.stateId.split('_raid-1')[0],
        raidId: 'raid-1',
        recruitmentId,
        cycleKey: '2026-09-09',
        status: stateStatus,
        revision: 1,
        updatedAt: now,
      });
    }
  });
}

async function lifecycleTransaction(db, memberCount, type, options = {}) {
  const recruitmentRef = db.doc(`recruitments/${recruitmentId}`);
  const listingRef = db.doc(`groups/${groupId}/raidListings/${recruitmentId}`);
  const groupRef = db.doc(`groups/${groupId}`);
  const memberTargets = targets(memberCount);
  const writtenTargets = options.omitLast
    ? memberTargets.slice(0, memberTargets.length - 1)
    : memberTargets;

  await db.runTransaction(async (transaction) => {
    const recruitmentSnapshot = await transaction.get(recruitmentRef);
    const recruitment = recruitmentSnapshot.data();
    const nextRevision = recruitment.revision + 1;
    const nextCycleKey = type === 'advanceCycle'
      ? '2026-09-16'
      : recruitment.currentCycleKey;
    const nextStatus = type === 'complete'
      ? 'completed'
      : type === 'disband'
        ? 'disbanded'
        : 'active';
    const nextCycleStatus = type === 'complete'
      ? 'completed'
      : type === 'disband'
        ? recruitment.currentCycleStatus
        : 'active';
    const commandId = `${type}-${memberCount}-${nextRevision}`;

    transaction.update(recruitmentRef, {
      status: nextStatus,
      currentCycleStatus: nextCycleStatus,
      currentCycleKey: nextCycleKey,
      commandTargets: memberTargets,
      groupActiveRecruitmentCountAfter: type === 'disband' ? 0 : 1,
      revision: options.staleRevision ? nextRevision + 1 : nextRevision,
      lastCommandId: commandId,
      lastCommandType: type,
      lastCommandActorPlayerId: leaderPlayerId,
      lastCommandAt: firebase.firestore.FieldValue.serverTimestamp(),
    });

    for (const target of writtenTargets) {
      const ref = stateRef(db, target);
      if (type === 'disband') {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {
          status: type === 'complete' ? 'completed' : 'active',
          cycleKey: nextCycleKey,
          revision: nextRevision,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    if (options.extraTarget) {
      transaction.update(
        stateRef(db, options.extraTarget),
        {
          status: 'completed',
          cycleKey: nextCycleKey,
          revision: 2,
          updatedAt: serverTimestamp(),
        },
      );
    }

    if (type === 'disband') {
      transaction.update(groupRef, {
        activeRecruitmentCount: 0,
        lastRecruitmentId: recruitmentId,
        revision: 2,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.update(listingRef, {
        recruitmentId,
        sourceRevision: nextRevision,
        status: nextStatus,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.set(db.doc(`partyEvents/${commandId}`), {
      schemaVersion: 1,
      eventId: commandId,
      recruitmentId,
      type,
      commandId,
      commandRevision: nextRevision,
      audiencePlayerIds: memberTargets.map((target) => target.playerId),
      occurredAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
  try {
    const leaderDb = testEnv.authenticatedContext(leaderUid).firestore();

    for (const memberCount of [1, 2, 4, 8]) {
      await seed(testEnv, memberCount, 'active');
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'complete'),
      );
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'cancelCompletion'),
      );
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'complete'),
      );
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'advanceCycle'),
      );
      console.log(`PASS: ${memberCount}-member lifecycle commands`);

      await seed(testEnv, memberCount, 'active');
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'disband'),
      );
      console.log(`PASS: ${memberCount}-member group disband`);
    }

    await seed(testEnv, 8, 'active');
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', { omitLast: true }),
    );
    console.log('PASS: omitted raidState denied');

    await seed(testEnv, 8, 'active');
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', { staleRevision: true }),
    );
    console.log('PASS: stale revision denied');

    await seed(testEnv, 8, 'active');
    const outsiderDb = testEnv.authenticatedContext('outsider-auth').firestore();
    await assertFails(lifecycleTransaction(outsiderDb, 8, 'complete'));
    console.log('PASS: non-leader denied');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
