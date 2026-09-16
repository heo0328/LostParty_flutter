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
  deleteDoc,
  deleteField,
  runTransaction,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'demo-party-group-cutover';
const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

const memberAuthUid = 'member-auth';
const leaderAuthUid = 'leader-auth';
const memberPlayerId = 'member-player';
const leaderPlayerId = 'leader-player';
const groupId = 'group-1';
const characterId = 'char-member';

async function seed(
  testEnv,
  activeGroupIds = [groupId],
  { soloLeader = false, activeRecruitmentCount = 0 } = {},
) {
  const now = Timestamp.now();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, playerId] of [
      [memberAuthUid, memberPlayerId],
      [leaderAuthUid, leaderPlayerId],
    ]) {
      await setDoc(doc(db, 'authBindings', uid), {
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
    }
    await setDoc(doc(db, 'characters', characterId), {
      schemaVersion: 1,
      ownerPlayerId: memberPlayerId,
      status: 'active',
      characterClassName: '워로드',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'groups', groupId), {
      schemaVersion: 1,
      status: 'active',
      name: '테스트그룹',
      leaderPlayerId: leaderPlayerId,
      memberCount: soloLeader ? 1 : 2,
      activeRecruitmentCount,
      hasActiveJoinCode: false,
      joinCodeVisibleToMembers: false,
      revision: 3,
      representativeCharacterId: 'char-leader',
      leaderDisplayCharacterNameSnapshot: '리더',
      lastActivityAt: now,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'groups', groupId, 'members', leaderPlayerId), {
      schemaVersion: 1,
      groupId,
      playerId: leaderPlayerId,
      role: 'leader',
      joinedAt: now,
      joinSequence: 1,
      joinedBy: 'created',
      displayCharacterIdSnapshot: 'char-leader',
      displayCharacterNameSnapshot: '리더',
      revision: 1,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(
      doc(db, 'players', leaderPlayerId, 'groupMembershipState', 'current'),
      {
        schemaVersion: 1,
        playerId: leaderPlayerId,
        activeGroupIds: [groupId],
        activeGroupCount: 1,
        revision: 1,
        updatedAt: now,
      },
    );
    await setDoc(
      doc(db, 'players', leaderPlayerId, 'groupRelations', groupId),
      {
        schemaVersion: 1,
        groupId,
        playerId: leaderPlayerId,
        relation: 'member',
        requestStatus: null,
        groupNameSnapshot: '테스트그룹',
        displayCharacterNameSnapshot: '리더',
        expiresAt: null,
        sourceRevision: 1,
        createdAt: now,
        updatedAt: now,
      },
    );
    if (soloLeader) return;
    await setDoc(doc(db, 'groups', groupId, 'members', memberPlayerId), {
      schemaVersion: 1,
      groupId,
      playerId: memberPlayerId,
      role: 'member',
      joinedAt: now,
      joinSequence: 2,
      joinedBy: 'invitation',
      displayCharacterIdSnapshot: characterId,
      displayCharacterNameSnapshot: '멤버',
      displayClassNameSnapshot: '워로드',
      itemLevelSnapshot: 1700,
      combatPowerSnapshot: 2500,
      revision: 1,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(
      doc(db, 'players', memberPlayerId, 'groupMembershipState', 'current'),
      {
        schemaVersion: 1,
        playerId: memberPlayerId,
        activeGroupIds,
        activeGroupCount: activeGroupIds.length,
        revision: 2,
        updatedAt: now,
      },
    );
    await setDoc(
      doc(db, 'players', memberPlayerId, 'groupRelations', groupId),
      {
        schemaVersion: 1,
        groupId,
        playerId: memberPlayerId,
        relation: 'member',
        requestStatus: null,
        groupNameSnapshot: '테스트그룹',
        displayCharacterNameSnapshot: '멤버',
        expiresAt: null,
        sourceRevision: 1,
        createdAt: now,
        updatedAt: now,
      },
    );
  });
}

async function transferLeadershipTransaction(db) {
  const groupRef = doc(db, 'groups', groupId);
  const outgoingRef = doc(db, 'groups', groupId, 'members', leaderPlayerId);
  const incomingRef = doc(db, 'groups', groupId, 'members', memberPlayerId);
  await runTransaction(db, async (transaction) => {
    const group = (await transaction.get(groupRef)).data();
    const outgoing = (await transaction.get(outgoingRef)).data();
    const incoming = (await transaction.get(incomingRef)).data();
    transaction.update(groupRef, {
      leaderPlayerId: memberPlayerId,
      leaderDisplayCharacterNameSnapshot: incoming.displayCharacterNameSnapshot,
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.update(outgoingRef, {
      role: 'member',
      revision: outgoing.revision + 1,
      updatedAt: serverTimestamp(),
    });
    transaction.update(incomingRef, {
      role: 'leader',
      revision: incoming.revision + 1,
      updatedAt: serverTimestamp(),
    });
  });
}

async function formerLeaderLeaveTransaction(db) {
  const groupRef = doc(db, 'groups', groupId);
  const memberRef = doc(db, 'groups', groupId, 'members', leaderPlayerId);
  const stateRef = doc(
    db,
    'players',
    leaderPlayerId,
    'groupMembershipState',
    'current',
  );
  const relationRef = doc(
    db,
    'players',
    leaderPlayerId,
    'groupRelations',
    groupId,
  );
  await runTransaction(db, async (transaction) => {
    const group = (await transaction.get(groupRef)).data();
    const state = (await transaction.get(stateRef)).data();
    transaction.delete(memberRef);
    transaction.update(groupRef, {
      memberCount: group.memberCount - 1,
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.update(stateRef, {
      schemaVersion: 1,
      playerId: leaderPlayerId,
      activeGroupIds: state.activeGroupIds.filter((id) => id !== groupId),
      activeGroupCount: state.activeGroupIds.length - 1,
      revision: state.revision + 1,
      updatedAt: serverTimestamp(),
    });
    transaction.delete(relationRef);
  });
}

async function disbandSoloGroupTransaction(db) {
  const groupRef = doc(db, 'groups', groupId);
  const memberRef = doc(db, 'groups', groupId, 'members', leaderPlayerId);
  const stateRef = doc(
    db,
    'players',
    leaderPlayerId,
    'groupMembershipState',
    'current',
  );
  const relationRef = doc(
    db,
    'players',
    leaderPlayerId,
    'groupRelations',
    groupId,
  );
  await runTransaction(db, async (transaction) => {
    const group = (await transaction.get(groupRef)).data();
    const state = (await transaction.get(stateRef)).data();
    transaction.update(groupRef, {
      status: 'softDeleted',
      memberCount: 0,
      deletedAt: serverTimestamp(),
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.delete(memberRef);
    transaction.update(stateRef, {
      schemaVersion: 1,
      playerId: leaderPlayerId,
      activeGroupIds: state.activeGroupIds.filter((id) => id !== groupId),
      activeGroupCount: state.activeGroupIds.length - 1,
      revision: state.revision + 1,
      updatedAt: serverTimestamp(),
    });
    transaction.delete(relationRef);
  });
}

async function leaveTransaction(db, overrideRemainingIds) {
  const groupRef = doc(db, 'groups', groupId);
  const memberRef = doc(db, 'groups', groupId, 'members', memberPlayerId);
  const stateRef = doc(
    db,
    'players',
    memberPlayerId,
    'groupMembershipState',
    'current',
  );
  const relationRef = doc(
    db,
    'players',
    memberPlayerId,
    'groupRelations',
    groupId,
  );

  await runTransaction(db, async (transaction) => {
    const groupSnap = await transaction.get(groupRef);
    const group = groupSnap.data();
    const stateSnap = await transaction.get(stateRef);
    const state = stateSnap.data();
    const remainingIds = overrideRemainingIds
      ?? state.activeGroupIds.filter((id) => id !== groupId);
    transaction.delete(memberRef);
    transaction.update(groupRef, {
      memberCount: group.memberCount - 1,
      revision: group.revision + 1,
      lastActivityAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.update(stateRef, {
      schemaVersion: 1,
      playerId: memberPlayerId,
      activeGroupIds: remainingIds,
      activeGroupCount: remainingIds.length,
      revision: state.revision + 1,
      updatedAt: serverTimestamp(),
    });
    transaction.delete(relationRef);
  });
}

async function main() {
  // Control compilation distinguishes an emulator transport failure from
  // failures caused by the full application's ruleset. Never deploy this.
  if (process.argv.includes('--compile-control')) {
    const control = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: "rules_version = '2'; service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read, write: if false; } } }",
      },
    });
    await control.cleanup();
    console.log('PASS: minimal deny-all control compiled (not a full Rules test)');
    return;
  }
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
  try {
    await seed(testEnv);
    const memberContext = testEnv.authenticatedContext(memberAuthUid);
    const db = memberContext.firestore();

    const snapshotRef = doc(db, 'groups', groupId, 'members', memberPlayerId);
    await assertSucceeds(updateDoc(snapshotRef, {
      displayClassNameSnapshot: '워로드', itemLevelSnapshot: 1710,
      combatPowerSnapshot: 2600, updatedAt: serverTimestamp(),
    }));
    for (const field of [
      'schemaVersion', 'groupId', 'playerId', 'role', 'joinedAt',
      'joinSequence', 'joinedBy', 'displayCharacterIdSnapshot',
      'displayCharacterNameSnapshot', 'revision', 'createdAt',
    ]) {
      await assertFails(updateDoc(snapshotRef, {
        [field]: 'tampered', updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(snapshotRef, {
        [field]: deleteField(), updatedAt: serverTimestamp(),
      }));
    }
    await assertFails(updateDoc(snapshotRef, {
      extraPermission: true, updatedAt: serverTimestamp(),
    }));
    const leaderDb = testEnv.authenticatedContext(leaderAuthUid).firestore();
    await assertFails(updateDoc(
      doc(leaderDb, 'groups', groupId, 'members', memberPlayerId),
      { combatPowerSnapshot: 3000, updatedAt: serverTimestamp() },
    ));
    console.log('PASS: self snapshot refresh and protected-field guards');

    await seed(testEnv);
    console.log('Running leader transfer and former leader leave...');
    await assertSucceeds(transferLeadershipTransaction(leaderDb));
    await assertSucceeds(formerLeaderLeaveTransaction(leaderDb));
    console.log('PASS: leader transfer and former leader leave');

    await seed(testEnv, [groupId], { soloLeader: true });
    console.log('Running solo group disband...');
    await assertSucceeds(disbandSoloGroupTransaction(leaderDb));
    console.log('PASS: solo group disband');

    await seed(testEnv, [groupId], {
      soloLeader: true,
      activeRecruitmentCount: 1,
    });
    await assertFails(disbandSoloGroupTransaction(leaderDb));
    console.log('PASS: active recruitment blocks solo group disband');

    await seed(testEnv);
    console.log('Running full leave transaction...');
    await assertSucceeds(leaveTransaction(db));
    console.log('PASS: full leave transaction');

    // Exercise the boundaries of every former ten-slot chunk.
    for (const index of [0, 9, 10, 19, 20, 29, 30, 39, 40, 49]) {
      const ids = Array.from({ length: 50 }, (_, i) => `other-${i}`);
      ids[index] = groupId;
      await seed(testEnv, ids);
      await assertSucceeds(leaveTransaction(db));
      console.log(`PASS: leave from 50 groups at index ${index}`);
    }

    await seed(testEnv, [groupId, 'other-a', 'other-b']);
    await assertFails(leaveTransaction(db, ['other-a']));
    console.log('PASS: removing two group IDs denied');

    await seed(testEnv, [groupId, 'other-a', 'other-b']);
    await assertFails(leaveTransaction(db, [groupId, 'other-a', 'other-b']));
    console.log('PASS: leaving membership without removing its ID denied');

    await seed(testEnv, [groupId, 'other-a', 'other-b']);
    await assertFails(leaveTransaction(db, ['other-a', 'injected-group']));
    console.log('PASS: injecting an unrelated group ID denied');

    // Individual operation probes after re-seed
    await seed(testEnv);

    console.log('Probe: member delete only...');
    await assertFails(
      deleteDoc(doc(db, 'groups', groupId, 'members', memberPlayerId)),
    );
    console.log('PASS: member delete alone denied (expected)');

    await seed(testEnv);
    console.log('Probe: group update only (leave patch)...');
    await assertFails(
      updateDoc(doc(db, 'groups', groupId), {
        memberCount: 1,
        revision: 4,
        lastActivityAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    console.log('PASS: group update alone denied (expected)');
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error('FAIL:', error);
  process.exit(1);
});
