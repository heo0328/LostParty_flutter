import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

import {
  EquipmentSnapshotError,
  evaluateEquipmentChallenge,
  extractEquipmentSnapshot,
  requireCompleteBaseline,
  selectChallengeSlots,
  validateRequiredSlots,
} from '../src/account_verification/equipment_verification.js';

const expiresAt = new Date('2026-08-25T10:10:00.000Z');
const now = new Date('2026-08-25T10:05:00.000Z');

test('extracts the six verification slots from the real armory fixture', async () => {
  const fixture = JSON.parse(await readFile(
    new URL('../../test/fixtures/lost_ark/character_armory_full.json', import.meta.url),
    'utf8',
  ));

  const snapshot = extractEquipmentSnapshot(fixture.ArmoryEquipment);

  requireCompleteBaseline(snapshot);
  assert.deepEqual(Object.keys(snapshot).sort(), [
    'chest', 'hands', 'head', 'legs', 'shoulders', 'weapon',
  ]);
  assert.equal(snapshot.weapon.name, '+21 운명의 전율 리아네 하프');
});

test('verifies when only every challenged slot is unequipped', () => {
  const baseline = completeSnapshot();
  const current = {...baseline};
  delete current.head;
  delete current.weapon;

  assert.deepEqual(evaluateEquipmentChallenge({
    baseline,
    current,
    requiredUnequippedSlots: ['head', 'weapon'],
    expiresAt,
    now,
  }), {status: 'verified'});
});

test('keeps the challenge pending while a required slot is equipped', () => {
  const baseline = completeSnapshot();
  const current = {...baseline};
  delete current.head;

  assert.deepEqual(evaluateEquipmentChallenge({
    baseline,
    current,
    requiredUnequippedSlots: ['head', 'weapon'],
    expiresAt,
    now,
  }), {
    status: 'requiredSlotsStillEquipped',
    slots: ['weapon'],
  });
});

test('rejects removal or replacement of an unchallenged slot', () => {
  const baseline = completeSnapshot();
  const current = {...baseline, chest: {name: '다른 상의', grade: '고대'}};
  delete current.head;

  assert.deepEqual(evaluateEquipmentChallenge({
    baseline,
    current,
    requiredUnequippedSlots: ['head'],
    expiresAt,
    now,
  }), {
    status: 'unchallengedSlotChanged',
    slots: ['chest'],
  });
});

test('expires at the exact server expiration time', () => {
  assert.deepEqual(evaluateEquipmentChallenge({
    baseline: completeSnapshot(),
    current: {},
    requiredUnequippedSlots: ['head'],
    expiresAt,
    now: new Date(expiresAt),
  }), {status: 'expired'});
});

test('requires a complete six-slot baseline', () => {
  const baseline = completeSnapshot();
  delete baseline.weapon;

  assert.throws(
    () => requireCompleteBaseline(baseline),
    EquipmentSnapshotError,
  );
});

test('requires one to three unique supported challenge slots', () => {
  assert.throws(() => validateRequiredSlots([]), EquipmentSnapshotError);
  assert.throws(
    () => validateRequiredSlots(['head', 'head']),
    EquipmentSnapshotError,
  );
  assert.throws(
    () => validateRequiredSlots(['head', 'weapon', 'hands', 'legs']),
    EquipmentSnapshotError,
  );
});

test('selects one to three unique slots with a server random source', () => {
  const values = [2, 0, 1, 2, 1, 0];
  const selected = selectChallengeSlots((maxExclusive) => {
    const value = values.shift();
    assert.ok(value < maxExclusive);
    return value;
  });

  assert.equal(selected.length, 3);
  assert.equal(new Set(selected).size, 3);
  validateRequiredSlots(selected);
});

test('rejects an invalid server random source', () => {
  assert.throws(
    () => selectChallengeSlots((maxExclusive) => maxExclusive),
    EquipmentSnapshotError,
  );
});

function completeSnapshot() {
  return {
    weapon: {name: '무기', grade: '고대'},
    head: {name: '투구', grade: '고대'},
    shoulders: {name: '어깨', grade: '고대'},
    chest: {name: '상의', grade: '고대'},
    legs: {name: '하의', grade: '고대'},
    hands: {name: '장갑', grade: '고대'},
  };
}
