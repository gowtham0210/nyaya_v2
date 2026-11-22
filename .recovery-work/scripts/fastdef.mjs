// Fast-default columns: ADD COLUMN ... DEFAULT <const> in drizzle migrations (evidence-based, not guessed).
import fs from 'node:fs';
const dir = '../../backend/drizzle';
export function fastDefaults() {
  const m = {};
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.sql')).sort()) {
    for (const line of fs.readFileSync(`${dir}/${f}`, 'utf8').split('\n')) {
      const r = line.match(/ALTER TABLE "(\w+)" ADD COLUMN "(\w+)" ([^;]*?) DEFAULT (.+?)( NOT NULL)?;/);
      if (!r) continue; let d = r[4].trim(); let v;
      if (d === 'false') v = false; else if (d === 'true') v = true; else if (/^'\{\}'/.test(d)) v = []; else if (/^'.*'$/.test(d) || /^'[^']*'::/.test(d)) v = d.match(/^'([^']*)'/)[1]; else if (/^-?\d+$/.test(d)) v = Number(d); else v = { _unresolved_default: d };
      (m[r[1]] ||= {})[r[2]] = { value: v, migration: f };
    }
  }
  return m;
}
