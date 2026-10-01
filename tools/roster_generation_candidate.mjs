// DE2-G2 demo candidate; existing authentication trust model is unchanged.
import assert from 'node:assert/strict';
import { lastMemberCandidate } from './roster_last_member_candidate.mjs';
export function generationCandidate(source) {
  let rules = lastMemberCandidate(source);
  const before = `    match /gameAccounts/{gameAccountId} {
      allow read, write: if signedIn();
    }

    match /characters/{characterId} {
      allow read, write: if signedIn();
    }`;
  assert.equal(rules.split(before).length, 2);
  return rules.replace(before, `
    function deValidGeneration(data) {
      return data.get('ownershipRevision', 0) is int
        && data.get('ownershipRevision', 0) >= 0
        && data.get('ownershipRevision', 0) <= 9007199254740991
        && data.ownerPlayerId is string && data.ownerPlayerId.size() > 0;
    }

    function deGenerationUpdate(before, after) {
      return deValidGeneration(before) && deValidGeneration(after)
        && (!before.keys().hasAny(['ownershipRevision'])
          || after.keys().hasAny(['ownershipRevision']))
        && after.get('ownershipRevision', 0) == before.get('ownershipRevision', 0)
          + (after.ownerPlayerId == before.ownerPlayerId ? 0 : 1);
    }

    function deCharacterGeneration(data) {
      let account = getAfter(/databases/$(database)/documents/gameAccounts/$(data.gameAccountId)).data;
      return deValidGeneration(data) && deValidGeneration(account)
        && data.ownerPlayerId == account.ownerPlayerId
        && data.get('ownershipRevision', 0) == account.get('ownershipRevision', 0);
    }

    match /gameAccounts/{gameAccountId} {
      allow read: if signedIn();
      allow create: if signedIn() && deValidGeneration(request.resource.data)
        && request.resource.data.ownershipRevision == 1;
      allow update: if signedIn() && deGenerationUpdate(resource.data, request.resource.data);
      allow delete: if false;
    }

    match /characters/{characterId} {
      allow read: if signedIn();
      allow create: if signedIn() && deCharacterGeneration(request.resource.data);
      allow update: if signedIn()
        && request.resource.data.gameAccountId == resource.data.gameAccountId
        && (!resource.data.keys().hasAny(['ownershipRevision'])
          || request.resource.data.keys().hasAny(['ownershipRevision']))
        && deCharacterGeneration(request.resource.data);
      allow delete: if false;
    }`);
}
