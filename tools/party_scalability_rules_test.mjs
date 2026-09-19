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

function partySlots(memberCount) {
  return Array.from({ length: memberCount }, (_, index) => ({
    playerId: `player-${index}`,
    characterId: `character-${index}`,
  }));
}

function stateRef(db, target) {
  return db.doc(`players/${target.playerId}/raidStates/${target.stateId}`);
}

async function seed(
  testEnv,
  memberCount,
  { status = 'active', cycleStatus = 'active', continueTogether = true } = {},
) {
  await testEnv.clearFirestore();
  const now = firebase.firestore.Timestamp.now();
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
      raidId: 'raid-1',
      difficultyId: 'hard',
      leaderPlayerId,
      groupId,
      status,
      continueTogether,
      currentCycleStatus: cycleStatus,
      currentCycleKey: '2026-09-09',
      partySlots: partySlots(memberCount),
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
  const commandTargets = type === 'disband'
      && recruitmentStatusRequiresPreservedStates(options)
    ? []
    : memberTargets;
  const writtenTargets = options.omitLast
    ? memberTargets.slice(0, memberTargets.length - 1)
    : commandTargets;

  await db.runTransaction(async (transaction) => {
    const recruitmentSnapshot = await transaction.get(recruitmentRef);
    const recruitment = recruitmentSnapshot.data();
    const nextRevision = recruitment.revision + 1;
    const nextCycleKey = type === 'advanceCycle'
      ? '2026-09-16'
      : recruitment.currentCycleKey;
    const nextStatus = type === 'complete'
      ? (recruitment.continueTogether ? 'active' : 'completed')
      : type === 'disband'
        ? 'disbanded'
        : 'active';
    const nextCycleStatus = type === 'complete'
      ? 'completed'
      : type === 'disband'
        ? recruitment.currentCycleStatus
        : 'active';
    const commandId = `${type}-${memberCount}-${nextRevision}`;
    const completionTargets = options.omitEventTarget
      ? recruitment.partySlots.slice(0, recruitment.partySlots.length - 1)
      : options.tamperEventCharacter
        ? recruitment.partySlots.map((target, index) => index === 0
          ? { ...target, characterId: 'other-character' }
          : target)
        : recruitment.partySlots;
    const closesActiveRecruitment =
      (type === 'complete' && recruitment.continueTogether === false)
      || (type === 'disband' && recruitment.status === 'active');

    transaction.update(recruitmentRef, {
      status: nextStatus,
      currentCycleStatus: nextCycleStatus,
      currentCycleKey: nextCycleKey,
      commandTargets,
      groupActiveRecruitmentCountAfter: closesActiveRecruitment
        ? recruitment.groupActiveRecruitmentCountAfter - 1
        : recruitment.groupActiveRecruitmentCountAfter,
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
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        },
      );
    }

    if (closesActiveRecruitment) {
      transaction.update(groupRef, {
        activeRecruitmentCount: 0,
        lastRecruitmentId: recruitmentId,
        revision: 2,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
      transaction.delete(listingRef);
    } else if (!(type === 'disband' && recruitment.status === 'completed')) {
      transaction.update(listingRef, {
        recruitmentId,
        sourceRevision: nextRevision,
        status: nextStatus,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });
    }

    transaction.set(db.doc(`partyEvents/${commandId}`), {
      schemaVersion: (type === 'complete' || type === 'cancelCompletion')
        ? 2
        : 1,
      eventId: commandId,
      recruitmentId,
      type,
      commandId,
      commandRevision: nextRevision,
      audiencePlayerIds: memberTargets.map((target) => target.playerId),
      actorPlayerId: leaderPlayerId,
      ...((type === 'complete' || type === 'cancelCompletion') ? {
        raidId: recruitment.raidId,
        difficultyId: recruitment.difficultyId,
        cycleKey: recruitment.currentCycleKey,
        completionTargets,
      } : {}),
      occurredAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  });
}

function recruitmentStatusRequiresPreservedStates(options) {
  return options.completedDisband === true;
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: { rules },
  });
  try {
    const leaderDb = testEnv.authenticatedContext(leaderUid).firestore();

    for (const memberCount of [1, 2, 4, 8]) {
      await seed(testEnv, memberCount);
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

      await seed(testEnv, memberCount);
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'disband'),
      );
      console.log(`PASS: ${memberCount}-member group disband`);
    }

    await seed(testEnv, 8, { continueTogether: false });
    await assertSucceeds(lifecycleTransaction(leaderDb, 8, 'complete'));
    await assertSucceeds(
      lifecycleTransaction(leaderDb, 8, 'disband', {
        completedDisband: true,
      }),
    );
    console.log('PASS: one-shot completion and completed disband');

    await seed(testEnv, 8);
    await assertSucceeds(lifecycleTransaction(leaderDb, 8, 'advanceCycle'));
    console.log('PASS: missed active cycle advances without stale state');

    await seed(testEnv, 8);
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', { omitLast: true }),
    );
    console.log('PASS: omitted raidState denied');

    await seed(testEnv, 8);
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', { staleRevision: true }),
    );
    console.log('PASS: stale revision denied');

    await seed(testEnv, 8);
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', {
        omitEventTarget: true,
      }),
    );
    console.log('PASS: incomplete completion event targets denied');

    await seed(testEnv, 8);
    await assertFails(
      lifecycleTransaction(leaderDb, 8, 'complete', {
        tamperEventCharacter: true,
      }),
    );
    console.log('PASS: forged completion event character denied');

    await seed(testEnv, 8);
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
