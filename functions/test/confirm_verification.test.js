import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ConfirmVerificationError,
  createConfirmVerificationHandler,
} from '../src/account_verification/confirm_verification.js';

test('rejects unauthenticated and invalid requests before loading a challenge', async () => {
  const dependencies = fakes();
  const handler = createConfirmVerificationHandler(dependencies);
  await assert.rejects(
    handler({auth: null, data: {challengeId: 'challenge-1'}}),
    hasCode('unauthenticated'),
  );
  await assert.rejects(
    handler({auth: {uid: 'auth-1'}, data: {challengeId: ' '}}),
    hasCode('invalid-argument'),
  );
  assert.equal(dependencies.challengeStore.loadCalls, 0);
});

test('expires without calling the Lost Ark API', async () => {
  const dependencies = fakes();
  dependencies.clock = () => new Date('2026-08-25T10:10:00.000Z');
  const result = await createConfirmVerificationHandler(dependencies)(request());
  assert.deepEqual(result, {status: 'expired'});
  assert.equal(dependencies.lostArkApi.calls, 0);
  assert.equal(dependencies.challengeStore.attempt.result.status, 'expired');
});

test('keeps a retryable result when required equipment remains', async () => {
  const dependencies = fakes();
  const result = await createConfirmVerificationHandler(dependencies)(request());
  assert.deepEqual(result, {
    status: 'requiredSlotsStillEquipped',
    slots: ['head'],
  });
  assert.equal(dependencies.verificationCompleter.calls, 0);
});

test('completes verification after the selected equipment is removed', async () => {
  const dependencies = fakes();
  dependencies.lostArkApi.armory.ArmoryEquipment = equipment().filter(
    (item) => item.Type !== '투구',
  );
  const result = await createConfirmVerificationHandler(dependencies)(request());
  assert.deepEqual(result, {
    status: 'verified',
    serverGameAccountId: 'game-account-1',
    serverCharacters: [{
      serverName: '루페온',
      characterName: '이슈아이',
      serverCharacterId: 'character-1',
    }],
  });
  assert.equal(dependencies.verificationCompleter.calls, 1);
  assert.equal(dependencies.challengeStore.attempt, null);
});

test('returns the stored result for an already verified challenge', async () => {
  const dependencies = fakes();
  dependencies.challengeStore.challenge.status = 'verified';
  dependencies.challengeStore.challenge.verificationResult = {
    serverGameAccountId: 'game-account-existing',
    serverCharacters: [],
  };
  const result = await createConfirmVerificationHandler(dependencies)(request());
  assert.equal(result.serverGameAccountId, 'game-account-existing');
  assert.equal(dependencies.lostArkApi.calls, 0);
});

function fakes() {
  const baselineEquipment = Object.fromEntries(equipment().map((item) => [
    slot(item.Type),
    {name: item.Name, grade: item.Grade},
  ]));
  return {
    bindingStore: {
      async requireActivePlayerId() {
        return 'player-1';
      },
    },
    lostArkApi: {
      calls: 0,
      armory: {ArmoryEquipment: equipment()},
      async fetchArmory() {
        this.calls += 1;
        return this.armory;
      },
    },
    challengeStore: {
      loadCalls: 0,
      attempt: null,
      challenge: {
        status: 'pending',
        characterName: '이슈아이',
        baselineEquipment,
        requiredUnequippedSlots: ['head'],
        expiresAt: new Date('2026-08-25T10:10:00.000Z'),
      },
      async loadOwnedChallenge() {
        this.loadCalls += 1;
        return this.challenge;
      },
      async recordAttempt(attempt) {
        this.attempt = attempt;
      },
    },
    verificationCompleter: {
      calls: 0,
      async complete() {
        this.calls += 1;
        return {
          serverGameAccountId: 'game-account-1',
          serverCharacters: [{
            serverName: '루페온',
            characterName: '이슈아이',
            serverCharacterId: 'character-1',
          }],
        };
      },
    },
    clock: () => new Date('2026-08-25T10:05:00.000Z'),
  };
}

function request() {
  return {auth: {uid: 'auth-1'}, data: {challengeId: 'challenge-1'}};
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

function slot(type) {
  return {
    '무기': 'weapon',
    '투구': 'head',
    '어깨': 'shoulders',
    '상의': 'chest',
    '하의': 'legs',
    '장갑': 'hands',
  }[type];
}

function hasCode(code) {
  return (error) => error instanceof ConfirmVerificationError && error.code === code;
}
