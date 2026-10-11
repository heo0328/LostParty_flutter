// Read-only contract inventory. No Rules output, compiler or remote requests.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { compactExecutableRules } from './rules_executable_compact.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';

const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
const compact = compactExecutableRules(input);
assert.equal(createHash('sha256').update(compact.source).digest('hex'),
  '17471d0f4bff19595c90ddb43c28766cbf976d77ba9d0adc0736ff59f4a93667');
const reverse = new Map(Object.entries(compact.functions).map(([name, short]) => [short, name]));
const source = compact.source;
const masked = source.replace(/'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\//g,
  value => value.replace(/[^\n]/g, ' '));
const close = open => {
  let depth = 1, end = open + 1;
  while (depth && end < masked.length) {
    if (masked[end] === '{') depth++;
    if (masked[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0);
  return end;
};
const calls = text => [...text.matchAll(/\b(\w+)\s*\(/g)]
  .map(m => reverse.get(m[1])).filter(Boolean);
const functions = [...masked.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => {
  const open = masked.indexOf('{', m.index), end = close(open);
  return { name: reverse.get(m[1]), bytes: Buffer.byteLength(source.slice(m.index, end)),
    calls: calls(masked.slice(open + 1, end - 1)) };
});
assert.equal(functions.length, reverse.size);
const byName = new Map(functions.map(f => [f.name, f]));
const matches = [...masked.matchAll(/\bmatch\s+([^\n]+?)\s+\{/g)].map(m => ({
  path: source.slice(m.index + 6, m.index + m[0].length - 1).trim(),
  start: m.index, end: close(m.index + m[0].length - 1),
}));
const reachable = (names, stack = []) => {
  const result = new Set();
  for (const name of names) {
    assert.ok(!stack.includes(name), 'Recursive helper');
    result.add(name);
    for (const child of reachable(byName.get(name).calls, [...stack, name])) result.add(child);
  }
  return result;
};
const allows = [...masked.matchAll(/\ballow\s+([^:]+):\s*if\s*([\s\S]*?);/g)].map(m => ({
  path: matches.filter(x => x.start < m.index && x.end > m.index).map(x => x.path).join(''),
  write: /\b(create|update|delete|write)\b/.test(m[1]),
  reachable: reachable(calls(m[2])),
}));
const sum = names => [...names].reduce((n, name) => n + byName.get(name).bytes, 0);
const contracts = {
  partyMembers: path => path.includes('/recruitments/') && path.includes('/members/'),
  partyEvents: path => path.includes('/partyEvents/'),
  legacyLedgers: path => /\/(activeRaidAssignments|weeklyRaidClaims)\//.test(path),
  groupListings: path => path.includes('/raidListings/'),
  groupRelationships: path => /\/(groupMembershipState|groupRelations|joinRelations)\//.test(path)
    || (path.includes('/groups/') && path.includes('/members/')),
  manualVerification: path => /\/manualVerification/.test(path),
};
const contractReport = Object.fromEntries(Object.entries(contracts).map(([name, predicate]) => {
  const selected = allows.filter(a => a.write && predicate(a.path));
  assert.ok(selected.length, `Missing roots: ${name}`);
  const roots = new Set(selected.flatMap(a => [...a.reachable]));
  const others = new Set(allows.filter(a => !selected.includes(a)).flatMap(a => [...a.reachable]));
  const exclusive = [...roots].filter(n => !others.has(n));
  const shared = [...roots].filter(n => others.has(n));
  return [name, { writeAllowCount: selected.length, exclusiveFunctionBytes: sum(exclusive),
    sharedFunctionBytes: sum(shared), exclusiveFunctions: exclusive }];
}));
const targetHelpers = ['atomicRaidStateListedInTargets', 'atomicCommandIncludes',
  'atomicAdvanceStateMatchesSlot', 'atomicAdvanceStateMatchesSlotAt',
  'atomicPositionInSlots', 'atomicPositionSlotAt', 'atomicEventTargetMatches', 'atomicAllEventTargetsMatch'];
for (const name of targetHelpers) assert.ok(byName.has(name));
const reached = new Set(allows.flatMap(a => [...a.reachable]));
// Hypothetical contract retirement, not a semantics-preserving optimization.
// Disable only the old non-atomic member-character write and prune newly unused
// declarations. Keep baseline unused declarations so they do not inflate savings.
const oldCall = /validMemberCharacterChange\(\s*recruitmentId,\s*playerId,\s*resource\.data,\s*request\.resource\.data\s*\)/g;
assert.equal([...input.matchAll(oldCall)].length, 1);
let legacyDraft = input.replace(oldCall, 'false');
const originallyUnused = new Set([...input.matchAll(/function (\w+)\(/g)].map(m => m[1])
  .filter(n => [...input.matchAll(new RegExp(`\\b${n}\\s*\\(`, 'g'))].length === 1));
const removed = [];
for (let i = 0; i < functions.length; i++) {
  const name = [...legacyDraft.matchAll(/function (\w+)\(/g)].map(m => m[1]).find(n =>
    !originallyUnused.has(n) && [...legacyDraft.matchAll(new RegExp(`\\b${n}\\s*\\(`, 'g'))].length === 1);
  if (!name) break;
  const f = rulesFunction(legacyDraft, name);
  legacyDraft = legacyDraft.slice(0, f.start) + legacyDraft.slice(f.end);
  removed.push(name);
}
// Six display copy equalities only. Removing them without typed replacements
// would weaken the stored display contract, so this is an optimistic ceiling.
let displayDraft = input;
const displayFields = ['lastCharacterNameSnapshot', 'lastItemLevelSnapshot', 'lastCombatPowerSnapshot',
  'characterNameSnapshot', 'itemLevelSnapshot', 'combatPowerSnapshot'];
for (const [i, field] of displayFields.entries()) {
  const name = i < 3 ? 'validGroupApplicantStatsWrite' : 'validGroupBlockCreate';
  const f = rulesFunction(displayDraft, name);
  const pattern = new RegExp(`\\s*&& data\\.${field} == relation\\.\\w+`);
  assert.ok(pattern.test(f.text));
  displayDraft = displayDraft.slice(0, f.start) + f.text.replace(pattern, '') + displayDraft.slice(f.end);
}
const legacyBytes = Buffer.byteLength(compactExecutableRules(legacyDraft).source);
const displayBytes = Buffer.byteLength(compactExecutableRules(displayDraft).source);
const memberExclusive = contractReport.partyMembers.exclusiveFunctions;
const combinedSurface = new Set([...memberExclusive, ...targetHelpers]);
console.log(JSON.stringify({ baselineBytes: Buffer.byteLength(source), functionCount: functions.length,
  totalFunctionBytes: functions.reduce((n, f) => n + f.bytes, 0),
  allowCount: allows.length,
  unreachable: functions.filter(f => !reached.has(f.name)).map(f => f.name),
  contracts: contractReport,
  targetRepresentation: { functionBytes: sum(targetHelpers), functions: targetHelpers },
  memberAndTargetUnionFunctionBytes: sum(combinedSurface),
  hypotheticalRetirements: {
    oldMemberCharacterWrite: { bytes: legacyBytes, reduction: Buffer.byteLength(source) - legacyBytes, removed },
    sixDisplayCopyEqualities: { bytes: displayBytes, optimisticReduction: Buffer.byteLength(source) - displayBytes },
  },
  largestFunctions: [...functions].sort((a, b) => b.bytes - a.bytes).slice(0, 12)
    .map(({ name, bytes }) => ({ name, bytes })),
  limitation: 'Function declarations at fixed baseline names only. Exclusive means reachable only from selected write roots, NOT removable security checks. Excludes allow edits and replacement validators. Shared totals overlap; do not add. No net reduction or runtime proof.'
}, null, 2));
