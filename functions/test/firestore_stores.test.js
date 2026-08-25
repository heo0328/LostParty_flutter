import assert from 'node:assert/strict';
import test from 'node:test';

import {Timestamp} from 'firebase-admin/firestore';

import {
  characterIdentityKey,
  FirestoreChallengeStore,
  FirestoreVerificationCompleter,
  IdentityConflictError,
} from '../src/account_verification/firestore_stores.js';

test('expires the previous pending challenge and replaces the active pointer', async () => {
  const firestore = fakeFirestore({
    'activeAccountVerificationChallenges/player-1': {
      challengeId: 'challenge-old',
    },
    'accountVerificationChallenges/challenge-old': {
      status: 'pending',
    },
  });
  const store = new FirestoreChallengeStore(firestore);

  const challengeId = await store.replacePendingChallenge({
    schemaVersion: 1,
    playerId: 'player-1',
    authUid: 'auth-1',
    characterName: '이슈아이',
    source: 'directInput',
    localAccountId: null,
    status: 'pending',
    baselineEquipment: {},
    requiredUnequippedSlots: ['head'],
    siblingsSnapshot: [],
    attemptCount: 0,
    createdAt: new Date('2026-08-25T10:00:00.000Z'),
    expiresAt: new Date('2026-08-25T10:10:00.000Z'),
    lastCheckedAt: null,
    verifiedAt: null,
    failureCode: null,
  });

  assert.equal(challengeId, 'challenge-new');
  assert.equal(
    firestore.documents.get('accountVerificationChallenges/challenge-old').status,
    'expired',
  );
  assert.equal(
    firestore.documents.get('accountVerificationChallenges/challenge-old').failureCode,
    'replaced',
  );
  assert.equal(
    firestore.documents.get('activeAccountVerificationChallenges/player-1')
      .challengeId,
    'challenge-new',
  );
  assert.equal(
    firestore.documents.get('accountVerificationChallenges/challenge-new').status,
    'pending',
  );
});

test('takes over an existing account while preserving server IDs', async () => {
  const character = sibling('이슈아이');
  const claimId = characterIdentityKey(character);
  const firestore = fakeFirestore({
    'activeAccountVerificationChallenges/player-new': {challengeId: 'challenge-1'},
    'accountVerificationChallenges/challenge-1': pendingChallenge([character]),
    [`characterIdentityClaims/${claimId}`]: {
      gameAccountId: 'account-existing',
      characterId: 'character-existing',
    },
    'gameAccounts/account-existing': {ownerPlayerId: 'player-old'},
    'characters/character-existing': {ownerPlayerId: 'player-old'},
    'characters/character-missing': {
      ownerPlayerId: 'player-old',
      gameAccountId: 'account-existing',
    },
  });

  const result = await new FirestoreVerificationCompleter(firestore).complete({
    challengeId: 'challenge-1',
    authUid: 'auth-new',
    playerId: 'player-new',
    verifiedAt: new Date('2026-08-25T10:05:00.000Z'),
  });

  assert.equal(result.serverGameAccountId, 'account-existing');
  assert.equal(result.serverCharacters[0].serverCharacterId, 'character-existing');
  assert.equal(
    firestore.documents.get('gameAccounts/account-existing').ownerPlayerId,
    'player-new',
  );
  assert.equal(
    firestore.documents.get('characters/character-existing').ownerPlayerId,
    'player-new',
  );
  assert.deepEqual(
    firestore.documents.get('characters/character-missing'),
    {
      ownerPlayerId: 'player-new',
      gameAccountId: 'account-existing',
      rosterStatus: 'missingFromLatestRoster',
      updatedAt: Timestamp.fromDate(new Date('2026-08-25T10:05:00.000Z')),
    },
  );
  assert.equal(
    firestore.documents.get('playerGameAccounts/player-old_account-existing').status,
    'ownershipLost',
  );
  assert.equal(
    firestore.documents.get('playerGameAccounts/player-new_account-existing').status,
    'active',
  );
  assert.equal(
    firestore.documents.get('accountVerificationChallenges/challenge-1').status,
    'verified',
  );
  assert.equal(
    firestore.documents.has('activeAccountVerificationChallenges/player-new'),
    false,
  );
});

