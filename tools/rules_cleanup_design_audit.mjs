// R3 design-only size experiment. Never writes Rules or calls Firebase.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
const compact = source => compactExecutableRules(source).source;
const baseline = compact(input);
assert.equal(createHash('sha256').update(baseline).digest('hex'),
  '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667');
let draft = input;
const replaceFunction = (name, transform) => {
  const f = rulesFunction(draft, name);
  const next = transform(f.text);
  assert.notEqual(next, f.text, `No replacement: ${name}`);
  draft = draft.slice(0, f.start) + next + draft.slice(f.end);
};
const common = `before.schemaVersion == 2 && before.status == 'active'
        && before.currentCycleStatus == 'completed' && before.continueTogether == true
        && before.memberCount >= 2 && before.memberCount <= 8`;
const bounds = `command.targetIndex is int && command.targetIndex >= 0
        && command.targetIndex < before.partySlots.size()`;
// Normalize line endings only for exact replacement assertions.
draft = draft.replaceAll('\r\n', '\n');
for (const name of ['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate']) {
  replaceFunction(name, text => {
    assert.equal(text.split(common).length, 2);
    assert.equal(text.split(bounds).length, 2);
    return text.replace(common, 'r3CleanupRoom(before)')
      .replace(bounds, 'r3CleanupTargetIndex(before, command)');
  });
}
const transitionTail = `before.revision + 1 == after.revision
        && after.ownershipCleanup.expectedRevision == before.revision
        && after.lastCommandActorPlayerId == currentPlayerId()
        && after.lastCommandAt == request.time`;
for (const name of ['deCleanupTransition', 'dePeerCleanupTransition', 'deLeaderCleanupTransition']) {
  replaceFunction(name, text => {
    assert.equal(text.split(transitionTail).length, 2);
    return text.replace(transitionTail, 'r3CleanupRevision(before, after)');
  });
}
const helpers = `
    function r3CleanupRoom(before) { return ${common}; }
    function r3CleanupTargetIndex(before, command) { return ${bounds}; }
    function r3CleanupRevision(before, after) { return ${transitionTail}; }
`;
const insertion = draft.indexOf('    function deLeaderCleanupTransition(');
assert.ok(insertion > 0);
draft = draft.slice(0, insertion) + helpers + draft.slice(insertion);
const result = compact(draft);
// Function footprint is readable source, not compiled size or removable bytes.
const families = {
  cleanupAggregates: ['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate'],
  activeCharacter: ['validAtomicCharacterRevisionUpdate', 'validAtomicMemberCharacterChange', 'atomicCharacterPlacementMatches'],
  lifecycleEvents: ['validAtomicLifecyclePartyEvent', 'atomicValidV2LifecycleEventPayload', 'atomicAllEventTargetsMatch', 'atomicEventTargetMatches'],
};
console.log(JSON.stringify({ kind: 'design-only-not-a-candidate',
  baselineBytes: Buffer.byteLength(baseline), estimateBytes: Buffer.byteLength(result),
  netSourceReduction: Buffer.byteLength(baseline) - Buffer.byteLength(result),
  readableFootprints: Object.fromEntries(Object.entries(families).map(([group, names]) =>
    [group, names.reduce((sum, name) => sum + Buffer.byteLength(rulesFunction(input, name).text), 0)])),
  limitation: 'Exact repeated predicates only. No policy relocation, compiler, evaluation-budget or equivalence validation.'
}, null, 2));
