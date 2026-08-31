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
  updateDoc,
  deleteDoc,
  deleteField,
  runTransaction,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'demo-rules-complexity';
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

async function seed(testEnv, activeGroupIds = [groupId]) {
  const now = Timestamp.now();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = getFirestore(context);
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
      memberCount: 2,
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
    const db = getFirestore(memberContext);

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
    const leaderDb = getFirestore(testEnv.authenticatedContext(leaderAuthUid));
    await assertFails(updateDoc(
      doc(leaderDb, 'groups', groupId, 'members', memberPlayerId),
      { combatPowerSnapshot: 3000, updatedAt: serverTimestamp() },
    ));
    console.log('PASS: self snapshot refresh and protected-field guards');

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
