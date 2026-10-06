import assert from 'node:assert/strict';

// Complete may fill an absent role; an existing conflicting role is never repaired.
export function completionRoleCompatibility(source) {
  const start = source.indexOf('    function validAtomicRaidStateUpdate(');
  const end = source.indexOf('    function validAtomicRaidStateDelete(', start);
  assert.ok(start >= 0 && end > start);
  let body = source.slice(start, end);
  const before = body;
  body = body.replace("'updatedAt'\n        ])", "'updatedAt', 'role'\n        ])");
  body = body.replace("&& (oldData.status == 'active' || oldData.status == 'completed')",
    "&& !newData.diff(oldData).affectedKeys().hasAny(['role'])\n            && (oldData.status == 'active' || oldData.status == 'completed')");
  body = body.replace('&& atomicAdvanceStateMatchesSlot(recruitment, oldData)',
    `&& oldData.recruitmentId == recruitment.recruitmentId
            && oldData.raidId == recruitment.raidId
            && oldData.difficultyId == recruitment.difficultyId
            && oldData.cycleKey == recruitment.currentCycleKey
            && (!('role' in oldData) || oldData.role == newData.role)
            && atomicAdvanceStateMatchesSlot(recruitment, newData)`);
  assert.notEqual(body, before);
  assert.ok(body.includes("'updatedAt', 'role'"));
  assert.ok(body.includes("!('role' in oldData)"));
  return source.slice(0, start) + body + source.slice(end);
}
