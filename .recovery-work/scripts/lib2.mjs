// Type decoding helpers (READ-ONLY recovery tooling).
import crypto from 'node:crypto';
import { readRelPages, pageTuples } from './heap.mjs';
import { visibility } from './lib.mjs';

const nm = (b) => { const e = b.indexOf(0); return b.subarray(0, e < 0 ? b.length : e).toString('utf8'); };

export function readTypes(cl) {
  const types = new Map(), enums = new Map();
  readRelPages(cl.dbdir, 1247).forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
    if (tp.bad || visibility(cl, tp).state !== 'live') continue; const d = tp.raw.subarray(tp.hoff);
    types.set(d.readUInt32LE(0), { name: nm(d.subarray(4, 68)), typtype: String.fromCharCode(d[79]) });
  } });
  readRelPages(cl.dbdir, 3501).forEach((p, blk) => { for (const tp of pageTuples(p, blk)) {
    if (tp.bad || visibility(cl, tp).state !== 'live') continue; const d = tp.raw.subarray(tp.hoff);
    enums.set(d.readUInt32LE(0), nm(d.subarray(12, 76)));
  } });
  return { types, enums };
}

export function numericStr(b, hasHdr = true) {
  let o = !hasHdr ? 0 : (b[0] & 1) ? 1 : 4;
  const hd = b.readUInt16LE(o); o += 2;
  const sb = hd & 0xc000;
  if (sb === 0xc000) return hd === 0xc000 ? 'NaN' : (hd === 0xd000 ? 'Infinity' : '-Infinity');
  let sign, dscale, weight;
  if (sb === 0x8000) { sign = hd & 0x2000 ? '-' : ''; dscale = (hd & 0x1f80) >> 7; weight = (hd & 0x3f) - (hd & 0x40 ? 64 : 0); }
  else { sign = sb === 0x4000 ? '-' : ''; dscale = hd & 0x3fff; weight = b.readInt16LE(o); o += 2; }
  const digits = []; for (; o + 2 <= b.length; o += 2) digits.push(b.readUInt16LE(o));
  let int = '';
  for (let i = 0; i <= weight; i++) int += String(digits[i] ?? 0).padStart(4, '0');
  int = int.replace(/^0+(?=\d)/, '') || '0';
  let frac = '';
  for (let k = 0; frac.length < dscale; k++) frac += String(digits[weight + 1 + k] ?? 0).padStart(4, '0');
  frac = frac.slice(0, dscale);
  return sign + int + (dscale ? '.' + frac : '');
}

export function jsonbDecode(buf) {
  function container(o) {
    const hd = buf.readUInt32LE(o), n = hd & 0x0fffffff, isObj = !!(hd & 0x20000000), scalar = !!(hd & 0x10000000);
    const cnt = isObj ? n * 2 : n; const ent = o + 4; const dataStart = ent + cnt * 4;
    const items = []; let pos = 0;
    for (let i = 0; i < cnt; i++) {
      const e = buf.readUInt32LE(ent + i * 4), type = e & 0x70000000, v = e & 0x0fffffff, hasoff = !!(e & 0x80000000);
      const start = pos, end = hasoff ? v : start + v;
      let s = start; if (type === 0x10000000 || type === 0x50000000) s = (start + 3) & ~3;
      const abs = dataStart + s; let val;
      if (type === 0) val = buf.subarray(dataStart + start, dataStart + end).toString('utf8');
      else if (type === 0x10000000) val = { $numeric: numericStr(buf.subarray(abs, dataStart + end)) };
      else if (type === 0x20000000) val = false; else if (type === 0x30000000) val = true; else if (type === 0x40000000) val = null;
      else val = container(abs);
      items.push(val); pos = end;
    }
    if (isObj) { const out = {}; for (let i = 0; i < n; i++) out[items[i]] = items[n + i]; return out; }
    return scalar ? items[0] : items;
  }
  const fix = (x) => Array.isArray(x) ? x.map(fix)
    : x && typeof x === 'object' ? ('$numeric' in x ? Number(x.$numeric) : Object.fromEntries(Object.entries(x).map(([k, v]) => [k, fix(v)]))) : x;
  return fix(container(0));
}

