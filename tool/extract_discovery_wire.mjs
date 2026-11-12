import fs from 'node:fs';
import crypto from 'node:crypto';
const input = fs.readFileSync(process.argv[2]);
if (crypto.createHash('sha256').update(input).digest('hex') !== '3fdc06616d64e19aa7abf35b548cf1156fa7fbee6bcfb02c1dccf4ce9a9d7052') throw Error('Unpinned discovery contract');
const api = JSON.parse(input);
const path = 'lib/features/recruitment_list/data/beta/beta_wire_schema.g.dart';
const original = fs.readFileSync(path, 'utf8');
const wire = JSON.parse(original.split("r'''", 2)[1].split("'''", 1)[0]);
const rewrite = v => Array.isArray(v) ? v.map(rewrite) : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k,x]) => [k,k === '$ref' ? '#/$defs/'+x.split('/').at(-1) : rewrite(x)])) : v;
const operation = wire.operations.find(o => o.method === 'POST' && o.path === '/v2/raid-rooms/search');
const source = api.paths['/v2/raid-rooms/search'].post;
operation.query = operation.query.filter(p => p.name !== 'response_profile');
operation.query.push(rewrite(source.parameters.find(p => p.name === 'response_profile')));
const names = new Set(['DiscoveryPage','DiscoveryGroupPage']);
for(const name of names) {
 const schema = api.components.schemas[name];
 if (!schema) throw Error(name);
 const walk = v => {if(Array.isArray(v))v.forEach(walk);else if(v && typeof v === 'object'){if(v.$ref) names.add(v.$ref.split('/').at(-1));Object.values(v).forEach(walk);}};
 walk(schema);
 wire.definitions[name] = rewrite(schema);
}
// Discovery is explicitly validated by its selected profile; existing response
// validation remains unchanged for existing rich readers and saved commands.
const prefix = '// Projected by tool/extract_discovery_wire.mjs; discovery source 558ee6da4299dea49729ebaca5825ce9a235a42e; SHA256 3fdc06616d64e19aa7abf35b548cf1156fa7fbee6bcfb02c1dccf4ce9a9d7052.\n' + original.slice(original.indexOf('const ')).split("r'''",1)[0];
fs.writeFileSync(path,prefix+"r'''\n"+JSON.stringify(wire,null,2)+"\n''';\n");
