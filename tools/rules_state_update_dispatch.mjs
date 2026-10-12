import assert from 'node:assert/strict';

// Consolidate dispatch only. All leaf authorization validators stay unchanged.
export function stateUpdateDispatch(source) {
  const scope = source.indexOf('match /raidStates/{stateId}');
  const start = source.indexOf('allow update:', scope);
  const end = source.indexOf(';', start);
  assert.ok(scope >= 0 && start > scope && end > start);
  const original = source.slice(start, end);
  for (const [name, count] of [['validAtomicRaidStateUpdate',3],
    ['validPersonalRaidStateCompletion',2],['deReplacePriorState',2]]) {
    assert.equal(original.split(name + '(').length - 1, count, name);
  }
  const marker = "((resource.data.get('status', '') == 'active' && request.resource.data.get('status', '') == 'active'";
  const tail = original.indexOf(marker);
  assert.ok(tail > 0);
  // Keep role, guard, idle and older-manual gates byte-for-byte. The remaining
  // suffix closes the surrounding role/guard/idle/older-manual ternaries.
  const a = `(resource.data.get('status', '') == 'active'
          && request.resource.data.get('status', '') == 'active'
          && request.resource.data.get('source', '') == 'party'
          && bug24Advancing(getAfter(recruitmentPath(request.resource.data.recruitmentId)).data))`;
  const b = `(resource.data.status == 'active' && request.resource.data.status == 'completed'
          && request.resource.data.source == 'party')`;
  const c = `(resource.data.status == 'completed' && request.resource.data.status == 'active'
          && request.resource.data.source == 'party')`;
  const d = `(resource.data.status == 'active' && request.resource.data.status == 'completed'
          && request.resource.data.source == 'manual'
          && resource.data.get('ownershipRevision', 0) == request.resource.data.get('ownershipRevision', 0))`;
  // Personal completion's immutable field set implies D, so its fallback call
  // is unreachable on a successful request. A/B formerly excluded replacement;
  // C formerly excluded lifecycle validation. Preserve these exclusions.
  const replacement = `(${d}
        ? validPersonalRaidStateCompletion(playerId, stateId, resource.data, request.resource.data)
        : ((${c} && sealAdvance(playerId, stateId, resource.data, request.resource.data, false))
          || (!${a} && !${b}
            && deReplacePriorState(playerId, stateId, resource.data, request.resource.data))
          || (!${c}
            && (!${b} || (resource.data.recruitmentId == request.resource.data.recruitmentId
              && existsAfter(recruitmentPath(resource.data.recruitmentId))))
            && validAtomicRaidStateUpdate(playerId, stateId, resource.data, request.resource.data)))))))`;
  const updated = original.slice(0, tail) + replacement;
  // Scope replacement catches accidental grammar drift before emulator compile.
  const masked = updated.replace(/'(?:\\.|[^'\\])*'/g, "''");
  let depth = 0;
  for (const char of masked) { if(char==='(')depth++;if(char===')')depth--;assert.ok(depth>=0); }
  assert.equal(depth,0,'unbalanced update expression');
  return source.slice(0,start) + updated + source.slice(end);
}
