import assert from 'node:assert/strict';
import fs from 'node:fs';
import { initializeTestEnvironment, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, runTransaction,
  serverTimestamp, setDoc } from 'firebase/firestore';
import { assertRulesDenied } from './assert_rules_denied.mjs';
import { seedBase, seedJoiner, createPublicRecruitmentTxn, applicationTxn,
  approvePublicApplicationTxn, seedExpandedApprovedRoom, seedGroupLinkedRoom,
  authUid, recruitmentId } from './party_group_cutover_rules_test.mjs';

// Local-only R1 proof. Invoke against the review candidate on a demo Emulator.
// Setup bypasses Rules only for fixtures; every tested request uses client auth.
const projectId = 'demo-party-group-cutover';
const rulesFile = process.env.PARTY_RULES_FILE;
assert.equal(process.env.R1_LISTING, '1', 'R1_LISTING=1 required');
assert.ok(rulesFile, 'PARTY_RULES_FILE must name the review candidate');
process.env.RULES_AUDIT = '1';
const env = await initializeTestEnvironment({ projectId,
  firestore: { host: '127.0.0.1', port: 8080, rules: fs.readFileSync(rulesFile, 'utf8') } });
const leader = env.authenticatedContext(authUid).firestore();
const participant = env.authenticatedContext('joiner-auth').firestore();
const groupOnly = env.authenticatedContext('listing-group-only').firestore();
const outsider = env.authenticatedContext('listing-outsider').firestore();
const anonymous = env.unauthenticatedContext().firestore();
const sourcePath = `recruitments/${recruitmentId}`;
const listingPath = `groups/group-room-1/raidListings/${recruitmentId}`;
const otherPath = `groups/other-group/raidListings/${recruitmentId}`;
const wrongIdPath = 'groups/group-room-1/raidListings/wrong-source';
const observed = [sourcePath, listingPath, otherPath, wrongIdPath];
async function admin(fn) {
  let result;
  await env.withSecurityRulesDisabled(async context => { result = await fn(context.firestore()); });
  return result;
}
const snapshot = () => admin(async db => Promise.all(observed.map(async path => {
  const result = await getDoc(doc(db, path));
  return result.exists() ? result.data() : null;
})));
let base;
let passed = 0;
const pass = name => { passed++; console.log(`PASS LISTING: ${name}`); };
async function reset({ missing = false, patch = {}, listing } = {}) {
  await admin(async db => {
    await setDoc(doc(db, sourcePath), { ...base, ...patch });
    if (missing) await deleteDoc(doc(db, listingPath));
    else await setDoc(doc(db, listingPath), listing ?? base);
    await deleteDoc(doc(db, otherPath));
    await deleteDoc(doc(db, wrongIdPath));
  });
}
async function denied(name, action) {
  const before = await snapshot();
  await assertRulesDenied(action());
  assert.deepEqual(await snapshot(), before, `${name}: writes must be atomic`);
  pass(name);
}
// Same transaction read order and missing-only write as the Dart backfill.
// No expected revision bump: the source must remain unchanged.
async function backfill(db, firstRead) {
  let attempts = 0;
  const result = await runTransaction(db, async tx => {
    attempts++;
    const source = await tx.get(doc(db, sourcePath));
    const listing = await tx.get(doc(db, listingPath));
    if (attempts === 1 && firstRead) await firstRead();
    if (listing.exists()) return 'existing';
    const data = source.data();
    if (data?.visibility !== 'group' || data.groupId !== 'group-room-1'
      || data.status !== 'active' || data.currentCycleStatus === 'disbanded') return 'closed';
    tx.set(doc(db, listingPath), data);
    return 'created';
  });
  return { result, attempts };
}
try {
  await env.clearFirestore();
  await seedBase(env);
  await seedJoiner(env);
  await assertSucceeds(createPublicRecruitmentTxn(leader));
  await assertSucceeds(applicationTxn(participant, 'apply'));
  await assertSucceeds(approvePublicApplicationTxn(leader));
  await seedExpandedApprovedRoom(env, 8);
  await seedGroupLinkedRoom(env, leader, { includeJoinerGroupMember: true });
  base = (await getDoc(doc(leader, sourcePath))).data();
  await admin(async db => {
    for (const id of ['listing-group-only', 'listing-outsider']) {
      await setDoc(doc(db, 'authBindings', id), { playerId: id, status: 'active' });
      await setDoc(doc(db, 'players', id), { status: 'active' });
    }
    await setDoc(doc(db, 'groups/group-room-1/members/listing-group-only'), { playerId: 'listing-group-only' });
    await setDoc(doc(db, 'groups/other-group'), { status: 'active' });
    await setDoc(doc(db, 'groups/other-group/members/player-1'), { playerId: 'player-1' });
  });

  const legacy = { recruitmentId, memberCount: 8, sourceRevision: base.revision, updatedAt: base.updatedAt };
  await reset({ listing: legacy });
  assert.deepEqual((await getDoc(doc(groupOnly, listingPath))).data(), legacy);
  assert.equal((await getDocs(collection(groupOnly, 'groups/group-room-1/raidListings'))).size, 1);
  pass('current group member reads legacy partial listing');
  await denied('outsider cannot get listing', () => getDoc(doc(outsider, listingPath)));
  await denied('outsider cannot list group listings', () => getDocs(collection(outsider, 'groups/group-room-1/raidListings')));
  await denied('unauthenticated listing read', () => getDoc(doc(anonymous, listingPath)));
  const legacyBefore = await snapshot();
  assert.equal((await backfill(leader)).result, 'existing');
  assert.deepEqual(await snapshot(), legacyBefore);
  pass('backfill reentry preserves an existing legacy listing');

  await reset();
  await denied('standalone update cannot invent source revision', () => setDoc(doc(leader, listingPath),
    { ...base, revision: base.revision + 1, updatedAt: serverTimestamp() }));
  await denied('standalone exact overwrite is not backfill', () => setDoc(doc(leader, listingPath), base));
  await denied('standalone delete cannot remove active listing', () => deleteDoc(doc(leader, listingPath)));

  await reset({ missing: true });
  await denied('group member without participation cannot backfill', () => setDoc(doc(groupOnly, listingPath), base));
  await denied('outsider cannot backfill', () => setDoc(doc(outsider, listingPath), base));
  await denied('unauthenticated backfill', () => setDoc(doc(anonymous, listingPath), base));
  await denied('copy cannot target another group even with membership', () => setDoc(doc(leader, otherPath), base));
  await denied('forged group ID cannot match source', () => setDoc(doc(leader, otherPath), { ...base, groupId: 'other-group' }));
  await denied('listing path requires its own source', () => setDoc(doc(leader, wrongIdPath), base));
  await denied('changed title is not a canonical backfill', () => setDoc(doc(leader, listingPath), { ...base, title: 'forged' }));
  await denied('invented revision is not a canonical backfill', () => setDoc(doc(leader, listingPath), { ...base, revision: base.revision + 1 }));
  const { title, ...partial } = base;
  await denied('partial projection is not a canonical backfill', () => setDoc(doc(leader, listingPath), partial));
  await denied('new listing field cannot be disclosed', () => setDoc(doc(leader, listingPath), { ...base, privateNote: 'synthetic' }));
  await reset({ missing: true, patch: { privateNote: 'synthetic' } });
  await denied('unknown field on source still cannot be disclosed', () => setDoc(doc(leader, listingPath), { ...base, privateNote: 'synthetic' }));

  for (const patch of [{ visibility: 'public' }, { status: 'disbanded' },
    { status: 'completed', currentCycleStatus: 'completed' }, { status: 'incompleteEnded' },
    { currentCycleStatus: 'disbanded' }]) {
    await reset({ missing: true, patch });
    await denied(`backfill excludes ${JSON.stringify(patch)}`, () => setDoc(doc(leader, listingPath), { ...base, ...patch }));
  }
  await reset({ missing: true });
  const participantMembership = await admin(async db => {
    const ref = doc(db, 'groups/group-room-1/members/player-2');
    const value = (await getDoc(ref)).data();
    await deleteDoc(ref); return value;
  });
  await denied('participant who left group cannot backfill', () => setDoc(doc(participant, listingPath), base));
  await denied('participant who left group gains no listing read', () => getDoc(doc(participant, listingPath)));
  await admin(db => setDoc(doc(db, 'groups/group-room-1/members/player-2'), participantMembership));

  await assertSucceeds(backfill(participant));
  assert.deepEqual(await snapshot(), [base, base, null, null]);
  pass('current group participant backfills missing eight-member listing');
  const beforeReentry = await snapshot();
  assert.equal((await backfill(participant)).result, 'existing');
  assert.deepEqual(await snapshot(), beforeReentry);
  pass('reentry performs no source or listing mutation');

  await reset({ missing: true, patch: { currentCycleStatus: 'completed' } });
  await assertSucceeds(backfill(leader));
  const waiting = { ...base, currentCycleStatus: 'completed' };
  assert.deepEqual(await snapshot(), [waiting, waiting, null, null]);
  pass('completed-cycle waiting room retains missing-listing backfill');

  await reset({ missing: true, patch: { revision: base.revision + 1, title: 'new source' } });
  await denied('stale source snapshot cannot be backfilled', () => setDoc(doc(leader, listingPath), base));
  await assertSucceeds(backfill(leader));
  const current = { ...base, revision: base.revision + 1, title: 'new source' };
  assert.deepEqual(await snapshot(), [current, current, null, null]);
  pass('fresh transaction copies current source without revision bump');

  await reset({ missing: true });
  let reads = 0; let release;
  const bothRead = new Promise(resolve => { release = resolve; });
  let timer;
  const deadline = new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Concurrent read barrier timeout')), 10000); });
  const barrier = async () => {
    reads++; if (reads === 2) release();
    await Promise.race([bothRead, deadline]);
  };
  let results;
  try { results = await Promise.all([backfill(leader, barrier), backfill(participant, barrier)]); }
  finally { clearTimeout(timer); }
  assert.deepEqual(results.map(r => r.result).sort(), ['created', 'existing']);
  assert.ok(results.some(r => r.attempts > 1), 'losing transaction must retry');
  assert.deepEqual(await snapshot(), [base, base, null, null]);
  pass('concurrent missing backfills retry without overwriting or source mutation');
  for (const patch of [{ visibility: 'public' }, { status: 'completed', currentCycleStatus: 'completed' }]) {
    await reset({ missing: true });
    const changed = { ...base, ...patch, revision: base.revision + 1 };
    // Inject only the committed source transition, after backfill has read.
    // Lifecycle/visibility command authorization is tested by separate suites.
    await assertRulesDenied(backfill(leader,
      () => admin(db => setDoc(doc(db, sourcePath), changed))));
    assert.deepEqual(await snapshot(), [changed, null, null, null]);
    assert.equal((await backfill(leader)).result, 'closed');
    assert.deepEqual(await snapshot(), [changed, null, null, null]);
    pass(`stale backfill is denied and reentry skips ${JSON.stringify(patch)}`);
  }
  console.log(`Listing boundary proof: ${passed} passed; no production requests.`);
} finally {
  await env.cleanup();
}
