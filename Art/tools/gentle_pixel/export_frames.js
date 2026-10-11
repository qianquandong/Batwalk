#!/usr/bin/env node
/* Export the Gentle-pixel engine's animation frames into the app.
 *
 *   node Art/tools/gentle_pixel/export_frames.js            # all 32 species
 *   node Art/tools/gentle_pixel/export_frames.js cocoa fox  # a few
 *
 * Writes, per species and action, one imageset per frame:
 *   Apps/Shared/Sprites.xcassets/gen_bat_<id>_<action>_<n>.imageset/{sprite.png, Contents.json}
 * as 128 × 128 PNGs (64 px logical canvas at 2×, nearest-neighbour — the same
 * contract as the hand-drawn pilots), plus a review sheet per species and a
 * manifest in Art/gentle-pixel/generated-frames/. No dependencies: the PNG
 * encoder below is 40 lines on top of Node's zlib.
 *
 * The frame plan (counts, seconds, rest) lives in engine.js PLAN and is
 * mirrored by GeneratedFramePlan in Packages/BatwalkCore/Sources/BatwalkCore/BatAnimation.swift.
 * Change both together. */
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const E = require('./engine.js');

const repo = path.resolve(__dirname, '..', '..', '..');
const catalog = path.join(repo, 'Apps', 'Shared', 'Sprites.xcassets');
const review = path.join(repo, 'Art', 'gentle-pixel', 'generated-frames');
const SCALE = 2;
const PREFIX = 'gen_bat_';

// ---------------------------------------------------------------- png
const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
function crc32(buf) { let c = 0xFFFFFFFF; for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xFF] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function png(width, height, rgba) {
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) { raw[y * (stride + 1)] = 0; rgba.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride); }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0; // 8-bit RGBA
  return Buffer.concat([Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function hex(c) { c = c.replace('#', ''); if (c.length === 3) c = c[0] + c[0] + c[1] + c[1] + c[2] + c[2]; return [parseInt(c.substr(0, 2), 16), parseInt(c.substr(2, 2), 16), parseInt(c.substr(4, 2), 16)]; }

/** One grid → RGBA at `scale`, transparent background. */
function rasterize(grid, scale, bg) {
  const w = E.W * scale, h = E.H * scale, out = Buffer.alloc(w * h * 4);
  for (let y = 0; y < E.H; y++) for (let x = 0; x < E.W; x++) {
    const c = grid.get(x, y);
    const rgb = c ? hex(c) : bg;
    if (!rgb) continue;
    for (let dy = 0; dy < scale; dy++) for (let dx = 0; dx < scale; dx++) {
      const i = ((y * scale + dy) * w + (x * scale + dx)) * 4;
      out[i] = rgb[0]; out[i + 1] = rgb[1]; out[i + 2] = rgb[2]; out[i + 3] = 255;
    }
  }
  return { w, h, rgba: out };
}

/** Blit a rasterized cell into a sheet. */
function blit(sheet, cell, ox, oy) {
  for (let y = 0; y < cell.h; y++) {
    cell.rgba.copy(sheet.rgba, ((oy + y) * sheet.w + ox) * 4, y * cell.w * 4, (y + 1) * cell.w * 4);
  }
}

// ---------------------------------------------------------------- export
const wanted = process.argv.slice(2);
const species = E.SPECIES.filter(s => !wanted.length || wanted.includes(s.id));
if (!species.length) { console.error('no such species:', wanted.join(' ')); process.exit(1); }
fs.mkdirSync(catalog, { recursive: true });
fs.mkdirSync(review, { recursive: true });

const contents = JSON.stringify({ images: [{ filename: 'sprite.png', idiom: 'universal', scale: '2x' }], info: { author: 'xcode', version: 1 } }, null, 2) + '\n';
let written = 0;
const manifest = { version: 2, engine: 'Art/tools/gentle_pixel/engine.js', prefix: PREFIX, logicalSize: E.W, scale: SCALE, plan: E.PLAN, species: {} };
const bgSheet = [0x1C, 0x2E, 0x32];

for (const s of species) {
  const maxFrames = Math.max(...E.ACTIONS.map(a => E.POSES[a].length));
  const sheet = { w: maxFrames * E.W * SCALE, h: E.ACTIONS.length * E.H * SCALE, rgba: Buffer.alloc(maxFrames * E.W * SCALE * E.ACTIONS.length * E.H * SCALE * 4) };
  for (let i = 0; i < sheet.w * sheet.h; i++) { sheet.rgba[i * 4] = bgSheet[0]; sheet.rgba[i * 4 + 1] = bgSheet[1]; sheet.rgba[i * 4 + 2] = bgSheet[2]; sheet.rgba[i * 4 + 3] = 255; }
  manifest.species[s.id] = {};
  E.ACTIONS.forEach((action, row) => {
    const frames = E.frameGrids(s.id, action, false);
    manifest.species[s.id][action] = frames.map(f => `${PREFIX}${s.id}_${action}_${f.index}`);
    for (const f of frames) {
      const name = `${PREFIX}${s.id}_${action}_${f.index}`;
      const dir = path.join(catalog, `${name}.imageset`);
      fs.mkdirSync(dir, { recursive: true });
      const cell = rasterize(f.grid, SCALE, null);
      fs.writeFileSync(path.join(dir, 'sprite.png'), png(cell.w, cell.h, cell.rgba));
      fs.writeFileSync(path.join(dir, 'Contents.json'), contents);
      blit(sheet, rasterize(f.grid, SCALE, bgSheet), f.index * E.W * SCALE, row * E.H * SCALE);
      written++;
    }
  });
  fs.writeFileSync(path.join(review, `${s.id}.png`), png(sheet.w, sheet.h, sheet.rgba));
}

fs.writeFileSync(path.join(review, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`${written} frames for ${species.length} species → ${path.relative(repo, catalog)}; review sheets in ${path.relative(repo, review)}`);
