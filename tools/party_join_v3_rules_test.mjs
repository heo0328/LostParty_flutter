import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  runTransaction,
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(
  path.join(dirname, 'party_join_v3_proof.rules'),
  'utf8',
);
const projectId = 'demo-party-join-v3';
const recruitmentId = 'group-room-v3';
const leaderPlayerId = 'leader-player';
const joinerPlayerId = 'joiner-player';
const joinerUid = 'joiner-auth';
const joinerCharacterId = 'joiner-character';
const raidId = 'horizon_cathedral';
const cycleKey = '2026-09-23';

const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: { rules },
});

function leaderSlot() {
  return {
    playerId: leaderPlayerId,
    characterId: 'leader-character',
    classKey: 'bard',
    role: 'support',
    partyIndex: 0,
    slotIndex: 0,
    countedAsNonGroupMember: false,
    characterNameSnapshot: 'Leader',
    itemLevelSnapshot: 1800,
    combatPowerSnapshot: 5000,
    gemValidationSnapshot: null,
    buildIntegritySnapshot: null,
    joinedBy: leaderPlayerId,
    joinedAt: new Date('2026-09-23T00:00:00.000Z'),
  };
}

function baseRecruitment(overrides = {}) {
  return {
    schemaVersion: 3,
    recruitmentId,
    raidId,
    difficultyId: 'stage3',
    status: 'active',
    currentCycleStatus: 'active',
    currentCycleKey: cycleKey,
    targetCycleKey: cycleKey,
    manualRecruitmentEnabled: true,
    approvalPolicy: { mode: 'directJoin' },
    visibility: 'group',
    groupId: 'group-1',
    leaderPlayerId,
    partyCount: 1,
    membersPerParty: 4,
    maxMemberCount: 4,
    memberPlayerIds: [leaderPlayerId],
    memberCount: 1,
    dealerCount: 0,
    supportCount: 1,
    hasAvailableSlot: true,
    partySlots: [leaderSlot()],
    raidStateTargets: [{
      playerId: leaderPlayerId,
      stateId: `leader-character_${raidId}`,
    }],
    revision: 1,
    updatedAt: new Date('2026-09-23T00:00:00.000Z'),
    ...overrides,
  };
}

function joinerSlot(overrides = {}) {
  return {
    playerId: joinerPlayerId,
    characterId: joinerCharacterId,
    classKey: 'artist',
    role: 'dealer',
    partyIndex: 0,
    slotIndex: 1,
    countedAsNonGroupMember: false,
    characterNameSnapshot: 'Joiner',
    itemLevelSnapshot: 1770,
    combatPowerSnapshot: 3200,
    gemValidationSnapshot: null,
    buildIntegritySnapshot: null,
    joinedBy: joinerPlayerId,
    joinedEventId: `memberJoined_${recruitmentId}_2`,
    ...overrides,
  };
}

async function seed({
  groupMember = true,
  blocked = false,
  characterOwner = joinerPlayerId,
  weeklyClaim = false,
} = {}) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'authBindings', joinerUid), {
      playerId: joinerPlayerId,
    });
    await setDoc(doc(db, 'characters', joinerCharacterId), {
      status: 'active',
      ownerPlayerId: characterOwner,
    });
    await setDoc(doc(db, 'recruitments', recruitmentId), baseRecruitment());
    if (groupMember) {
      await setDoc(doc(db, 'groups', 'group-1', 'members', joinerPlayerId), {
        playerId: joinerPlayerId,
      });
    }
    if (blocked) {
      await setDoc(doc(db, 'groups', 'group-1', 'blockedPlayers', joinerPlayerId), {
        playerId: joinerPlayerId,
      });
    }
    if (weeklyClaim) {
      await setDoc(doc(
        db,
        'players',
        joinerPlayerId,
        'weeklyRaidClaims',
        `${cycleKey}_${joinerCharacterId}_${raidId}`,
      ), { status: 'completed' });
    }
    // 탈퇴 뒤 남을 수 있는 구 membership Projection은 v3 권위 참가 판정에 쓰지 않는다.
    await setDoc(doc(
      db,
      'recruitments',
      recruitmentId,
      'members',
      joinerPlayerId,
    ), { playerId: joinerPlayerId, status: 'left' });
  });
}

