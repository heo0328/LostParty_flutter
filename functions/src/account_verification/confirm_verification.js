import {
  EquipmentSnapshotError,
  evaluateEquipmentChallenge,
  extractEquipmentSnapshot,
} from './equipment_verification.js';

export function createConfirmVerificationHandler({
  bindingStore,
  lostArkApi,
  challengeStore,
  verificationCompleter,
  clock = () => new Date(),
}) {
  return async function confirmVerification(request) {
    const authUid = request.auth?.uid;
    if (typeof authUid !== 'string' || authUid.trim() === '') {
      throw new ConfirmVerificationError('unauthenticated');
    }
    const challengeId = parseChallengeId(request.data);
    const playerId = await bindingStore.requireActivePlayerId(authUid);
    const challenge = await challengeStore.loadOwnedChallenge({
      challengeId,
      authUid,
      playerId,
    });
    if (challenge.status === 'verified') {
      return verifiedResponse(challenge.verificationResult);
    }
    if (challenge.status !== 'pending') {
      return Object.freeze({status: challenge.status});
    }

    const now = clock();
    const expiredResult = evaluateEquipmentChallenge({
      baseline: challenge.baselineEquipment,
      current: {},
      requiredUnequippedSlots: challenge.requiredUnequippedSlots,
      expiresAt: challenge.expiresAt,
      now,
    });
    if (expiredResult.status === 'expired') {
      await challengeStore.recordAttempt({
        challengeId,
        authUid,
        playerId,
        result: expiredResult,
        checkedAt: now,
      });
      return expiredResult;
    }

    let currentEquipment;
    try {
      const armory = await lostArkApi.fetchArmory(challenge.characterName);
      currentEquipment = extractEquipmentSnapshot(armory?.ArmoryEquipment);
    } catch (error) {
      if (!(error instanceof EquipmentSnapshotError)) throw error;
      const result = Object.freeze({status: 'invalidEquipmentSnapshot'});
      await challengeStore.recordAttempt({
        challengeId,
        authUid,
        playerId,
        result,
        checkedAt: now,
      });
      return result;
    }

    const result = evaluateEquipmentChallenge({
      baseline: challenge.baselineEquipment,
      current: currentEquipment,
      requiredUnequippedSlots: challenge.requiredUnequippedSlots,
      expiresAt: challenge.expiresAt,
      now,
    });
    if (result.status !== 'verified') {
      await challengeStore.recordAttempt({
        challengeId,
        authUid,
        playerId,
        result,
        checkedAt: now,
      });
      return result;
    }

    const verificationResult = await verificationCompleter.complete({
      challenge,
      challengeId,
      authUid,
      playerId,
      verifiedAt: now,
    });
    return verifiedResponse(verificationResult);
  };
}

function parseChallengeId(data) {
  const challengeId = data !== null && typeof data === 'object' &&
    typeof data.challengeId === 'string' ? data.challengeId.trim() : '';
  if (challengeId.length < 1 || challengeId.length > 128) {
    throw new ConfirmVerificationError('invalid-argument');
  }
  return challengeId;
}

function verifiedResponse(result) {
  if (result === null || typeof result !== 'object') {
    throw new ConfirmVerificationError('invalid-verification-result');
  }
  return Object.freeze({
    status: 'verified',
    serverGameAccountId: result.serverGameAccountId,
    serverCharacters: result.serverCharacters,
  });
}

export class ConfirmVerificationError extends Error {
  constructor(code) {
    super(code);
    this.name = 'ConfirmVerificationError';
    this.code = code;
  }
}
