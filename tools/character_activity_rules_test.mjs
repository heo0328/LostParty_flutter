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
  deleteDoc,
  writeBatch,
  serverTimestamp,
  Timestamp,
  collection,
  getDocs,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = process.env.RULES_AUDIT === '1' ? 'demo-party-group-cutover' : 'lost-party-character-activity-rules';
const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

const ownerAuthUid = 'owner-auth';
const ownerPlayerId = 'player-1';
const otherAuthUid = 'other-auth';
const otherPlayerId = 'player-2';

function activityRef(db, characterId, playerId = ownerPlayerId) {
  return doc(db, 'players', playerId, 'characterActivity', characterId);
}

function activityDoc(characterId, gameAccountId = 'account-1') {
  return {
    schemaVersion: 1,
    playerId: ownerPlayerId,
    characterId,
    gameAccountId,
    updatedAt: serverTimestamp(),
  };
}

async function writeActivity(db, characterId, gameAccountId) {
  return setDoc(
    activityRef(db, characterId),
    activityDoc(characterId, gameAccountId),
  );
}

async function seed(
  testEnv,
  { characterStatus = 'active', ownershipStatus = 'active' } = {},
) {
  const now = Timestamp.now();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'authBindings', ownerAuthUid), {
      schemaVersion: 1,
      playerId: ownerPlayerId,
      status: 'active',
      linkedAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'authBindings', otherAuthUid), {
      schemaVersion: 1,
      playerId: otherPlayerId,
      status: 'active',
      linkedAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'players', ownerPlayerId), {
      schemaVersion: 1,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'players', otherPlayerId), {
      schemaVersion: 1,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, 'characters', 'char-1'), {
      schemaVersion: 1,
      ownerPlayerId: ownerPlayerId,
      gameAccountId: 'account-1',
      status: characterStatus,
      characterName: '대표',
      serverName: '루페온',
      characterClassName: '바드',
    });
    await setDoc(doc(db, 'characters', 'char-2'), {
      schemaVersion: 1,
      ownerPlayerId: ownerPlayerId,
      gameAccountId: 'account-1',
      status: 'active',
      characterName: '부캐',
      serverName: '루페온',
      characterClassName: '바드',
    });
    await setDoc(doc(db, 'characters', 'char-other'), {
      schemaVersion: 1,
      ownerPlayerId: otherPlayerId,
      gameAccountId: 'account-other',
      status: 'active',
      characterName: '타인',
      serverName: '루페온',
      characterClassName: '바드',
    });
    await setDoc(doc(db, 'playerGameAccounts', `${ownerPlayerId}_account-1`), {
      schemaVersion: 1,
      playerId: ownerPlayerId,
      gameAccountId: 'account-1',
      status: ownershipStatus,
      representativeCharacterId: 'char-1',
    });
    await setDoc(doc(db, 'playerGameAccounts', `${otherPlayerId}_account-other`), {
      schemaVersion: 1,
      playerId: otherPlayerId,
      gameAccountId: 'account-other',
      status: 'active',
      representativeCharacterId: 'char-other',
    });
    await setDoc(doc(db, 'playerGameAccounts', `${ownerPlayerId}_account-2`), {
      schemaVersion: 1,
      playerId: ownerPlayerId,
      gameAccountId: 'account-2',
      status: 'active',
      representativeCharacterId: 'char-3',
    });
    await setDoc(doc(db, 'characters', 'char-3'), {
      schemaVersion: 1,
      ownerPlayerId: ownerPlayerId,
      gameAccountId: 'account-2',
      status: 'active',
      characterName: '다른계정대표',
      serverName: '루페온',
      characterClassName: '바드',
    });
  });
}

async function seedActivity(testEnv, characterIds) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const characterId of characterIds) {
      await setDoc(activityRef(db, characterId), {
        schemaVersion: 1,
        playerId: ownerPlayerId,
        characterId,
        gameAccountId: 'account-1',
        updatedAt: Timestamp.now(),
      });
    }
  });
}

async function seedAdditionalCharacters(testEnv, lastIndex) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = Timestamp.now();
    for (let index = 3; index <= lastIndex; index += 1) {
      await setDoc(doc(db, 'characters', `char-${index}`), {
        schemaVersion: 1,
        ownerPlayerId,
        gameAccountId: 'account-1',
        status: 'active',
        characterName: `캐릭터${index}`,
        serverName: '루페온',
        characterClassName: '바드',
        updatedAt: now,
      });
    }
  });
}

async function writeActivityInBoundedBatches(db, characterIds) {
  for (let start = 0; start < characterIds.length; start += 4) {
    const batch = writeBatch(db);
    for (const characterId of characterIds.slice(start, start + 4)) {
      batch.set(activityRef(db, characterId), activityDoc(characterId));
    }
    await batch.commit();
  }
}

