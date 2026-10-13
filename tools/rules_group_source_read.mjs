import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// L1 cutover: source documents replace the retired group listing projection.
// This transform runs after the historical stages; it does not relax commands.
export function groupSourceRead(input) {
  let source = input;
  const remove = (pattern, count) => {
    assert.equal([...source.matchAll(pattern)].length, count, String(pattern));
    source = source.replace(pattern, '');
  };
  remove(/\s*&& \(before\.visibility != 'group' \|\| bug24PrepListing\(before, after\)\)/g, 1);
  remove(/\s*&& \(!\(before\.groupId is string\) \|\| dePersonalCompletionListing\(before, after\)\)/g, 1);
  remove(/\s*&& \(before\.visibility != 'group'\s*\|\| !existsAfter\(\/databases\/\$\(database\)\/documents\/groups\/\$\(before\.groupId\)\/raidListings\/\$\(before\.recruitmentId\)\)\)/g, 1);
  remove(/\s*&& \(before\.visibility != 'group' \|\| de(?:Leader)?CleanupComposition\(\s*getAfter\(\/databases\/\$\(database\)\/documents\/groups\/\$\(before\.groupId\)\/raidListings\/\$\(before\.recruitmentId\)\)\.data, after\)\)/g, 3);
  remove(/\s*&& r1InitialListing\(request\.resource\.data\)/g, 3);
  remove(/\s*&& r1ListingTransition\(resource\.data, request\.resource\.data\)/g, 2);
  remove(/r1ListingTransition\(resource\.data, request\.resource\.data\) && /g, 1);
  for (const name of ['bug24PrepListing', 'dePersonalCompletionListing',
    'r1InitialListing', 'r1ListingTransition', 'deLeaderCleanupComposition', 'deCleanupComposition']) {
    const fn = rulesFunction(source, name);
    source = source.slice(0, fn.start) + source.slice(fn.end);
    assert.ok(!source.includes(`${name}(`), `remaining call: ${name}`);
  }
  const start = source.indexOf('match /raidListings/{recruitmentId} {');
  assert.ok(start >= 0);
  // The next sibling match is a stable boundary, avoiding path-template braces.
  const end = source.indexOf('match /joinRelations/{playerId} {', start);
  assert.ok(end > start);
  source = source.slice(0, start) + source.slice(end);
  const list = rulesFunction(source, 'canListRecruitment');
  assert.ok(list.text.includes("data.visibility == 'public'"));
  source = source.slice(0, list.start)
    + list.text.replace("data.visibility == 'public'", 'canAccessRecruitmentByAudience(data)')
    + source.slice(list.end);
  assert.ok(!source.includes('raidListings'), 'projection path must be fully retired');
  return source;
}
