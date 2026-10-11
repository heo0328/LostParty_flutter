// Local R3 candidate only. Production generation remains unchanged.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { rulesFunction } from './roster_complexity_candidate.mjs';
import { compactExecutableRules } from './rules_executable_compact.mjs';

export function cleanupCandidate(input) {
  let source = input.replaceAll('\r\n', '\n');
  const common = [
    `before.schemaVersion == 2 && before.status == 'active'
        && before.currentCycleStatus == 'completed' && before.continueTogether == true
        && before.memberCount >= 2 && before.memberCount <= 8`,
    `command.targetIndex is int && command.targetIndex >= 0
        && command.targetIndex < before.partySlots.size()`,
    `deCleanupAggregateUpdate(before, after, target, remaining)`,
    `!existsAfter(/databases/$(database)/documents/recruitments/$(before.recruitmentId)/members/$(target.playerId))`,
  ];
  const names = ['deCleanupAggregate', 'dePeerCleanupAggregate', 'deLeaderCleanupAggregate'];
  const events = ['deCleanupEvent', 'dePeerCleanupEvent', 'deLeaderCleanupEvent'];
  for (const [kind, name] of names.entries()) {
    const f = rulesFunction(source, name);
    let policy = f.text;
    for (const condition of common) {
      assert.equal(policy.split(`\n        && ${condition}`).length, 2, `${name}: ${condition}`);
      policy = policy.replace(`\n        && ${condition}`, '');
    }
    const listing = `\n        && (before.visibility != 'group' || ${kind === 2 ? 'deLeaderCleanupComposition' : 'deCleanupComposition'}(
          getAfter(/databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId)).data, after))`;
    assert.ok(policy.includes(listing));
    policy = policy.replace(listing, '');
    const event = `\n        && getAfter(/databases/$(database)/documents/partyEvents/$(after.lastCommandId)).data == ${events[kind]}(before, after)`;
    assert.ok(policy.includes(event));
    policy = policy.replace(event, '');
    policy = policy.replace(`function ${name}(before, after)`, `function r3CleanupPolicy${kind}(before, after, command, target)`)
      .replace('      let command = after.ownershipCleanup;\n', '')
      .replace('      let target = before.partySlots[command.targetIndex];\n', '')
      .replace('      let remaining = before.partySlots.removeAll([target]);\n', '')
      .replace('return hasActiveBinding() && ', 'return ');
    source = source.slice(0, f.start) + policy + source.slice(f.end);
    const call = `${name}(resource.data, request.resource.data)`;
    assert.equal(source.split(call).length, 2);
    source = source.replace(call, `r3CleanupAggregate(resource.data, request.resource.data, ${kind})`);
  }
  // Keep exact leader listing predicate; no semantic simplification in this step.
  const helper = `
    function r3CleanupAggregate(before, after, kind) {
      let command = after.ownershipCleanup;
      let target = before.partySlots[command.targetIndex];
      let remaining = before.partySlots.removeAll([target]);
      return hasActiveBinding()
        && ${common[0]}
        && ${common[1]}
        && (kind == 0 ? r3CleanupPolicy0(before, after, command, target)
          : kind == 1 ? r3CleanupPolicy1(before, after, command, target)
          : r3CleanupPolicy2(before, after, command, target))
        && ${common[2]}
        && ${common[3]}
        && (before.visibility != 'group' || (kind == 2
          ? deLeaderCleanupComposition(getAfter(/databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId)).data, after)
          : deCleanupComposition(getAfter(/databases/$(database)/documents/groups/$(before.groupId)/raidListings/$(before.recruitmentId)).data, after)))
        && getAfter(/databases/$(database)/documents/partyEvents/$(after.lastCommandId)).data == (kind == 0
          ? deCleanupEvent(before, after) : kind == 1 ? dePeerCleanupEvent(before, after) : deLeaderCleanupEvent(before, after));
    }
`;
  const index = source.indexOf('    function r3CleanupPolicy0(');
  return source.slice(0, index) + helper + source.slice(index);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
  const hash = value => createHash('sha256').update(value).digest('hex');
  const baseline = compactExecutableRules(input).source;
  assert.equal(hash(baseline), '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667');
  const readable = cleanupCandidate(input);
  const candidate = compactExecutableRules(readable).source;
  const dir = 'coverage/rules-cleanup';
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(`${dir}/readable.rules`, readable);
  fs.writeFileSync(`${dir}/candidate.rules`, candidate);
  const result = { baselineSha: hash(baseline), candidateSha: hash(candidate),
    baselineBytes: Buffer.byteLength(baseline), candidateBytes: Buffer.byteLength(candidate),
    removedBytes: Buffer.byteLength(baseline) - Buffer.byteLength(candidate) };
  fs.writeFileSync(`${dir}/manifest.json`, JSON.stringify(result, null, 2));
  console.log(result);
}
