import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createStartVerificationHandler,
  StartVerificationError,
} from '../src/account_verification/start_verification.js';

test('rejects an unauthenticated request before reading data', async () => {
  const dependencies = fakes();
  const handler = createStartVerificationHandler(dependencies);

  await assert.rejects(
    handler({auth: null, data: validInput()}),
    hasCode('unauthenticated'),
  );
  assert.equal(dependencies.bindingStore.calls, 0);
});

test('rejects invalid character input before reading a binding', async () => {
  const dependencies = fakes();
  const handler = createStartVerificationHandler(dependencies);

  await assert.rejects(
    handler({auth: {uid: 'auth-1'}, data: {...validInput(), characterName: ' '}}),
    hasCode('invalid-argument'),
  );
  assert.equal(dependencies.bindingStore.calls, 0);
});

test('propagates a missing active player binding and does not call the API', async () => {
  const dependencies = fakes();
  dependencies.bindingStore.error = new Error('missing binding');
  const handler = createStartVerificationHandler(dependencies);

  await assert.rejects(
    handler({auth: {uid: 'auth-1'}, data: validInput()}),
    /missing binding/,
  );
  assert.equal(dependencies.lostArkApi.calls, 0);
});

test('creates a ten-minute challenge from fresh API responses', async () => {
  const dependencies = fakes();
  const handler = createStartVerificationHandler(dependencies);

  const response = await handler({
    auth: {uid: 'auth-1'},
    data: validInput(),
  });

  assert.equal(dependencies.lostArkApi.calls, 2);
  assert.equal(dependencies.challengeStore.saved.playerId, 'player-1');
  assert.equal(dependencies.challengeStore.saved.authUid, 'auth-1');
  assert.equal(
    dependencies.challengeStore.saved.expiresAt.valueOf() -
      dependencies.challengeStore.saved.createdAt.valueOf(),
    10 * 60 * 1000,
  );
  assert.deepEqual(response, {
    challengeId: 'challenge-1',
    characterName: '이슈아이',
    requiredUnequippedSlots: ['head'],
    expiresAtMillis: new Date('2026-08-25T10:10:00.000Z').valueOf(),
    status: 'pending',
  });
  assert.equal(Object.hasOwn(response, 'baselineEquipment'), false);
  assert.equal(Object.hasOwn(response, 'siblingsSnapshot'), false);
});

test('requires every verification equipment slot at challenge start', async () => {
  const dependencies = fakes();
  dependencies.lostArkApi.armory.ArmoryEquipment =
    dependencies.lostArkApi.armory.ArmoryEquipment.filter(
      (item) => item.Type !== '무기',
    );
  const handler = createStartVerificationHandler(dependencies);

  await assert.rejects(
    handler({auth: {uid: 'auth-1'}, data: validInput()}),
    /All verification equipment must be equipped/,
  );
  assert.equal(dependencies.challengeStore.saved, null);
});

test('rejects siblings that do not contain the requested character', async () => {
  const dependencies = fakes();
  dependencies.lostArkApi.siblings[0].CharacterName = '다른캐릭터';
  const handler = createStartVerificationHandler(dependencies);

  await assert.rejects(
    handler({auth: {uid: 'auth-1'}, data: validInput()}),
    hasCode('invalid-api-response'),
  );
  assert.equal(dependencies.challengeStore.saved, null);
});

function fakes() {
  const bindingStore = {
    calls: 0,
    error: null,
    async requireActivePlayerId() {
      this.calls += 1;
      if (this.error !== null) throw this.error;
      return 'player-1';
    },
  };
  const lostArkApi = {
    calls: 0,
    siblings: [{
      ServerName: '루페온',
      CharacterName: '이슈아이',
      CharacterClassName: '바드',
      CharacterLevel: 70,
      ItemAvgLevel: '1,760.00',
    }],
    armory: {ArmoryEquipment: equipment()},
    async fetchSiblings() {
      this.calls += 1;
      return this.siblings;
    },
    async fetchArmory() {
      this.calls += 1;
      return this.armory;
    },
  };
  const challengeStore = {
    saved: null,
    async replacePendingChallenge(challenge) {
      this.saved = challenge;
      return 'challenge-1';
    },
  };
  return {
    bindingStore,
    lostArkApi,
    challengeStore,
    randomInt: () => 0,
    clock: () => new Date('2026-08-25T10:00:00.000Z'),
  };
}

function validInput() {
  return {
    characterName: ' 이슈아이 ',
    source: 'directInput',
    localAccountId: null,
  };
}

function equipment() {
  return [
    {Type: '무기', Name: '무기', Grade: '고대'},
    {Type: '투구', Name: '투구', Grade: '고대'},
    {Type: '어깨', Name: '어깨', Grade: '고대'},
    {Type: '상의', Name: '상의', Grade: '고대'},
    {Type: '하의', Name: '하의', Grade: '고대'},
    {Type: '장갑', Name: '장갑', Grade: '고대'},
  ];
}

function hasCode(code) {
  return (error) => error instanceof StartVerificationError && error.code === code;
}
