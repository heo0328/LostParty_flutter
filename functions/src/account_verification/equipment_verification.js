export const EQUIPMENT_SLOTS = Object.freeze([
  'weapon',
  'head',
  'shoulders',
  'chest',
  'legs',
  'hands',
]);

const API_TYPE_TO_SLOT = Object.freeze({
  '무기': 'weapon',
  '투구': 'head',
  '어깨': 'shoulders',
  '상의': 'chest',
  '하의': 'legs',
  '장갑': 'hands',
});

export function extractEquipmentSnapshot(armoryEquipment) {
  if (!Array.isArray(armoryEquipment)) {
    throw new EquipmentSnapshotError('ArmoryEquipment must be an array.');
  }

  const snapshot = {};
  for (const item of armoryEquipment) {
    if (item === null || typeof item !== 'object') continue;
    const slot = API_TYPE_TO_SLOT[item.Type];
    if (slot === undefined) continue;
    if (Object.hasOwn(snapshot, slot)) {
      throw new EquipmentSnapshotError(`Duplicate equipment slot: ${slot}`);
    }
    if (typeof item.Name !== 'string' || item.Name.trim() === '' ||
        typeof item.Grade !== 'string' || item.Grade.trim() === '') {
      throw new EquipmentSnapshotError(`Invalid equipment item: ${slot}`);
    }
    snapshot[slot] = Object.freeze({
      name: item.Name.trim(),
      grade: item.Grade.trim(),
    });
  }
  return Object.freeze(snapshot);
}

export function requireCompleteBaseline(snapshot) {
  const missingSlots = EQUIPMENT_SLOTS.filter(
    (slot) => !Object.hasOwn(snapshot, slot),
  );
  if (missingSlots.length > 0) {
    throw new EquipmentSnapshotError(
      `All verification equipment must be equipped: ${missingSlots.join(', ')}`,
    );
  }
}

export function validateRequiredSlots(requiredSlots) {
  if (!Array.isArray(requiredSlots) ||
      requiredSlots.length < 1 || requiredSlots.length > 3) {
    throw new EquipmentSnapshotError(
      'A challenge must contain between one and three slots.',
    );
  }
  const uniqueSlots = new Set(requiredSlots);
  if (uniqueSlots.size !== requiredSlots.length ||
      requiredSlots.some((slot) => !EQUIPMENT_SLOTS.includes(slot))) {
    throw new EquipmentSnapshotError('Challenge slots must be unique and valid.');
  }
}

export function selectChallengeSlots(randomInt) {
  if (typeof randomInt !== 'function') {
    throw new EquipmentSnapshotError('A server random integer source is required.');
  }
  const count = checkedRandomInt(randomInt, 3) + 1;
  const candidates = [...EQUIPMENT_SLOTS];
  for (let index = candidates.length - 1; index > 0; index -= 1) {
    const selectedIndex = checkedRandomInt(randomInt, index + 1);
    [candidates[index], candidates[selectedIndex]] =
      [candidates[selectedIndex], candidates[index]];
  }
  return Object.freeze(candidates.slice(0, count));
}

export function evaluateEquipmentChallenge({
  baseline,
  current,
  requiredUnequippedSlots,
  expiresAt,
  now,
}) {
  requireCompleteBaseline(baseline);
  validateRequiredSlots(requiredUnequippedSlots);
  if (!(expiresAt instanceof Date) || Number.isNaN(expiresAt.valueOf()) ||
      !(now instanceof Date) || Number.isNaN(now.valueOf())) {
    throw new EquipmentSnapshotError('Challenge times must be valid dates.');
  }
  if (now >= expiresAt) {
    return Object.freeze({status: 'expired'});
  }

  const required = new Set(requiredUnequippedSlots);
  const stillEquipped = requiredUnequippedSlots.filter(
    (slot) => Object.hasOwn(current, slot),
  );
  if (stillEquipped.length > 0) {
    return Object.freeze({
      status: 'requiredSlotsStillEquipped',
      slots: Object.freeze(stillEquipped),
    });
  }

  const changedSlots = EQUIPMENT_SLOTS.filter((slot) => {
    if (required.has(slot)) return false;
    return !sameItem(baseline[slot], current[slot]);
  });
  if (changedSlots.length > 0) {
    return Object.freeze({
      status: 'unchallengedSlotChanged',
      slots: Object.freeze(changedSlots),
    });
  }
  return Object.freeze({status: 'verified'});
}

function sameItem(left, right) {
  return left !== undefined && right !== undefined &&
    left.name === right.name && left.grade === right.grade;
}

function checkedRandomInt(randomInt, maxExclusive) {
  const value = randomInt(maxExclusive);
  if (!Number.isInteger(value) || value < 0 || value >= maxExclusive) {
    throw new EquipmentSnapshotError(
      `Random source must return an integer from 0 to ${maxExclusive - 1}.`,
    );
  }
  return value;
}

export class EquipmentSnapshotError extends Error {
  constructor(message) {
    super(message);
    this.name = 'EquipmentSnapshotError';
  }
}
