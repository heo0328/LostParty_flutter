// Read-only audit of the pinned runtime contract against embedded Flutter wire.
// Usage: node tool/audit_server_processing_contract.mjs path/to/openapi.json
import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const source = '5172c7535b556997e76b9d728dc4714a1988ab60';
const raw = fs.readFileSync(process.argv[2]);
assert.equal(crypto.createHash('sha256').update(raw).digest('hex'),
  '2f0ae34849e99618e194ad158383091f71967d3c41083d17dfee32a175fd9c9f',
  'Unexpected Backend contract; review the handoff before changing the pin.');
const api = JSON.parse(raw);
const schemas = api.components.schemas;
const paths = Object.keys(api.paths);
const methods = ['get', 'post', 'put', 'patch', 'delete', 'head', 'options'];
const operations = Object.values(api.paths).reduce((n, p) =>
  n + methods.filter(m => p[m]).length, 0);
assert.equal(paths.length, 191);
assert.equal(operations, 211);
assert.ok(api.paths['/v2/me/character-analysis/refresh']?.post);
assert.ok(!api.paths['/v1/me/lostark-api-key']);
assert.ok(!api.paths['/v2/me/role-summary-batches']);
assert.ok(!api.paths['/v2/me/characters/{character_id}/role-summaries/{role}']);

const canonical = v => JSON.stringify(normalize(v));
function normalize(v) {
  if (Array.isArray(v)) return v.map(normalize);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort()
    .map(k => [k, k === '$ref' ? '#/$defs/' + v[k].split('/').at(-1) : normalize(v[k])]));
  return v;
}
function references(value) {
  const names = new Set();
  function visit(v) {
    if (!v || typeof v !== 'object') return;
    if (v.$ref) names.add(v.$ref.split('/').at(-1));
    Object.values(v).forEach(visit);
  }
  visit(value);
  return names;
}
const reports = [];
for (const file of [
  'lib/features/recruitment_list/data/beta/beta_wire_schema.g.dart',
  'lib/features/recruitment_list/data/beta/beta_original_wire_schema.g.dart',
  'lib/features/group/data/backend/group_wire_schema.g.dart',
]) {
  const text = fs.readFileSync(file, 'utf8');
  const wire = JSON.parse(text.split("r'''")[1].split("'''")[0]);
  const needed = new Set();
  const missingOperations = [];
  for (const op of wire.operations) {
    const actual = api.paths[op.path]?.[op.method.toLowerCase()];
    if (!actual) missingOperations.push(`${op.method} ${op.path}`);
    else references(actual).forEach(n => needed.add(n));
  }
  const changed = [], added = [], missing = [];
  const seen = new Set();
  for (const name of needed) {
    if (seen.has(name)) continue;
    seen.add(name);
    const actual = schemas[name];
    if (!actual) { missing.push(name); continue; }
    references(actual).forEach(n => needed.add(n));
    const old = (wire.definitions ?? wire.$defs ?? wire.schemas)?.[name];
    if (!old) added.push(name);
    else if (canonical(old) !== canonical(actual)) changed.push(name);
  }
  assert.deepEqual(missingOperations, [], `Missing operations in ${file}`);
  assert.deepEqual(missing, [], `Unresolved runtime references in ${file}`);
  reports.push({file, operations: wire.operations.length,
    reachableDefinitions: seen.size, changed: changed.sort(), added: added.sort()});
}
const analysis = api.paths['/v2/me/character-analysis/refresh'].post;
const report = {source, sha256: crypto.createHash('sha256').update(raw).digest('hex'),
  paths: paths.length, operations, analysisRequest: analysis.requestBody,
  analysisResponse: analysis.responses['200'], reports};
if (process.argv[3]) fs.writeFileSync(process.argv[3], JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({source, paths: paths.length, operations,
  reports: reports.map(r => ({file: r.file, operations: r.operations,
    reachableDefinitions: r.reachableDefinitions, changed: r.changed.length,
    added: r.added.length}))}, null, 2));