test('returns the stored completion result idempotently', async () => {
  const verificationResult = {
    serverGameAccountId: 'account-1',
    serverCharacters: [],
  };
  const firestore = fakeFirestore({
    'accountVerificationChallenges/challenge-1': {
      ...pendingChallenge([sibling('이슈아이')]),
      status: 'verified',
      verificationResult,
    },
  });
  const result = await new FirestoreVerificationCompleter(firestore).complete({
    challengeId: 'challenge-1',
    authUid: 'auth-new',
    playerId: 'player-new',
    verifiedAt: new Date('2026-08-25T10:05:00.000Z'),
  });
  assert.deepEqual(result, verificationResult);
});

test('rejects siblings claimed by different game accounts', async () => {
  const first = sibling('이슈아이');
  const second = sibling('이슈둘');
  const firestore = fakeFirestore({
    'activeAccountVerificationChallenges/player-new': {challengeId: 'challenge-1'},
    'accountVerificationChallenges/challenge-1': pendingChallenge([first, second]),
    [`characterIdentityClaims/${characterIdentityKey(first)}`]: {
      gameAccountId: 'account-1', characterId: 'character-1',
    },
    [`characterIdentityClaims/${characterIdentityKey(second)}`]: {
      gameAccountId: 'account-2', characterId: 'character-2',
    },
  });
  await assert.rejects(
    new FirestoreVerificationCompleter(firestore).complete({
      challengeId: 'challenge-1',
      authUid: 'auth-new',
      playerId: 'player-new',
      verifiedAt: new Date('2026-08-25T10:05:00.000Z'),
    }),
    (error) => error instanceof IdentityConflictError,
  );
});

function sibling(characterName) {
  return {
    serverName: '루페온',
    characterName,
    characterClassName: '도화가',
    characterLevel: 70,
    itemAvgLevel: '1,700.00',
  };
}

function pendingChallenge(siblingsSnapshot) {
  return {
    schemaVersion: 1,
    authUid: 'auth-new',
    playerId: 'player-new',
    status: 'pending',
    characterName: '이슈아이',
    siblingsSnapshot,
    expiresAt: Timestamp.fromDate(new Date('2026-08-25T10:10:00.000Z')),
  };
}

function fakeFirestore(initialDocuments) {
  const documents = new Map(Object.entries(initialDocuments));
  const reference = (path) => ({path, id: path.split('/').at(-1)});
  const generatedIds = new Map();
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          if (id === undefined) {
            const next = (generatedIds.get(name) ?? 0) + 1;
            generatedIds.set(name, next);
            id = name === 'accountVerificationChallenges' ?
              'challenge-new' : `${name}-new-${next}`;
          }
          return reference(`${name}/${id}`);
        },
        where(field, operator, value) {
          assert.equal(operator, '==');
          return {collectionName: name, field, value};
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collectionName !== undefined) {
            const prefix = `${ref.collectionName}/`;
            const docs = [...documents.entries()]
              .filter(([path, value]) =>
                path.startsWith(prefix) && value?.[ref.field] === ref.value)
              .map(([path, value]) => ({
                ...reference(path),
                ref: reference(path),
                exists: true,
                data: () => value,
              }));
            return {docs, empty: docs.length === 0, size: docs.length};
          }
          const value = documents.get(ref.path);
          return {
            exists: value !== undefined,
            data: () => value,
          };
        },
        async getAll(...refs) {
          return Promise.all(refs.map((ref) => this.get(ref)));
        },
        update(ref, data) {
          documents.set(ref.path, {...documents.get(ref.path), ...data});
        },
        create(ref, data) {
          assert.equal(documents.has(ref.path), false);
          documents.set(ref.path, data);
        },
        set(ref, data, options) {
          documents.set(ref.path, options?.merge ?
            {...documents.get(ref.path), ...data} : data);
        },
        delete(ref) {
          documents.delete(ref.path);
        },
      });
    },
  };
}