export function uuidStr(b) { const h = b.toString('hex'); return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`; }

function arrayDecode(b, types) {
  const ndim = b.readInt32LE(0), flags = b.readInt32LE(4), elemtype = b.readUInt32LE(8);
  if (ndim === 0) return [];
  const dims = []; let o = 12;
  for (let i = 0; i < ndim; i++) { dims.push(b.readInt32LE(o)); o += 8; }
  const total = dims.reduce((a, c) => a * c, 1);
  const hasnull = !!(flags & 1); let p = hasnull ? ((o + Math.ceil(total / 8) + 3) & ~3) : ((o + 3) & ~3);
  const bm = o; const out = []; const et = types.get(elemtype); const tn = et?.name;
  for (let i = 0; i < total; i++) {
    if (hasnull && !(b[bm + (i >> 3)] & (1 << (i & 7)))) { out.push(null); continue; }
    if (tn === 'text' || tn === 'varchar') {
      const h = b[p];
      if (h & 1) { const len = h >> 1; out.push(b.subarray(p + 1, p + len).toString('utf8')); p += len; }
      else { p = (p + 3) & ~3; const len = b.readUInt32LE(p) >> 2; out.push(b.subarray(p + 4, p + len).toString('utf8')); p += len; }
    } else if (et?.typtype === 'e') { p = (p + 3) & ~3; out.push({ enumOid: b.readUInt32LE(p) }); p += 4; }
    else if (tn === 'uuid') { out.push(uuidStr(b.subarray(p, p + 16))); p += 16; }
    else if (tn === 'int4') { p = (p + 3) & ~3; out.push(b.readInt32LE(p)); p += 4; }
    else return { _unreadable: `array of ${tn}` };
  }
  return ndim === 1 ? out : { dims, data: out };
}

const PG_EPOCH_MS = 946684800000;
export function convert(at, buf, ctx) {
  if (buf === null || buf === undefined) return null;
  if (!Buffer.isBuffer(buf)) return buf;
  const ty = ctx.types.get(at.typid); const tn = ty?.name;
  try {
    if (ty?.typtype === 'e') return ctx.enums.get(buf.readUInt32LE(0)) ?? { _unreadable: 'enum oid ' + buf.readUInt32LE(0) };
    switch (tn) {
      case 'bool': return !!buf[0];
      case 'int2': return buf.readInt16LE(0);
      case 'int4': return buf.readInt32LE(0);
      case 'int8': return buf.readBigInt64LE(0).toString();
      case 'oid': return buf.readUInt32LE(0);
      case 'float4': return buf.readFloatLE(0);
      case 'float8': return buf.readDoubleLE(0);
      case 'uuid': return uuidStr(buf);
      case 'text': case 'varchar': case 'bpchar': case 'name': return buf.toString('utf8');
      case 'timestamptz': case 'timestamp': {
        const us = buf.readBigInt64LE(0); const ms = Number(us / 1000n) + PG_EPOCH_MS;
        const frac = String(((us % 1000000n) + 1000000n) % 1000000n).padStart(6, '0');
        return new Date(ms).toISOString().replace(/\.\d{3}Z$/, `.${frac}Z`);
      }
      case 'date': return new Date(buf.readInt32LE(0) * 86400000 + PG_EPOCH_MS).toISOString().slice(0, 10);
      case "numeric": return numericStr(buf, false);
      case 'jsonb': return jsonbDecode(buf);
      case 'json': return JSON.parse(buf.toString('utf8'));
      case 'bytea': return { _bytea_len: buf.length, _sha: crypto.createHash('sha256').update(buf).digest('hex').slice(0, 16) };
      case '_text': case '_varchar': case '_uuid': case '_int4': return arrayDecode(buf, ctx.types);
      default: return { _unreadable: `type ${tn ?? at.typid}`, _hex: buf.subarray(0, 32).toString('hex') };
    }
  } catch (e) { return { _unreadable: 'decode error: ' + e.message }; }
}
