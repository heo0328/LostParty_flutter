import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LostArkApi,
  LostArkApiError,
} from '../src/account_verification/lost_ark_api.js';

test('requests encoded character data with a bearer secret', async () => {
  const requests = [];
  const api = new LostArkApi({
    apiKey: 'secret-token',
    fetchImpl: async (url, options) => {
      requests.push({url, options});
      return {ok: true, json: async () => [{CharacterName: '이슈 아이'}]};
    },
  });

  await api.fetchSiblings('이슈 아이');

  assert.match(requests[0].url, /characters\/%EC%9D%B4%EC%8A%88%20%EC%95%84%EC%9D%B4\/siblings$/);
  assert.equal(requests[0].options.headers.Authorization, 'bearer secret-token');
});

test('does not duplicate an existing bearer prefix', async () => {
  let authorization;
  const api = new LostArkApi({
    apiKey: 'Bearer secret-token',
    fetchImpl: async (_url, options) => {
      authorization = options.headers.Authorization;
      return {ok: true, json: async () => ({})};
    },
  });

  await api.fetchArmory('이슈아이');

  assert.equal(authorization, 'Bearer secret-token');
});

test('reports an upstream HTTP status without exposing a response body', async () => {
  const api = new LostArkApi({
    apiKey: 'secret-token',
    fetchImpl: async () => ({ok: false, status: 429}),
  });

  await assert.rejects(
    api.fetchArmory('이슈아이'),
    (error) => error instanceof LostArkApiError && error.status === 429,
  );
});
