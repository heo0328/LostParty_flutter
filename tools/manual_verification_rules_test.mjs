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
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ID = 'lost-party-rules-test';
const rules = fs.readFileSync(
  path.join(__dirname, '..', 'firestore.rules'),
  'utf8',
);

const operatorAuthUid = 'operator-auth';
const operatorPlayerId = 'operator-player';
const requesterPlayerId = 'requester-player';
const ownerPlayerId = 'owner-player';
const requestId = 'req-1';

function futureTimestamp(hours = 24) {
  return Timestamp.fromDate(new Date(Date.now() + hours * 60 * 60 * 1000));
}

function pastTimestamp(hours = 1) {
  return Timestamp.fromDate(new Date(Date.now() - hours * 60 * 60 * 1000));
}

async function seedBase(testEnv) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = getFirestore(context);
    await setDoc(doc(db, 'authBindings', operatorAuthUid), {
      schemaVersion: 1,
      playerId: operatorPlayerId,
      status: 'active',
      linkedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'players', operatorPlayerId), {
      schemaVersion: 1,
      status: 'active',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'operatorAssignments', operatorPlayerId), {
      schemaVersion: 1,
      playerId: operatorPlayerId,
      status: 'active',
    });
    await setDoc(doc(db, 'players', ownerPlayerId), {
      schemaVersion: 1,
      status: 'active',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'gameAccounts', 'ga-1'), {
      ownerPlayerId: ownerPlayerId,
      status: 'active',
    });
  });
}

async function seedPendingRequest(testEnv, overrides = {}) {
  const createdAt = Timestamp.now();
  const expiresAt = futureTimestamp(24);
  const payload = {
    schemaVersion: 1,
    requesterPlayerId,
    targetIdentityKey: 'identity-1',
    localAccountId: 1,
    localAccountLabelSnapshot: '부캐1',
    proofServerName: '루페온',
    proofCharacterName: '테스트캐',
    proofClassName: '워로드',
    verificationCode: 'LP-234567',
    status: 'pendingProof',
    attemptNumberForTarget: 1,
    totalAttemptNumberForPlayer: 1,
    createdAt,
    expiresAt,
    updatedAt: createdAt,
    ...overrides,
  };
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = getFirestore(context);
    await setDoc(doc(db, 'manualVerificationRequests', requestId), payload);
  });
  return { createdAt, expiresAt };
}

const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: { rules },
});

try {
  await testEnv.clearFirestore();
  await seedBase(testEnv);
  await seedPendingRequest(testEnv);

  const operatorDb = getFirestore(
    testEnv.authenticatedContext(operatorAuthUid),
  );

  console.log('test: operator cancel');
  await assertSucceeds(
    updateDoc(doc(operatorDb, 'manualVerificationRequests', requestId), {
      status: 'cancelled',
      reviewedByOperatorPlayerId: operatorPlayerId,
      reviewedAt: serverTimestamp(),
      reviewReason: '테스트 취소',
      resolvedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await testEnv.clearFirestore();
  await seedBase(testEnv);
  const { expiresAt } = await seedPendingRequest(testEnv);

  console.log('test: operator dispute open + event');
  const deadline = futureTimestamp(24);
  await assertSucceeds(
  updateDoc(doc(operatorDb, 'manualVerificationRequests', requestId), {
      status: 'awaitingOwnerResponse',
      targetGameAccountId: 'ga-1',
      previousOwnerPlayerId: ownerPlayerId,
      disputeOpenedAt: serverTimestamp(),
      ownerResponseDeadlineAt: deadline,
      reviewedByOperatorPlayerId: operatorPlayerId,
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await testEnv.clearFirestore();
  await seedBase(testEnv);
  await seedPendingRequest(testEnv, { expiresAt: pastTimestamp(1) });

  console.log('test: operator cancel on expired request');
  const expiredCancel = await assertFails(
    updateDoc(doc(operatorDb, 'manualVerificationRequests', requestId), {
      status: 'cancelled',
      reviewedByOperatorPlayerId: operatorPlayerId,
      reviewedAt: serverTimestamp(),
      reviewReason: '만료 취소',
      resolvedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  console.log('expired cancel error:', expiredCancel?.code);

  console.log('all targeted checks finished');
} finally {
  await testEnv.cleanup();
}
