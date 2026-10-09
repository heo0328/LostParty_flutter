// A2 cumulative local source: R1 -> A1-F -> remove one unreferenced helper.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { leaderBudgetCandidate } from './rules_leader_budget_candidate.mjs';
import { rulesFunction } from './roster_complexity_candidate.mjs';
import { compactExecutableRules } from './rules_executable_compact.mjs';
const input = fs.readFileSync('coverage/rules-listing/readable.rules', 'utf8');
const prior = leaderBudgetCandidate(input);
const hash = source => createHash('sha256').update(source).digest('hex');
assert.equal(hash(compactExecutableRules(prior).source), '053603bc5584f8ac5fa4a86d538390a8b010d55863afad9f93ec5ca6dbfe68b8');
assert.equal([...prior.matchAll(/\batomicHasGroupId\s*\(/g)].length, 1, 'declaration only');
const unused = rulesFunction(prior, 'atomicHasGroupId');
const readable = prior.slice(0, unused.start) + prior.slice(unused.end);
// Only unreachable declaration removed; retain every executable allow/function verbatim.
assert.equal(rulesFunction(readable, 'deLeaderCleanupAggregate').text, rulesFunction(prior, 'deLeaderCleanupAggregate').text);
assert.deepEqual([...readable.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]),
  [...prior.matchAll(/\ballow\s+[\s\S]*?;/g)].map(m => m[0]));
const source = compactExecutableRules(readable).source;
const manifest = { sha256: hash(source), bytes: Buffer.byteLength(source), delta: Buffer.byteLength(source) - 148914 };
fs.mkdirSync('coverage/rules-listing-safety', { recursive: true });
fs.writeFileSync('coverage/rules-listing-safety/readable.rules', readable);
fs.writeFileSync('coverage/rules-listing-safety/candidate.rules', source);
fs.writeFileSync('coverage/rules-listing-safety/manifest.json', JSON.stringify(manifest, null, 2));
console.log(JSON.stringify(manifest));
