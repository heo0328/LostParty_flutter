// Design-only, in-memory measurement. No Rules output or Firebase requests.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
const compact = text => compactExecutableRules(text).source;
const hash = text => createHash('sha256').update(text).digest('hex');
const baseline = compact(input);
assert.equal(hash(baseline), '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667');
let draft = input.replaceAll('\r\n', '\n');
const original = draft;
const replace = (name, transform) => {
  const f = rulesFunction(draft, name);
  const next = transform(f.text);
  assert.notEqual(next, f.text);
  draft = draft.slice(0, f.start) + next + draft.slice(f.end);
};
const families = ['deCleanup', 'dePeerCleanup', 'deLeaderCleanup'];
for (const prefix of families) {
  const eventRead = `getAfter(/databases/$(database)/documents/partyEvents/$(after.lastCommandId)).data == ${prefix}Event(before, after)`;
  replace(`${prefix}Aggregate`, text => {
    assert.equal(text.split(`\n        && ${eventRead}`).length, 2);
    const policy = text.replace(`${prefix}Aggregate(`, `${prefix}EventPolicy(`)
      .replace(`\n        && ${eventRead}`, '');
    // Keep canonical event binding in the source gate; require a fresh event.
    return policy + `\n\n    function ${prefix}Aggregate(before, after) {\n`
      + `      return !exists(/databases/$(database)/documents/partyEvents/$(after.lastCommandId))\n`
      + `        && ${eventRead};\n    }`;
  });
  replace(`${prefix}EventCreate`, text => {
    const from = `${prefix}Transition(before, after)`;
    assert.equal(text.split(from).length, 2);
    return text.replace(from, `${prefix}EventPolicy(before, after)`);
  });
}
// Existing source call sites, member/state validators and all other functions
// must remain byte-identical. This is a transformation guard, not equivalence proof.
const changed = new Set(families.flatMap(p => [`${p}Aggregate`, `${p}EventCreate`]));
for (const match of original.matchAll(/^    function (\w+)\(/gm)) {
  if (!changed.has(match[1])) {
    assert.equal(rulesFunction(draft, match[1]).text, rulesFunction(original, match[1]).text);
  }
}
assert.deepEqual(draft.match(/^\s*allow .*$/gm), original.match(/^\s*allow .*$/gm));
const result = compact(draft);
// A smaller envelope gate still pins the event to the same room and the exact
// dedicated create validator. Its canonical map is then checked only at create.
const eventTypes = ['ownershipParticipantRemoved', 'ownershipPeerRemoved', 'ownershipLeaderRemoved'];
for (const [index, prefix] of families.entries()) {
  replace(`${prefix}Aggregate`, () => `    function ${prefix}Aggregate(before, after) {\n`
    + `      let path = /databases/$(database)/documents/partyEvents/$(after.lastCommandId);\n`
    + `      let event = getAfter(path).data;\n`
    + `      return !exists(path) && event.recruitmentId == before.recruitmentId\n`
    + `        && event.type == '${eventTypes[index]}';\n    }`);
}
const envelope = compact(draft);
console.log(JSON.stringify({ kind: 'design-only-not-a-deployable-candidate',
  baselineBytes: Buffer.byteLength(baseline), proposedBytes: Buffer.byteLength(result),
  netReductionBytes: Buffer.byteLength(baseline) - Buffer.byteLength(result),
  proposedSourceSha256: hash(result),
  envelopeBytes: Buffer.byteLength(envelope),
  envelopeReductionBytes: Buffer.byteLength(baseline) - Buffer.byteLength(envelope),
  envelopeSourceSha256: hash(envelope),
  limitation: 'Conservative relocation retaining canonical source/event binding. No compiler, emulator, equivalence or runtime budget proof. No Rules file written.'
}, null, 2));
