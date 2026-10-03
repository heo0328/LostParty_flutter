// Run only with a separately started local demo Firestore emulator on port 8080.
// No Firebase CLI, production project, deploy, or tracked Rules writes.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { deduplicateCleanup, dispatchCleanupEvents, preserveExistingSlots } from './roster_complexity_candidate.mjs';

const root = new URL('../', import.meta.url);
const directory = new URL('coverage/roster-complexity/', root);
fs.mkdirSync(directory, { recursive: true });
const baseline = fs.readFileSync(new URL('firestore.rules', root), 'utf8').replace(/\r\n/g, '\n');
// Unmodified baseline already failed CI37106260020; do not repeat that run.
const repaired = preserveExistingSlots(baseline);
const deduplicated = deduplicateCleanup(repaired);
const variants = { repaired, deduplicated, dispatched: dispatchCleanupEvents(deduplicated) };
const suites = [
  ['cleanup-peer', 'tools/roster_peer_cleanup_proof.mjs'],
  ['last-member', 'tools/roster_last_member_proof.mjs'],
];
const summary = [];
let expected;
for (const [variant, rules] of Object.entries(variants)) {
  const rulesFile = new URL(`${variant}.rules`, directory);
  fs.writeFileSync(rulesFile, rules);
  const results = [];
  for (const [suite, script] of suites) {
    const run = spawnSync(process.execPath, [script], {
      cwd: fileURLToPath(root), encoding: 'utf8', timeout: 300000,
      env: { ...process.env, ROSTER_TRACKED_RULES: '1', LEADER_PROOF_SCOPE: '',
        ROSTER_COMPLEXITY_RULES_FILE: fileURLToPath(rulesFile),
        FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
    });
    fs.writeFileSync(new URL(`${variant}-${suite}.log`, directory), (run.stdout ?? '') + (run.stderr ?? ''));
    const passes = (run.stdout ?? '').split(/\r?\n/).filter(l => l.startsWith('PASS CLEANUP:'));
    const succeeded = run.status === 0 && passes.length > 0;
    results.push({ suite, succeeded, passes, error: run.error?.message });
    summary.push({ variant, suite, succeeded, count: passes.length,
      sha256: createHash('sha256').update(rules).digest('hex') });
    fs.writeFileSync(new URL('differential-results.json', directory), JSON.stringify(summary, null, 2));
    console.log(`${variant}/${suite}: ${succeeded ? 'PASS' : 'STOP'} (${passes.length})`);
    assert.ok(succeeded, `Stopped at ${variant}/${suite}; inspect local log, do not promote`);
  }
  const comparable = results.map(({ suite, passes }) => ({ suite, passes }));
  if (expected) assert.deepEqual(comparable, expected, 'baseline/candidate case mismatch');
  else expected = comparable;
}
