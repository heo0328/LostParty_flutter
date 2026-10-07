// Explicit promotion tool. The fixture is never a Firebase deployment path.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { deduplicateCleanup, dispatchCleanupEvents, preserveExistingSlots, integratedBaseline, removeRepeatedPositionValidation, prioritizeCharacterChange, removeRepeatedPersonalCompletion } from './roster_complexity_candidate.mjs';
import { targetScanCandidate } from './rules_target_scan_candidate.mjs';
import { scopeFunctions } from './rules_scope_candidate.mjs';
import { simplifyGroupDisplay } from './rules_group_display_candidate.mjs';
import { stripRulesComments } from './rules_strip_comments.mjs';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { completionRoleCompatibility } from './rules_completion_role.mjs';
import { nextWeekPreparation } from './rules_next_week_preparation.mjs';
const target = new URL('../firestore.rules', import.meta.url);
const baseline = integratedBaseline();
const repaired = preserveExistingSlots(baseline);
const deduplicated = deduplicateCleanup(repaired);
const readable = stripRulesComments(scopeFunctions(simplifyGroupDisplay(targetScanCandidate(removeRepeatedPersonalCompletion(prioritizeCharacterChange(removeRepeatedPositionValidation(dispatchCleanupEvents(deduplicated))))))).source);
assert.ok(readable.includes('function deGenerationUpdate('));
assert.ok(readable.includes('function deLastCompletedDisband('));
assert.ok(readable.includes('function deReplacePriorState('));
const compatible = nextWeekPreparation(completionRoleCompatibility(readable));
const compact = compactExecutableRules(compatible);
const result = compact.source;
if (process.argv.includes('--review')) {
  const directory = new URL('../coverage/rules-executable/review/', import.meta.url);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(new URL('readable.rules', directory), compatible);
  fs.writeFileSync(new URL('symbols.json', directory), JSON.stringify({
    functions: compact.functions, locals: compact.locals,
    renamedBindings: compact.renamedBindings,
  }, null, 2));
}
assert.ok(Buffer.byteLength(result) < 256 * 1024, 'Rules source size limit');
if (process.argv.includes('--complexity-candidates')) {
  // Preserve the comparison inputs without writing the deployment path.
  const directory = new URL('../coverage/roster-complexity/', import.meta.url);
  fs.mkdirSync(directory, { recursive: true });
  for (const [name, rules] of Object.entries({ baseline, repaired, deduplicated,
    dispatched: result })) {
    fs.writeFileSync(new URL(`${name}.rules`, directory), rules);
    console.log(JSON.stringify({ candidate: name, bytes: Buffer.byteLength(rules),
      sha256: createHash('sha256').update(rules).digest('hex') }));
  }
} else if (process.argv.includes('--check')) {
  assert.equal(fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n'), result);
} else {
  fs.writeFileSync(target, result);
}
console.log(JSON.stringify({ bytes: Buffer.byteLength(result), sha256: createHash('sha256').update(result).digest('hex') }));
