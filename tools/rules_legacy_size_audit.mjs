// Static sizing only: no Rules file writes, compiler, Emulator, or remote calls.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
const baseline = compactExecutableRules(input).source;
assert.equal(createHash('sha256').update(baseline).digest('hex'),
  '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667',
  'Review baseline changed; audit must be reviewed again');
let candidate = input;
const baselineUnused = [...input.matchAll(/function (\w+)\(/g)].map(m => m[1])
  .filter(name => [...input.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))].length === 1);
const sections = [];
for (const [collection, wildcard] of [
  ['activeRaidAssignments', 'assignmentId'], ['weeklyRaidClaims', 'claimId'],
]) {
  const marker = `      match /${collection}/{${wildcard}} {`;
  const start = candidate.indexOf(marker);
  assert.ok(start >= 0);
  let depth = 1, end = start + marker.length;
  while (depth && end < candidate.length) {
    if (candidate[end] === '{') depth++;
    if (candidate[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0);
  const original = candidate.slice(start, end);
  const reads = [...original.matchAll(/allow (?:get|list):[\s\S]*?;/g)].map(m => m[0]);
  assert.equal(reads.length, 2, 'Preserve existing get/list conditions exactly');
  sections.push({ collection, functions: [...original.matchAll(/function (\w+)\(/g)].map(m => m[1]) });
  candidate = candidate.slice(0, start) + `${marker}\n        ${reads.join('\n        ')}
        allow write: if false;
      }` + candidate.slice(end);
}
// Conservative reference counting: only remove declarations with no remaining
// textual call; this is a size estimate, not a security equivalence proof.
const unreferenced = [];
for (let pass = 0; pass < 400; pass++) {
  const names = [...candidate.matchAll(/function (\w+)\(/g)].map(m => m[1]);
  assert.equal(names.length, new Set(names).size, 'Ambiguous scoped function name');
  const unused = names.find(name => !baselineUnused.includes(name)
    && [...candidate.matchAll(new RegExp(`\\b${name}\\s*\\(`, 'g'))].length === 1);
  if (!unused) break;
  const f = rulesFunction(candidate, unused);
  candidate = candidate.slice(0, f.start) + candidate.slice(f.end);
  unreferenced.push(unused);
  assert.ok(pass < 399, 'Bounded traversal exceeded');
}
const result = compactExecutableRules(candidate).source;
console.log(JSON.stringify({ kind: 'static-estimate-not-deployable',
  baselineBytes: Buffer.byteLength(baseline), estimateBytes: Buffer.byteLength(result),
  removedBytes: Buffer.byteLength(baseline) - Buffer.byteLength(result),
  sections, unreferenced, baselineUnused,
  remainingLegacyPathReferences: [...candidate.matchAll(/\b(?:assignmentPath|weeklyRaidClaimPath)\s*\(/g)].length,
  limitation: 'Reads preserved; legacy consumption deletes would stop. No migration or policy validation.' }, null, 2));