console.log('rules compile: loading production firestore.rules');
const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: { rules, host: '127.0.0.1', port: 8080 },
});
console.log('rules compile: succeeded');

try {
  const ownerDb = () => testEnv.authenticatedContext(ownerAuthUid).firestore();
  const otherDb = () => testEnv.authenticatedContext(otherAuthUid).firestore();

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: owned representative activity create succeeds');
  await assertSucceeds(writeActivity(ownerDb(), 'char-1'));

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: owned representative and sub-character batch create succeeds');
  {
    const db = ownerDb();
    const batch = writeBatch(db);
    batch.set(activityRef(db, 'char-1'), activityDoc('char-1'));
    batch.set(activityRef(db, 'char-2'), activityDoc('char-2'));
    await assertSucceeds(batch.commit());
  }

  await testEnv.clearFirestore();
  await seed(testEnv);
  await seedAdditionalCharacters(testEnv, 15);
  console.log('test: fifteen activity characters succeed in bounded batches');
  {
    const db = ownerDb();
    const characterIds = Array.from(
      { length: 15 },
      (_, index) => `char-${index + 1}`,
    );
    await assertSucceeds(writeActivityInBoundedBatches(db, characterIds));
  }

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: foreign character activity create is rejected');
  await assertFails(
    setDoc(activityRef(ownerDb(), 'char-other'), {
      ...activityDoc('char-other'),
      gameAccountId: 'account-other',
    }),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: mixing own representative fields with a foreign character id is rejected');
  await assertFails(
    setDoc(activityRef(ownerDb(), 'char-other'), activityDoc('char-1')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv, { characterStatus: 'archived' });
  console.log('test: inactive character activity create is rejected');
  await assertFails(
    setDoc(activityRef(ownerDb(), 'char-1'), activityDoc('char-1')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv, { ownershipStatus: 'ownershipLost' });
  console.log('test: inactive ownership activity create is rejected');
  await assertFails(
    setDoc(activityRef(ownerDb(), 'char-1'), activityDoc('char-1')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  await seedActivity(testEnv, ['char-1', 'char-2']);
  console.log('test: representative activity delete is rejected');
  await assertFails(deleteDoc(activityRef(ownerDb(), 'char-1')));
  console.log('test: non-representative activity delete succeeds');
  await assertSucceeds(deleteDoc(activityRef(ownerDb(), 'char-2')));

  await testEnv.clearFirestore();
  await seed(testEnv);
  await seedActivity(testEnv, ['char-1', 'char-2']);
  console.log('test: emptying activity by deleting representative and sub-character is rejected');
  {
    const db = ownerDb();
    const batch = writeBatch(db);
    batch.delete(activityRef(db, 'char-1'));
    batch.delete(activityRef(db, 'char-2'));
    await assertFails(batch.commit());
  }

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: missing representative sub-character create is rejected');
  await assertFails(writeActivity(ownerDb(), 'char-2'));

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: missing representative still allows owned activity create');
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'playerGameAccounts', `${ownerPlayerId}_account-1`), {
      schemaVersion: 1,
      playerId: ownerPlayerId,
      gameAccountId: 'account-1',
      status: 'active',
    });
  });
  await assertSucceeds(
    writeActivity(ownerDb(), 'char-1'),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: mismatched gameAccountId write is rejected');
  await assertFails(
    setDoc(
      activityRef(ownerDb(), 'char-1'),
      activityDoc('char-1', 'account-2'),
    ),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: legacy list document write is rejected');
  await assertFails(
    setDoc(activityRef(ownerDb(), 'current'), {
      schemaVersion: 1,
      playerId: ownerPlayerId,
      activityCharacterIds: ['char-1', 'char-other'],
      gameAccountIds: ['account-1'],
      updatedAt: serverTimestamp(),
    }),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: other player cannot write into owner activity collection');
  await assertFails(
    setDoc(activityRef(otherDb(), 'char-1'), activityDoc('char-1')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  console.log('test: activity write without extra documents succeeds');
  await assertSucceeds(
    setDoc(activityRef(ownerDb(), 'char-1'), activityDoc('char-1')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  await seedActivity(testEnv, ['char-1']);
  console.log('test: owner can list activity documents');
  await assertSucceeds(
    getDocs(collection(ownerDb(), 'players', ownerPlayerId, 'characterActivity')),
  );

  await testEnv.clearFirestore();
  await seed(testEnv);
  await seedActivity(testEnv, ['char-1']);
  console.log('test: other bound player can list owner activity documents');
  await assertSucceeds(
    getDocs(collection(otherDb(), 'players', ownerPlayerId, 'characterActivity')),
  );

  console.log('all character activity rules checks finished');
} finally {
  await testEnv.cleanup();
}
