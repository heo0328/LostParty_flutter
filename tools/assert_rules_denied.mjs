import assert from 'node:assert/strict';

// Permission policy must reject the request, rather than exhausting the engine.
export async function assertRulesDenied(operation) {
  let error;
  try { await operation; } catch (caught) { error = caught; }
  assert.equal(error?.code, 'permission-denied', 'expected Rules permission denial');
  assert.doesNotMatch(error.message, /maximum|evaluation limit|service call error/i,
    'access/evaluation exhaustion is not a valid policy rejection');
  return error;
}
