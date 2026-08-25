import {
  extractEquipmentSnapshot,
  requireCompleteBaseline,
  selectChallengeSlots,
} from './equipment_verification.js';

const CHALLENGE_DURATION_MS = 10 * 60 * 1000;
const VALID_SOURCES = new Set(['provisional', 'directInput']);

export function createStartVerificationHandler({
  bindingStore,
  lostArkApi,
  challengeStore,
  randomInt,
  clock = () => new Date(),
}) {
  return async function startVerification(request) {
    const authUid = request.auth?.uid;
    if (typeof authUid !== 'string' || authUid.trim() === '') {
      throw new StartVerificationError('unauthenticated');
    }
    const input = parseInput(request.data);
    const playerId = await bindingStore.requireActivePlayerId(authUid);
    const [siblings, armory] = await Promise.all([
      lostArkApi.fetchSiblings(input.characterName),
      lostArkApi.fetchArmory(input.characterName),
    ]);
    const normalizedSiblings = normalizeSiblings(siblings, input.characterName);
    const baselineEquipment = extractEquipmentSnapshot(armory?.ArmoryEquipment);
    requireCompleteBaseline(baselineEquipment);
    const requiredUnequippedSlots = selectChallengeSlots(randomInt);
    const createdAt = clock();
    if (!(createdAt instanceof Date) || Number.isNaN(createdAt.valueOf())) {
      throw new StartVerificationError('internal');
    }
    const expiresAt = new Date(createdAt.valueOf() + CHALLENGE_DURATION_MS);

    const challengeId = await challengeStore.replacePendingChallenge({
      schemaVersion: 1,
      playerId,
      authUid,
      characterName: input.characterName,
      source: input.source,
      localAccountId: input.localAccountId,
      status: 'pending',
      baselineEquipment,
      requiredUnequippedSlots,
      siblingsSnapshot: normalizedSiblings,
      attemptCount: 0,
      createdAt,
      expiresAt,
      lastCheckedAt: null,
      verifiedAt: null,
      failureCode: null,
    });

    return Object.freeze({
      challengeId,
      characterName: input.characterName,
      requiredUnequippedSlots,
      expiresAtMillis: expiresAt.valueOf(),
      status: 'pending',
    });
  };
}

function parseInput(data) {
  if (data === null || typeof data !== 'object') {
    throw new StartVerificationError('invalid-argument');
  }
  const characterName = typeof data.characterName === 'string' ?
    data.characterName.trim() : '';
  if (characterName.length < 1 || characterName.length > 20) {
    throw new StartVerificationError('invalid-argument');
  }
  if (!VALID_SOURCES.has(data.source)) {
    throw new StartVerificationError('invalid-argument');
  }
  const localAccountId = data.localAccountId ?? null;
  if (localAccountId !== null &&
      (!Number.isSafeInteger(localAccountId) || localAccountId <= 0)) {
    throw new StartVerificationError('invalid-argument');
  }
  return {characterName, source: data.source, localAccountId};
}

function normalizeSiblings(siblings, requestedCharacterName) {
  if (!Array.isArray(siblings) || siblings.length === 0) {
    throw new StartVerificationError('invalid-api-response');
  }
  const normalized = siblings.map((character) => {
    if (character === null || typeof character !== 'object' ||
        typeof character.ServerName !== 'string' ||
        typeof character.CharacterName !== 'string' ||
        typeof character.CharacterClassName !== 'string' ||
        !Number.isSafeInteger(character.CharacterLevel)) {
      throw new StartVerificationError('invalid-api-response');
    }
    return Object.freeze({
      serverName: character.ServerName.trim(),
      characterName: character.CharacterName.trim(),
      characterClassName: character.CharacterClassName.trim(),
      characterLevel: character.CharacterLevel,
      itemAvgLevel: typeof character.ItemAvgLevel === 'string' ?
        character.ItemAvgLevel : null,
    });
  });
  if (!normalized.some(
    (character) => character.characterName === requestedCharacterName,
  )) {
    throw new StartVerificationError('invalid-api-response');
  }
  return Object.freeze(normalized);
}

export class StartVerificationError extends Error {
  constructor(code, cause) {
    super(code, {cause});
    this.name = 'StartVerificationError';
    this.code = code;
  }
}
