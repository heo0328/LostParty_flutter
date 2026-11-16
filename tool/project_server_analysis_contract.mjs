import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const bytes = fs.readFileSync(process.argv[2]);
assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),
  '2f0ae34849e99618e194ad158383091f71967d3c41083d17dfee32a175fd9c9f');
const api = JSON.parse(bytes), definitions = {};
const names = new Set(['AnalysisRequest', 'AnalysisResponse', 'RoleAnalysis', 'AnalysisDetail', 'BPowerComparison', 'CandidatePower', 'GroupRolePower']);
function refs(v) {
  if (!v || typeof v !== 'object') return;
  if (v.$ref) names.add(v.$ref.split('/').at(-1));
  Object.values(v).forEach(refs);
}
for (const name of names) {
  if (!api.components.schemas[name]) { names.delete(name); continue; }
  definitions[name] = api.components.schemas[name]; refs(definitions[name]);
}
fs.mkdirSync('lib/shared/backend', {recursive: true});
fs.writeFileSync('lib/shared/backend/server_analysis_schema.g.dart',
  '// Backend b95cff51; regenerate with tool/project_server_analysis_contract.mjs.\n' +
  "const serverAnalysisSchemaJson = r'''\n" + JSON.stringify(definitions, null, 2) + "\n''';\n");

// Keep existing query/profile selections; replace the role projections with the
// published contract and include only their referenced definitions.
for (const file of [
  'lib/features/recruitment_list/data/beta/beta_wire_schema.g.dart',
  'lib/features/recruitment_list/data/beta/beta_original_wire_schema.g.dart',
  'lib/features/group/data/backend/group_wire_schema.g.dart',
]) {
  const original = fs.readFileSync(file, 'utf8');
  const wire = JSON.parse(original.split("r'''")[1].split("'''")[0]);
  const key = wire.definitions ? 'definitions' : 'schemas';
  const defs = wire[key];
  const needed = new Set(Object.keys(defs).filter(n => /PowerComparison$|CandidatePower$|GroupRolePower$/.test(n)));
  // Current detail envelopes carry the agreed group policy metadata as well.
  // Persisted original-command schemas keep their historical selection.
  if (file.endsWith('/beta_wire_schema.g.dart')) {
    needed.add('BInterval');
    for (const name of Object.keys(defs)) {
      if (/(?:ApplicationDisplayDetailResponse|ApplicationDisplayPageResponse|GroupLinkedApplicationDetail)$/.test(name) || name === 'Successor') {
        needed.add(name);
      }
    }
  }
  const collect = v => {
    if (!v || typeof v !== 'object') return;
    if (v.$ref) needed.add(v.$ref.split('/').at(-1));
    Object.values(v).forEach(collect);
  };
  const rewrite = v => Array.isArray(v) ? v.map(rewrite) : v && typeof v === 'object'
    ? Object.fromEntries(Object.entries(v).map(([k,x]) => [k, k === '$ref' && key === 'definitions'
      ? '#/$defs/' + x.split('/').at(-1) : rewrite(x)])) : v;
  for (const name of needed) {
    const schema = api.components.schemas[name];
    assert.ok(schema, name); collect(schema); defs[name] = rewrite(schema);
  }
  const prefix = original.slice(0, original.indexOf("r'''"))
    .replace(/^\/\/ (?:Role|Runtime) projection updated[^\n]*\n/, '');
  const provenance = file.endsWith('/beta_wire_schema.g.dart')
    ? '// Runtime projection updated to Backend 5172c753; query/profile selections preserved.\n'
    : '// Role projection updated to Backend b95cff51; other profiles unchanged.\n';
  fs.writeFileSync(file, provenance +
    prefix + "r'''\n" + JSON.stringify(wire, null, 2) + "\n''';\n");
}
