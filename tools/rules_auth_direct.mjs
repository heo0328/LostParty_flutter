import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// Keep shared authorization entry points, but express their checks without
// another user-function call. get/exists and short-circuit conditions remain.
export function directAuthorization(source) {
  const replaceFunction = (name, text) => {
    const before = rulesFunction(source, name);
    source = source.slice(0, before.start) + text + source.slice(before.end);
  };
  replaceFunction('hasActiveBinding', `    function hasActiveBinding() {
      let binding = /databases/$(database)/documents/authBindings/$(request.auth.uid);
      return request.auth != null && exists(binding) && get(binding).data.status == 'active';
    }`);
  replaceFunction('currentPlayerId', `    function currentPlayerId() {
      return get(/databases/$(database)/documents/authBindings/$(request.auth.uid)).data.playerId;
    }`);
  replaceFunction('isActiveOperator', `    function isActiveOperator() {
      let binding = /databases/$(database)/documents/authBindings/$(request.auth.uid);
      return request.auth != null && exists(binding) && get(binding).data.status == 'active'
        && exists(/databases/$(database)/documents/players/$(get(binding).data.playerId))
        && get(/databases/$(database)/documents/players/$(get(binding).data.playerId)).data.status == 'active'
        && exists(/databases/$(database)/documents/operatorAssignments/$(get(binding).data.playerId))
        && get(/databases/$(database)/documents/operatorAssignments/$(get(binding).data.playerId)).data.status == 'active';
    }`);
  replaceFunction('isCurrentPlayerActive', `    function isCurrentPlayerActive() {
      let binding = /databases/$(database)/documents/authBindings/$(request.auth.uid);
      return request.auth != null && exists(binding) && get(binding).data.status == 'active'
        && get(/databases/$(database)/documents/players/$(get(binding).data.playerId)).data.status == 'active';
    }`);
  replaceFunction('isCurrentGroupMember', `    function isCurrentGroupMember(groupId) {
      let binding = /databases/$(database)/documents/authBindings/$(request.auth.uid);
      return request.auth != null && exists(binding) && get(binding).data.status == 'active'
        && exists(/databases/$(database)/documents/groups/$(groupId)/members/$(get(binding).data.playerId));
    }`);
  replaceFunction('isActiveGroupLeader', `    function isActiveGroupLeader(groupId) {
      let binding = /databases/$(database)/documents/authBindings/$(request.auth.uid);
      let callerId = get(binding).data.playerId;
      return request.auth != null && exists(binding) && get(binding).data.status == 'active'
        && get(/databases/$(database)/documents/players/$(callerId)).data.status == 'active'
        && get(/databases/$(database)/documents/groups/$(groupId)).data.leaderPlayerId == callerId;
    }`);
  replaceFunction('canApproveApplications', `    function canApproveApplications(recruitmentId) {
      let recruitment = get(/databases/$(database)/documents/recruitments/$(recruitmentId)).data;
      let playerId = get(/databases/$(database)/documents/authBindings/$(request.auth.uid)).data.playerId;
      return recruitment.leaderPlayerId == playerId
        || (exists(/databases/$(database)/documents/recruitments/$(recruitmentId)/members/$(playerId))
          && get(/databases/$(database)/documents/recruitments/$(recruitmentId)/members/$(playerId)).data.canApproveApplications == true);
    }`);
  const signed = rulesFunction(source, 'signedIn');
  source = source.slice(0, signed.start) + source.slice(signed.end);
  source = source.replace(/\bsignedIn\(\)/g, '(request.auth != null)');
  // Never leave unresolved calls when a helper becomes unused.
  for (const name of ['operatorAssignmentPath']) {
    assert.equal([...source.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))].length, 1);
    const f = rulesFunction(source, name);
    source = source.slice(0, f.start) + source.slice(f.end);
  }
  return source;
}
