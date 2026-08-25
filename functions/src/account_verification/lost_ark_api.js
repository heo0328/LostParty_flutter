const DEFAULT_LOST_ARK_API_BASE_URL =
  'https://developer-lostark.game.onstove.com';

export class LostArkApi {
  constructor({
    apiKey,
    baseUrl = DEFAULT_LOST_ARK_API_BASE_URL,
    fetchImpl = fetch,
  }) {
    if (typeof apiKey !== 'string' || apiKey.trim() === '') {
      throw new Error('Lost Ark API key is required.');
    }
    this.authorization = apiKey.trim().toLowerCase().startsWith('bearer ') ?
      apiKey.trim() : `bearer ${apiKey.trim()}`;
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.fetchImpl = fetchImpl;
  }

  fetchSiblings(characterName) {
    return this.#get(`/characters/${encodeURIComponent(characterName)}/siblings`);
  }

  fetchArmory(characterName) {
    return this.#get(`/armories/characters/${encodeURIComponent(characterName)}`);
  }

  async #get(path) {
    const response = await this.fetchImpl(`${this.baseUrl}${path}`, {
      headers: {
        'Accept': 'application/json',
        'Authorization': this.authorization,
      },
      signal: AbortSignal.timeout(10_000),
    });
    if (!response.ok) {
      throw new LostArkApiError(response.status);
    }
    return response.json();
  }
}

export class LostArkApiError extends Error {
  constructor(status) {
    super(`Lost Ark API request failed with status ${status}.`);
    this.name = 'LostArkApiError';
    this.status = status;
  }
}
