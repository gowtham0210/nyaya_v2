// Raw heap-page reader for a PGlite (PG18, 32-bit wasm) data dir. READ-ONLY.
import fs from 'node:fs';
import path from 'node:path';

export const BLCKSZ = 8192;
const RELSEG = 131072;

export function readRelPages(dbdir, filenode) {
  const pages = [];
  for (let seg = 0; ; seg++) {
    const f = path.join(dbdir, seg === 0 ? `${filenode}` : `${filenode}.${seg}`);
    if (!fs.existsSync(f)) break;
    const buf = fs.readFileSync(f);
    for (let o = 0; o + BLCKSZ <= buf.length; o += BLCKSZ) pages.push(buf.subarray(o, o + BLCKSZ));
  }
  return pages;
}

/** Yields raw tuples from a page. */
export function* pageTuples(page, blkno) {
  const lower = page.readUInt16LE(12), upper = page.readUInt16LE(14), special = page.readUInt16LE(16);
  if (lower === 0 && upper === 0) return; // new/empty page
  if (lower < 24 || lower > upper || upper > BLCKSZ || special > BLCKSZ) {
    yield { bad: true, blkno, reason: `bad page header lower=${lower} upper=${upper}` };
    return;
  }
  const n = (lower - 24) / 4;
  for (let i = 0; i < n; i++) {
    const lp = page.readUInt32LE(24 + i * 4);
    const off = lp & 0x7fff, flags = (lp >> 15) & 3, len = (lp >> 17) & 0x7fff;
    if (flags !== 1 || len < 23 || off + len > BLCKSZ) continue; // LP_NORMAL only
    const t = page.subarray(off, off + len);
    yield {
      blkno, offnum: i + 1,
      xmin: t.readUInt32LE(0), xmax: t.readUInt32LE(4),
      infomask2: t.readUInt16LE(18), infomask: t.readUInt16LE(20), hoff: t[22],
      ctid: [t.readUInt16LE(12) * 65536 + t.readUInt16LE(14), t.readUInt16LE(16)],
      raw: t,
    };
  }
}

export function pglzDecompress(src, rawsize) {
  const dst = Buffer.alloc(rawsize); let sp = 0, dp = 0;
  while (sp < src.length && dp < rawsize) {
    let ctrl = src[sp++];
    for (let b = 0; b < 8 && sp < src.length && dp < rawsize; b++, ctrl >>= 1) {
      if (ctrl & 1) {
        let len = (src[sp] & 0x0f) + 3, off = ((src[sp] & 0xf0) << 4) | src[sp + 1]; sp += 2;
        if (len === 18) len += src[sp++];
        if (off === 0 || off > dp) throw new Error('pglz bad offset');
        for (let k = 0; k < len && dp < rawsize; k++, dp++) dst[dp] = dst[dp - off];
      } else dst[dp++] = src[sp++];
    }
  }
  if (dp !== rawsize) throw new Error('pglz short');
  return dst;
}

const align = (o, a) => (o + (a - 1)) & ~(a - 1);
const ALIGN = { c: 1, s: 2, i: 4, d: 8 };

/** attrs: [{name, typid, len, byval, align, ...}]; toast: optional (valueoid)=>Buffer */
export function decodeTuple(tp, attrs, toastFetch) {
  const t = tp.raw, natts = tp.infomask2 & 0x7ff, hasnull = tp.infomask & 1;
  const out = {}; const warn = [];
  let off = tp.hoff;
  for (let a = 0; a < attrs.length; a++) {
    const at = attrs[a];
    if (a >= natts) { out[at.name] = null; continue; } // added later -> missing
    if (hasnull && !(t[23 + (a >> 3)] & (1 << (a & 7)))) { out[at.name] = null; continue; }
    const al = ALIGN[at.align] || 1;
    if (at.len === -1) {
      // varlena: 1-byte header needs no alignment
      if (t[off] === 0) off = align(off, 4);
      if (off >= t.length) { warn.push('overrun'); break; }
      const h = t[off];
      let data;
      if (h & 1) {
        if (h === 1) { // TOAST pointer
          const vartag = t[off + 1];
          if (vartag !== 18) { warn.push(`vartag ${vartag}`); off += 2; out[at.name] = { _unreadable: 'toast-tag' }; continue; }
          const rawsize = t.readInt32LE(off + 2), extinfo = t.readUInt32LE(off + 6), valueid = t.readUInt32LE(off + 10), toastrel = t.readUInt32LE(off + 14);
          off += 18;
          const ext = extinfo & 0x3fffffff, comp = ext < rawsize - 4;
          const chunks = toastFetch ? toastFetch(toastrel, valueid) : null;
          if (!chunks) { out[at.name] = { _unreadable: 'toast-missing', valueid }; warn.push('toast-missing'); continue; }
          if (comp) { const tc = chunks.readUInt32LE(0); if ((tc >>> 30) !== 0) { out[at.name] = { _unreadable: "lz4-toast" }; warn.push("lz4"); continue; } data = pglzDecompress(chunks.subarray(4), tc & 0x3fffffff); } else data = chunks;
        } else { const len = h >> 1; data = t.subarray(off + 1, off + len); off += len; }
      } else {
        const hd = t.readUInt32LE(off), len = hd >> 2, compressed = (hd & 3) === 2;
        if (compressed) {
          const rawsize = t.readUInt32LE(off + 4) & 0x3fffffff; const meth = t.readUInt32LE(off + 4) >>> 30;
          if (meth !== 0) { out[at.name] = { _unreadable: 'lz4' }; warn.push('lz4'); off += len; continue; }
          data = pglzDecompress(t.subarray(off + 8, off + len), rawsize);
        } else data = t.subarray(off + 4, off + len);
        off += len;
      }
      out[at.name] = data;
    } else if (at.len === -2) {
      const e = t.indexOf(0, off); out[at.name] = t.subarray(off, e); off = e + 1;
    } else {
      off = align(off, al);
      if (off + at.len > t.length) { warn.push('overrun'); break; }
      out[at.name] = t.subarray(off, off + at.len); off += at.len;
    }
  }
  return { vals: out, warn };
}
