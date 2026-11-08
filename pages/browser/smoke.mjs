#!/usr/bin/env node
// Schema validation for pages/browser/case/*/case.json (Phase 1 smoke check).
// Run: node pages/browser/smoke.mjs   from the repo root
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CASE_DIR = path.join(ROOT, 'pages', 'browser', 'case');
let failed = 0;
const errors = [];

for (const dir of await fs.readdir(CASE_DIR, { withFileTypes: true })) {
  if (!dir.isDirectory()) continue;
  const p = path.join(CASE_DIR, dir.name, 'case.json');
  let raw;
  try { raw = await fs.readFile(p, 'utf8'); }
  catch { errors.push(`${dir.name}: missing case.json`); failed++; continue; }
  let j;
  try { j = JSON.parse(raw); }
  catch (e) { errors.push(`${dir.name}: invalid JSON ${e.message}`); failed++; continue; }
  const base = `${dir.name}: `;
  if (j.id !== dir.name) { errors.push(`${base}id mismatch ${j.id} vs ${dir.name}`); failed++; }
  if (typeof j.title !== 'string') { errors.push(`${base}missing title`); failed++; }
  if (!Array.isArray(j.layers) || j.layers.some(l => typeof l.name !== 'string' || typeof l.text !== 'string')) {
    errors.push(`${base}layers malformed`); failed++;
  }
  if (!Array.isArray(j.ops)) { errors.push(`${base}ops missing`); failed++; }
  else {
    const validOps = ['open','getTimeSamples','get','getMetadata','customData','flatten','primIndex','listOpApply','crateEncodeDecode','usdaRoundTrip','parsePath'];
    j.ops.forEach((o, k) => {
      if (!validOps.includes(o.op)) errors.push(`${base}op[${k}] unknown op ${o.op}`);
      if (typeof o.id !== 'string') errors.push(`${base}op[${k}] missing id`);
    });
  }
  const col = (c) => typeof c === 'object' && c !== null ? Object.keys(c) : [];
  if (j.lean && typeof j.lean !== 'object') errors.push(`${base}lean malformed`);
}

if (failed) {
  console.error(`SMOKE FAILURE: ${failed} issue(s)`);
  for (const e of errors) console.error(' -', e);
  process.exitCode = 1;
} else console.log(`smoke ok: case(s) validated under ${CASE_DIR}`);