async function directJoin(db, {
  omitState = false,
  omitEvent = false,
  slotPatch = {},
  recruitmentPatch = {},
  mutateExisting = null,
} = {}) {
  const recruitmentRef = doc(db, 'recruitments', recruitmentId);
  const stateId = `${joinerCharacterId}_${raidId}`;
  const eventId = `memberJoined_${recruitmentId}_2`;
  return runTransaction(db, async (tx) => {
    const current = (await tx.get(recruitmentRef)).data();
    const slot = joinerSlot(slotPatch);
    const existing = mutateExisting == null
      ? current
      : mutateExisting(structuredClone(current));
    tx.update(recruitmentRef, {
      memberPlayerIds: [...existing.memberPlayerIds, joinerPlayerId],
      memberCount: 2,
      dealerCount: 1,
      supportCount: 1,
      hasAvailableSlot: true,
      partySlots: [...existing.partySlots, slot],
      raidStateTargets: [
        ...existing.raidStateTargets,
        { playerId: joinerPlayerId, stateId },
      ],
      revision: 2,
      updatedAt: serverTimestamp(),
      ...recruitmentPatch,
    });
    if (!omitState) {
      tx.set(doc(db, 'players', joinerPlayerId, 'raidStates', stateId), {
        schemaVersion: 1,
        playerId: joinerPlayerId,
        characterId: joinerCharacterId,
        raidId,
        difficultyId: 'stage3',
        recruitmentId,
        cycleKey,
        role: slot.role,
        status: 'active',
        source: 'party',
        revision: 1,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }
    if (!omitEvent) {
      tx.set(doc(db, 'partyEvents', eventId), {
        schemaVersion: 1,
        eventId,
        recruitmentId,
        type: 'memberJoined',
        commandId: eventId,
        commandRevision: 2,
        audiencePlayerIds: [leaderPlayerId, joinerPlayerId],
        actorPlayerId: joinerPlayerId,
        occurredAt: serverTimestamp(),
      });
    }
  });
}

const db = testEnv.authenticatedContext(joinerUid).firestore();

try {
  console.log('test: v3 group direct rejoin succeeds with 3 authoritative writes');
  await seed();
  await assertSucceeds(directJoin(db));
  console.log('PASS: v3 group direct rejoin');

  console.log('test: group membership is required');
  await seed({ groupMember: false });
  await assertFails(directJoin(db));
  console.log('PASS: non-group member denied');

  console.log('test: blocked group member is denied');
  await seed({ blocked: true });
  await assertFails(directJoin(db));
  console.log('PASS: blocked member denied');

  console.log('test: current character ownership is required');
  await seed({ characterOwner: 'other-player' });
  await assertFails(directJoin(db));
  console.log('PASS: foreign character denied');

  console.log('test: weekly completion blocks join');
  await seed({ weeklyClaim: true });
  await assertFails(directJoin(db));
  console.log('PASS: weekly claim denied');

  console.log('test: occupied slot and forged count are denied');
  await seed();
  await assertFails(directJoin(db, { slotPatch: { slotIndex: 0 } }));
  await seed();
  await assertFails(directJoin(db, { recruitmentPatch: { dealerCount: 2 } }));
  console.log('PASS: placement and count forgery denied');

  console.log('test: existing aggregate entries cannot be rewritten during join');
  await seed();
  await assertFails(directJoin(db, {
    mutateExisting: (current) => {
      current.partySlots[0].characterId = 'forged-leader-character';
      return current;
    },
  }));
  await seed();
  await assertFails(directJoin(db, {
    mutateExisting: (current) => {
      current.raidStateTargets[0].stateId = 'forged-target';
      return current;
    },
  }));
  console.log('PASS: existing aggregate entries preserved');

  console.log('test: raidState and event are mandatory atomic writes');
  await seed();
  await assertFails(directJoin(db, { omitState: true }));
  await seed();
  await assertFails(directJoin(db, { omitEvent: true }));
  console.log('PASS: missing authoritative write denied');
} finally {
  await testEnv.cleanup();
}
