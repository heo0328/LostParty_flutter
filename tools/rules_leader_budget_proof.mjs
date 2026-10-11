import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { doc, updateDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { recruitmentId } from './party_group_cutover_rules_test.mjs';
import { assertRulesDenied } from './assert_rules_denied.mjs';
export async function runLeaderBudgetProof({ env, setup, snapshot, request, command, client, getSlots }) {
  const results = [], directory = process.env.LEADER_BUDGET_DIRECTORY || 'coverage/rules-leader-budget';
  const manifest = JSON.parse(fs.readFileSync(`${directory}/manifest.json`, 'utf8'));
  assert.equal(createHash('sha256').update(fs.readFileSync(process.env.ROSTER_COMPLEXITY_RULES_FILE)).digest('hex'), manifest.sha256);
  fs.writeFileSync(`${directory}/proof-input.json`, JSON.stringify(manifest, null, 2));
  const timeout = setTimeout(() => { console.error('A1-F exceeded 180 seconds'); process.exit(2); }, 180000).unref();
  async function check(name, action) {
    try { await action(); results.push({ name, passed: true }); }
    catch (error) { results.push({ name, passed: false, code: error.code, error: error.message }); process.exitCode = 1; }
    fs.writeFileSync(`${directory}/results.json`, JSON.stringify(results, null, 2));
    console.log(JSON.stringify(results.at(-1)));
    return results.at(-1).passed;
  }
  try {
    const positive = await check('six peers then leader succession, receipt and completion preservation', async () => {
      await setup(); const before = await snapshot();
      for (let i = 0; i < 6; i++) assert.equal(await command(await request()), 'applied');
      const req = await request('leader'); assert.equal(await command(req), 'applied');
      const after = await snapshot();
      assert.equal(after.room.memberCount, 1); assert.equal(after.room.leaderPlayerId, req.actor);
      assert.equal(after.members.length, 1); assert.equal(after.members[0].canApproveApplications, true);
      for (const key of ['states', 'group', 'groupMembers']) assert.deepEqual(after[key], before[key], key);
      assert.deepEqual(after.listing, after.room);
      assert.equal(await command(req), 'already-applied'); assert.deepEqual(await snapshot(), after);
    });
    if (!positive) return;
    const distinct = await check('eight slots, distinct actor and first successor, later independent member permission', async () => {
      await setup(1); const before = await snapshot(), req = await request('leader');
      assert.equal(await command(req), 'applied'); const after = await snapshot();
      assert.equal(after.room.leaderPlayerId, getSlots()[1].playerId); assert.equal(after.room.memberCount, 7);
      assert.deepEqual(after.states, before.states); assert.deepEqual(after.listing, after.room);
      await updateDoc(doc(client(getSlots()[1].playerId), 'recruitments', recruitmentId, 'members', req.actor),
        { canApproveApplications: true, updatedAt: serverTimestamp() });
    });
    if (!distinct) return;
    for (const scenario of ['stale-generation', 'stale-revision', 'outsider', 'stale-actor', 'stale-successor', 'later-successor',
      'omit-successor', 'omit-member', 'omit-event', 'omit-listing', 'remaining-generation',
      'delete-state', 'missing-leader-member', 'missing-leader-member-delete-state']) {
      await check(`reject ${scenario} atomically without budget exhaustion`, async () => {
        await setup(1); const req = await request('leader');
        if (scenario === 'stale-generation') req.observedOwnershipRevision--;
        if (scenario === 'stale-revision') req.expectedRevision--;
        if (scenario === 'outsider') req.actor = 'outsider';
        if (scenario === 'later-successor') req.successorIndex = 2;
        if (scenario === 'stale-successor' || scenario === 'stale-actor') await env.withSecurityRulesDisabled(async ctx => {
          const slot = getSlots()[scenario === 'stale-actor' ? 7 : 1];
          for (const ref of [doc(ctx.firestore(), 'characters', slot.characterId), doc(ctx.firestore(), 'gameAccounts', `de-account-${slot.playerId}`)])
            await updateDoc(ref, { ownerPlayerId: 'new-owner', ownershipRevision: 2 });
        });
        if (scenario.startsWith('missing-leader-member')) await env.withSecurityRulesDisabled(ctx =>
          deleteDoc(doc(ctx.firestore(), 'recruitments', recruitmentId, 'members', req.targetPlayerId)));
        const before = await snapshot();
        await assertRulesDenied(command(req, scenario === 'missing-leader-member-delete-state' ? 'delete-state' : scenario));
        assert.deepEqual(await snapshot(), before);
      });
    }
  } finally { clearTimeout(timeout); }
}
