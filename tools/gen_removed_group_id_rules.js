const chunkSize = 10;
const chunkCount = 5;

function chunkFunction(base) {
  const lines = [];
  lines.push(`    function removedActiveGroupIdChunk${base}(previousIds, newIds) {`);
  lines.push('      return');
  for (let offset = 0; offset < chunkSize; offset++) {
    const i = base + offset;
    const conds = [`previousIds.size() > ${i}`];
    for (let j = base; j < i; j++) {
      conds.push(`(previousIds[${j}] in newIds.toSet())`);
    }
    conds.push(`!(previousIds[${i}] in newIds.toSet())`);
    const prefix = offset === 0 ? '        ' : '        : ';
    lines.push(`${prefix}(${conds.join(' && ')})`);
    lines.push(`          ? previousIds[${i}]`);
  }
  lines.push("        : '';");
  lines.push('    }');
  return lines.join('\n');
}

const chunks = [];
for (let base = 0; base < chunkSize * chunkCount; base += chunkSize) {
  chunks.push(chunkFunction(base));
}

const dispatcher = [
  '    function removedActiveGroupId(previousIds, newIds) {',
  '      let from0 = removedActiveGroupIdChunk0(previousIds, newIds);',
  '      let from10 = removedActiveGroupIdChunk10(previousIds, newIds);',
  '      let from20 = removedActiveGroupIdChunk20(previousIds, newIds);',
  '      let from30 = removedActiveGroupIdChunk30(previousIds, newIds);',
  '      let from40 = removedActiveGroupIdChunk40(previousIds, newIds);',
  "      return from0 != '' ? from0",
  "        : from10 != '' ? from10",
  "        : from20 != '' ? from20",
  "        : from30 != '' ? from30",
  "        : from40 != '' ? from40",
  "        : '';",
  '    }',
].join('\n');

process.stdout.write(`${dispatcher}\n\n${chunks.join('\n\n')}\n`);
