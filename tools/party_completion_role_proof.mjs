// Local emulator only. Fixtures preserve the observed defects, not private documents.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField } from 'firebase/firestore';
import { authUid, recruitmentId, raidId, seedGroupLinkedRoom } from './party_group_cutover_rules_test.mjs';

process.env.ROSTER_TRACKED_RULES = '1';
process.env.ROSTER_COMPLEXITY_RULES_FILE = 'firestore.rules';
const { seedRoom, lifecycle, inspectAll } = await import('./roster_ownership_rules_proof.mjs');
const baseline = execFileSync('git', ['show', '223e852:firestore.rules'], { encoding: 'utf8' });
const candidate = fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');
const results = [];
for (const [version, rules] of [['baseline', baseline], ['candidate', candidate]]) {
  const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover',
    firestore: { host: '127.0.0.1', port: 8080, rules } });
  const db = env.authenticatedContext(authUid).firestore();
  async function check(label, { missing = true, listingFixed = false, roleFixed = false,
    targetIndex = 0, count = 3, invalid = null, tamper = null, expected = true,
    type = 'complete', roomRevision = 13 } = {}) {
    await seedRoom(env, db);
    await seedGroupLinkedRoom(env, db);
    await env.withSecurityRulesDisabled(async ctx => {
      const admin = ctx.firestore();
      const roomRef = doc(admin, 'recruitments', recruitmentId);
      const original = (await getDoc(roomRef)).data();
      const slots = original.partySlots.slice(0, count);
      const ids = slots.map(s => s.playerId);
      await updateDoc(roomRef, { partySlots: slots, memberPlayerIds: ids,
        memberCount: count, dealerCount: slots.filter(s => s.role === 'dealer').length,
        supportCount: slots.filter(s => s.role === 'support').length,
        raidStateTargets: original.raidStateTargets.filter(t => ids.includes(t.playerId)),
        revision: roomRevision });
      await updateDoc(doc(admin, 'groups', original.groupId, 'raidListings', recruitmentId),
        { revision: listingFixed ? roomRevision : roomRevision - 2 });
      for (const [index, slot] of slots.entries()) {
        const accountId = `completion-account-${index}`;
        await setDoc(doc(admin, 'gameAccounts', accountId), { ownerPlayerId: slot.playerId, status: 'active', ownershipRevision: 1 });
        await updateDoc(doc(admin, 'characters', slot.characterId), { gameAccountId: accountId });
        const ref = doc(admin, 'players', slot.playerId, 'raidStates', `${slot.characterId}_${raidId}`);
        await updateDoc(ref, { revision: index === targetIndex ? 1 : 3,
          role: index === targetIndex && missing && !roleFixed ? deleteField() : slot.role });
        if (index !== targetIndex) continue;
        if (invalid === 'existing-role') await updateDoc(ref, { role: slot.role === 'dealer' ? 'support' : 'dealer' });
        if (invalid === 'cycle') await updateDoc(ref, { cycleKey: '2000-01-01' });
        if (invalid === 'room') await updateDoc(ref, { recruitmentId: 'another-room' });
        if (invalid === 'owner') await updateDoc(doc(admin, 'characters', slot.characterId), { ownershipRevision: 2 });
        if (invalid === 'missing-document') await deleteDoc(ref);
      }
    });
    const before = await inspectAll(env);
    let error;
    try { await lifecycle(db, type, { completionRole: version === 'candidate', tamper }); }
    catch (caught) { error = caught; }
    const after = await inspectAll(env);
    const allowed = !error;
    if (!allowed) assert.deepEqual(after, before, `${label}: rejected write changed data`);
    assert.equal(allowed, expected, `${version}/${label}: ${error?.message ?? 'unexpected allow'}`);
    if (allowed) {
      assert.equal(after.room.revision, before.room.revision + 1);
      assert.equal(after.listing.sourceRevision, after.room.revision);
      assert.ok(after.states.every((state, index) => state.role === after.room.partySlots[index].role));
      assert.ok(after.states.every(state => state.status === (type === 'complete' ? 'completed' : 'active')));
    }
    results.push({ version, label, allowed, error: error?.code ?? null });
    console.log(`PASS ${version}/${label}: ${allowed ? 'allowed' : 'denied; atomic unchanged'}`);
  }
  try {
    for (const [room, targetIndex, roomRevision] of [['Ailker', 0, 13], ['Nitian', 1, 9]]) {
      for (const listingFixed of [false, true]) for (const roleFixed of [false, true]) {
        await check(`${room}/listing=${listingFixed}/role=${roleFixed}`, { targetIndex, roomRevision,
          listingFixed, roleFixed, expected: version === 'candidate' || roleFixed });
      }
    }
    if (version === 'candidate') {
      await check('8-member-missing-role', { count: 8, targetIndex: 7 });
      await check('normal-complete', { missing: false });
      await check('normal-advance', { missing: false, type: 'advanceCycle', count: 8 });
      for (const invalid of ['existing-role', 'cycle', 'room', 'owner', 'missing-document'])
        await check(`reject-${invalid}`, { invalid, expected: false });
      for (const tamper of ['role', 'omit-state', 'target-player'])
        await check(`reject-${tamper}`, { tamper, expected: false });
    }
  } finally { await env.cleanup(); }
}
fs.mkdirSync(new URL('../coverage/party-completion-role/', import.meta.url), { recursive: true });
fs.writeFileSync(new URL('../coverage/party-completion-role/results.json', import.meta.url), JSON.stringify(results, null, 2));
console.log(`Completion role proof: ${results.length} passed; no production data accessed.`);
