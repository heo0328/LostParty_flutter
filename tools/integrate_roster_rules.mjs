// Explicit promotion tool. The fixture is never a Firebase deployment path.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { orphanCleanupCandidate } from './roster_orphan_cleanup_candidate.mjs';
const base = new URL('./fixtures/roster_reauth_preintegration.rules', import.meta.url);
const target = new URL('../firestore.rules', import.meta.url);
const source = fs.readFileSync(base, 'utf8').replace(/\r\n/g, '\n');
const marker = '// roster-reauth-integrated-v1\n';
const result = marker + orphanCleanupCandidate(source);
assert.ok(result.includes('function deGenerationUpdate('));
assert.ok(result.includes('function deLastCompletedDisband('));
assert.ok(result.includes('function deReplacePriorState('));
assert.ok(Buffer.byteLength(result) < 256 * 1024, 'Rules source size limit');
if (process.argv.includes('--check')) {
  assert.equal(fs.readFileSync(target, 'utf8').replace(/\r\n/g, '\n'), result);
} else {
  fs.writeFileSync(target, result);
}
console.log(JSON.stringify({ bytes: Buffer.byteLength(result), sha256: createHash('sha256').update(result).digest('hex') }));
