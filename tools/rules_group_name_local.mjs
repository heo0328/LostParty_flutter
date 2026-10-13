import assert from 'node:assert/strict';
import {rulesFunction} from './roster_complexity_candidate.mjs';

// Informational name quality only. Search stays a bounded server query;
// malformed projection values are not repaired by downloading all groups.
export function localizeGroupNames(input) {
  let source = input;
  const initial = rulesFunction(source, 'validInitialGroup');
  let text = initial.text;
  for (const call of ['validGroupDisplayName(data.name)', 'validGroupSearchProjection(data)']) {
    const clause = new RegExp(`\\s*&& ${call.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`);
    assert.equal((text.match(new RegExp(clause.source, 'g')) ?? []).length, 1, call);
    text = text.replace(clause, '');
  }
  source = source.slice(0, initial.start) + text + source.slice(initial.end);
  for (const name of ['validGroupDisplayName', 'validGroupSearchProjection']) {
    const helper = rulesFunction(source, name);
    source = source.slice(0, helper.start) + source.slice(helper.end);
    assert.ok(!source.includes(name), `remaining call to ${name}`);
  }
  return source;
}
