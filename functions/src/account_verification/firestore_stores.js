import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {createHash} from 'node:crypto';

export class FirestoreBindingStore {
  constructor(firestore) {
    this.firestore = firestore;
  }

  async requireActivePlayerId(authUid) {
    const binding = await this.firestore.collection('authBindings').doc(authUid).get();
    const data = binding.data();
    if (!binding.exists || data?.schemaVersion !== 1 ||
        data?.status !== 'active' || typeof data?.playerId !== 'string' ||
        data.playerId.trim() === '') {
      throw new ActivePlayerBindingError();
    }
    const player = await this.firestore.collection('players').doc(data.playerId).get();
    if (!player.exists || player.data()?.schemaVersion !== 1 ||
        player.data()?.status !== 'active') {
      throw new ActivePlayerBindingError();
    }
    return data.playerId;
  }
}

export class ActivePlayerBindingError extends Error {
  constructor() {
    super('Active player binding is required.');
    this.name = 'ActivePlayerBindingError';
  }
}

export class FirestoreChallengeStore {
  constructor(firestore) {
    this.firestore = firestore;
  }

  replacePendingChallenge(challenge) {
    const challengeRef = this.firestore
      .collection('accountVerificationChallenges').doc();
    const activeRef = this.firestore
      .collection('activeAccountVerificationChallenges')
      .doc(challenge.playerId);

    return this.firestore.runTransaction(async (transaction) => {
      const active = await transaction.get(activeRef);
      const previousChallengeId = active.data()?.challengeId;
      if (typeof previousChallengeId === 'string' && previousChallengeId !== '') {
        const previousRef = this.firestore
          .collection('accountVerificationChallenges')
          .doc(previousChallengeId);
        const previous = await transaction.get(previousRef);
        if (previous.exists && previous.data()?.status === 'pending') {
          transaction.update(previousRef, {
            status: 'expired',
            failureCode: 'replaced',
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      transaction.create(challengeRef, {
        ...challenge,
        createdAt: Timestamp.fromDate(challenge.createdAt),
        expiresAt: Timestamp.fromDate(challenge.expiresAt),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(activeRef, {
        schemaVersion: 1,
        playerId: challenge.playerId,
        challengeId: challengeRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return challengeRef.id;
    });
  }

  async loadOwnedChallenge({challengeId, authUid, playerId}) {
    const snapshot = await this.firestore
      .collection('accountVerificationChallenges').doc(challengeId).get();
    const data = snapshot.data();
    if (!snapshot.exists || data?.schemaVersion !== 1 ||
        data.authUid !== authUid || data.playerId !== playerId) {
      throw new ChallengeAccessError();
    }
    return decodeChallenge(data);
  }

  recordAttempt({challengeId, authUid, playerId, result, checkedAt}) {
    const challengeRef = this.firestore
      .collection('accountVerificationChallenges').doc(challengeId);
    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(challengeRef);
      const data = snapshot.data();
      if (!snapshot.exists || data?.schemaVersion !== 1 ||
          data.authUid !== authUid || data.playerId !== playerId) {
        throw new ChallengeAccessError();
      }
      if (data.status !== 'pending') return;
      transaction.update(challengeRef, {
        status: result.status === 'expired' ? 'expired' : 'pending',
        attemptCount: FieldValue.increment(1),
        lastCheckedAt: Timestamp.fromDate(checkedAt),
        failureCode: result.status === 'expired' ? 'expired' : result.status,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }
}

export class FirestoreVerificationCompleter {
  constructor(firestore) {
    this.firestore = firestore;
  }

  complete({challengeId, authUid, playerId, verifiedAt}) {
    const challengeRef = this.firestore
      .collection('accountVerificationChallenges').doc(challengeId);
    const activeRef = this.firestore
      .collection('activeAccountVerificationChallenges').doc(playerId);

    return this.firestore.runTransaction(async (transaction) => {
      const challengeSnapshot = await transaction.get(challengeRef);
      const activeSnapshot = await transaction.get(activeRef);
      const challenge = challengeSnapshot.data();
      if (!challengeSnapshot.exists || challenge?.schemaVersion !== 1 ||
          challenge.authUid !== authUid || challenge.playerId !== playerId) {
        throw new ChallengeAccessError();
      }
      if (challenge.status === 'verified') {
        return challenge.verificationResult;
      }
      if (challenge.status !== 'pending' ||
          challenge.expiresAt.toDate() <= verifiedAt) {
        throw new ChallengeStateError();
      }

      const siblings = challenge.siblingsSnapshot;
      if (!Array.isArray(siblings) || siblings.length === 0) {
        throw new ChallengeStateError();
      }
      const claimRefs = siblings.map((character) => this.firestore
        .collection('characterIdentityClaims')
        .doc(characterIdentityKey(character)));
      const claimSnapshots = await transaction.getAll(...claimRefs);
      for (const claim of claimSnapshots) {
        if (claim.exists &&
            (typeof claim.data()?.gameAccountId !== 'string' ||
             claim.data().gameAccountId === '' ||
             typeof claim.data()?.characterId !== 'string' ||
             claim.data().characterId === '')) {
          throw new IdentityConflictError();
        }
      }
      const claimedAccountIds = new Set(claimSnapshots
        .filter((snapshot) => snapshot.exists)
        .map((snapshot) => snapshot.data()?.gameAccountId)
        .filter((value) => typeof value === 'string' && value !== ''));
      if (claimedAccountIds.size > 1) {
        throw new IdentityConflictError();
      }

      const existingGameAccountId = [...claimedAccountIds][0];
      const gameAccountRef = existingGameAccountId === undefined ?
        this.firestore.collection('gameAccounts').doc() :
        this.firestore.collection('gameAccounts').doc(existingGameAccountId);
      const gameAccountSnapshot = existingGameAccountId === undefined ? null :
        await transaction.get(gameAccountRef);
      if (existingGameAccountId !== undefined && !gameAccountSnapshot.exists) {
        throw new IdentityConflictError();
      }
      const accountCharactersSnapshot = existingGameAccountId === undefined ? null :
        await transaction.get(this.firestore.collection('characters')
          .where('gameAccountId', '==', existingGameAccountId));
      const previousOwnerPlayerId = gameAccountSnapshot?.data()?.ownerPlayerId;

      const characterRefs = claimSnapshots.map((claim) => {
        const characterId = claim.data()?.characterId;
        return typeof characterId === 'string' && characterId !== '' ?
          this.firestore.collection('characters').doc(characterId) :
          this.firestore.collection('characters').doc();
      });
      const existingCharacterRefs = characterRefs.filter(
        (_ref, index) => claimSnapshots[index].exists,
      );
      if (existingCharacterRefs.length > 0) {
        const existingCharacters = await transaction.getAll(...existingCharacterRefs);
        if (existingCharacters.some((snapshot) => !snapshot.exists)) {
          throw new IdentityConflictError();
        }
      }

      const now = Timestamp.fromDate(verifiedAt);
      const currentCharacterIds = new Set(characterRefs.map((ref) => ref.id));
      accountCharactersSnapshot?.docs
        .filter((snapshot) => !currentCharacterIds.has(snapshot.id))
        .forEach((snapshot) => transaction.update(snapshot.ref, {
          ownerPlayerId: playerId,
          rosterStatus: 'missingFromLatestRoster',
          updatedAt: now,
        }));
      transaction.set(gameAccountRef, {
        schemaVersion: 1,
        ownerPlayerId: playerId,
        status: 'active',
        lookupCharacterName: challenge.characterName,
        updatedAt: now,
        ...(gameAccountSnapshot?.exists ? {} : {createdAt: now}),
      }, {merge: true});

      const serverCharacters = [];
      siblings.forEach((character, index) => {
        const characterRef = characterRefs[index];
        transaction.set(characterRef, {
          schemaVersion: 1,
          ownerPlayerId: playerId,
          gameAccountId: gameAccountRef.id,
          status: 'active',
          rosterStatus: 'confirmed',
          ...character,
          updatedAt: now,
          ...(claimSnapshots[index].exists ? {} : {createdAt: now}),
        }, {merge: true});
        transaction.set(claimRefs[index], {
          schemaVersion: 1,
          gameAccountId: gameAccountRef.id,
          characterId: characterRef.id,
          serverName: character.serverName,
          characterName: character.characterName,
          updatedAt: now,
        });
        serverCharacters.push({
          serverName: character.serverName,
          characterName: character.characterName,
          serverCharacterId: characterRef.id,
        });
      });

      transaction.set(
        this.firestore.collection('playerGameAccounts')
          .doc(`${playerId}_${gameAccountRef.id}`),
        {
          schemaVersion: 1,
          playerId,
          gameAccountId: gameAccountRef.id,
          status: 'active',
          updatedAt: now,
        },
      );
      if (typeof previousOwnerPlayerId === 'string' &&
          previousOwnerPlayerId !== playerId) {
        transaction.set(
          this.firestore.collection('playerGameAccounts')
            .doc(`${previousOwnerPlayerId}_${gameAccountRef.id}`),
          {
            schemaVersion: 1,
            playerId: previousOwnerPlayerId,
            gameAccountId: gameAccountRef.id,
            status: 'ownershipLost',
            updatedAt: now,
          },
          {merge: true},
        );
      }

      const verificationResult = {
        serverGameAccountId: gameAccountRef.id,
        serverCharacters,
      };
      transaction.update(challengeRef, {
        status: 'verified',
        verifiedAt: now,
        lastCheckedAt: now,
        attemptCount: FieldValue.increment(1),
        failureCode: null,
        verificationResult,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (activeSnapshot.data()?.challengeId === challengeId) {
        transaction.delete(activeRef);
      }
      return verificationResult;
    });
  }
}

function decodeChallenge(data) {
  return {
    ...data,
    createdAt: data.createdAt.toDate(),
    expiresAt: data.expiresAt.toDate(),
    lastCheckedAt: data.lastCheckedAt?.toDate() ?? null,
    verifiedAt: data.verifiedAt?.toDate() ?? null,
  };
}

export function characterIdentityKey(character) {
  if (typeof character?.serverName !== 'string' ||
      typeof character?.characterName !== 'string' ||
      character.serverName.trim() === '' || character.characterName.trim() === '') {
    throw new ChallengeStateError();
  }
  return createHash('sha256')
    .update(`${character.serverName.trim()}\u0000${character.characterName.trim()}`)
    .digest('base64url');
}

export class ChallengeAccessError extends Error {}
export class ChallengeStateError extends Error {}
export class IdentityConflictError extends Error {}
