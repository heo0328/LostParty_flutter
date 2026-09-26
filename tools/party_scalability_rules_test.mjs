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
const memberUid = 'member-auth';
const memberPlayerId = 'player-1';

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
  {
    status = 'active',
    cycleStatus = 'active',
    continueTogether = true,
    groupActiveRecruitmentCount = 1,
    recruitmentGroupCountSnapshot = groupActiveRecruitmentCount,
  } = {},
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
    if (memberCount > 1) {
      await db.doc(`authBindings/${memberUid}`).set({
        playerId: memberPlayerId,
        status: 'active',
      });
    }
    await db.doc(`groups/${groupId}`).set({
      activeRecruitmentCount: groupActiveRecruitmentCount,
      lastRecruitmentId: recruitmentId,
      revision: 1,
      updatedAt: now,
    });
    await db.doc(`recruitments/${recruitmentId}`).set({
      schemaVersion: 2,
      recruitmentId,
      raidId: 'raid-1',
      difficultyId: 'hard',
      leaderPlayerId,
      groupId,
      status,
      continueTogether,
      currentCycleStatus: cycleStatus,
      currentCycleKey: '2026-09-09',
      cycleEndsAt: firebase.firestore.Timestamp.fromDate(
        new Date('2026-09-16T00:00:00Z'),
      ),
      manualRecruitmentEnabled: true,
      hasAvailableSlot: true,
      memberPlayerIds: memberTargets.map((target) => target.playerId),
      partySlots: partySlots(memberCount),
      raidStateTargets: memberTargets,
      commandTargets: memberTargets,
      groupActiveRecruitmentCountAfter: recruitmentGroupCountSnapshot,
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
  const commandTargets = type === 'incompleteEnd'
    || (type === 'disband' && recruitmentStatusRequiresPreservedStates(options))
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
        : type === 'incompleteEnd'
          ? 'incompleteEnded'
        : 'active';
    const nextCycleStatus = type === 'complete'
      ? 'completed'
      : type === 'disband'
        ? recruitment.currentCycleStatus
        : type === 'incompleteEnd'
          ? 'incompleteEnded'
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
      || type === 'incompleteEnd'
      || (type === 'disband' && recruitment.status === 'active');
    const group = closesActiveRecruitment
      ? (await transaction.get(groupRef)).data()
      : null;
    const nextGroupCount = closesActiveRecruitment
      ? group.activeRecruitmentCount - 1
      : recruitment.groupActiveRecruitmentCountAfter;

    transaction.update(recruitmentRef, {
      status: nextStatus,
      currentCycleStatus: nextCycleStatus,
      currentCycleKey: nextCycleKey,
      commandTargets,
      groupActiveRecruitmentCountAfter: nextGroupCount,
      revision: options.staleRevision ? nextRevision + 1 : nextRevision,
      lastCommandId: commandId,
      lastCommandType: type,
      lastCommandActorPlayerId: options.actorPlayerId ?? leaderPlayerId,
      lastCommandAt: firebase.firestore.FieldValue.serverTimestamp(),
      ...(type === 'incompleteEnd' ? {
        manualRecruitmentEnabled: false,
        hasAvailableSlot: false,
      } : {}),
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
        activeRecruitmentCount: nextGroupCount,
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
      schemaVersion: type === 'complete' || type === 'incompleteEnd'
        ? 2
        : 1,
      eventId: commandId,
      recruitmentId,
      type: type === 'incompleteEnd' ? 'partyIncompleteEnded' : type,
      commandId,
      commandRevision: nextRevision,
      audiencePlayerIds: memberTargets.map((target) => target.playerId),
      actorPlayerId: options.actorPlayerId ?? leaderPlayerId,
      ...(type === 'complete' || type === 'incompleteEnd' ? {
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
        lifecycleTransaction(leaderDb, memberCount, 'advanceCycle'),
      );
      console.log(`PASS: ${memberCount}-member lifecycle commands`);

      await seed(testEnv, memberCount);
      await assertSucceeds(
        lifecycleTransaction(leaderDb, memberCount, 'disband'),
      );
      console.log(`PASS: ${memberCount}-member group disband`);
    }

    await seed(testEnv, 8, {
      groupActiveRecruitmentCount: 17,
      recruitmentGroupCountSnapshot: 5,
    });
    await assertSucceeds(lifecycleTransaction(leaderDb, 8, 'disband'));
    console.log('PASS: old group room closes from current 17 to 16');

    await seed(testEnv, 8, { continueTogether: false });
    await assertSucceeds(lifecycleTransaction(leaderDb, 8, 'complete'));
    await assertSucceeds(
      lifecycleTransaction(leaderDb, 8, 'disband', {
        completedDisband: true,
      }),
    );
    console.log('PASS: one-shot completion and completed disband');

    await seed(testEnv, 8, { continueTogether: false });
    const memberDb = testEnv.authenticatedContext(memberUid).firestore();
    await assertSucceeds(
      lifecycleTransaction(memberDb, 8, 'incompleteEnd', {
        actorPlayerId: memberPlayerId,
      }),
    );
    for (const target of targets(8)) {
      await assertSucceeds(stateRef(memberDb, target).get());
    }
    console.log('PASS: expired one-shot ends without raidState writes');

    await seed(testEnv, 8, { continueTogether: true });
    await assertFails(
      lifecycleTransaction(memberDb, 8, 'incompleteEnd', {
        actorPlayerId: memberPlayerId,
      }),
    );
    console.log('PASS: recurring room incomplete end denied');

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
