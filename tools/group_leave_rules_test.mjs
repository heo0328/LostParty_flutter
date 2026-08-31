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
  runTransaction,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'lost-party-leave-rules-test';
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

async function seed(testEnv) {
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
        activeGroupIds: [groupId],
        activeGroupCount: 1,
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

async function leaveTransaction(db) {
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
      activeGroupIds: [],
      activeGroupCount: 0,
      revision: state.revision + 1,
      updatedAt: serverTimestamp(),
    });
    transaction.delete(relationRef);
  });
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
  try {
    await seed(testEnv);
    const memberContext = testEnv.authenticatedContext(memberAuthUid);
    const db = getFirestore(memberContext);

    console.log('Running full leave transaction...');
    await assertSucceeds(leaveTransaction(db));
    console.log('PASS: full leave transaction');

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
