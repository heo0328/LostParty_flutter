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
import { availabilityRuntime } from './rules_availability_runtime.mjs';
import { indentRules } from './rules_indent.mjs';
import { readableExecutableRules } from './rules_readable_executable.mjs';
const target = new URL('../firestore.rules', import.meta.url);
const baseline = integratedBaseline();
const repaired = preserveExistingSlots(baseline);
const deduplicated = deduplicateCleanup(repaired);
const readable = stripRulesComments(scopeFunctions(simplifyGroupDisplay(targetScanCandidate(removeRepeatedPersonalCompletion(prioritizeCharacterChange(removeRepeatedPositionValidation(dispatchCleanupEvents(deduplicated))))))).source);
assert.ok(readable.includes('function deGenerationUpdate('));
assert.ok(readable.includes('function deLastCompletedDisband('));
assert.ok(readable.includes('function deReplacePriorState('));
const compatible = availabilityRuntime(nextWeekPreparation(completionRoleCompatibility(readable)));
const candidate = process.argv.includes('--listing-candidate');
const localized = !candidate && !process.argv.includes('--legacy-baseline');
assert.ok(!(candidate && localized), 'Choose one integration mode');
const localization = localized ? (await import('./rules_localization_pipeline.mjs')).localizationPipeline(compatible) : null;
const reviewed = localization?.source ?? (candidate ? (await import('./rules_listing_candidate.mjs')).canonicalListings(compatible) : compatible);
const compact = compactExecutableRules(reviewed);
const readableExecutable = readableExecutableRules(reviewed);
const result = indentRules(readableExecutable.source);
if (localized) {
  fs.mkdirSync('coverage/rules-localization', {recursive:true});
  fs.writeFileSync('coverage/rules-localization/readable.rules', reviewed);
  fs.writeFileSync('coverage/rules-localization/candidate.rules', result);
  fs.writeFileSync('coverage/rules-localization/before-group-source.rules',
    indentRules(readableExecutableRules(localization.beforeGroupSource).source));
  fs.writeFileSync('coverage/rules-localization/manifest.json', JSON.stringify(localization.stages,null,2));
  fs.writeFileSync('coverage/rules-localization/deployment.json', JSON.stringify({
    format: 'meaningful-identifiers', bytes: Buffer.byteLength(result),
    sha256: createHash('sha256').update(result).digest('hex'),
    functions: readableExecutable.functions,
    historicalCompactSha256: createHash('sha256').update(compact.source).digest('hex'),
  }, null, 2));
  if (process.argv.includes('--candidate-only')) {
    console.log(JSON.stringify(localization.stages));process.exit(0);
  }
}
if (candidate) {
  fs.mkdirSync('coverage/rules-listing', {recursive: true});
  fs.writeFileSync('coverage/rules-listing/candidate.rules', result);
  fs.writeFileSync('coverage/rules-listing/readable.rules', reviewed);
  console.log(JSON.stringify({candidate: true, bytes: Buffer.byteLength(result), sha256: createHash('sha256').update(result).digest('hex')}));
  process.exit(0);
}
if (process.argv.includes('--review')) {
  const directory = new URL('../coverage/rules-executable/review/', import.meta.url);
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(new URL('readable.rules', directory), result);
  fs.writeFileSync(new URL('symbols.json', directory), JSON.stringify({
    format: 'meaningful-identifiers', functions: readableExecutable.functions,
    renamedBindings: 0,
    historicalCompact: {functions: compact.functions, locals: compact.locals},
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
