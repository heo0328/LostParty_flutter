// C1 contract boundaries on a local demo Emulator, never production.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  serverTimestamp, Timestamp } from 'firebase/firestore';
import { assertRulesDenied } from './assert_rules_denied.mjs';
import { seedBase, createPublicRecruitmentTxn, authUid, playerId, characterId,
  recruitmentId, raidId, cycleKey, cycleWindow } from './party_group_cutover_rules_test.mjs';
const directory = process.env.C1_RESULTS_DIRECTORY || 'coverage/rules-member-retirement';
const selected = process.env.PARTY_RULES_FILE;
const results = [];
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); throw error; }
}
process.env.RULES_AUDIT = '1';
try {
  for (const version of selected ? ['candidate'] : ['baseline', 'candidate']) {
    const file = selected || (version === 'baseline' ? 'coverage/rules-depth-recheck/candidate.rules' : `${directory}/candidate.rules`);
    const rules = fs.readFileSync(file, 'utf8');
    if (!selected) assert.equal(createHash('sha256').update(rules).digest('hex'), version === 'baseline'
      ? 'b6b4003a705ed313c08ecc3aafabed709330a43a2dc0a8069fe9db66f5742971'
      : '18cf2c09344823c6d749a82077213d0e8a88a2381c4e2d9a2a04e1f3f96a3d61');
    const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
      firestore: { host: '127.0.0.1', port: 8080, rules } });
    const db = env.authenticatedContext(authUid).firestore();
    try {
      await env.clearFirestore(); await seedBase(env); await createPublicRecruitmentTxn(db);
      const replacement = 'retiredcharacter0001a';
      await env.withSecurityRulesDisabled(async ctx => {
        const admin = ctx.firestore();
        await updateDoc(doc(admin, 'recruitments', recruitmentId), { schemaVersion: 1, slotLedgerVersion: 2 });
        const original = (await getDoc(doc(admin, 'characters', characterId))).data();
        await setDoc(doc(admin, 'characters', replacement), { ...original });
        await setDoc(doc(admin, 'players', playerId, 'activeRaidAssignments', `${replacement}_${raidId}`),
          { playerId, characterId: replacement, raidId, role: 'dealer', status: 'active', recruitmentId, cycleKey });
      });
      await check(`${version}: old member-only replacement ${version === 'baseline' ? 'budget failure recorded' : 'policy denied'}`, async () => {
        const ref = doc(db, 'recruitments', recruitmentId, 'members', playerId);
        const before = (await getDoc(ref)).data();
        const operation = updateDoc(ref, { characterId: replacement, characterChangedAt: serverTimestamp(), updatedAt: serverTimestamp() });
        if (version === 'baseline') {
          await assert.rejects(operation, e => e.code === 'permission-denied'
            && /maximum of 1000 expressions/.test(e.message));
          assert.deepEqual((await getDoc(ref)).data(), before);
        } else {
          await assertRulesDenied(operation); assert.deepEqual((await getDoc(ref)).data(), before);
        }
      });
      if (version === 'baseline') continue;
      await check('legacy own get/list and manual claim clearing remain allowed', async () => {
        const window = cycleWindow(cycleKey);
        const claim = doc(db, 'players', playerId, 'weeklyRaidClaims', `${cycleKey}_${characterId}_${raidId}`);
        await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), claim.path), {
          playerId, characterId, raidId, cycleKey, source: 'manual',
          cycleStartedAt: Timestamp.fromDate(window.startedAt), cycleEndsAt: Timestamp.fromDate(window.endsAt),
        }));
        assert.equal((await getDoc(claim)).exists(), true);
        assert.equal((await getDocs(collection(db, 'players', playerId, 'weeklyRaidClaims'))).size, 1);
        assert.equal((await getDocs(collection(db, 'players', playerId, 'activeRaidAssignments'))).size, 1);
        await deleteDoc(claim); assert.equal((await getDoc(claim)).exists(), false);
      });
      await check('legacy orphan assignment consumption remains allowed', async () => {
        const ref = doc(db, 'players', playerId, 'activeRaidAssignments', `${characterId}_${raidId}`);
        await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), ref.path), {
          playerId, characterId, raidId, cycleKey, status: 'active', recruitmentId: 'missing-old-room',
        }));
        await deleteDoc(ref); assert.equal((await getDoc(ref)).exists(), false);
      });
    } finally { await env.cleanup(); }
  }
  process.env.BUG024_RULES_FILE = selected || `${directory}/candidate.rules`;
  process.env.BUG024_IMPORT_ONLY = '1'; process.env.BUG024_SPARK_EVENT = '1';
  process.env.R1_LISTING = '1';
  const p = await import('./bug024_preparation_proof.mjs');
  try {
    await check('8-member repeated preparation preserves completed states and claims', async () => {
      await p.seed({ actorLast: true }); const before = await p.snapshot();
      await p.prepare(); await p.prepare({ id: p.second });
      const after = await p.snapshot();
      assert.deepEqual(after.states, before.states); assert.deepEqual(after.claims, before.claims);
      assert.deepEqual(after.room.completedAt, before.room.completedAt);
      assert.deepEqual(after.listing, after.room);
    });
    for (const omit of ['room', 'member', 'listing', 'event']) await check(`preparation rejects missing ${omit}`, async () => {
      await p.seed(); await p.denied(() => p.prepare({ omit }));
    });
    await check('preparation rejects another player', async () => {
      await p.seed(); await p.denied(() => p.prepare({ client: p.env.authenticatedContext('joiner-auth').firestore() }));
    });
  } finally { await p.env.cleanup(); }
} finally {
  fs.writeFileSync(`${directory}/contract-results.json`, JSON.stringify(results, null, 2));
}
console.log(`C1 contract boundaries: ${results.length} passed`);
