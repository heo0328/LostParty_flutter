import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, runTransaction, deleteField } from 'firebase/firestore';
import { generationCandidate } from './roster_generation_candidate.mjs';

const rules = generationCandidate(fs.readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'));
const directory = new URL('../coverage/roster-leader/', import.meta.url);
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(new URL('candidate.rules', directory), rules);
fs.writeFileSync(new URL('manifest.json', directory), JSON.stringify({ sha256: createHash('sha256').update(rules).digest('hex') }));
const env = await initializeTestEnvironment({ projectId: 'demo-party-group-cutover', firestore: { rules, host: '127.0.0.1', port: 8080 } });
const db = env.authenticatedContext('generation-client').firestore();
const accountRef = doc(db, 'gameAccounts', 'roster');
const characterRefs = Array.from({ length: 8 }, (_, i) => doc(db, 'characters', `generation-${i}`));
const results = [];
async function check(name, work) {
  try { await work(); results.push({ name, passed: true }); console.log(`PASS GENERATION: ${name}`); }
  catch (error) { results.push({ name, passed: false, error: error.message }); console.error(`FAIL GENERATION: ${name}: ${error.message}`); }
}
async function snapshot() {
  let result;
  await env.withSecurityRulesDisabled(async ctx => {
    result = {
      account: (await getDoc(doc(ctx.firestore(), 'gameAccounts', 'roster'))).data(),
      characters: await Promise.all(characterRefs.map(ref => getDoc(doc(ctx.firestore(), ref.path)).then(s => s.data()))),
    };
  });
  assert.ok(result && Array.isArray(result.characters), 'snapshot was not captured');
  return result;
}
async function seed(legacy = false) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async ctx => {
    const batch = writeBatch(ctx.firestore());
    const ownership = { ownerPlayerId: 'A', ...(legacy ? {} : { ownershipRevision: 1 }) };
    batch.set(doc(ctx.firestore(), accountRef.path), ownership);
    for (const ref of characterRefs) batch.set(doc(ctx.firestore(), ref.path), { ...ownership, gameAccountId: 'roster', display: 'preserved' });
    await batch.commit();
  });
}
async function transfer(owner) {
  return runTransaction(db, async tx => {
    const before = (await tx.get(accountRef)).data();
    const chars = [];
    for (const ref of characterRefs) chars.push((await tx.get(ref)).data());
    const revision = before ? (before.ownershipRevision ?? 0) + (before.ownerPlayerId === owner ? 0 : 1) : 1;
    tx.set(accountRef, { ...before, ownerPlayerId: owner, ownershipRevision: revision });
    for (let i = 0; i < characterRefs.length; i++) tx.set(characterRefs[i], { ...chars[i], gameAccountId: 'roster', ownerPlayerId: owner, ownershipRevision: revision });
  });
}
try {
  await check('new maximum roster, reauth, A-B-A generations', async () => {
    await env.clearFirestore();
    await assertSucceeds(transfer('A'));
    assert.equal((await snapshot()).account.ownershipRevision, 1);
    await assertSucceeds(transfer('A'));
    assert.equal((await snapshot()).account.ownershipRevision, 1);
    await assertSucceeds(transfer('B'));
    await assertSucceeds(transfer('A'));
    const after = await snapshot();
    assert.equal(after.account.ownershipRevision, 3);
    assert.ok(after.characters.every(c => c.ownerPlayerId === 'A' && c.ownershipRevision === 3));
  });
  await check('legacy display write and reauth retain zero until transfer', async () => {
    await seed(true);
    await assertSucceeds(updateDoc(characterRefs[0], { display: 'updated' }));
    await assertSucceeds(transfer('A'));
    assert.equal((await snapshot()).account.ownershipRevision, 0);
    await assertSucceeds(transfer('B'));
    const after = await snapshot();
    assert.equal(after.account.ownershipRevision, 1);
    assert.equal(after.characters[0].display, 'updated');
  });
  for (const [name, patch] of [
    ['decrease', { ownershipRevision: 0 }], ['omit', { ownershipRevision: deleteField() }],
    ['same-owner-increment', { ownershipRevision: 2 }], ['transfer-without-increment', { ownerPlayerId: 'B' }],
    ['null', { ownershipRevision: null }], ['fraction', { ownershipRevision: 1.5 }],
  ]) {
    await check(`reject account ${name}`, async () => {
      await seed(); const before = await snapshot();
      await assertFails(updateDoc(accountRef, patch));
      assert.deepEqual(await snapshot(), before);
    });
  }
  for (const [name, patch] of [
    ['wrong-owner', { ownerPlayerId: 'B' }], ['wrong-generation', { ownershipRevision: 2 }],
    ['omit-generation', { ownershipRevision: deleteField() }], ['rebind-account', { gameAccountId: 'other' }],
  ]) {
    await check(`reject Character ${name}`, async () => {
      await seed(); const before = await snapshot();
      await assertFails(updateDoc(characterRefs[0], patch));
      assert.deepEqual(await snapshot(), before);
    });
  }
  await check('one incorrect Character rolls back whole maximum transfer', async () => {
    await seed(); const before = await snapshot(), batch = writeBatch(db);
    batch.update(accountRef, { ownerPlayerId: 'B', ownershipRevision: 2 });
    for (const [i, ref] of characterRefs.entries()) batch.update(ref, { ownerPlayerId: 'B', ownershipRevision: i === 7 ? 1 : 2 });
    await assertFails(batch.commit());
    assert.deepEqual(await snapshot(), before);
  });
  await check('delete cannot reset generations', async () => {
    await seed(); const before = await snapshot();
    await assertFails(deleteDoc(accountRef));
    await assertFails(deleteDoc(characterRefs[0]));
    assert.deepEqual(await snapshot(), before);
  });
  await check('concurrent distinct owners serialize and same owner is idempotent', async () => {
    await seed();
    const owners = ['B', 'C'];
    const competing = await Promise.allSettled(owners.map(transfer));
    assert.ok(competing.some(r => r.status === 'fulfilled'));
    for (const [index, result] of competing.entries()) {
      if (result.status === 'rejected') {
        assert.ok(['permission-denied', 'aborted'].includes(result.reason.code), result.reason.message);
        const stable = await snapshot();
        assert.ok(stable.characters.every(c => c.ownershipRevision === stable.account.ownershipRevision && c.ownerPlayerId === stable.account.ownerPlayerId));
        // Explicit retry is a fresh authentication attempt against the latest owner.
        await assertSucceeds(transfer(owners[index]));
      }
    }
    const after = await snapshot();
    assert.equal(after.account.ownershipRevision, 3);
    assert.ok(after.characters.every(c => c.ownershipRevision === 3 && c.ownerPlayerId === after.account.ownerPlayerId));
    await seed();
    const duplicate = await Promise.allSettled([transfer('B'), transfer('B')]);
    assert.ok(duplicate.some(r => r.status === 'fulfilled'));
    for (const result of duplicate) {
      if (result.status === 'rejected') {
        assert.ok(['permission-denied', 'aborted'].includes(result.reason.code), result.reason.message);
        await assertSucceeds(transfer('B'));
      }
    }
    assert.equal((await snapshot()).account.ownershipRevision, 2);
  });
} finally { await env.cleanup(); }
fs.writeFileSync(new URL('results.json', directory), JSON.stringify(results, null, 2));
if (results.some(result => !result.passed)) process.exitCode = 1;
