import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createServer} from 'node:http';
import test, {after, before} from 'node:test';

import {
  connectAuthEmulator,
  getAuth,
  signInAnonymously,
} from 'firebase/auth';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';
import {initializeApp} from 'firebase/app';

const projectId = 'lost-party-emulator';
let fakeApiServer;
let armoryFixture;

before(async () => {
  armoryFixture = JSON.parse(await readFile(
    new URL('../../../test/fixtures/lost_ark/character_armory_full.json', import.meta.url),
    'utf8',
  ));
  fakeApiServer = createServer((request, response) => {
    response.setHeader('Content-Type', 'application/json');
    if (request.url?.includes('/siblings')) {
      response.end(JSON.stringify([{
        ServerName: '루페온',
        CharacterName: '이슈아이',
        CharacterLevel: 70,
        CharacterClassName: '바드',
        ItemAvgLevel: '1,760.00',
      }]));
      return;
    }
    if (request.url?.includes('/armories/characters/')) {
      response.end(JSON.stringify(armoryFixture));
      return;
    }
    response.statusCode = 404;
    response.end('{}');
  });
  await new Promise((resolve, reject) => {
    fakeApiServer.once('error', reject);
    fakeApiServer.listen(9999, '127.0.0.1', resolve);
  });

});

after(async () => {
  await new Promise((resolve) => fakeApiServer?.close(resolve));
});

test('creates and replaces a private challenge through the callable', async () => {
  const client = await authenticatedClient('auth-owner');
  await ownerSet('players/player-owner', {
    schemaVersion: 1,
    status: 'active',
  });
  await ownerSet(`authBindings/${client.uid}`, {
    schemaVersion: 1,
    status: 'active',
    playerId: 'player-owner',
  });

  const first = await client.start({
    characterName: '이슈아이',
    source: 'directInput',
    localAccountId: null,
  });
  assert.equal(first.data.status, 'pending');
  assert.ok(first.data.requiredUnequippedSlots.length >= 1);
  assert.ok(first.data.requiredUnequippedSlots.length <= 3);
  assert.equal(Object.hasOwn(first.data, 'baselineEquipment'), false);
  assert.equal(Object.hasOwn(first.data, 'siblingsSnapshot'), false);

  const firstDocument = await ownerGet(
    `accountVerificationChallenges/${first.data.challengeId}`,
  );
  assert.equal(firstDocument.playerId, 'player-owner');
  assert.equal(Object.keys(firstDocument.baselineEquipment).length, 6);
  assert.equal(firstDocument.expiresAt.valueOf() -
    firstDocument.createdAt.valueOf(), 10 * 60 * 1000);

  const second = await client.start({
    characterName: '이슈아이',
    source: 'provisional',
    localAccountId: 1,
  });
  assert.notEqual(second.data.challengeId, first.data.challengeId);
  const replaced = await ownerGet(
    `accountVerificationChallenges/${first.data.challengeId}`,
  );
  assert.equal(replaced.status, 'expired');
  assert.equal(replaced.failureCode, 'replaced');
});

test('rejects unauthenticated and unbound callable requests', async () => {
  const publicApp = initializeApp(clientOptions(), 'public-client');
  const publicFunctions = getFunctions(publicApp, 'asia-northeast3');
  connectFunctionsEmulator(publicFunctions, '127.0.0.1', 5001);
  const start = httpsCallable(publicFunctions, 'startGameAccountVerification');
  await assert.rejects(
    start({characterName: '이슈아이', source: 'directInput'}),
    (error) => error.code === 'functions/unauthenticated',
  );

  const unbound = await authenticatedClient('auth-unbound');
  await assert.rejects(
    unbound.start({characterName: '이슈아이', source: 'directInput'}),
    (error) => error.code === 'functions/failed-precondition',
  );
});

test('security rules deny direct challenge access for its owner', async () => {
  const client = await authenticatedClient('rules-owner');
  const token = await client.user.getIdToken();
  const listResponse = await fetch(firestoreRestUrl(
    'accountVerificationChallenges',
  ), {headers: {Authorization: `Bearer ${token}`}});
  assert.equal(listResponse.status, 403);

  const writeResponse = await fetch(firestoreRestUrl(
    'accountVerificationChallenges/manual',
  ), {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({fields: encodeFields({status: 'pending'})}),
  });
  assert.equal(writeResponse.status, 403);
});

async function authenticatedClient(name) {
  const app = initializeApp(clientOptions(), name);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const credential = await signInAnonymously(auth);
  const functions = getFunctions(app, 'asia-northeast3');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {
    uid: credential.user.uid,
    user: credential.user,
    start: httpsCallable(functions, 'startGameAccountVerification'),
  };
}

function clientOptions() {
  return {
    apiKey: 'fake-api-key',
    authDomain: `${projectId}.firebaseapp.com`,
    projectId,
    appId: '1:123:web:emulator',
  };
}

async function ownerSet(path, data) {
  const response = await fetch(firestoreRestUrl(path), {
    method: 'PATCH',
    headers: {
      Authorization: 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({fields: encodeFields(data)}),
  });
  assert.equal(response.ok, true, await response.text());
}

async function ownerGet(path) {
  const response = await fetch(firestoreRestUrl(path), {
    headers: {Authorization: 'Bearer owner'},
  });
  assert.equal(response.ok, true, await response.text());
  const document = await response.json();
  return decodeFields(document.fields);
}

function firestoreRestUrl(path) {
  return `http://127.0.0.1:8080/v1/projects/${projectId}` +
    `/databases/(default)/documents/${path}`;
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function encodeValue(value) {
  if (value === null) return {nullValue: null};
  if (typeof value === 'string') return {stringValue: value};
  if (typeof value === 'boolean') return {booleanValue: value};
  if (Number.isInteger(value)) return {integerValue: String(value)};
  if (typeof value === 'number') return {doubleValue: value};
  if (value instanceof Date) return {timestampValue: value.toISOString()};
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map(encodeValue)}};
  }
  return {mapValue: {fields: encodeFields(value)}};
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields ?? {}).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function decodeValue(value) {
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  return decodeFields(value.mapValue?.fields);
}
