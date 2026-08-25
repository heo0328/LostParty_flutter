import {randomInt} from 'node:crypto';

import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {defineSecret, defineString} from 'firebase-functions/params';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

import {
  ActivePlayerBindingError,
  ChallengeAccessError,
  ChallengeStateError,
  FirestoreBindingStore,
  FirestoreChallengeStore,
  FirestoreVerificationCompleter,
  IdentityConflictError,
} from './account_verification/firestore_stores.js';
import {LostArkApi} from './account_verification/lost_ark_api.js';
import {LostArkApiError} from './account_verification/lost_ark_api.js';
import {EquipmentSnapshotError} from './account_verification/equipment_verification.js';
import {
  createStartVerificationHandler,
  StartVerificationError,
} from './account_verification/start_verification.js';
import {
  ConfirmVerificationError,
  createConfirmVerificationHandler,
} from './account_verification/confirm_verification.js';

initializeApp();

const lostArkApiJwt = defineSecret('LOST_ARK_API_JWT');
const lostArkApiBaseUrl = defineString('LOST_ARK_API_BASE_URL', {
  default: 'https://developer-lostark.game.onstove.com',
});

export const startGameAccountVerification = onCall(
  {
    region: 'asia-northeast3',
    secrets: [lostArkApiJwt],
    timeoutSeconds: 30,
  },
  async (request) => {
    const firestore = getFirestore();
    const handler = createStartVerificationHandler({
      bindingStore: new FirestoreBindingStore(firestore),
      lostArkApi: new LostArkApi({
        apiKey: lostArkApiJwt.value(),
        baseUrl: lostArkApiBaseUrl.value(),
      }),
      challengeStore: new FirestoreChallengeStore(firestore),
      randomInt,
    });
    try {
      return await handler(request);
    } catch (error) {
      throw toHttpsError(error);
    }
  },
);

export const confirmGameAccountVerification = onCall(
  {
    region: 'asia-northeast3',
    secrets: [lostArkApiJwt],
    timeoutSeconds: 30,
  },
  async (request) => {
    const firestore = getFirestore();
    const handler = createConfirmVerificationHandler({
      bindingStore: new FirestoreBindingStore(firestore),
      lostArkApi: new LostArkApi({
        apiKey: lostArkApiJwt.value(),
        baseUrl: lostArkApiBaseUrl.value(),
      }),
      challengeStore: new FirestoreChallengeStore(firestore),
      verificationCompleter: new FirestoreVerificationCompleter(firestore),
    });
    try {
      return await handler(request);
    } catch (error) {
      throw toHttpsError(error, 'confirm');
    }
  },
);

function toHttpsError(error, operation = 'start') {
  if (error instanceof ConfirmVerificationError) {
    if (error.code === 'unauthenticated') {
      return new HttpsError('unauthenticated', 'Authentication is required.');
    }
    if (error.code === 'invalid-argument') {
      return new HttpsError('invalid-argument', 'Invalid verification request.');
    }
  }
  if (error instanceof StartVerificationError) {
    if (error.code === 'unauthenticated') {
      return new HttpsError('unauthenticated', 'Authentication is required.');
    }
    if (error.code === 'invalid-argument') {
      return new HttpsError('invalid-argument', 'Invalid verification request.');
    }
    if (error.code === 'invalid-api-response') {
      return new HttpsError('failed-precondition', 'Character data is unavailable.');
    }
  }
  if (error instanceof ActivePlayerBindingError) {
    return new HttpsError(
      'failed-precondition',
      'An active player binding is required.',
    );
  }
  if (error instanceof ChallengeAccessError) {
    return new HttpsError('not-found', 'Verification challenge was not found.');
  }
  if (error instanceof ChallengeStateError) {
    return new HttpsError(
      'failed-precondition',
      'Verification challenge can no longer be completed.',
    );
  }
  if (error instanceof IdentityConflictError) {
    return new HttpsError(
      'aborted',
      'Conflicting character identity data must be reviewed.',
    );
  }
  if (error instanceof EquipmentSnapshotError) {
    return new HttpsError(
      'failed-precondition',
      'All verification equipment must be equipped.',
    );
  }
  if (error instanceof LostArkApiError) {
    if (error.status === 429) {
      return new HttpsError('resource-exhausted', 'Please try again later.');
    }
    return new HttpsError('unavailable', 'Character data is unavailable.');
  }
  return new HttpsError('internal', `Unable to ${operation} verification.`);
}
